import { query } from "../db.js";
import { config } from "../config.js";

export const STREAMING_CACHE_MS = 12 * 60 * 60 * 1000;

export const isFreshStreamingCache = (
  refreshedAt: Date | string | null | undefined,
  now = Date.now()
) => {
  if (!refreshedAt) {
    return false;
  }
  const at = refreshedAt instanceof Date ? refreshedAt.getTime() : Date.parse(String(refreshedAt));
  return Number.isFinite(at) && now - at < STREAMING_CACHE_MS;
};

export const persistStreamingProviders = async (movieId: string, providers: unknown[]) => {
  await query(
    `
    INSERT INTO mov_streaming (movie_id, region, providers, refreshed_at)
    VALUES ($1, $2, $3::jsonb, NOW())
    ON CONFLICT (movie_id, region) DO UPDATE SET
      providers = EXCLUDED.providers,
      refreshed_at = NOW()
    `,
    [movieId, config.tmdbRegion, JSON.stringify(providers ?? [])]
  );
  await query(`UPDATE mov_movies SET last_updated = NOW() WHERE id = $1`, [movieId]);
};
