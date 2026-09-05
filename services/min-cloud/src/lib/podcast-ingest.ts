import { config } from "../config.js";
import { query } from "../db.js";
import { bumpWatchedIt, upsertAdminMovie } from "./admin-catalog.js";
import { fetchTmdbMovieDetails, searchTmdbMovies } from "./tmdb.js";
import {
  decidePodcastEpisodeIngest,
  determineItemStatus,
  isNonMovieTitle,
  matchNeedsCreditCheck,
  episodeTitleNamesMovie,
  pickConfidentTmdbMatch,
  prepareMovieQuery,
  scoreTmdbMatch,
  shouldSkipPodcastNoise,
  type EpisodeMovieHints,
  type MatchHints,
  type TmdbCreditsHint,
  type TmdbSearchHit
} from "./title-match.js";

const asHit = (movie: {
  id: number;
  title: string;
  original_title?: string;
  original_language?: string;
  release_date?: string;
  poster_path?: string;
  overview?: string;
  popularity?: number;
}): TmdbSearchHit => movie;

const creditsFromDetails = (details: Record<string, unknown>): TmdbCreditsHint => {
  const credits = details.credits as { cast?: Array<{ name?: string }>; crew?: Array<{ name?: string; job?: string }> } | undefined;
  const names = [
    ...(credits?.cast ?? []).slice(0, 12).map((member) => String(member.name || "")),
    ...(credits?.crew ?? [])
      .filter((member) => member.job === "Director")
      .map((member) => String(member.name || ""))
  ].filter(Boolean);
  return { names };
};

export const resolveTmdbMatch = async (prepared: EpisodeMovieHints) => {
  if (!prepared.query || !config.tmdbApiKey) {
    return null;
  }
  const search = async (query: string, year?: number) => {
    const results = await searchTmdbMovies(query, year, config.tmdbApiKey);
    return results.map(asHit);
  };
  let results = await search(prepared.query, prepared.year ?? undefined);
  if (!results.length && prepared.year) {
    results = await search(prepared.query);
  }
  if (!results.length) {
    for (const alternate of prepared.alternateQueries) {
      results = await search(alternate, prepared.year ?? undefined);
      if (results.length) {
        break;
      }
      results = await search(alternate);
      if (results.length) {
        break;
      }
    }
  }
  if (!results.length) {
    return null;
  }
  const hints: MatchHints = {
    year: prepared.year,
    people: prepared.people,
    language: prepared.language,
    era: prepared.era
  };
  if (matchNeedsCreditCheck(prepared.query, results, hints)) {
    const creditsById: Record<number, TmdbCreditsHint> = {};
    for (const movie of results.slice(0, 4)) {
      try {
        const details = await fetchTmdbMovieDetails(movie.id, config.tmdbApiKey);
        creditsById[movie.id] = creditsFromDetails(details);
      } catch {
        creditsById[movie.id] = { names: [] };
      }
    }
    hints.creditsById = creditsById;
  }
  return pickConfidentTmdbMatch(prepared.query, results, hints);
};

export const matchScore = (prepared: EpisodeMovieHints, movie: TmdbSearchHit) =>
  scoreTmdbMatch(prepared.query, movie, {
    year: prepared.year,
    people: prepared.people,
    language: prepared.language,
    era: prepared.era
  });

export const ingestPodcastEpisode = async (input: {
  title: string;
  sourceTitle: string;
  sourceIdentifier: string;
  episodeDate?: string | null;
  description?: string | null;
  existingTitles: Set<string>;
  bump?: boolean;
}) => {
  const prepared = prepareMovieQuery(input.title || input.sourceTitle, input.description);
  const early = decidePodcastEpisodeIngest({
    sourceTitle: input.sourceTitle,
    sourceIdentifier: input.sourceIdentifier,
    existingTitles: input.existingTitles,
    preparedTitle: prepared.title
  });
  if (early.action === "skip") {
    return { added: false, skipped: true, reason: early.reason };
  }
  const match = await resolveTmdbMatch(prepared);
  // Do not upsert unmatched leftovers — that created empty BRUNCH / topic stubs.
  const decided = decidePodcastEpisodeIngest({
    sourceTitle: input.sourceTitle,
    sourceIdentifier: input.sourceIdentifier,
    existingTitles: input.existingTitles,
    preparedTitle: prepared.title,
    match
  });
  if (!match) {
    return { added: false, skipped: true, reason: "unmatched" as const };
  }
  if (decided.action === "skip") {
    return { added: false, skipped: true, reason: decided.reason };
  }
  const details = await fetchTmdbMovieDetails(match.id, config.tmdbApiKey);
  const posterPath = (details.poster_path as string) || null;
  const ready = decidePodcastEpisodeIngest({
    sourceTitle: input.sourceTitle,
    sourceIdentifier: input.sourceIdentifier,
    existingTitles: input.existingTitles,
    preparedTitle: prepared.title,
    match,
    posterPath
  });
  if (ready.action === "skip") {
    return { added: false, skipped: true, reason: ready.reason };
  }
  if (!episodeTitleNamesMovie(input.sourceTitle, String(details.title || prepared.title))) {
    return { added: false, skipped: true, reason: "unmatched" as const };
  }
  const releaseDate = details.release_date ? String(details.release_date) : "";
  const credits = details.credits as { cast?: Array<Record<string, unknown>>; crew?: Array<Record<string, unknown>> } | undefined;
  const director = credits?.crew?.find((member) => member.job === "Director");
  const cast = (credits?.cast ?? []).slice(0, 10).map((member) => ({
    id: member.id,
    name: member.name,
    character: member.character ?? null,
    profilePath: member.profile_path ?? null
  }));
  await upsertAdminMovie(
    {
      title: String(details.title || prepared.title),
      tmdbId: Number(details.id),
      year: releaseDate ? Number(releaseDate.slice(0, 4)) : prepared.year,
      sourceIdentifier: input.sourceIdentifier,
      sourceTitle: input.sourceTitle,
      episodeDate: input.episodeDate ?? null,
      overview: (details.overview as string) || input.description || null,
      posterPath,
      backdropPath: (details.backdrop_path as string) || null,
      genres: Array.isArray(details.genres) ? (details.genres as Array<{ name: string }>).map((genre) => genre.name) : [],
      credits: director || cast.length ? { director: director?.name ?? null, cast } : null,
      podcastEpisodeDescription: input.description ?? null
    },
    null,
    { bump: input.bump !== false }
  );
  input.existingTitles.add(input.sourceTitle);
  return {
    added: true,
    skipped: false,
    reason: determineItemStatus({
      tmdbId: Number(details.id),
      year: releaseDate ? Number(releaseDate.slice(0, 4)) : null,
      posterPath,
      overview: (details.overview as string) || null,
      genres: Array.isArray(details.genres) ? details.genres : []
    }) as "enriched" | "light",
    title: String(details.title || prepared.title),
    tmdbId: Number(details.id)
  };
};

const updateSourceMovieCount = async (sourceId: string) => {
  await query(
    `
    UPDATE mov_sources SET movie_count = (
      SELECT COUNT(*) FROM mov_movie_sources WHERE source_id = $1
    ), updated_at = NOW()
    WHERE identifier = $1
    `,
    [sourceId]
  );
};

const purgeUnverifiedBigPictureLinks = async () => {
  const links = await query(
    `
    SELECT ms.movie_id, ms.source_id, ms.source_title, m.title
    FROM mov_movie_sources ms
    JOIN mov_movies m ON m.id = ms.movie_id
    WHERE ms.source_id = 'big-picture'
    `
  );
  const sourceIds = new Set<string>();
  const movieIds = new Set<string>();
  let purgedLinks = 0;
  for (const row of links.rows) {
    const sourceTitle = String(row.source_title || "").trim();
    const title = String(row.title || "");
    const keep =
      Boolean(sourceTitle) &&
      !shouldSkipPodcastNoise("big-picture", sourceTitle, sourceTitle) &&
      episodeTitleNamesMovie(sourceTitle, title);
    if (keep) {
      continue;
    }
    await query(`DELETE FROM mov_movie_sources WHERE movie_id = $1 AND source_id = $2`, [row.movie_id, row.source_id]);
    purgedLinks += 1;
    sourceIds.add(String(row.source_id));
    movieIds.add(String(row.movie_id));
  }
  let purgedMovies = 0;
  for (const movieId of movieIds) {
    const remaining = await query(`SELECT 1 FROM mov_movie_sources WHERE movie_id = $1 LIMIT 1`, [movieId]);
    if (!remaining.rowCount) {
      await query(`DELETE FROM mov_movies WHERE id = $1`, [movieId]);
      purgedMovies += 1;
    }
  }
  for (const sourceId of sourceIds) {
    await updateSourceMovieCount(sourceId);
  }
  return { purgedLinks, purgedMovies };
};

/**
 * Remove catalog leftovers that are not movies: Confused Breakfast BRUNCH stubs,
 * Criterion-style "Available …" / "Released …" badges, and Big Picture episodes
 * that never named the film they were attached to.
 */
export const purgePodcastNoiseMovies = async () => {
  const candidates = await query(
    `
    SELECT ms.movie_id, ms.source_id, ms.source_title, m.title, m.tmdb_id
    FROM mov_movie_sources ms
    JOIN mov_movies m ON m.id = ms.movie_id
    LEFT JOIN mov_sources s ON s.identifier = ms.source_id
    WHERE (
      ms.source_id = 'confused-breakfast'
      AND (
        COALESCE(ms.source_title, '') ~* 'brunch'
        OR COALESCE(m.title, '') ~* 'brunch'
      )
    )
    OR (
      m.tmdb_id IS NULL
      AND (s.type IS NULL OR s.type = 'podcast')
      AND (
        COALESCE(ms.source_title, '') ~* 'brunch'
        OR COALESCE(m.title, '') ~* 'brunch'
      )
    )
    OR (
      COALESCE(ms.source_title, '') ~* '^\\s*(available|released)\\b'
      OR COALESCE(m.title, '') ~* '^\\s*(available|released)\\b'
    )
    `
  );

  const sourceIds = new Set<string>();
  const movieIds = new Set<string>();
  let purgedLinks = 0;

  for (const row of candidates.rows) {
    const sourceTitle = String(row.source_title || "");
    const title = String(row.title || "");
    if (!isNonMovieTitle(sourceTitle) && !isNonMovieTitle(title)) {
      continue;
    }
    await query(`DELETE FROM mov_movie_sources WHERE movie_id = $1 AND source_id = $2`, [
      row.movie_id,
      row.source_id
    ]);
    purgedLinks += 1;
    sourceIds.add(String(row.source_id));
    movieIds.add(String(row.movie_id));
  }

  let purgedMovies = 0;
  for (const movieId of movieIds) {
    const remaining = await query(`SELECT 1 FROM mov_movie_sources WHERE movie_id = $1 LIMIT 1`, [movieId]);
    if (!remaining.rowCount) {
      await query(`DELETE FROM mov_movies WHERE id = $1`, [movieId]);
      purgedMovies += 1;
    }
  }

  for (const sourceId of sourceIds) {
    await updateSourceMovieCount(sourceId);
  }

  const bigPicture = await purgeUnverifiedBigPictureLinks();
  purgedLinks += bigPicture.purgedLinks;
  purgedMovies += bigPicture.purgedMovies;

  if (purgedLinks > 0 || purgedMovies > 0) {
    await bumpWatchedIt();
  }

  return { purgedMovies, purgedLinks };
};
