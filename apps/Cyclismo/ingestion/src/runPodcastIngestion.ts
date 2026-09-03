import path from "node:path";
import { fileURLToPath } from "node:url";
import { closePool, query } from "./db.js";
import {
  getConfiguredPodcastSources,
  matchPodcastEpisodesToRaces,
  scrapePodcastEpisodes,
  type RaceForPodcastMatch,
  type StageForPodcastMatch
} from "./sources/podcasts.js";

type SourceRow = {
  source_id: string;
  slug: string;
  name: string;
};

type EpisodeRow = {
  episode_id: string;
};

const __filename = fileURLToPath(import.meta.url);

const upsertPodcastSource = async (source: {
  slug: string;
  name: string;
  feedUrl: string;
  websiteUrl: string | null;
}): Promise<SourceRow> => {
  const result = await query(
    `
    INSERT INTO podcast_sources (slug, name, feed_url, website_url)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (slug)
    DO UPDATE SET
      name = EXCLUDED.name,
      feed_url = EXCLUDED.feed_url,
      website_url = EXCLUDED.website_url
    RETURNING source_id, slug, name
    `,
    [source.slug, source.name, source.feedUrl, source.websiteUrl]
  );
  return result.rows[0] as SourceRow;
};

const upsertPodcastEpisode = async (
  sourceId: string,
  episode: {
    guid: string | null;
    title: string;
    rawTitle: string;
    description: string | null;
    episodeUrl: string | null;
    publishedAt: string | null;
  }
): Promise<EpisodeRow | null> => {
  const keyGuid = episode.guid?.trim() || null;
  const keyUrl = episode.episodeUrl?.trim() || null;
  if (!keyGuid && !keyUrl) {
    return null;
  }
  if (keyGuid) {
    const result = await query(
      `
      INSERT INTO podcast_episodes (
        source_id, guid, title, raw_title, description, episode_url, published_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (source_id, guid)
      DO UPDATE SET
        title = EXCLUDED.title,
        raw_title = EXCLUDED.raw_title,
        description = EXCLUDED.description,
        episode_url = COALESCE(EXCLUDED.episode_url, podcast_episodes.episode_url),
        published_at = COALESCE(EXCLUDED.published_at, podcast_episodes.published_at),
        scraped_at = NOW()
      RETURNING episode_id
      `,
      [
        sourceId,
        keyGuid,
        episode.title,
        episode.rawTitle,
        episode.description,
        keyUrl,
        episode.publishedAt
      ]
    );
    return result.rows[0] as EpisodeRow;
  }

  if (keyUrl) {
    const result = await query(
      `
      INSERT INTO podcast_episodes (
        source_id, guid, title, raw_title, description, episode_url, published_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (source_id, episode_url)
      DO UPDATE SET
        title = EXCLUDED.title,
        raw_title = EXCLUDED.raw_title,
        description = EXCLUDED.description,
        published_at = COALESCE(EXCLUDED.published_at, podcast_episodes.published_at),
        scraped_at = NOW()
      RETURNING episode_id
      `,
      [
        sourceId,
        null,
        episode.title,
        episode.rawTitle,
        episode.description,
        keyUrl,
        episode.publishedAt
      ]
    );
    return result.rows[0] as EpisodeRow;
  }

  return null;
};

const upsertRaceEpisodeLink = async (raceId: string, episodeId: string, matchedBy: string) => {
  await query(
    `
    INSERT INTO race_podcast_episodes (race_id, episode_id, matched_by)
    VALUES ($1, $2, $3)
    ON CONFLICT (race_id, episode_id)
    DO UPDATE SET
      matched_by = EXCLUDED.matched_by,
      matched_at = NOW()
    `,
    [raceId, episodeId, matchedBy]
  );
};

const upsertStageEpisodeLink = async (stageId: string, episodeId: string, matchedBy: string) => {
  await query(
    `
    INSERT INTO stage_podcast_episodes (stage_id, episode_id, matched_by)
    VALUES ($1, $2, $3)
    ON CONFLICT (stage_id, episode_id)
    DO UPDATE SET
      matched_by = EXCLUDED.matched_by,
      matched_at = NOW()
    `,
    [stageId, episodeId, matchedBy]
  );
};

export const runPodcastIngestion = async () => {
  const raceRows = await query(
    `
    SELECT race_id, name, start_date
    FROM races
    ORDER BY start_date DESC
    `
  );
  const races = (raceRows.rows as Array<{ race_id: string; name: string; start_date: string }>).map(
    (race) =>
      ({
        raceId: race.race_id,
        name: race.name,
        startDate: race.start_date
      }) satisfies RaceForPodcastMatch
  );
  const stageRows = await query(
    `
    SELECT
      s.stage_id,
      s.race_id,
      s.stage_number,
      s.name,
      s.date,
      s.is_rest_day,
      s.stage_type,
      r.name AS race_name,
      r.start_date AS race_start_date
    FROM race_stages s
    INNER JOIN races r ON r.race_id = s.race_id
    `
  );
  const stages = stageRows.rows as StageForPodcastMatch[];

  const podcastSources = await getConfiguredPodcastSources();
  let linkCount = 0;
  let unmatchedCount = 0;
  let scrapedCount = 0;

  for (const source of podcastSources) {
    const sourceRow = await upsertPodcastSource(source);
    const episodes = await scrapePodcastEpisodes(source);
    scrapedCount += episodes.length;
    const matches = matchPodcastEpisodesToRaces(source, episodes, races, stages, 4);

    const matchByKey = new Map<
      string,
      Array<{ raceId: string; matchedBy: string; stageId?: string; stageMatchedBy?: string }>
    >();
    for (const match of matches) {
      const key = `${match.episode.guid ?? ""}::${match.episode.episodeUrl ?? ""}`;
      const existing = matchByKey.get(key) ?? [];
      existing.push({
        raceId: match.raceId,
        matchedBy: match.matchedBy,
        stageId: match.stageId,
        stageMatchedBy: match.stageMatchedBy
      });
      matchByKey.set(key, existing);
    }

    for (const episode of episodes) {
      const episodeRow = await upsertPodcastEpisode(sourceRow.source_id, episode);
      if (!episodeRow) continue;
      const key = `${episode.guid ?? ""}::${episode.episodeUrl ?? ""}`;
      const episodeMatches = matchByKey.get(key) ?? [];
      if (episodeMatches.length === 0) {
        unmatchedCount += 1;
        continue;
      }
      for (const match of episodeMatches) {
        await upsertRaceEpisodeLink(match.raceId, episodeRow.episode_id, match.matchedBy);
        if (match.stageId && match.stageMatchedBy) {
          await upsertStageEpisodeLink(match.stageId, episodeRow.episode_id, match.stageMatchedBy);
        }
        linkCount += 1;
      }
    }
  }

  console.log(
    `Podcast ingestion: ${scrapedCount} episodes scraped, ${linkCount} race links, ${unmatchedCount} unmatched`
  );
};

const isCli = path.resolve(process.argv[1] ?? "") === __filename;
if (isCli) {
  runPodcastIngestion()
    .catch((error) => {
      console.error("Podcast ingestion failed:", error);
      process.exitCode = 1;
    })
    .finally(async () => {
      await closePool();
    });
}
