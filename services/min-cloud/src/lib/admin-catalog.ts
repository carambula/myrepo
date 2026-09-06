import { query } from "../db.js";
import { config } from "../config.js";
import { catalogMovieId, type ImportMovie } from "./catalog-import.js";
import { movieIdFromTmdb } from "./passwords.js";
import { normalizePhysicalMedia } from "./physical-media.js";

export type AdminMovie = {
  __index?: number;
  __movieId?: string;
  title: string;
  year: number | null;
  tmdbId: number | null;
  imdbId?: string | null;
  sourceIdentifier: string | null;
  sourceTitle: string | null;
  rank: number | null;
  mpaaRating: string | null;
  episodeDate: string | null;
  overview: string | null;
  posterPath: string | null;
  backdropPath: string | null;
  genres: string[];
  streamingServices: unknown[];
  credits: unknown;
  trailer: unknown;
  oscarAwards: unknown;
  physicalMedia: unknown;
  podcastEpisodeDescription: string | null;
  sourceUrl?: string | null;
  youtubeUrl?: string | null;
};

export type AdminSource = {
  identifier: string;
  name: string;
  type: string;
  url: string | null;
  isRankedList: boolean;
  movieCount: number;
};

const bumpWatchedIt = async () => {
  await query(`UPDATE catalog_revisions SET revision = revision + 1, generated_at = NOW() WHERE app = 'watchedit'`);
};

export const loadAdminSources = async (): Promise<AdminSource[]> => {
  const sources = await query(
    `SELECT identifier, name, type, url, is_ranked, movie_count FROM mov_sources ORDER BY name`
  );
  return sources.rows.map((row) => ({
    identifier: String(row.identifier),
    name: String(row.name),
    type: String(row.type),
    url: (row.url as string | null) ?? null,
    isRankedList: Boolean(row.is_ranked),
    movieCount: Number(row.movie_count ?? 0)
  }));
};

export const loadAdminMovies = async (): Promise<AdminMovie[]> => {
  const result = await query(
    `
    SELECT
      m.id, m.tmdb_id, m.imdb_id, m.title, m.year, m.poster_path, m.backdrop_path,
      m.overview, m.mpaa_rating, m.genres, m.credits, m.trailer, m.oscar_awards, m.physical_media,
      COALESCE(s.providers, '[]'::jsonb) AS providers,
      ms.source_id, ms.rank, ms.source_title, ms.episode_date, ms.episode
    FROM mov_movies m
    LEFT JOIN mov_streaming s ON s.movie_id = m.id AND s.region = $1
    LEFT JOIN mov_movie_sources ms ON ms.movie_id = m.id
    ORDER BY m.title ASC, ms.source_id ASC NULLS LAST, m.id ASC
    `,
    [config.tmdbRegion]
  );
  return result.rows.map((row, index) => {
    const episode = row.episode && typeof row.episode === "object" ? (row.episode as Record<string, unknown>) : null;
    return {
      __index: index,
      __movieId: String(row.id),
      title: String(row.title),
      year: row.year == null ? null : Number(row.year),
      tmdbId: row.tmdb_id == null ? null : Number(row.tmdb_id),
      imdbId: (row.imdb_id as string | null) ?? null,
      sourceIdentifier: row.source_id ? String(row.source_id) : null,
      sourceTitle: row.source_title ? String(row.source_title) : null,
      rank: row.rank == null ? null : Number(row.rank),
      mpaaRating: (row.mpaa_rating as string | null) ?? null,
      episodeDate: row.episode_date ? new Date(row.episode_date as string).toUTCString() : null,
      overview: (row.overview as string | null) ?? null,
      posterPath: (row.poster_path as string | null) ?? null,
      backdropPath: (row.backdrop_path as string | null) ?? null,
      genres: Array.isArray(row.genres) ? (row.genres as string[]) : [],
      streamingServices: Array.isArray(row.providers) ? row.providers : [],
      credits: row.credits ?? null,
      trailer: row.trailer ?? null,
      oscarAwards: row.oscar_awards ?? null,
      physicalMedia: row.physical_media ?? null,
      podcastEpisodeDescription: episode?.description ? String(episode.description) : null,
      sourceUrl: episode?.episodeId ? String(episode.episodeId) : null,
      youtubeUrl: episode?.youtubeUrl ? String(episode.youtubeUrl) : null
    };
  });
};

export const loadAdminBootstrap = async () => {
  const revision = await query(`SELECT revision, generated_at FROM catalog_revisions WHERE app = 'watchedit'`);
  const movies = await loadAdminMovies();
  const dataSources = await loadAdminSources();
  return {
    version: 1,
    generatedDate: revision.rows[0]?.generated_at ?? new Date().toISOString(),
    revision: Number(revision.rows[0]?.revision ?? 0),
    dataSources,
    movies
  };
};

const upsertStreaming = async (movieId: string, providers: unknown[]) => {
  await query(
    `
    INSERT INTO mov_streaming (movie_id, region, providers, refreshed_at)
    VALUES ($1, $2, $3::jsonb, NOW())
    ON CONFLICT (movie_id, region) DO UPDATE SET providers = EXCLUDED.providers, refreshed_at = NOW()
    `,
    [movieId, config.tmdbRegion, JSON.stringify(providers ?? [])]
  );
};

export const upsertAdminMovie = async (
  payload: Record<string, unknown>,
  previous?: AdminMovie | null,
  options: { bump?: boolean; touch?: boolean } = {}
) => {
  const importMovie: ImportMovie = {
    id: previous?.__movieId,
    title: String(payload.title || previous?.title || ""),
    tmdbId: payload.tmdbId != null ? Number(payload.tmdbId) : previous?.tmdbId,
    year: payload.year != null ? Number(payload.year) : previous?.year,
    posterPath: (payload.posterPath as string | null) ?? previous?.posterPath,
    backdropPath: (payload.backdropPath as string | null) ?? previous?.backdropPath,
    overview: (payload.overview as string | null) ?? previous?.overview,
    mpaaRating: (payload.mpaaRating as string | null) ?? previous?.mpaaRating,
    genres: Array.isArray(payload.genres) ? (payload.genres as string[]) : previous?.genres,
    credits: payload.credits ?? previous?.credits,
    trailer: payload.trailer ?? previous?.trailer,
    oscarAwards: payload.oscarAwards ?? previous?.oscarAwards,
    physicalMedia: payload.physicalMedia ?? previous?.physicalMedia,
    imdbId: (payload.imdbId as string | null) ?? previous?.imdbId,
    streamingServices: Array.isArray(payload.streamingServices)
      ? (payload.streamingServices as Array<Record<string, unknown>>)
      : undefined
  };
  const id = catalogMovieId(importMovie) || previous?.__movieId || (importMovie.tmdbId ? movieIdFromTmdb(Number(importMovie.tmdbId)) : `custom-${Date.now()}`);
  const physicalMedia = normalizePhysicalMedia(importMovie.physicalMedia);
  await query(
    `
    INSERT INTO mov_movies (
      id, tmdb_id, title, year, poster_path, backdrop_path, overview, mpaa_rating,
      genres, imdb_id, credits, trailer, oscar_awards, physical_media, last_updated
    )
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10,$11::jsonb,$12::jsonb,$13::jsonb,$14::jsonb,NOW())
    ON CONFLICT (id) DO UPDATE SET
      tmdb_id = COALESCE(EXCLUDED.tmdb_id, mov_movies.tmdb_id),
      title = EXCLUDED.title,
      year = EXCLUDED.year,
      poster_path = EXCLUDED.poster_path,
      backdrop_path = EXCLUDED.backdrop_path,
      overview = EXCLUDED.overview,
      mpaa_rating = EXCLUDED.mpaa_rating,
      genres = EXCLUDED.genres,
      imdb_id = COALESCE(EXCLUDED.imdb_id, mov_movies.imdb_id),
      credits = EXCLUDED.credits,
      trailer = EXCLUDED.trailer,
      oscar_awards = EXCLUDED.oscar_awards,
      physical_media = COALESCE(EXCLUDED.physical_media, mov_movies.physical_media),
      last_updated = ${options.touch === false ? "mov_movies.last_updated" : "NOW()"}
    `,
    [
      id,
      importMovie.tmdbId ?? null,
      importMovie.title,
      importMovie.year ?? null,
      importMovie.posterPath ?? null,
      importMovie.backdropPath ?? null,
      importMovie.overview ?? null,
      importMovie.mpaaRating ?? null,
      JSON.stringify(importMovie.genres ?? []),
      importMovie.imdbId ?? null,
      JSON.stringify(importMovie.credits ?? null),
      JSON.stringify(importMovie.trailer ?? null),
      JSON.stringify(importMovie.oscarAwards ?? null),
      physicalMedia ? JSON.stringify(physicalMedia) : null
    ]
  );

  if (Array.isArray(payload.streamingServices)) {
    await upsertStreaming(id, payload.streamingServices);
  }

  const sourceId = String(payload.sourceIdentifier || previous?.sourceIdentifier || "").trim();
  if (sourceId) {
    const previousSource = previous?.sourceIdentifier;
    if (previousSource && previousSource !== sourceId) {
      await query(`DELETE FROM mov_movie_sources WHERE movie_id = $1 AND source_id = $2`, [id, previousSource]);
    }
    await query(
      `
      INSERT INTO mov_movie_sources (movie_id, source_id, rank, source_title, episode_date, episode)
      VALUES ($1,$2,$3,$4,$5,$6::jsonb)
      ON CONFLICT (movie_id, source_id) DO UPDATE SET
        rank = EXCLUDED.rank,
        source_title = EXCLUDED.source_title,
        episode_date = EXCLUDED.episode_date,
        episode = EXCLUDED.episode
      `,
      [
        id,
        sourceId,
        payload.rank != null ? Number(payload.rank) : previous?.rank ?? null,
        (payload.sourceTitle as string | null) ?? previous?.sourceTitle ?? null,
        (() => {
          if (!payload.episodeDate) {
            return null;
          }
          const parsed = Date.parse(String(payload.episodeDate));
          return Number.isNaN(parsed) ? null : new Date(parsed).toISOString();
        })(),
        JSON.stringify(
          payload.podcastEpisodeDescription ||
            payload.sourceTitle ||
            payload.sourceUrl ||
            payload.filmUrl ||
            payload.youtubeUrl
            ? {
                title: payload.sourceTitle ?? null,
                description: payload.podcastEpisodeDescription ?? null,
                publishDate: payload.episodeDate ?? null,
                episodeId: payload.sourceUrl ?? null,
                filmUrl: payload.filmUrl ?? null,
                director: payload.director ?? null,
                youtubeUrl: payload.youtubeUrl ?? previous?.youtubeUrl ?? null
              }
            : null
        )
      ]
    );
    await query(
      `
      UPDATE mov_sources SET movie_count = (
        SELECT COUNT(*) FROM mov_movie_sources WHERE source_id = $1
      ), updated_at = NOW()
      WHERE identifier = $1
      `,
      [sourceId]
    );
  }
  if (options.bump !== false) {
    await bumpWatchedIt();
  }
  return id;
};

export const deleteAdminRow = async (row: AdminMovie, options: { bump?: boolean } = {}) => {
  if (row.sourceIdentifier && row.__movieId) {
    await query(`DELETE FROM mov_movie_sources WHERE movie_id = $1 AND source_id = $2`, [
      row.__movieId,
      row.sourceIdentifier
    ]);
    await query(
      `
      UPDATE mov_sources SET movie_count = (
        SELECT COUNT(*) FROM mov_movie_sources WHERE source_id = $1
      ), updated_at = NOW()
      WHERE identifier = $1
      `,
      [row.sourceIdentifier]
    );
    const remaining = await query(`SELECT 1 FROM mov_movie_sources WHERE movie_id = $1 LIMIT 1`, [row.__movieId]);
    if (!remaining.rowCount) {
      await query(`DELETE FROM mov_movies WHERE id = $1`, [row.__movieId]);
    }
  } else if (row.__movieId) {
    await query(`DELETE FROM mov_movies WHERE id = $1`, [row.__movieId]);
  }
  if (options.bump !== false) {
    await bumpWatchedIt();
  }
};

export const adminCatalogHealth = (movies: AdminMovie[], sources: AdminSource[]) => {
  const missing = (movie: AdminMovie, field: keyof AdminMovie) => movie[field] == null || movie[field] === "";
  const seen = new Set<string>();
  let duplicateSourceTitles = 0;
  for (const movie of movies) {
    const key = `${movie.sourceIdentifier}|${movie.sourceTitle || movie.title}`;
    if (seen.has(key)) {
      duplicateSourceTitles += 1;
    } else {
      seen.add(key);
    }
  }
  return {
    totalMovies: movies.length,
    totalSources: sources.length,
    missingTmdbId: movies.filter((movie) => missing(movie, "tmdbId")).length,
    missingYear: movies.filter((movie) => missing(movie, "year")).length,
    missingPoster: movies.filter((movie) => missing(movie, "posterPath")).length,
    missingOverview: movies.filter((movie) => missing(movie, "overview")).length,
    missingGenres: movies.filter((movie) => !movie.genres?.length).length,
    missingStreaming: movies.filter((movie) => !movie.streamingServices?.length).length,
    missingCredits: movies.filter((movie) => movie.credits == null).length,
    missingTrailer: movies.filter((movie) => movie.trailer == null).length,
    duplicateSourceTitles
  };
};

export const buildDedupeGroups = (movies: AdminMovie[], sources: AdminSource[]) => {
  const groups = new Map<string, { key: string; sourceIdentifier: string | null; sourceName: string; title: string; items: Array<{ index: number; title: string; year: number | null; tmdbId: number | null }> }>();
  movies.forEach((movie, index) => {
    const sourceTitle = movie.sourceTitle || movie.title || "";
    const key = `${movie.sourceIdentifier}|${sourceTitle.toLowerCase()}`;
    if (!groups.has(key)) {
      groups.set(key, {
        key,
        sourceIdentifier: movie.sourceIdentifier,
        sourceName: sources.find((source) => source.identifier === movie.sourceIdentifier)?.name || movie.sourceIdentifier || "",
        title: sourceTitle,
        items: []
      });
    }
    groups.get(key)?.items.push({
      index,
      title: movie.title,
      year: movie.year,
      tmdbId: movie.tmdbId
    });
  });
  return [...groups.values()].filter((group) => group.items.length > 1);
};

export const updateOscarAwardsForTmdb = async (
  tmdbId: number,
  oscarAwards: unknown,
  imdbId?: string | null
) => {
  await query(
    `
    UPDATE mov_movies
    SET oscar_awards = $2::jsonb,
        imdb_id = COALESCE($3, imdb_id),
        last_updated = NOW()
    WHERE tmdb_id = $1
    `,
    [tmdbId, JSON.stringify(oscarAwards ?? null), imdbId ?? null]
  );
};

export const updateImdbIdForTmdb = async (tmdbId: number, imdbId: string) => {
  await query(
    `UPDATE mov_movies SET imdb_id = COALESCE(imdb_id, $2), last_updated = NOW() WHERE tmdb_id = $1`,
    [tmdbId, imdbId]
  );
};

export const clearOscarAwards = async () => {
  const result = await query(
    `UPDATE mov_movies SET oscar_awards = NULL, last_updated = NOW() WHERE oscar_awards IS NOT NULL`
  );
  return result.rowCount ?? 0;
};

export const clearInferredPhysicalMedia = async () => {
  const result = await query(
    `
    UPDATE mov_movies
    SET physical_media = NULL, last_updated = NOW()
    WHERE physical_media IS NOT NULL
      AND COALESCE((physical_media->>'manualOverride')::boolean, false) = false
    `
  );
  return result.rowCount ?? 0;
};

export { bumpWatchedIt };
