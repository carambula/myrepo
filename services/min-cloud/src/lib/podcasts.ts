import { query } from "../db.js";
import { podcastIdFromFeed, podcastIdFromItunes } from "./passwords.js";

export type EnsurePodcastInput = {
  podcastId?: string | null;
  feedUrl: string;
  title?: string | null;
  artworkUrl?: string | null;
  itunesId?: string | null;
};

export const ensurePodcast = async (input: EnsurePodcastInput) => {
  const feedUrl = input.feedUrl.trim();
  const existing = await query(`SELECT id FROM pod_podcasts WHERE feed_url = $1`, [feedUrl]);
  if (existing.rowCount) {
    return String(existing.rows[0].id);
  }

  const requested = input.podcastId ? String(input.podcastId) : "";
  const itunesId = input.itunesId
    ? String(input.itunesId)
    : /^\d+$/.test(requested)
      ? requested
      : null;
  const id = itunesId
    ? podcastIdFromItunes(itunesId)
    : requested.startsWith("itunes-") || requested.startsWith("feed-")
      ? requested
      : podcastIdFromFeed(feedUrl);

  await query(
    `
    INSERT INTO pod_podcasts (id, itunes_id, title, author, feed_url, artwork_url, categories, updated_at)
    VALUES ($1, $2, $3, '', $4, $5, '[]'::jsonb, NOW())
    ON CONFLICT (id) DO UPDATE SET
      feed_url = EXCLUDED.feed_url,
      title = COALESCE(NULLIF(EXCLUDED.title, ''), pod_podcasts.title),
      artwork_url = COALESCE(EXCLUDED.artwork_url, pod_podcasts.artwork_url),
      updated_at = NOW()
    `,
    [id, itunesId, input.title || "Untitled podcast", feedUrl, input.artworkUrl ?? null]
  );
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'podlink'`);
  return id;
};
