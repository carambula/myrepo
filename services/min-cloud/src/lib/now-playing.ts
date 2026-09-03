import { fetchJson } from "./http.js";

export type TicketLinks = {
  amc?: string;
  fandango?: string;
  atom?: string;
};

export type NowPlayingMovie = {
  tmdbId: number;
  title: string;
  hasIMAX: boolean;
  year?: number;
  originalTitle?: string;
  ticketLinks?: TicketLinks;
};

type TmdbNowPlaying = {
  page?: number;
  total_pages?: number;
  results?: Array<{ id?: number; title?: string; original_title?: string; release_date?: string }>;
};

type TmdbReleaseDates = {
  results?: Array<{
    iso_3166_1?: string;
    release_dates?: Array<{ note?: string | null; type?: number }>;
  }>;
};

export const CACHE_MS = 6 * 60 * 60 * 1000;
let cache: { at: number; region: string; movies: NowPlayingMovie[] } | null = null;

export const seedNowPlayingCache = (region: string, movies: NowPlayingMovie[], at = Date.now()) => {
  cache = { at, region, movies };
};

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

export const yearFromReleaseDate = (value?: string | null) => {
  const year = Number(String(value || "").slice(0, 4));
  return year >= 1900 && year <= 2100 ? year : undefined;
};

export const loadNowPlaying = async (
  apiKey: string,
  region: string,
  catalogTmdbIds: Set<number>,
  options: { maxPages?: number } = {}
) => {
  const maxPages = options.maxPages ?? 5;
  const playing = new Map<
    number,
    { title: string; originalTitle?: string; year?: number }
  >();
  for (let page = 1; page <= maxPages; page += 1) {
    const data = await fetchNowPlayingPage(apiKey, region, page);
    for (const movie of data.results ?? []) {
      if (typeof movie.id === "number") {
        playing.set(movie.id, {
          title: movie.title || "",
          originalTitle: movie.original_title || undefined,
          year: yearFromReleaseDate(movie.release_date)
        });
      }
    }
    if ((data.page ?? page) >= (data.total_pages ?? page)) {
      break;
    }
  }

  const movies: NowPlayingMovie[] = [];
  for (const [tmdbId, meta] of playing) {
    let hasIMAX = false;
    if (catalogTmdbIds.has(tmdbId)) {
      try {
        const dates = await fetchReleaseDates(tmdbId, apiKey);
        hasIMAX = releaseDatesHaveIMAX(dates, region);
      } catch {
        hasIMAX = false;
      }
    }
    movies.push({
      tmdbId,
      title: meta.title,
      hasIMAX,
      ...(meta.year ? { year: meta.year } : {}),
      ...(meta.originalTitle && meta.originalTitle !== meta.title ? { originalTitle: meta.originalTitle } : {})
    });
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
