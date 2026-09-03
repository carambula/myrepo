import { fetchJson } from "./http.js";
import { movieIdFromTmdb } from "./passwords.js";

export type StreamingProvider = {
  id: string;
  name: string;
  logoPath: string | null;
  url: string | null;
  providerId: number;
  providerName: string;
  displayPriority: number;
};

type TmdbWatchProviders = {
  results?: Record<
    string,
    {
      link?: string;
      flatrate?: Array<{ provider_id: number; provider_name: string; logo_path?: string; display_priority?: number }>;
      ads?: Array<{ provider_id: number; provider_name: string; logo_path?: string; display_priority?: number }>;
      free?: Array<{ provider_id: number; provider_name: string; logo_path?: string; display_priority?: number }>;
    }
  >;
};

type TmdbMovie = {
  id: number;
  title: string;
  release_date?: string;
  poster_path?: string;
  backdrop_path?: string;
  overview?: string;
  genres?: Array<{ name: string }>;
};

export const mapStreamingProviders = (data: TmdbWatchProviders, region: string): StreamingProvider[] => {
  const regional = data.results?.[region] ?? data.results?.US;
  if (!regional) {
    return [];
  }
  const buckets = [...(regional.flatrate ?? []), ...(regional.ads ?? []), ...(regional.free ?? [])];
  const providerMap = new Map<number, StreamingProvider>();
  for (const provider of buckets) {
    if (providerMap.has(provider.provider_id)) {
      continue;
    }
    providerMap.set(provider.provider_id, {
      id: String(provider.provider_id),
      name: provider.provider_name,
      logoPath: provider.logo_path ?? null,
      url: regional.link ?? null,
      providerId: provider.provider_id,
      providerName: provider.provider_name,
      displayPriority: provider.display_priority ?? 999
    });
  }
  return Array.from(providerMap.values()).sort((a, b) => a.displayPriority - b.displayPriority);
};

export const fetchStreamingServices = async (tmdbId: number, apiKey: string, region: string) => {
  if (!apiKey) {
    throw new Error("TMDB_API_KEY is not configured");
  }
  const url = new URL(`https://api.themoviedb.org/3/movie/${tmdbId}/watch/providers`);
  url.searchParams.set("api_key", apiKey);
  const data = await fetchJson<TmdbWatchProviders>(url.toString());
  return mapStreamingProviders(data, region);
};

export const searchTmdbMovie = async (title: string, year: number | undefined, apiKey: string) => {
  const url = new URL("https://api.themoviedb.org/3/search/movie");
  url.searchParams.set("api_key", apiKey);
  url.searchParams.set("query", title);
  if (year) {
    url.searchParams.set("year", String(year));
  }
  const data = await fetchJson<{ results: TmdbMovie[] }>(url.toString());
  return data.results?.[0] ?? null;
};

export const fetchTmdbMovie = async (tmdbId: number, apiKey: string) => {
  const url = new URL(`https://api.themoviedb.org/3/movie/${tmdbId}`);
  url.searchParams.set("api_key", apiKey);
  return fetchJson<TmdbMovie>(url.toString());
};

export const catalogMovieFromTmdb = (movie: TmdbMovie) => {
  const year = movie.release_date ? Number(movie.release_date.slice(0, 4)) : null;
  return {
    id: movieIdFromTmdb(movie.id),
    tmdbId: movie.id,
    title: movie.title,
    year,
    posterPath: movie.poster_path ?? null,
    backdropPath: movie.backdrop_path ?? null,
    overview: movie.overview ?? null,
    genres: (movie.genres ?? []).map((genre) => genre.name)
  };
};
