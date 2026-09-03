import { config } from "../config.js";
import { upsertAdminMovie } from "./admin-catalog.js";
import { fetchTmdbMovieDetails, searchTmdbMovies } from "./tmdb.js";
import {
  determineItemStatus,
  matchNeedsCreditCheck,
  pickBestTmdbMatch,
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
  return pickBestTmdbMatch(prepared.query, results, hints);
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
  if (input.existingTitles.has(input.sourceTitle)) {
    return { added: false, skipped: true, reason: "duplicate" as const };
  }
  const prepared = prepareMovieQuery(input.title || input.sourceTitle, input.description);
  if (!prepared.title || shouldSkipPodcastNoise(input.sourceIdentifier, input.sourceTitle, prepared.title)) {
    return { added: false, skipped: true, reason: "noise" as const };
  }
  const match = await resolveTmdbMatch(prepared);
  if (!match) {
    await upsertAdminMovie(
    {
      title: prepared.title,
      sourceIdentifier: input.sourceIdentifier,
      sourceTitle: input.sourceTitle,
      episodeDate: input.episodeDate ?? null,
      overview: input.description ?? null,
      podcastEpisodeDescription: input.description ?? null
    },
    null,
    { bump: input.bump !== false }
  );
    input.existingTitles.add(input.sourceTitle);
    return { added: true, skipped: false, reason: "unmatched" as const, title: prepared.title };
  }
  const details = await fetchTmdbMovieDetails(match.id, config.tmdbApiKey);
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
      posterPath: (details.poster_path as string) || null,
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
      posterPath: (details.poster_path as string) || null,
      overview: (details.overview as string) || null,
      genres: Array.isArray(details.genres) ? details.genres : []
    }) as "enriched" | "light",
    title: String(details.title || prepared.title),
    tmdbId: Number(details.id)
  };
};
