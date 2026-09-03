import { query, withTransaction } from "../db.js";
import { loadNowPlaying, resetNowPlayingCacheForTests, seedNowPlayingCache } from "./now-playing.js";
import {
  isFreshTheaterStaySnapshot,
  mergeTheaterStayRefresh,
  theaterStayStats,
  toPublicMovies,
  type TheaterStay,
  type TheaterStaySnapshot,
  type TheaterStayStats
} from "./theater-stays-logic.js";

export {
  isFreshTheaterStaySnapshot,
  mergeTheaterStayRefresh,
  normalizeTheaterStayUpdate,
  theaterStayStats,
  toPublicMovies
} from "./theater-stays-logic.js";
export type { TheaterStay, TheaterStaySnapshot, TheaterStayStats } from "./theater-stays-logic.js";

const mapStayRow = (row: Record<string, unknown>): TheaterStay => ({
  tmdbId: Number(row.tmdb_id),
  title: String(row.title || ""),
  hasIMAX: Boolean(row.has_imax),
  inCatalog: Boolean(row.in_catalog),
  manualOverride: Boolean(row.manual_override)
});

const isoDate = (value: unknown) => {
  if (value instanceof Date) {
    return value.toISOString();
  }
  const parsed = Date.parse(String(value || ""));
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : new Date().toISOString();
};

export const listTheaterStays = async (region: string): Promise<TheaterStay[]> => {
  const result = await query(
    `
    SELECT tmdb_id, title, has_imax, in_catalog, manual_override
    FROM mov_theater_stays
    WHERE region = $1
    ORDER BY title ASC, tmdb_id ASC
    `,
    [region]
  );
  return result.rows.map((row) => mapStayRow(row as Record<string, unknown>));
};

export const loadTheaterStaySnapshot = async (region: string): Promise<TheaterStaySnapshot | null> => {
  const snap = await query(
    `SELECT refreshed_at, source FROM mov_theater_stay_snapshots WHERE region = $1`,
    [region]
  );
  if (!snap.rowCount) {
    return null;
  }
  return {
    region,
    stays: await listTheaterStays(region),
    refreshedAt: isoDate(snap.rows[0].refreshed_at),
    source: String(snap.rows[0].source || "tmdb")
  };
};

export const findTheaterStay = async (region: string, tmdbId: number): Promise<TheaterStay | null> => {
  const result = await query(
    `
    SELECT tmdb_id, title, has_imax, in_catalog, manual_override
    FROM mov_theater_stays
    WHERE region = $1 AND tmdb_id = $2
    `,
    [region, tmdbId]
  );
  return result.rowCount ? mapStayRow(result.rows[0] as Record<string, unknown>) : null;
};

export const saveTheaterStaySnapshot = async (
  region: string,
  stays: TheaterStay[],
  refreshedAt: string,
  source: string
) => {
  await withTransaction(async (client) => {
    await client.query(`DELETE FROM mov_theater_stays WHERE region = $1`, [region]);
    for (const stay of stays) {
      await client.query(
        `
        INSERT INTO mov_theater_stays (
          tmdb_id, region, title, has_imax, in_catalog, manual_override, refreshed_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        `,
        [stay.tmdbId, region, stay.title, stay.hasIMAX, stay.inCatalog, stay.manualOverride, refreshedAt]
      );
    }
    await client.query(
      `
      INSERT INTO mov_theater_stay_snapshots (region, refreshed_at, source)
      VALUES ($1, $2, $3)
      ON CONFLICT (region) DO UPDATE SET
        refreshed_at = EXCLUDED.refreshed_at,
        source = EXCLUDED.source
      `,
      [region, refreshedAt, source]
    );
  });
  seedNowPlayingCache(region, toPublicMovies(stays), Date.parse(refreshedAt));
};

export const clearInferredTheaterStays = async (region: string) => {
  const result = await query(
    `DELETE FROM mov_theater_stays WHERE region = $1 AND manual_override = false`,
    [region]
  );
  await query(
    `
    INSERT INTO mov_theater_stay_snapshots (region, refreshed_at, source)
    VALUES ($1, NOW(), 'clear')
    ON CONFLICT (region) DO UPDATE SET
      refreshed_at = NOW(),
      source = 'clear'
    `,
    [region]
  );
  const stays = await listTheaterStays(region);
  seedNowPlayingCache(region, toPublicMovies(stays));
  return result.rowCount ?? 0;
};

export const upsertManualTheaterStay = async (
  region: string,
  update: { tmdbId: number; title: string; hasIMAX: boolean; remove: boolean; inCatalog?: boolean }
) => {
  if (update.remove) {
    await query(`DELETE FROM mov_theater_stays WHERE tmdb_id = $1 AND region = $2`, [update.tmdbId, region]);
  } else {
    await query(
      `
      INSERT INTO mov_theater_stays (
        tmdb_id, region, title, has_imax, in_catalog, manual_override, refreshed_at
      ) VALUES ($1, $2, $3, $4, $5, true, NOW())
      ON CONFLICT (tmdb_id, region) DO UPDATE SET
        title = COALESCE(NULLIF(EXCLUDED.title, ''), mov_theater_stays.title),
        has_imax = EXCLUDED.has_imax,
        in_catalog = EXCLUDED.in_catalog,
        manual_override = true,
        refreshed_at = NOW()
      `,
      [update.tmdbId, region, update.title, update.hasIMAX, update.inCatalog ?? true]
    );
  }
  const stored = await loadTheaterStaySnapshot(region);
  if (stored) {
    seedNowPlayingCache(region, toPublicMovies(stored.stays), Date.parse(stored.refreshedAt));
  } else {
    seedNowPlayingCache(region, toPublicMovies(await listTheaterStays(region)));
  }
  return findTheaterStay(region, update.tmdbId);
};

export const loadTheaterStayStats = async (region: string): Promise<TheaterStayStats & { stays: TheaterStay[] }> => {
  const stored = await loadTheaterStaySnapshot(region);
  const stays = stored?.stays ?? (await listTheaterStays(region));
  return {
    ...theaterStayStats(stays, stored?.refreshedAt ?? null, region, stored?.source ?? null),
    stays
  };
};

const publicPayload = (stored: TheaterStaySnapshot, source: "store" | "tmdb") => ({
  movies: toPublicMovies(stored.stays),
  refreshedAt: stored.refreshedAt,
  source
});

export const resolveNowPlaying = async (
  apiKey: string | undefined,
  region: string,
  catalogTmdbIds: Set<number>,
  options: { force?: boolean } = {}
) => {
  const stored = await loadTheaterStaySnapshot(region);
  if (!options.force && stored && isFreshTheaterStaySnapshot(stored.refreshedAt)) {
    seedNowPlayingCache(region, toPublicMovies(stored.stays), Date.parse(stored.refreshedAt));
    return publicPayload(stored, "store");
  }
  if (!apiKey) {
    if (stored) {
      return publicPayload(stored, "store");
    }
    throw new Error("Now-playing lookup unavailable.");
  }
  try {
    const incoming = await loadNowPlaying(apiKey, region, catalogTmdbIds);
    const merged = mergeTheaterStayRefresh(stored?.stays ?? [], incoming, catalogTmdbIds);
    const refreshedAt = new Date().toISOString();
    await saveTheaterStaySnapshot(region, merged, refreshedAt, "tmdb");
    return { movies: toPublicMovies(merged), refreshedAt, source: "tmdb" as const };
  } catch (error) {
    if (stored) {
      return publicPayload(stored, "store");
    }
    throw error;
  }
};

export { resetNowPlayingCacheForTests };
