import { query } from "../db.js";
import { config } from "../config.js";
import { movieIdFromTmdb } from "./passwords.js";

export type ImportSource = {
  identifier?: string;
  name?: string;
  type?: string;
  url?: string | null;
  isRankedList?: boolean;
  movieCount?: number;
};

export type ImportMovie = {
  id?: string;
  title?: string;
  tmdbId?: number | null;
  imdbId?: string | null;
  year?: number | null;
  posterPath?: string | null;
  backdropPath?: string | null;
  overview?: string | null;
  mpaaRating?: string | null;
  genres?: string[];
  credits?: unknown;
  trailer?: unknown;
  oscarAwards?: unknown;
  streamingServices?: Array<Record<string, unknown>>;
  sourceIdentifier?: string;
  rank?: number | null;
  sourceTitle?: string | null;
  episodeDate?: string | null;
  podcastEpisode?: unknown;
};

const toTimestamp = (value: string | null | undefined) => {
  if (!value) {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : new Date(parsed).toISOString();
};

const slugId = (title: string) =>
  `title-${title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80)}`;

export const catalogMovieId = (movie: ImportMovie) => {
  if (movie.id) {
    return String(movie.id);
  }
  const tmdbId = movie.tmdbId ? Number(movie.tmdbId) : null;
  if (tmdbId) {
    return movieIdFromTmdb(tmdbId);
  }
  if (movie.title) {
    return slugId(movie.title);
  }
  return null;
};

const mapProviders = (services: ImportMovie["streamingServices"]) =>
  (services ?? []).map((service) => ({
    id: String(service.providerId ?? service.id ?? ""),
    name: service.providerName ?? service.name,
    logoPath: service.logoPath ?? null,
    url: service.url ?? null,
    providerId: service.providerId ?? Number(service.id) ?? null,
    providerName: service.providerName ?? service.name,
    displayPriority: service.displayPriority ?? 999
  }));

const chunk = <T,>(items: T[], size: number) => {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
};

export const importMovieCatalog = async (payload: {
  dataSources?: ImportSource[];
  movies?: ImportMovie[];
}) => {
  const sources = Array.isArray(payload.dataSources) ? payload.dataSources : [];
  const movies = Array.isArray(payload.movies) ? payload.movies : [];
  let importedSources = 0;
  let importedMovies = 0;
  let importedLinks = 0;

  for (const source of sources) {
    if (!source?.identifier) {
      continue;
    }
    await query(
      `
      INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, movie_count, updated_at)
      VALUES ($1,$2,$3,$4,$5,TRUE,$6,NOW())
      ON CONFLICT (identifier) DO UPDATE SET
        name = EXCLUDED.name,
        url = EXCLUDED.url,
        movie_count = EXCLUDED.movie_count,
        updated_at = NOW()
      `,
      [
        source.identifier,
        source.name || source.identifier,
        source.type || "url",
        source.url ?? null,
        Boolean(source.isRankedList),
        source.movieCount ?? 0
      ]
    );
    importedSources += 1;
  }

  const uniqueMovies = new Map<string, ImportMovie>();
  const links: Array<{
    movieId: string;
    sourceId: string;
    rank: number | null;
    sourceTitle: string | null;
    episodeDate: string | null;
    episode: unknown;
  }> = [];
  const streaming: Array<{ movieId: string; providers: unknown[] }> = [];

  for (const movie of movies) {
    const id = catalogMovieId(movie);
    if (!id || !movie.title) {
      continue;
    }
    const existing = uniqueMovies.get(id);
    if (!existing) {
      uniqueMovies.set(id, movie);
    } else {
      if (!existing.streamingServices?.length && movie.streamingServices?.length) {
        existing.streamingServices = movie.streamingServices;
      }
      if (!existing.credits && movie.credits) {
        existing.credits = movie.credits;
      }
      if (!existing.trailer && movie.trailer) {
        existing.trailer = movie.trailer;
      }
      if (!existing.oscarAwards && movie.oscarAwards) {
        existing.oscarAwards = movie.oscarAwards;
      }
    }
    if (movie.sourceIdentifier) {
      links.push({
        movieId: id,
        sourceId: movie.sourceIdentifier,
        rank: movie.rank ?? null,
        sourceTitle: movie.sourceTitle ?? null,
        episodeDate: toTimestamp(movie.episodeDate),
        episode: movie.podcastEpisode ?? null
      });
    }
  }

  for (const [id, movie] of uniqueMovies) {
    const providers = mapProviders(movie.streamingServices);
    if (providers.length) {
      streaming.push({ movieId: id, providers });
    }
  }

  for (const group of chunk([...uniqueMovies.entries()], 80)) {
    const values: string[] = [];
    const params: unknown[] = [];
    group.forEach(([id, movie], index) => {
      const base = index * 13;
      values.push(
        `($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},$${base + 7},$${base + 8},$${base + 9}::jsonb,$${base + 10},$${base + 11}::jsonb,$${base + 12}::jsonb,$${base + 13}::jsonb,NOW())`
      );
      params.push(
        id,
        movie.tmdbId ?? null,
        movie.title,
        movie.year ?? null,
        movie.posterPath ?? null,
        movie.backdropPath ?? null,
        movie.overview ?? null,
        movie.mpaaRating ?? null,
        JSON.stringify(movie.genres ?? []),
        movie.imdbId ?? null,
        JSON.stringify(movie.credits ?? null),
        JSON.stringify(movie.trailer ?? null),
        JSON.stringify(movie.oscarAwards ?? null)
      );
    });
    await query(
      `
      INSERT INTO mov_movies (
        id, tmdb_id, title, year, poster_path, backdrop_path, overview, mpaa_rating,
        genres, imdb_id, credits, trailer, oscar_awards, last_updated
      )
      VALUES ${values.join(",")}
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        year = COALESCE(EXCLUDED.year, mov_movies.year),
        poster_path = COALESCE(EXCLUDED.poster_path, mov_movies.poster_path),
        backdrop_path = COALESCE(EXCLUDED.backdrop_path, mov_movies.backdrop_path),
        overview = COALESCE(EXCLUDED.overview, mov_movies.overview),
        mpaa_rating = COALESCE(EXCLUDED.mpaa_rating, mov_movies.mpaa_rating),
        genres = EXCLUDED.genres,
        imdb_id = COALESCE(EXCLUDED.imdb_id, mov_movies.imdb_id),
        credits = COALESCE(EXCLUDED.credits, mov_movies.credits),
        trailer = COALESCE(EXCLUDED.trailer, mov_movies.trailer),
        oscar_awards = COALESCE(EXCLUDED.oscar_awards, mov_movies.oscar_awards),
        last_updated = NOW()
      `,
      params
    );
    importedMovies += group.length;
  }

  for (const group of chunk(streaming, 80)) {
    const values: string[] = [];
    const params: unknown[] = [];
    group.forEach((row, index) => {
      const base = index * 3;
      values.push(`($${base + 1},$${base + 2},$${base + 3}::jsonb,NOW())`);
      params.push(row.movieId, config.tmdbRegion, JSON.stringify(row.providers));
    });
    await query(
      `
      INSERT INTO mov_streaming (movie_id, region, providers, refreshed_at)
      VALUES ${values.join(",")}
      ON CONFLICT (movie_id, region) DO UPDATE SET
        providers = EXCLUDED.providers,
        refreshed_at = NOW()
      `,
      params
    );
  }

  for (const group of chunk(links, 80)) {
    const values: string[] = [];
    const params: unknown[] = [];
    group.forEach((row, index) => {
      const base = index * 6;
      values.push(`($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6}::jsonb)`);
      params.push(
        row.movieId,
        row.sourceId,
        row.rank,
        row.sourceTitle,
        row.episodeDate,
        JSON.stringify(row.episode)
      );
    });
    await query(
      `
      INSERT INTO mov_movie_sources (movie_id, source_id, rank, source_title, episode_date, episode)
      VALUES ${values.join(",")}
      ON CONFLICT (movie_id, source_id) DO UPDATE SET
        rank = EXCLUDED.rank,
        source_title = EXCLUDED.source_title,
        episode_date = EXCLUDED.episode_date,
        episode = EXCLUDED.episode
      `,
      params
    );
    importedLinks += group.length;
  }

  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'watchedit'`);
  return { importedMovies, importedSources, importedLinks };
};
