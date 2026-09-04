import { config } from "./config.js";
import { query } from "./db.js";
import {
  isApnsConfigured,
  isInvalidDeviceToken,
  isTransientApnsStatus,
  sendApnsNotification,
  type ApnsApp
} from "./lib/apns.js";
import { lookupItunesPodcast } from "./lib/itunes.js";
import { fetchText } from "./lib/http.js";
import { notifyWorthyEpisodes, parseRssFeed } from "./lib/rss.js";
import { fetchStreamingServices } from "./lib/tmdb.js";
import { persistStreamingProviders } from "./lib/streaming-cache.js";
import { bumpWatchedIt } from "./lib/admin-catalog.js";
import { resolveNowPlaying } from "./lib/theater-stays.js";
import { ingestPodcastEpisode, purgePodcastNoiseMovies } from "./lib/podcast-ingest.js";
import { rematchClosetPicks } from "./lib/closet-picks-rematch.js";

type JobStats = Record<string, number | string | boolean | undefined>;
type JobReport = (stats: JobStats) => Promise<void>;

const backgroundJobNames = new Set<string>();

const bumpRevision = async (app: "watchedit" | "podlink") => {
  await query(
    `UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = $1`,
    [app]
  );
};

const writeJobStats = async (id: string, stats: JobStats) => {
  await query(`UPDATE job_runs SET stats = $2 WHERE id = $1 AND status = 'running'`, [id, JSON.stringify(stats)]);
};

const finishJobOk = async (id: string, stats: JobStats) => {
  await query(`UPDATE job_runs SET status = 'ok', finished_at = NOW(), stats = $2 WHERE id = $1`, [
    id,
    JSON.stringify(stats)
  ]);
};

const finishJobError = async (id: string, message: string) => {
  await query(`UPDATE job_runs SET status = 'error', finished_at = NOW(), error = $2 WHERE id = $1`, [id, message]);
};

export const markInterruptedJobs = async () => {
  await query(
    `UPDATE job_runs
     SET status = 'error', finished_at = NOW(), error = 'interrupted (process restart)'
     WHERE status = 'running'`
  );
};

const recordJob = async (name: string, runner: (report: JobReport) => Promise<JobStats>) => {
  const inserted = await query(
    `INSERT INTO job_runs (name, status) VALUES ($1, 'running') RETURNING id`,
    [name]
  );
  const id = inserted.rows[0].id as string;
  try {
    const stats = await runner((next) => writeJobStats(id, next));
    await finishJobOk(id, stats);
    return { id, name, status: "ok" as const, stats };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await finishJobError(id, message);
    return { id, name, status: "error" as const, error: message };
  }
};

const startBackgroundJob = async (name: string, runner: (report: JobReport) => Promise<JobStats>) => {
  if (backgroundJobNames.has(name)) {
    const existing = await query(
      `SELECT id FROM job_runs WHERE name = $1 AND status = 'running' ORDER BY started_at DESC LIMIT 1`,
      [name]
    );
    return { id: existing.rows[0]?.id as string | undefined, name, status: "already_running" as const };
  }
  const existing = await query(
    `SELECT id FROM job_runs WHERE name = $1 AND status = 'running' ORDER BY started_at DESC LIMIT 1`,
    [name]
  );
  if (existing.rows.length) {
    return { id: existing.rows[0].id as string, name, status: "already_running" as const };
  }

  backgroundJobNames.add(name);
  const inserted = await query(
    `INSERT INTO job_runs (name, status, stats) VALUES ($1, 'running', $2::jsonb) RETURNING id`,
    [name, JSON.stringify({ phase: "starting" })]
  );
  const id = inserted.rows[0].id as string;

  void (async () => {
    try {
      const stats = await runner((next) => writeJobStats(id, next));
      await finishJobOk(id, stats);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`${name} failed:`, error);
      await finishJobError(id, message);
    } finally {
      backgroundJobNames.delete(name);
    }
  })();

  return { id, name, status: "running" as const };
};

const upsertEpisode = async (
  podcastId: string,
  episode: ReturnType<typeof parseRssFeed>["episodes"][number]
) => {
  const id = `${podcastId}:${episode.guid}`.slice(0, 180);
  await query(
    `
    INSERT INTO pod_episodes (
      id, podcast_id, guid, title, description, publish_date, duration_seconds,
      audio_url, video_url, artwork_url, episode_number, season_number, updated_at
    ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW())
    ON CONFLICT (id) DO UPDATE SET
      title = EXCLUDED.title,
      description = EXCLUDED.description,
      publish_date = EXCLUDED.publish_date,
      duration_seconds = EXCLUDED.duration_seconds,
      audio_url = EXCLUDED.audio_url,
      video_url = EXCLUDED.video_url,
      artwork_url = EXCLUDED.artwork_url,
      updated_at = NOW()
    `,
    [
      id,
      podcastId,
      episode.guid,
      episode.title,
      episode.description,
      episode.publishDate,
      episode.durationSeconds,
      episode.audioUrl,
      episode.videoUrl,
      episode.artworkUrl,
      episode.episodeNumber,
      episode.seasonNumber
    ]
  );
};

export const refreshStreamingCatalog = async (limit = 200) => {
  return recordJob("mov.streaming.refresh", async () => {
    if (!config.tmdbApiKey) {
      return { skipped: 1, reason: "missing-tmdb-key" };
    }
    const movies = await query(
      `
      SELECT m.id, m.tmdb_id
      FROM mov_movies m
      LEFT JOIN mov_streaming s ON s.movie_id = m.id AND s.region = $1
      WHERE m.tmdb_id IS NOT NULL
      ORDER BY s.refreshed_at ASC NULLS FIRST
      LIMIT $2
      `,
      [config.tmdbRegion, limit]
    );
    let updated = 0;
    let failed = 0;
    for (const row of movies.rows) {
      try {
        const providers = await fetchStreamingServices(
          Number(row.tmdb_id),
          config.tmdbApiKey,
          config.tmdbRegion
        );
        await persistStreamingProviders(String(row.id), providers);
        updated += 1;
      } catch {
        failed += 1;
      }
    }
    if (updated > 0) {
      await bumpRevision("watchedit");
    }
    return { scanned: movies.rowCount ?? 0, updated, failed, region: config.tmdbRegion };
  });
};

export const refreshTheaterStays = async () => {
  return recordJob("mov.theaters.refresh", async () => {
    if (!config.tmdbApiKey) {
      return { skipped: 1, reason: "missing-tmdb-key" };
    }
    const catalog = await query(`SELECT tmdb_id FROM mov_movies WHERE tmdb_id IS NOT NULL`);
    const catalogIds = new Set(
      catalog.rows
        .map((row) => Number(row.tmdb_id))
        .filter((id) => Number.isFinite(id))
    );
    const payload = await resolveNowPlaying(config.tmdbApiKey, config.tmdbRegion, catalogIds, {
      force: true
    });
    return {
      updated: payload.movies.length,
      imax: payload.movies.filter((movie) => movie.hasIMAX).length,
      ticketLinks: payload.movies.filter((movie) => movie.ticketLinks).length,
      region: config.tmdbRegion,
      source: payload.source
    };
  });
};

export const refreshPodcastFeeds = async (limit = 80) => {
  return recordJob("pod.feeds.refresh", async () => {
    const podcasts = await query(
      `
      SELECT id, feed_url, title
      FROM pod_podcasts
      ORDER BY updated_at ASC
      LIMIT $1
      `,
      [limit]
    );
    let refreshed = 0;
    let newEpisodes = 0;
    let failed = 0;
    const discovered: Array<{ podcastId: string; title: string; episodeTitle: string; publishDate: string | null }> =
      [];
    for (const row of podcasts.rows) {
      try {
        const latest = await query(
          `SELECT MAX(publish_date) AS latest FROM pod_episodes WHERE podcast_id = $1`,
          [row.id]
        );
        const previousLatest = latest.rows[0]?.latest
          ? new Date(latest.rows[0].latest as string).toISOString()
          : null;
        const xml = await fetchText(String(row.feed_url));
        const parsed = parseRssFeed(xml);
        for (const episode of parsed.episodes) {
          await upsertEpisode(String(row.id), episode);
        }
        const fresh = notifyWorthyEpisodes(parsed.episodes, previousLatest);
        newEpisodes += fresh.length;
        for (const episode of fresh) {
          discovered.push({
            podcastId: String(row.id),
            title: String(row.title),
            episodeTitle: episode.title,
            publishDate: episode.publishDate
          });
        }
        await query(
          `
          UPDATE pod_podcasts
          SET title = COALESCE(NULLIF($2, ''), title),
              author = COALESCE(NULLIF($3, ''), author),
              description = COALESCE(NULLIF($4, ''), description),
              artwork_url = COALESCE($5, artwork_url),
              updated_at = NOW()
          WHERE id = $1
          `,
          [row.id, parsed.meta.title, parsed.meta.author, parsed.meta.description, parsed.meta.artworkUrl]
        );
        refreshed += 1;
      } catch {
        failed += 1;
      }
    }
    if (refreshed > 0) {
      await bumpRevision("podlink");
    }
    if (discovered.length) {
      await enqueueNewEpisodeNotifications(discovered);
    }
    return { scanned: podcasts.rowCount ?? 0, refreshed, newEpisodes, failed };
  });
};

export const refreshMoviePodcastSources = async () => {
  return recordJob("mov.feeds.refresh", async () => {
    const purged = await purgePodcastNoiseMovies();
    const sources = await query(
      `SELECT identifier, name, url FROM mov_sources WHERE type = 'podcast' AND enabled = TRUE AND url IS NOT NULL`
    );
    let refreshed = 0;
    let failed = 0;
    let addedMovies = 0;
    let skippedMovies = 0;
    for (const source of sources.rows) {
      try {
        const xml = await fetchText(String(source.url));
        const parsed = parseRssFeed(xml);
        const podcastId = `movsrc-${source.identifier}`;
        await query(
          `
          INSERT INTO pod_podcasts (id, title, author, feed_url, description, artwork_url, categories, updated_at)
          VALUES ($1, $2, $3, $4, $5, $6, '["Movies"]'::jsonb, NOW())
          ON CONFLICT (id) DO UPDATE SET
            title = EXCLUDED.title,
            description = EXCLUDED.description,
            artwork_url = COALESCE(EXCLUDED.artwork_url, pod_podcasts.artwork_url),
            updated_at = NOW()
          `,
          [
            podcastId,
            parsed.meta.title || source.name,
            parsed.meta.author,
            source.url,
            parsed.meta.description,
            parsed.meta.artworkUrl
          ]
        );
        for (const episode of parsed.episodes.slice(0, 40)) {
          await upsertEpisode(podcastId, episode);
        }
        const existing = await query(
          `SELECT source_title FROM mov_movie_sources WHERE source_id = $1 AND source_title IS NOT NULL`,
          [source.identifier]
        );
        const existingTitles = new Set(existing.rows.map((row) => String(row.source_title)));
        for (const episode of parsed.episodes.slice(0, 12)) {
          const result = await ingestPodcastEpisode({
            title: episode.title,
            sourceTitle: episode.title,
            sourceIdentifier: String(source.identifier),
            episodeDate: episode.publishDate,
            description: episode.description,
            existingTitles,
            bump: false
          });
          if (result.added) {
            addedMovies += 1;
          } else {
            skippedMovies += 1;
          }
        }
        refreshed += 1;
      } catch {
        failed += 1;
      }
    }
    if (addedMovies > 0) {
      await bumpWatchedIt();
    }
    return {
      scanned: sources.rowCount ?? 0,
      refreshed,
      failed,
      addedMovies,
      skippedMovies,
      purgedMovies: purged.purgedMovies,
      purgedLinks: purged.purgedLinks
    };
  });
};

const enqueueNewEpisodeNotifications = async (
  episodes: Array<{ podcastId: string; title: string; episodeTitle: string; publishDate: string | null }>
) => {
  const subscribers = await query(
    `
    SELECT user_id, podcast_id, notifications_enabled
    FROM user_library_pod
    WHERE is_followed = TRUE
    `
  );
  const deviceSubs = await query(
    `
    SELECT ds.device_id, ds.item_id AS podcast_id, ds.notifications_enabled, d.user_id
    FROM device_subscriptions ds
    JOIN devices d ON d.id = ds.device_id
    WHERE ds.kind = 'pod'
    `
  );
  const prefs = await query(
    `SELECT user_id, app, preferences FROM notification_preferences`
  );
  const prefByUser = new Map<string, Record<string, unknown>>();
  for (const row of prefs.rows) {
    prefByUser.set(`${row.user_id}:${row.app}`, (row.preferences ?? {}) as Record<string, unknown>);
  }
  const byPodcast = new Map<string, typeof subscribers.rows>();
  for (const row of subscribers.rows) {
    const list = byPodcast.get(String(row.podcast_id)) ?? [];
    list.push(row);
    byPodcast.set(String(row.podcast_id), list);
  }
  const devicesByPodcast = new Map<string, typeof deviceSubs.rows>();
  for (const row of deviceSubs.rows) {
    const list = devicesByPodcast.get(String(row.podcast_id)) ?? [];
    list.push(row);
    devicesByPodcast.set(String(row.podcast_id), list);
  }

  let enqueued = 0;
  for (const episode of episodes) {
    const users = byPodcast.get(episode.podcastId) ?? [];
    const notifiedUsers = new Set<string>();
    for (const user of users) {
      const podPrefs = prefByUser.get(`${user.user_id}:podlink`) ?? {};
      const movPrefs = prefByUser.get(`${user.user_id}:watchedit`) ?? {};
      const priority = (podPrefs.priority_podcasts as { enabled?: boolean; priorityPodcastIds?: string[] } | undefined)
        ?? { enabled: Boolean(user.notifications_enabled) };
      const morning = podPrefs.morning_queue as { enabled?: boolean } | undefined;
      const movEpisodes = movPrefs.new_episodes as { enabled?: boolean } | undefined;
      const isPriority =
        Boolean(user.notifications_enabled) ||
        Boolean(priority.enabled && priority.priorityPodcastIds?.includes(episode.podcastId));
      if (!isPriority && !morning?.enabled && !movEpisodes?.enabled) {
        continue;
      }
      const app = episode.podcastId.startsWith("movsrc-") ? "watchedit" : "podlink";
      await query(
        `
        INSERT INTO notification_queue (user_id, app, type, title, body, payload)
        VALUES ($1, $2, $3, $4, $5, $6::jsonb)
        `,
        [
          user.user_id,
          app,
          isPriority ? "priority_podcasts" : "new_episodes",
          episode.title,
          episode.episodeTitle,
          JSON.stringify(episode)
        ]
      );
      notifiedUsers.add(String(user.user_id));
      enqueued += 1;
    }

    const devices = devicesByPodcast.get(episode.podcastId) ?? [];
    for (const device of devices) {
      if (device.user_id && notifiedUsers.has(String(device.user_id))) {
        continue;
      }
      if (!device.notifications_enabled) {
        continue;
      }
      const app = episode.podcastId.startsWith("movsrc-") ? "watchedit" : "podlink";
      await query(
        `
        INSERT INTO notification_queue (user_id, device_id, app, type, title, body, payload)
        VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb)
        `,
        [
          device.user_id ?? null,
          device.device_id,
          app,
          "priority_podcasts",
          episode.title,
          episode.episodeTitle,
          JSON.stringify(episode)
        ]
      );
      enqueued += 1;
    }
  }
  return enqueued;
};

const pushTokensForNotification = async (row: {
  user_id: string | null;
  device_id: string | null;
  app: string;
}) => {
  const tokens = new Set<string>();
  if (row.device_id) {
    const device = await query(`SELECT push_token FROM devices WHERE id = $1 AND push_token IS NOT NULL`, [
      row.device_id
    ]);
    for (const item of device.rows) {
      if (item.push_token) {
        tokens.add(String(item.push_token));
      }
    }
  }
  if (row.user_id) {
    const devices = await query(
      `SELECT push_token FROM devices WHERE user_id = $1 AND app = $2 AND push_token IS NOT NULL`,
      [row.user_id, row.app]
    );
    for (const item of devices.rows) {
      if (item.push_token) {
        tokens.add(String(item.push_token));
      }
    }
  }
  return [...tokens];
};

const clearInvalidPushToken = async (token: string) => {
  await query(`UPDATE devices SET push_token = NULL, updated_at = NOW() WHERE push_token = $1`, [token]);
};

export const dispatchNotifications = async () => {
  return recordJob("notifications.dispatch", async () => {
    const pending = await query(
      `
      SELECT id, user_id, device_id, app, type, title, body, payload
      FROM notification_queue
      WHERE sent_at IS NULL AND scheduled_for <= NOW()
      ORDER BY scheduled_for ASC
      LIMIT 200
      `
    );
    let delivered = 0;
    let pushed = 0;
    let failed = 0;
    let deferred = 0;
    const canPush = isApnsConfigured();
    for (const row of pending.rows) {
      const tokens = canPush ? await pushTokensForNotification(row) : [];
      if (!canPush || tokens.length === 0) {
        await query(`UPDATE notification_queue SET sent_at = NOW() WHERE id = $1`, [row.id]);
        delivered += 1;
        continue;
      }
      let anySuccess = false;
      let anyTransient = false;
      for (const token of tokens) {
        try {
          const result = await sendApnsNotification({
            token,
            app: row.app === "watchedit" ? "watchedit" : ("podlink" as ApnsApp),
            title: String(row.title),
            body: String(row.body),
            type: String(row.type),
            payload: (row.payload ?? {}) as Record<string, unknown>
          });
          if (result.status >= 200 && result.status < 300) {
            anySuccess = true;
            pushed += 1;
            continue;
          }
          if (isInvalidDeviceToken(result)) {
            await clearInvalidPushToken(token);
            failed += 1;
            continue;
          }
          if (isTransientApnsStatus(result.status)) {
            anyTransient = true;
            failed += 1;
            continue;
          }
          failed += 1;
        } catch {
          anyTransient = true;
          failed += 1;
        }
      }
      if (anySuccess || !anyTransient) {
        await query(`UPDATE notification_queue SET sent_at = NOW() WHERE id = $1`, [row.id]);
        delivered += 1;
      } else {
        deferred += 1;
      }
    }
    return {
      pending: pending.rowCount ?? 0,
      delivered,
      pushed,
      failed,
      deferred,
      apnsConfigured: canPush
    };
  });
};

export const enrichDefaultPodcasts = async () => {
  return recordJob("pod.itunes.enrich", async () => {
    const rows = await query(
      `SELECT id, itunes_id FROM pod_podcasts WHERE itunes_id IS NOT NULL AND (feed_url = '' OR artwork_url IS NULL)`
    );
    let updated = 0;
    for (const row of rows.rows) {
      const found = await lookupItunesPodcast(String(row.itunes_id));
      if (!found?.feedUrl) {
        continue;
      }
      await query(
        `
        UPDATE pod_podcasts
        SET title = $2, author = $3, feed_url = $4, artwork_url = $5, artwork_url_600 = $6,
            categories = $7::jsonb, website_url = $8, updated_at = NOW()
        WHERE id = $1
        `,
        [
          row.id,
          found.title,
          found.author,
          found.feedUrl,
          found.artworkUrl,
          found.artworkUrl600,
          JSON.stringify(found.categories),
          found.websiteUrl
        ]
      );
      updated += 1;
    }
    if (updated > 0) {
      await bumpRevision("podlink");
    }
    return { scanned: rows.rowCount ?? 0, updated };
  });
};

export const rematchClosetPicksCatalog = async () => {
  return startBackgroundJob("mov.closet.rematch", async (report) => {
    const result = await rematchClosetPicks({
      fetchFilmPages: true,
      onProgress: (progress) => report(progress)
    });
    return {
      phase: "done",
      scanned: result.scanned,
      matched: result.matched,
      corrected: result.corrected,
      unchanged: result.unchanged,
      added: result.added,
      missing: result.missing
    };
  });
};

export const runNamedJob = async (name: string) => {
  switch (name) {
    case "mov.streaming.refresh":
      return refreshStreamingCatalog();
    case "mov.theaters.refresh":
      return refreshTheaterStays();
    case "pod.feeds.refresh":
      return refreshPodcastFeeds();
    case "mov.feeds.refresh":
      return refreshMoviePodcastSources();
    case "notifications.dispatch":
      return dispatchNotifications();
    case "pod.itunes.enrich":
      return enrichDefaultPodcasts();
    case "mov.closet.rematch":
      return rematchClosetPicksCatalog();
    case "all":
      return {
        streaming: await refreshStreamingCatalog(),
        theaters: await refreshTheaterStays(),
        podFeeds: await refreshPodcastFeeds(),
        movFeeds: await refreshMoviePodcastSources(),
        notifications: await dispatchNotifications()
      };
    default:
      throw new Error(`Unknown job: ${name}`);
  }
};

export const startJobScheduler = () => {
  if (!config.enableJobs) {
    return;
  }
  const hour = 60 * 60 * 1000;
  setTimeout(() => {
    void runNamedJob("pod.feeds.refresh");
  }, 15_000);
  setInterval(() => {
    void runNamedJob("pod.feeds.refresh");
  }, 30 * 60 * 1000);
  setInterval(() => {
    void runNamedJob("mov.streaming.refresh");
  }, 6 * hour);
  setInterval(() => {
    void runNamedJob("mov.theaters.refresh");
  }, 6 * hour);
  setInterval(() => {
    void runNamedJob("mov.feeds.refresh");
  }, 2 * hour);
  setInterval(() => {
    void runNamedJob("notifications.dispatch");
  }, 15 * 60 * 1000);
};
