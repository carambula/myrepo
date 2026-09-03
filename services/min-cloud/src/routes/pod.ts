import { Router } from "express";
import { query } from "../db.js";
import { fetchText } from "../lib/http.js";
import { searchItunesPodcasts } from "../lib/itunes.js";
import { parseRssFeed } from "../lib/rss.js";
import { ensurePodcast } from "../lib/podcasts.js";
import { upsertAnonymousDevice } from "../lib/devices.js";

const router = Router();

const mapPodcast = (row: Record<string, unknown>) => ({
  id: row.id,
  itunesId: row.itunes_id,
  title: row.title,
  author: row.author,
  feedUrl: row.feed_url,
  artworkUrl: row.artwork_url,
  artworkUrl600: row.artwork_url_600,
  categories: row.categories ?? [],
  language: row.language,
  description: row.description,
  websiteUrl: row.website_url,
  isExplicit: row.is_explicit,
  updatedAt: row.updated_at
});

const mapEpisode = (row: Record<string, unknown>) => ({
  id: row.id,
  podcastId: row.podcast_id,
  guid: row.guid,
  title: row.title,
  description: row.description,
  publishDate: row.publish_date,
  duration: Number(row.duration_seconds ?? 0),
  audioUrl: row.audio_url,
  videoUrl: row.video_url,
  artworkUrl: row.artwork_url,
  episodeNumber: row.episode_number,
  seasonNumber: row.season_number
});

router.get("/catalog", async (req, res) => {
  const since = typeof req.query.updatedSince === "string" ? req.query.updatedSince : null;
  const revision = await query(`SELECT revision, generated_at FROM catalog_revisions WHERE app = 'podlink'`);
  const params: string[] = [];
  let where = "";
  if (since) {
    params.push(since);
    where = `WHERE updated_at > $1`;
  }
  const podcasts = await query(
    `SELECT * FROM pod_podcasts ${where} ORDER BY title ASC`,
    params
  );
  const categories = await query(`SELECT name, sort_order FROM pod_categories ORDER BY sort_order, name`);
  res.json({
    app: "podlink",
    revision: Number(revision.rows[0]?.revision ?? 0),
    generatedAt: revision.rows[0]?.generated_at ?? null,
    categories: categories.rows,
    podcasts: podcasts.rows.map(mapPodcast)
  });
});

router.get("/podcasts/:id", async (req, res) => {
  const result = await query(
    `SELECT * FROM pod_podcasts WHERE id = $1 OR itunes_id = $1 OR feed_url = $1`,
    [String(req.params.id)]
  );
  if (!result.rowCount) {
    res.status(404).json({ error: "Podcast not found." });
    return;
  }
  res.json({ podcast: mapPodcast(result.rows[0]) });
});

router.get("/podcasts/:id/episodes", async (req, res) => {
  const podcast = await query(
    `SELECT id FROM pod_podcasts WHERE id = $1 OR itunes_id = $1 OR feed_url = $1`,
    [String(req.params.id)]
  );
  if (!podcast.rowCount) {
    res.status(404).json({ error: "Podcast not found." });
    return;
  }
  const limit = Math.min(Number(req.query.limit) || 50, 200);
  const episodes = await query(
    `SELECT * FROM pod_episodes WHERE podcast_id = $1 ORDER BY publish_date DESC NULLS LAST LIMIT $2`,
    [podcast.rows[0].id, limit]
  );
  res.json({
    podcastId: podcast.rows[0].id,
    episodes: episodes.rows.map(mapEpisode),
    source: "catalog"
  });
});

router.get("/feeds", async (req, res) => {
  const feedUrl = typeof req.query.url === "string" ? req.query.url : "";
  if (!feedUrl) {
    res.status(400).json({ error: "url query parameter required." });
    return;
  }
  const cachedPodcast = await query(`SELECT id FROM pod_podcasts WHERE feed_url = $1`, [feedUrl]);
  if (cachedPodcast.rowCount) {
    const episodes = await query(
      `SELECT * FROM pod_episodes WHERE podcast_id = $1 ORDER BY publish_date DESC NULLS LAST LIMIT 80`,
      [cachedPodcast.rows[0].id]
    );
    if (episodes.rowCount) {
      res.json({
        podcastId: cachedPodcast.rows[0].id,
        episodes: episodes.rows.map(mapEpisode),
        source: "catalog"
      });
      return;
    }
  }
  try {
    const xml = await fetchText(feedUrl);
    const parsed = parseRssFeed(xml);
    res.json({
      meta: parsed.meta,
      episodes: parsed.episodes,
      source: "live"
    });
  } catch (error) {
    res.status(502).json({ error: error instanceof Error ? error.message : "Feed fetch failed." });
  }
});

router.post("/watch", async (req, res) => {
  const deviceKey = String(req.body?.deviceId || "").trim();
  if (!deviceKey) {
    res.status(400).json({ error: "deviceId required." });
    return;
  }
  const items = Array.isArray(req.body?.items) ? req.body.items : req.body?.feedUrl ? [req.body] : [];
  const deviceId = await upsertAnonymousDevice(deviceKey);

  const keptIds: string[] = [];
  for (const item of items) {
    const feedUrl = String(item?.feedUrl || "").trim();
    if (!feedUrl) {
      continue;
    }
    const podcastId = await ensurePodcast({
      podcastId: item.podcastId,
      feedUrl,
      title: item.title,
      artworkUrl: item.artworkUrl,
      itunesId: item.itunesId
    });
    keptIds.push(podcastId);
    await query(
      `
      INSERT INTO device_subscriptions (device_id, kind, item_id, feed_url, title, notifications_enabled, updated_at)
      VALUES ($1, 'pod', $2, $3, $4, $5, NOW())
      ON CONFLICT (device_id, kind, item_id) DO UPDATE SET
        feed_url = EXCLUDED.feed_url,
        title = EXCLUDED.title,
        notifications_enabled = EXCLUDED.notifications_enabled,
        updated_at = NOW()
      `,
        [deviceId, podcastId, feedUrl, item.title ?? null, item.notificationsEnabled === true]
    );
  }

  if (req.body?.replace !== false) {
    if (keptIds.length) {
      await query(
        `DELETE FROM device_subscriptions WHERE device_id = $1 AND kind = 'pod' AND NOT (item_id = ANY($2::text[]))`,
        [deviceId, keptIds]
      );
    } else {
      await query(`DELETE FROM device_subscriptions WHERE device_id = $1 AND kind = 'pod'`, [deviceId]);
    }
  }

  res.json({ ok: true, deviceId: deviceKey, watched: keptIds.length });
});

router.post("/unwatch", async (req, res) => {
  const deviceKey = String(req.body?.deviceId || "").trim();
  const feedUrl = String(req.body?.feedUrl || "").trim();
  if (!deviceKey || !feedUrl) {
    res.status(400).json({ error: "deviceId and feedUrl required." });
    return;
  }
  const device = await query(`SELECT id FROM devices WHERE device_key = $1`, [deviceKey]);
  if (device.rowCount) {
    await query(
      `DELETE FROM device_subscriptions WHERE device_id = $1 AND kind = 'pod' AND feed_url = $2`,
      [device.rows[0].id, feedUrl]
    );
  }
  res.json({ ok: true });
});

router.get("/search", async (req, res) => {
  const term = typeof req.query.q === "string" ? req.query.q.trim() : "";
  if (!term) {
    res.status(400).json({ error: "q query parameter required." });
    return;
  }
  const local = await query(
    `
    SELECT * FROM pod_podcasts
    WHERE title ILIKE $1 OR author ILIKE $1
    ORDER BY title
    LIMIT 20
    `,
    [`%${term}%`]
  );
  let remote: unknown[] = [];
  try {
    remote = await searchItunesPodcasts(term);
  } catch {
    remote = [];
  }
  res.json({
    local: local.rows.map(mapPodcast),
    remote
  });
});

export default router;
