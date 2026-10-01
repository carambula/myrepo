import { query } from "../db.js";
import { config } from "../config.js";
import { bumpWatchedIt, upsertAdminMovie } from "./admin-catalog.js";
import {
  DELTA_IN_FLIGHT_SOURCE_ID,
  DELTA_IN_FLIGHT_SOURCE_NAME,
  DELTA_IN_FLIGHT_URL,
  fetchDeltaInFlightPage,
  scrapeDeltaInFlightMovies
} from "./delta-in-flight.js";
import { resolveTmdbMatch } from "./podcast-ingest.js";
import { fetchTmdbMovieDetails } from "./tmdb.js";
import { prepareMovieQuery } from "./title-match.js";

export type DeltaInFlightRefreshStats = {
  scraped: number;
  linked: number;
  added: number;
  unmatched: number;
  unlinked: number;
  failed: number;
};

const ensureSource = async () => {
  await query(
    `
    INSERT INTO mov_sources (identifier, name, type, url, is_ranked, enabled, movie_count, updated_at)
    VALUES ($1, $2, 'url', $3, FALSE, TRUE, 0, NOW())
    ON CONFLICT (identifier) DO UPDATE SET
      name = EXCLUDED.name,
      type = EXCLUDED.type,
      url = EXCLUDED.url,
      enabled = TRUE,
      updated_at = NOW()
    `,
    [DELTA_IN_FLIGHT_SOURCE_ID, DELTA_IN_FLIGHT_SOURCE_NAME, DELTA_IN_FLIGHT_URL]
  );
};

const findExistingMovieId = async (title: string, year: number | null, tmdbId: number | null) => {
  if (tmdbId) {
    const byTmdb = await query(`SELECT id FROM mov_movies WHERE tmdb_id = $1 LIMIT 1`, [tmdbId]);
    if (byTmdb.rows[0]?.id) {
      return String(byTmdb.rows[0].id);
    }
  }
  const byTitle = await query(`SELECT id, year FROM mov_movies WHERE lower(title) = lower($1)`, [title]);
  if (year != null) {
    const yearHit = byTitle.rows.find((row) => Number(row.year) === year);
    if (yearHit?.id) {
      return String(yearHit.id);
    }
  }
  if (byTitle.rows.length === 1 && byTitle.rows[0]?.id) {
    return String(byTitle.rows[0].id);
  }
  return null;
};

const linkMovie = async (movieId: string, sourceTitle: string, rank: number, section: string | null) => {
  await query(
    `
    INSERT INTO mov_movie_sources (movie_id, source_id, rank, source_title, episode_date, episode)
    VALUES ($1, $2, $3, $4, NULL, $5::jsonb)
    ON CONFLICT (movie_id, source_id) DO UPDATE SET
      rank = EXCLUDED.rank,
      source_title = EXCLUDED.source_title,
      episode = EXCLUDED.episode
    `,
    [
      movieId,
      DELTA_IN_FLIGHT_SOURCE_ID,
      rank,
      sourceTitle,
      JSON.stringify({
        title: sourceTitle,
        description: section ? `${DELTA_IN_FLIGHT_SOURCE_NAME}   ${section}` : DELTA_IN_FLIGHT_SOURCE_NAME,
        episodeId: DELTA_IN_FLIGHT_URL
      })
    ]
  );
  await query(`UPDATE mov_movies SET last_updated = NOW() WHERE id = $1`, [movieId]);
};

export const refreshDeltaInFlightCatalog = async (
  html?: string
): Promise<DeltaInFlightRefreshStats> => {
  await ensureSource();
  const page = html ?? (await fetchDeltaInFlightPage());
  const movies = scrapeDeltaInFlightMovies(page);
  const linkedIds = new Set<string>();
  const stats: DeltaInFlightRefreshStats = {
    scraped: movies.length,
    linked: 0,
    added: 0,
    unmatched: 0,
    unlinked: 0,
    failed: 0
  };

  for (const [index, movie] of movies.entries()) {
    try {
      const prepared = prepareMovieQuery(movie.year ? `${movie.title} (${movie.year})` : movie.title);
      const match = config.tmdbApiKey ? await resolveTmdbMatch(prepared) : null;
      const tmdbId = match?.id ?? null;
      let movieId = await findExistingMovieId(movie.title, movie.year ?? prepared.year, tmdbId);
      if (!movieId && match && config.tmdbApiKey) {
        const details = await fetchTmdbMovieDetails(match.id, config.tmdbApiKey);
        const releaseDate = details.release_date ? String(details.release_date) : "";
        movieId = await upsertAdminMovie(
          {
            title: String(details.title || movie.title),
            tmdbId: Number(details.id),
            year: releaseDate ? Number(releaseDate.slice(0, 4)) : movie.year ?? prepared.year,
            sourceIdentifier: DELTA_IN_FLIGHT_SOURCE_ID,
            sourceTitle: movie.title,
            rank: index + 1,
            overview: (details.overview as string) || null,
            posterPath: (details.poster_path as string) || null,
            backdropPath: (details.backdrop_path as string) || null,
            genres: Array.isArray(details.genres)
              ? (details.genres as Array<{ name: string }>).map((genre) => genre.name)
              : [],
            podcastEpisodeDescription: movie.section
              ? `${DELTA_IN_FLIGHT_SOURCE_NAME}   ${movie.section}`
              : DELTA_IN_FLIGHT_SOURCE_NAME,
            sourceUrl: DELTA_IN_FLIGHT_URL
          },
          null,
          { bump: false }
        );
        stats.added += 1;
      } else if (movieId) {
        await linkMovie(movieId, movie.title, index + 1, movie.section);
        stats.linked += 1;
      } else {
        stats.unmatched += 1;
        continue;
      }
      if (movieId) {
        linkedIds.add(movieId);
      }
    } catch {
      stats.failed += 1;
    }
  }

  const existing = await query(
    `SELECT movie_id FROM mov_movie_sources WHERE source_id = $1`,
    [DELTA_IN_FLIGHT_SOURCE_ID]
  );
  for (const row of existing.rows) {
    const movieId = String(row.movie_id);
    if (linkedIds.has(movieId)) {
      continue;
    }
    await query(`DELETE FROM mov_movie_sources WHERE movie_id = $1 AND source_id = $2`, [
      movieId,
      DELTA_IN_FLIGHT_SOURCE_ID
    ]);
    await query(`UPDATE mov_movies SET last_updated = NOW() WHERE id = $1`, [movieId]);
    stats.unlinked += 1;
  }

  await query(
    `
    UPDATE mov_sources SET movie_count = (
      SELECT COUNT(*) FROM mov_movie_sources WHERE source_id = $1
    ), updated_at = NOW()
    WHERE identifier = $1
    `,
    [DELTA_IN_FLIGHT_SOURCE_ID]
  );
  await bumpWatchedIt();
  return stats;
};
