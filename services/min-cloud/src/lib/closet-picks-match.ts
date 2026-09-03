import { cleanTitle, type EpisodeMovieHints } from "./title-match.js";
import { CLOSET_PICKS_SOURCE_ID, normalizeClosetPicksTitle } from "./closet-picks-scrape.js";

export const isClosetPicksSource = (identifier?: string | null) =>
  String(identifier || "").trim() === CLOSET_PICKS_SOURCE_ID;

const foldName = (value: string) =>
  normalizeClosetPicksTitle(value)
    .replace(/\b(jr|sr|iii|ii)\b/g, "")
    .replace(/\s+/g, " ")
    .trim();

export const splitDirectorNames = (director?: string | null) => {
  const cleaned = String(director || "").trim();
  if (!cleaned) {
    return [];
  }
  return cleaned
    .split(/\s+(?:and|&)\s+/i)
    .map((name) => name.replace(/\s+/g, " ").trim())
    .filter((name) => name.length > 2);
};

export const directorsOverlap = (expected?: string | null, actual?: string | null) => {
  const left = splitDirectorNames(expected).map(foldName).filter(Boolean);
  const right = splitDirectorNames(actual).map(foldName).filter(Boolean);
  if (!left.length || !right.length) {
    return false;
  }
  return left.some((name) => right.some((other) => name === other || name.includes(other) || other.includes(name)));
};

export const prepareClosetPicksQuery = (item: {
  title: string;
  year?: number | null;
  director?: string | null;
  originalTitle?: string | null;
}): EpisodeMovieHints => {
  const title = cleanTitle(String(item.title || "").trim()) || String(item.title || "").trim();
  const original = String(item.originalTitle || "").trim();
  const alternateQueries = [original, title].filter((value) => value && value !== title);
  return {
    title,
    query: title,
    year: item.year ?? null,
    people: splitDirectorNames(item.director),
    language: null,
    era: item.year && item.year <= 1985 ? "original" : null,
    sourceTitle: item.title,
    alternateQueries: [...new Set(alternateQueries)]
  };
};

export const closetPicksMatchLooksWrong = (
  movie: { tmdbId?: number | null; year?: number | null; credits?: { director?: string | null } | null | unknown },
  film: { year?: number | null; director?: string | null }
) => {
  if (!movie.tmdbId) {
    return true;
  }
  if (film.year && movie.year && Math.abs(Number(movie.year) - Number(film.year)) > 2) {
    return true;
  }
  const director =
    movie.credits && typeof movie.credits === "object"
      ? String((movie.credits as { director?: string | null }).director || "")
      : "";
  if (film.director && director && !directorsOverlap(film.director, director)) {
    return true;
  }
  return false;
};
