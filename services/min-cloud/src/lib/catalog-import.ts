import { query } from "../db.js";
import { config } from "../config.js";
import { movieIdFromTmdb } from "./passwords.js";
import {
  mergePhysicalMedia,
  normalizePhysicalMedia,
  overlayMapFromUnknown
} from "./physical-media.js";

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
  podcastEpisodeDescription?: string | null;
  sourceUrl?: string | null;
  physicalMedia?: unknown;
};

export const episodeFromImportMovie = (movie: ImportMovie) => {
  if (movie.podcastEpisode) {
    return movie.podcastEpisode;
  }
  if (!movie.podcastEpisodeDescription) {
    return null;
  }
  return {
    title: movie.sourceTitle ?? movie.title ?? null,
    description: movie.podcastEpisodeDescription,
    publishDate: movie.episodeDate ?? null,
    episodeId: movie.sourceUrl ?? null
  };
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

export const applyPhysicalMediaOverlay = async (
  raw: unknown,
  options: { overwriteManual?: boolean } = {}
) => {
  const overlay = overlayMapFromUnknown(raw);
  let updated = 0;
  for (const group of chunk([...overlay.entries()], 80)) {
    const tmdbIds = group.map(([tmdbId]) => tmdbId);
    const existing = await query(
      `SELECT id, tmdb_id, physical_media FROM mov_movies WHERE tmdb_id = ANY($1::int[])`,
      [tmdbIds]
    );
    const byTmdb = new Map(existing.rows.map((row) => [Number(row.tmdb_id), row]));
    for (const [tmdbId, inferred] of group) {
      const row = byTmdb.get(tmdbId);
      if (!row) {
        continue;
      }
      const stored = normalizePhysicalMedia(row.physical_media);
      if (stored?.manualOverride && !options.overwriteManual) {
        continue;
      }
      const base = options.overwriteManual && stored?.manualOverride ? { ...stored, manualOverride: false } : stored;
      const merged = mergePhysicalMedia(base, inferred);
      if (!merged) {
        continue;
      }
      await query(
        `UPDATE mov_movies SET physical_media = $2::jsonb, last_updated = NOW() WHERE id = $1`,
        [row.id, JSON.stringify(merged)]
      );
      updated += 1;
    }
  }
  return updated;
};

export const importMovieCatalog = async (payload: {
  dataSources?: ImportSource[];
  movies?: ImportMovie[];
  physicalMediaByTmdbId?: unknown;
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
  const links = new Map<string, {
    movieId: string;
    sourceId: string;
    rank: number | null;
    sourceTitle: string | null;
    episodeDate: string | null;
    episode: unknown;
  }>();
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
      const mergedMedia = mergePhysicalMedia(
        normalizePhysicalMedia(existing.physicalMedia),
        normalizePhysicalMedia(movie.physicalMedia)
      );
      if (mergedMedia) {
        existing.physicalMedia = mergedMedia;
      }
    }
    if (movie.sourceIdentifier) {
      const key = `${id}|${movie.sourceIdentifier}`;
      if (!links.has(key)) {
        links.set(key, {
          movieId: id,
          sourceId: movie.sourceIdentifier,
          rank: movie.rank ?? null,
          sourceTitle: movie.sourceTitle ?? null,
          episodeDate: toTimestamp(movie.episodeDate),
          episode: episodeFromImportMovie(movie)
        });
      }
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
      const base = index * 14;
      const media = normalizePhysicalMedia(movie.physicalMedia);
      values.push(
        `($${base + 1},$${base + 2},$${base + 3},$${base + 4},$${base + 5},$${base + 6},$${base + 7},$${base + 8},$${base + 9}::jsonb,$${base + 10},$${base + 11}::jsonb,$${base + 12}::jsonb,$${base + 13}::jsonb,$${base + 14}::jsonb,NOW())`
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
        JSON.stringify(movie.oscarAwards ?? null),
        media ? JSON.stringify(media) : null
      );
    });
    await query(
      `
      INSERT INTO mov_movies (
        id, tmdb_id, title, year, poster_path, backdrop_path, overview, mpaa_rating,
        genres, imdb_id, credits, trailer, oscar_awards, physical_media, last_updated
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
        physical_media = COALESCE(EXCLUDED.physical_media, mov_movies.physical_media),
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

  for (const group of chunk([...links.values()], 80)) {
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

  const importedPhysicalMedia = await applyPhysicalMediaOverlay(payload.physicalMediaByTmdbId);
  if (importedMovies || importedSources || importedLinks || importedPhysicalMedia) {
    await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'watchedit'`);
  }
  return { importedMovies, importedSources, importedLinks, importedPhysicalMedia };
};
