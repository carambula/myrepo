export type TmdbSearchHit = {
  id: number;
  title: string;
  release_date?: string;
  poster_path?: string;
  overview?: string;
};

export const normalizeEpisodeTitle = (title: string) => title.trim().toLowerCase();

export const cleanPodcastTitle = (title: string) => {
  let cleaned = String(title || "");
  cleaned = cleaned.replace(/^["'“”‘’]+|["'“”‘’]+$/g, "");
  cleaned = cleaned.replace(/\s+/g, " ").trim();

  const withIndex = cleaned.toLowerCase().indexOf(" with ");
  if (withIndex > 0) {
    cleaned = cleaned.slice(0, withIndex).trim();
  }

  const dashIndex = cleaned.indexOf(" - ");
  if (dashIndex > 0) {
    cleaned = cleaned.slice(0, dashIndex).trim();
  }

  cleaned = cleaned.replace(/^episode\s+\d+:\s*/i, "").trim();
  cleaned = cleaned.replace(/^\d+[\.\):\-]\s+/, "").trim();
  cleaned = cleaned.replace(/[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$/g, "").trim();
  cleaned = cleaned.replace(/^["'“”‘’]+|["'“”‘’]+$/g, "").trim();
  return cleaned;
};

export const cleanTitle = (title: string) => {
  let cleaned = String(title || "");
  cleaned = cleaned.replace(/\s*(?:LIVE|Live)\s+From\s+[A-Za-z\s]+/gi, "");

  const listNumbering = [/^(\d+)\.\s+/, /^#(\d+)\s+/, /^(\d+)\)\s+/, /^\((\d+)\)\s+/, /^(\d+)[:–\-]\s+/];
  for (const pattern of listNumbering) {
    const match = cleaned.match(pattern);
    if (match && Number(match[1]) <= 999) {
      cleaned = cleaned.slice(match[0].length);
      break;
    }
  }

  cleaned = cleaned
    .replace(/\s*\(Part\s+\d+\)/gi, "")
    .replace(/\s*\(Part\s+[IVX]+\)/gi, "")
    .replace(/\s*Part\s+\d+/gi, "")
    .replace(/\s*Part\s+[IVX]+/gi, "")
    .replace(/\s*\(Episode\s+\d+\)/gi, "")
    .replace(/\s*Episode\s+\d+/gi, "");

  const quotes = `'"“”‘’\`´′″`;
  let changed = true;
  while (changed) {
    changed = false;
    const next = cleaned.replace(new RegExp(`^[${quotes}]+|[${quotes}]+$`, "g"), "").trim();
    if (next !== cleaned) {
      cleaned = next;
      changed = true;
    }
  }

  cleaned = cleaned.replace(/\s+/g, " ").replace(/^[, ]+|[, ]+$/g, "").trim();
  return cleaned;
};

export const extractYearFromDescription = (description: string) => {
  const patterns = [
    /(?:the\s+)?((?:19|20)\d{2})\s+film/i,
    /(?:from|in)\s+((?:19|20)\d{2})/i,
    /released\s+in\s+((?:19|20)\d{2})/i,
    /((?:19|20)\d{2})(?:'s|\s+release)/i,
    /[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]/
  ];
  for (const pattern of patterns) {
    const match = description.match(pattern);
    if (match) {
      return Number(match[1]);
    }
  }
  return null;
};

export const buildTmdbSearchInput = (rawTitle: string, description?: string | null) => {
  let query = String(rawTitle || "").trim();
  let year: number | null = null;
  const yearMatch = query.match(/[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]\s*$/);
  if (yearMatch) {
    year = Number(yearMatch[1]);
  }
  if (year == null && description) {
    year = extractYearFromDescription(description);
  }
  query = query.replace(/[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$/g, "").replace(/\s+/g, " ").trim();
  return {
    query: query || String(rawTitle || "").trim(),
    year
  };
};

export const prepareMovieQuery = (rawTitle: string, description?: string | null) => {
  const sourceTitle = String(rawTitle || "").trim();
  const title = cleanTitle(cleanPodcastTitle(sourceTitle) || sourceTitle);
  const search = buildTmdbSearchInput(title, description);
  return {
    title,
    query: search.query,
    year: search.year,
    sourceTitle
  };
};

const movieYear = (movie: TmdbSearchHit) =>
  movie.release_date && /^\d{4}/.test(movie.release_date) ? Number(movie.release_date.slice(0, 4)) : null;

export const scoreTmdbMatch = (query: string, movie: TmdbSearchHit, preferredYear?: number | null) => {
  let score = 0;
  const year = movieYear(movie);
  if (preferredYear && year) {
    if (year === preferredYear) {
      score += 100;
    } else {
      const diff = Math.abs(year - preferredYear);
      if (diff === 1) {
        score += 50;
      } else if (diff <= 5) {
        score += 25 - diff * 5;
      } else {
        score -= 50;
      }
    }
  }

  const normalizedQuery = query.toLowerCase().trim();
  const normalizedTitle = movie.title.toLowerCase().trim();
  if (normalizedQuery === normalizedTitle) {
    score += 50;
  } else if (normalizedTitle.includes(normalizedQuery) || normalizedQuery.includes(normalizedTitle)) {
    score += 30;
  }

  if (movie.poster_path) {
    score += 10;
  }
  return score;
};

export const pickBestTmdbMatch = (query: string, results: TmdbSearchHit[], preferredYear?: number | null) => {
  if (!results.length) {
    return null;
  }
  if (results.length === 1) {
    return results[0];
  }
  return [...results].sort((left, right) => scoreTmdbMatch(query, right, preferredYear) - scoreTmdbMatch(query, left, preferredYear))[0];
};

export const determineItemStatus = (item: { tmdbId?: number | null; year?: number | null; posterPath?: string | null; overview?: string | null; genres?: unknown[] }) => {
  if (!item.tmdbId) {
    return "missing";
  }
  const hasCore = Boolean(item.year && item.posterPath && item.overview && item.genres && item.genres.length > 0);
  return hasCore ? "enriched" : "light";
};

export const shouldSkipPodcastNoise = (sourceIdentifier: string, rawTitle: string, cleanedTitle: string) => {
  if (!normalizeEpisodeTitle(cleanedTitle)) {
    return true;
  }
  if (sourceIdentifier === "big-picture") {
    return /\b(mailbag|draft|auction|box office|top\s*\d+|rankings|hall of fame|interview|preview|q&a|questions|state of|awards? race|oscars?|emmys?|tv corner|trailer talk|news round(up)?|hot take|power rankings)\b/i.test(
      normalizeEpisodeTitle(rawTitle)
    );
  }
  return false;
};
