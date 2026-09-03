import { CACHE_MS, type NowPlayingMovie } from "./now-playing.js";

export type TheaterStay = {
  tmdbId: number;
  title: string;
  hasIMAX: boolean;
  inCatalog: boolean;
  manualOverride: boolean;
};

export type TheaterStaySnapshot = {
  region: string;
  stays: TheaterStay[];
  refreshedAt: string;
  source: string;
};

export type TheaterStayStats = {
  region: string;
  refreshedAt: string | null;
  source: string | null;
  inTheaters: number;
  inCatalog: number;
  withIMAX: number;
  manualOverrides: number;
};

export const theaterStayStats = (
  stays: TheaterStay[],
  refreshedAt: string | null,
  region: string,
  source: string | null = null
): TheaterStayStats => ({
  region,
  refreshedAt,
  source,
  inTheaters: stays.length,
  inCatalog: stays.filter((stay) => stay.inCatalog).length,
  withIMAX: stays.filter((stay) => stay.hasIMAX).length,
  manualOverrides: stays.filter((stay) => stay.manualOverride).length
});

export const toPublicMovies = (stays: TheaterStay[]): NowPlayingMovie[] =>
  stays.map((stay) => ({
    tmdbId: stay.tmdbId,
    title: stay.title,
    hasIMAX: stay.hasIMAX
  }));

export const mergeTheaterStayRefresh = (
  existing: TheaterStay[],
  incoming: NowPlayingMovie[],
  catalogTmdbIds: Set<number>
): TheaterStay[] => {
  const manuals = existing.filter((stay) => stay.manualOverride);
  const manualIds = new Set(manuals.map((stay) => stay.tmdbId));
  const fromTmdb = incoming
    .filter((movie) => !manualIds.has(movie.tmdbId))
    .map((movie) => ({
      tmdbId: movie.tmdbId,
      title: movie.title,
      hasIMAX: movie.hasIMAX,
      inCatalog: catalogTmdbIds.has(movie.tmdbId),
      manualOverride: false
    }));
  const nextManuals = manuals.map((stay) => ({
    ...stay,
    inCatalog: catalogTmdbIds.has(stay.tmdbId),
    title: stay.title || incoming.find((movie) => movie.tmdbId === stay.tmdbId)?.title || stay.title
  }));
  return [...nextManuals, ...fromTmdb].sort(
    (left, right) => left.title.localeCompare(right.title) || left.tmdbId - right.tmdbId
  );
};

export const normalizeTheaterStayUpdate = (body: {
  tmdbId?: unknown;
  title?: unknown;
  inTheaters?: unknown;
  hasIMAX?: unknown;
}): { tmdbId: number; title: string; hasIMAX: boolean; remove: boolean } | null => {
  const tmdbId = Number(body.tmdbId);
  if (!Number.isFinite(tmdbId) || tmdbId <= 0) {
    return null;
  }
  const inTheaters = Boolean(body.inTheaters) || Boolean(body.hasIMAX);
  const hasIMAX = Boolean(body.hasIMAX);
  if (!inTheaters) {
    return { tmdbId, title: String(body.title || "").trim(), hasIMAX: false, remove: true };
  }
  return {
    tmdbId,
    title: String(body.title || "").trim(),
    hasIMAX,
    remove: false
  };
};

export const isFreshTheaterStaySnapshot = (refreshedAt: string | null | undefined, now = Date.now()) => {
  if (!refreshedAt) {
    return false;
  }
  const at = Date.parse(refreshedAt);
  return Number.isFinite(at) && now - at < CACHE_MS;
};
