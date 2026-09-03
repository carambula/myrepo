import { fetchJson } from "./http.js";

export type NowPlayingMovie = {
  tmdbId: number;
  title: string;
  hasIMAX: boolean;
};

type TmdbNowPlaying = {
  page?: number;
  total_pages?: number;
  results?: Array<{ id?: number; title?: string }>;
};

type TmdbReleaseDates = {
  results?: Array<{
    iso_3166_1?: string;
    release_dates?: Array<{ note?: string | null; type?: number }>;
  }>;
};

const CACHE_MS = 6 * 60 * 60 * 1000;
let cache: { at: number; region: string; movies: NowPlayingMovie[] } | null = null;

export const noteLooksLikeIMAX = (note?: string | null) =>
  typeof note === "string" && /\bimax\b/i.test(note);

export const releaseDatesHaveIMAX = (data: TmdbReleaseDates | null | undefined, region: string) => {
  const rows = data?.results ?? [];
  const regional = rows.find((row) => row.iso_3166_1 === region) ?? rows.find((row) => row.iso_3166_1 === "US");
  return (regional?.release_dates ?? []).some((entry) => noteLooksLikeIMAX(entry.note));
};

export const fetchNowPlayingPage = async (apiKey: string, region: string, page: number) => {
  const url = new URL("https://api.themoviedb.org/3/movie/now_playing");
  url.searchParams.set("api_key", apiKey);
  url.searchParams.set("region", region);
  url.searchParams.set("page", String(page));
  return fetchJson<TmdbNowPlaying>(url.toString());
};

export const fetchReleaseDates = async (tmdbId: number, apiKey: string) => {
  const url = new URL(`https://api.themoviedb.org/3/movie/${tmdbId}/release_dates`);
  url.searchParams.set("api_key", apiKey);
  return fetchJson<TmdbReleaseDates>(url.toString());
};

export const loadNowPlaying = async (
  apiKey: string,
  region: string,
  catalogTmdbIds: Set<number>,
  options: { maxPages?: number } = {}
) => {
  const maxPages = options.maxPages ?? 5;
  const playing = new Map<number, string>();
  for (let page = 1; page <= maxPages; page += 1) {
    const data = await fetchNowPlayingPage(apiKey, region, page);
    for (const movie of data.results ?? []) {
      if (typeof movie.id === "number") {
        playing.set(movie.id, movie.title || "");
      }
    }
    if ((data.page ?? page) >= (data.total_pages ?? page)) {
      break;
    }
  }

  const movies: NowPlayingMovie[] = [];
  for (const [tmdbId, title] of playing) {
    let hasIMAX = false;
    if (catalogTmdbIds.has(tmdbId)) {
      try {
        const dates = await fetchReleaseDates(tmdbId, apiKey);
        hasIMAX = releaseDatesHaveIMAX(dates, region);
      } catch {
        hasIMAX = false;
      }
    }
    movies.push({ tmdbId, title, hasIMAX });
  }
  return movies;
};

export const cachedNowPlaying = async (
  apiKey: string,
  region: string,
  catalogTmdbIds: Set<number>
) => {
  if (cache && cache.region === region && Date.now() - cache.at < CACHE_MS) {
    return { movies: cache.movies, refreshedAt: new Date(cache.at).toISOString(), source: "cache" as const };
  }
  const movies = await loadNowPlaying(apiKey, region, catalogTmdbIds);
  cache = { at: Date.now(), region, movies };
  return { movies, refreshedAt: new Date(cache.at).toISOString(), source: "tmdb" as const };
};

export const resetNowPlayingCacheForTests = () => {
  cache = null;
};
