export type TmdbSearchHit = {
  id: number;
  title: string;
  original_title?: string;
  original_language?: string;
  release_date?: string;
  poster_path?: string;
  overview?: string;
  popularity?: number;
};

export type EpisodeMovieHints = {
  title: string;
  query: string;
  year: number | null;
  people: string[];
  language: string | null;
  era: "remake" | "original" | null;
  sourceTitle: string;
  alternateQueries: string[];
};

export type TmdbCreditsHint = {
  names: string[];
};

export type MatchHints = {
  year?: number | null;
  people?: string[];
  language?: string | null;
  era?: "remake" | "original" | null;
  creditsById?: Record<number, TmdbCreditsHint>;
};

const SHOW_PREFIXES = [
  /^the rewatchables\s*[:\-–—]\s*/i,
  /^the big picture\s*[:\-–—]\s*/i,
  /^blank check(?:\s+with griffin(?: and david)?)?\s*[:\-–—]\s*/i,
  /^the confused breakfast\s*[:\-–—]\s*/i,
  /^(?:miniseries|minisode|rewatch(?:ables)?)\s*[:\-–—]\s*/i
];

const stripShowAffixes = (title: string) => {
  let cleaned = String(title || "").replace(/\s+/g, " ").trim();
  for (const pattern of SHOW_PREFIXES) {
    cleaned = cleaned.replace(pattern, "");
  }
  for (const pattern of SHOW_SUFFIXES) {
    cleaned = cleaned.replace(pattern, "");
  }
  return cleaned.trim();
};

const BRUNCH_TITLE_PATTERN = /^\s*brunch\b/i;
const AVAILABILITY_BLURB_PATTERN = /^\s*(?:available|released)\b/i;

/** Confused Breakfast Monday bonuses are titled BRUNCH, not a single movie. */
export const isBrunchPodcastNoiseTitle = (title: string) => {
  const raw = String(title || "");
  return BRUNCH_TITLE_PATTERN.test(raw) || BRUNCH_TITLE_PATTERN.test(stripShowAffixes(raw));
};

/** Criterion shop chrome and similar list leftovers: "Available Feb 4, 2025", "Released Dec 10, 2024", "Available now". */
export const isAvailabilityBlurbTitle = (title: string) => {
  const raw = String(title || "");
  return AVAILABILITY_BLURB_PATTERN.test(raw) || AVAILABILITY_BLURB_PATTERN.test(stripShowAffixes(raw));
};

export const isNonMovieTitle = (title: string) => isBrunchPodcastNoiseTitle(title) || isAvailabilityBlurbTitle(title);

const SHOW_SUFFIXES = [
  /\s*[:\-–—]\s*(?:the rewatchables|the big picture|blank check|the confused breakfast)\s*$/i
];

const EDITORIAL_SUFFIXES = [
  /\s*[\(\[]\s*(?:rewatch|revisit|recap|review|live|bonus|mailbag)\s*[\)\]]\s*$/i,
  /\s+(?:recap|review|rewatch|revisit)\s*$/i
];

const HOST_NAMES = [
  "bill simmons",
  "chris ryan",
  "van lathan",
  "sean fennessey",
  "amanda dobbins",
  "wesley morris",
  "griffin newman",
  "david sims",
  "joanna robinson",
  "mallory rubin",
  "chris connelly"
];

const LANGUAGE_HINTS: Array<{ pattern: RegExp; code: string }> = [
  { pattern: /\b(?:south\s+)?korean(?:-language)?\b/i, code: "ko" },
  { pattern: /\bjapanese(?:-language)?\b/i, code: "ja" },
  { pattern: /\b(?:mandarin|cantonese|chinese|hong\s+kong|taiwanese)\b/i, code: "zh" },
  { pattern: /\b(?:hindi|bollywood)\b/i, code: "hi" },
  { pattern: /\bfrench(?:-language)?\b/i, code: "fr" },
  { pattern: /\bitalian(?:-language)?\b/i, code: "it" },
  { pattern: /\bspanish(?:-language)?|mexican|almod[oó]var\b/i, code: "es" },
  { pattern: /\bgerman(?:-language)?\b/i, code: "de" },
  { pattern: /\bswedish(?:-language)?\b/i, code: "sv" },
  { pattern: /\bdanish(?:-language)?\b/i, code: "da" },
  { pattern: /\bthai(?:-language)?\b/i, code: "th" }
];

const PERSON_STOP = new Set([
  ...HOST_NAMES,
  "the film",
  "the movie",
  "this one",
  "this movie",
  "our guests"
]);

export const normalizeEpisodeTitle = (title: string) => title.trim().toLowerCase();

const foldTitle = (value: string) =>
  String(value || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const looksLikePersonName = (value: string) => {
  const trimmed = value.trim();
  if (trimmed.length < 4 || trimmed.length > 40) {
    return false;
  }
  if (PERSON_STOP.has(trimmed.toLowerCase())) {
    return false;
  }
  return /^[A-Z][A-Za-zÀ-ÿ'.-]+(?:\s+[A-Z][A-Za-zÀ-ÿ'.-]+){1,3}$/.test(trimmed);
};

const looksLikeGuestList = (after: string) => {
  const text = String(after || "").trim();
  if (!text) {
    return false;
  }
  const lower = text.toLowerCase();
  if (HOST_NAMES.some((host) => lower.includes(host))) {
    return true;
  }
  if (/\b(?:guest|special guest|friends of the pod)\b/i.test(text)) {
    return true;
  }
  const parts = text
    .split(/\s*(?:,|\/|&| and )\s*/i)
    .map((part) => part.replace(/\.$/, "").trim())
    .filter(Boolean);
  if (parts.length >= 2 && parts.every((part) => looksLikePersonName(part) || HOST_NAMES.includes(part.toLowerCase()))) {
    return true;
  }
  return parts.length === 1 && looksLikePersonName(parts[0]);
};

const extractQuotedTitle = (title: string) => {
  const trimmed = String(title || "").trim();
  const wrapped = trimmed.match(/^[“"‘'](.+)[”"’'](?:\s+(?:with|feat\.?|featuring|—|-)\b|$)/i);
  if (wrapped?.[1] && wrapped[1].length >= 2) {
    return wrapped[1].trim();
  }
  const embedded = trimmed.match(/[“"]([^”"]{2,80})[”"]/);
  if (embedded?.[1]) {
    return embedded[1].trim();
  }
  const curly = trimmed.match(/[‘']([^’']{2,80})[’']/);
  if (curly?.[1] && !/^[a-z]/.test(curly[1])) {
    return curly[1].trim();
  }
  return null;
};

export const cleanPodcastTitle = (title: string) => {
  let cleaned = String(title || "").replace(/\s+/g, " ").trim();
  for (const pattern of SHOW_PREFIXES) {
    cleaned = cleaned.replace(pattern, "");
  }
  for (const pattern of SHOW_SUFFIXES) {
    cleaned = cleaned.replace(pattern, "");
  }

  const quoted = extractQuotedTitle(cleaned);
  if (quoted) {
    cleaned = quoted;
  } else {
    const withMatch = cleaned.match(/^(.*)\s+(?:with|feat\.?|featuring)\s+(.+)$/i);
    if (withMatch && looksLikeGuestList(withMatch[2])) {
      cleaned = withMatch[1].trim();
    } else {
      const dash = cleaned.match(/^(.*)\s+[—–-]\s+(.+)$/);
      if (dash && (looksLikeGuestList(dash[2]) || SHOW_SUFFIXES.some((pattern) => pattern.test(` - ${dash[2]}`)))) {
        cleaned = dash[1].trim();
      }
    }
  }
  cleaned = cleaned.replace(/\s*[—–-]\s*$/g, "").trim();

  cleaned = cleaned.replace(/^episode\s+\d+\s*[:\-–—]\s*/i, "").trim();
  cleaned = cleaned.replace(/^\d+[\.\):\-]\s+/, "").trim();
  for (const pattern of EDITORIAL_SUFFIXES) {
    cleaned = cleaned.replace(pattern, "");
  }
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

type YearCandidate = { year: number; weight: number };

const collectYears = (text: string) => {
  const candidates: YearCandidate[] = [];
  const add = (year: number, weight: number) => {
    if (year >= 1900 && year <= 2035) {
      candidates.push({ year, weight });
    }
  };
  const patterns: Array<{ regex: RegExp; weight: number }> = [
    { regex: /[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]/g, weight: 100 },
    { regex: /(?:the\s+)?((?:19|20)\d{2})\s+(?:south\s+)?(?:korean|japanese|chinese|hong\s+kong|mandarin|cantonese|french|italian|swedish)\s+(?:language\s+)?(?:film|movie|original|remake)/gi, weight: 95 },
    { regex: /(?:the\s+)?((?:19|20)\d{2})\s+(?:film|movie|picture|original|remake)/gi, weight: 90 },
    { regex: /((?:19|20)\d{2})\s+remake/gi, weight: 90 },
    { regex: /remake\s+(?:from|of|in)?\s*((?:19|20)\d{2})/gi, weight: 85 },
    { regex: /original(?:ly)?\s+(?:from|released\s+in|in)\s+((?:19|20)\d{2})/gi, weight: 85 },
    { regex: /released\s+in\s+((?:19|20)\d{2})/gi, weight: 70 },
    { regex: /((?:19|20)\d{2})(?:'s|\s+release)/gi, weight: 65 },
    { regex: /(?:from|in)\s+((?:19|20)\d{2})(?=\s+(?:film|movie|starring|directed|with))/gi, weight: 55 }
  ];
  for (const { regex, weight } of patterns) {
    regex.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = regex.exec(text))) {
      const start = Math.max(0, text.lastIndexOf(".", match.index));
      const end = text.indexOf(".", match.index);
      const sentence = text.slice(start, end === -1 ? undefined : end);
      const isAside = /\b(?:like|unlike|compared?(?:\s+it)?\s+to|mention(?:s|ed)?|reminds?(?:\s+me)?\s+of|echoes)\b/i.test(
        sentence
      );
      add(Number(match[1]), isAside ? Math.min(weight, 20) : weight);
    }
  }
  return candidates;
};

export const extractYearFromDescription = (description: string) => {
  const candidates = collectYears(description);
  if (!candidates.length) {
    return null;
  }
  return candidates.sort((left, right) => right.weight - left.weight)[0].year;
};

export const extractPersonNames = (text: string) => {
  const names = new Set<string>();
  const patterns = [
    /(?:starring|stars|featuring|feat\.)\s+([A-Z][A-Za-zÀ-ÿ'.-]+(?:\s+[A-Z][A-Za-zÀ-ÿ'.-]+){1,3})/g,
    /directed\s+by\s+([A-Z][A-Za-zÀ-ÿ'.-]+(?:\s+[A-Z][A-Za-zÀ-ÿ'.-]+){1,3})/g,
    /(?:director|cast(?:\s+includes)?)\s+([A-Z][A-Za-zÀ-ÿ'.-]+(?:\s+[A-Z][A-Za-zÀ-ÿ'.-]+){1,3})/g
  ];
  for (const pattern of patterns) {
    pattern.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(text))) {
      const name = match[1].trim();
      if (looksLikePersonName(name) && !HOST_NAMES.includes(name.toLowerCase())) {
        names.add(name);
      }
    }
  }
  const list = text.match(/(?:starring|stars|featuring)\s+([^.]+)/i);
  if (list?.[1]) {
    for (const part of list[1].split(/\s*(?:,|\/|&| and )\s*/i)) {
      const name = part.replace(/\.$/, "").trim();
      if (looksLikePersonName(name) && !HOST_NAMES.includes(name.toLowerCase())) {
        names.add(name);
      }
    }
  }
  return [...names];
};

export const extractLanguageHint = (text: string) => {
  for (const hint of LANGUAGE_HINTS) {
    if (hint.pattern.test(text)) {
      return hint.code;
    }
  }
  return null;
};

export const extractEraHint = (text: string): "remake" | "original" | null => {
  if (/\bremake\b/i.test(text) && !/\bthe original\b/i.test(text)) {
    return "remake";
  }
  if (/\b(?:the original|originally (?:released|made|shot))\b/i.test(text) && !/\bremake\b/i.test(text)) {
    return "original";
  }
  return null;
};

export const buildTmdbSearchInput = (rawTitle: string, description?: string | null) => {
  let query = String(rawTitle || "").trim();
  const titleYears = collectYears(query);
  let year: number | null = titleYears.sort((left, right) => right.weight - left.weight)[0]?.year ?? null;
  if (year == null && description) {
    year = extractYearFromDescription(description);
  }
  query = query.replace(/[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$/g, "").replace(/\s+/g, " ").trim();
  return {
    query: query || String(rawTitle || "").trim(),
    year
  };
};

export const prepareMovieQuery = (rawTitle: string, description?: string | null): EpisodeMovieHints => {
  const sourceTitle = String(rawTitle || "").trim();
  const combined = `${sourceTitle}\n${description || ""}`;
  const title = cleanTitle(cleanPodcastTitle(sourceTitle) || sourceTitle);
  const search = buildTmdbSearchInput(title, description);
  const alternateQueries = [...new Set([title, search.query].filter((value) => value && value !== search.query))];
  return {
    title,
    query: search.query,
    year: search.year,
    people: extractPersonNames(combined),
    language: extractLanguageHint(combined),
    era: extractEraHint(combined),
    sourceTitle,
    alternateQueries
  };
};

const movieYear = (movie: TmdbSearchHit) =>
  movie.release_date && /^\d{4}/.test(movie.release_date) ? Number(movie.release_date.slice(0, 4)) : null;

const namesMatch = (expected: string, actual: string) => {
  const left = foldTitle(expected);
  const right = foldTitle(actual);
  return Boolean(left && right && (left === right || left.includes(right) || right.includes(left)));
};

export const scoreTmdbMatch = (
  query: string,
  movie: TmdbSearchHit,
  yearOrHints?: number | null | MatchHints
) => {
  const hints: MatchHints =
    typeof yearOrHints === "number" || yearOrHints == null ? { year: yearOrHints ?? null } : yearOrHints;
  let score = 0;
  const year = movieYear(movie);
  const preferredYear = hints.year ?? null;
  if (preferredYear && year) {
    if (year === preferredYear) {
      score += 120;
    } else {
      const diff = Math.abs(year - preferredYear);
      if (diff === 1) {
        score += 40;
      } else if (diff <= 5) {
        score += 20 - diff * 4;
      } else {
        score -= 80;
      }
    }
  } else if (hints.era === "remake" && year && year >= 1995) {
    score += 20;
  } else if (hints.era === "original" && year && year <= 1985) {
    score += 20;
  }

  const normalizedQuery = foldTitle(query);
  const normalizedTitle = foldTitle(movie.title);
  const normalizedOriginal = foldTitle(movie.original_title || "");
  if (normalizedQuery && normalizedQuery === normalizedTitle) {
    score += 60;
  } else if (normalizedQuery && normalizedQuery === normalizedOriginal) {
    score += 60;
  } else if (
    normalizedQuery &&
    (normalizedTitle.includes(normalizedQuery) ||
      normalizedQuery.includes(normalizedTitle) ||
      (normalizedOriginal && (normalizedOriginal.includes(normalizedQuery) || normalizedQuery.includes(normalizedOriginal))))
  ) {
    score += 28;
  }

  if (hints.language && movie.original_language === hints.language) {
    score += 45;
  } else if (hints.language && movie.original_language && movie.original_language !== hints.language) {
    score -= 25;
  }

  const creditNames = hints.creditsById?.[movie.id]?.names ?? [];
  const haystack = [...creditNames, movie.overview || ""];
  for (const person of hints.people ?? []) {
    if (haystack.some((entry) => namesMatch(person, entry))) {
      score += creditNames.length ? 80 : 18;
    }
  }

  if (movie.poster_path) {
    score += 8;
  }
  if (typeof movie.popularity === "number") {
    score += Math.min(8, movie.popularity / 40);
  }
  return score;
};

export const pickBestTmdbMatch = (
  query: string,
  results: TmdbSearchHit[],
  yearOrHints?: number | null | MatchHints
) => {
  if (!results.length) {
    return null;
  }
  if (results.length === 1) {
    return results[0];
  }
  return [...results].sort(
    (left, right) => scoreTmdbMatch(query, right, yearOrHints) - scoreTmdbMatch(query, left, yearOrHints)
  )[0];
};

export const matchNeedsCreditCheck = (
  query: string,
  results: TmdbSearchHit[],
  hints: MatchHints
) => {
  if (results.length < 2) {
    return false;
  }
  const ranked = [...results].sort(
    (left, right) => scoreTmdbMatch(query, right, hints) - scoreTmdbMatch(query, left, hints)
  );
  const top = ranked[0];
  const runnerUp = ranked[1];
  const gap = scoreTmdbMatch(query, top, hints) - scoreTmdbMatch(query, runnerUp, hints);
  const years = new Set(ranked.slice(0, 4).map((movie) => movieYear(movie)).filter(Boolean));
  return gap < 40 || years.size > 1 || (hints.people?.length ?? 0) > 0;
};

export const determineItemStatus = (item: {
  tmdbId?: number | null;
  year?: number | null;
  posterPath?: string | null;
  overview?: string | null;
  genres?: unknown[];
}) => {
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
  if (isNonMovieTitle(rawTitle) || isNonMovieTitle(cleanedTitle)) {
    return true;
  }
  const haystack = `${rawTitle} ${cleanedTitle}`;
  if (sourceIdentifier === "big-picture") {
    return /\b(mailbag|draft|auction|box office|top\s*\d+|rankings|hall of fame|interview|preview|q&a|questions|state of|awards? race|oscars?|emmys?|tv corner|trailer talk|news round(up)?|hot take|power rankings)\b/i.test(
      haystack
    );
  }
  if (sourceIdentifier === "blank-check") {
    return /\b(mailbag|patreon|miniseries announcement|housekeeping)\b/i.test(haystack);
  }
  if (sourceIdentifier === "confused-breakfast") {
    return /\b(mailbag|q\s*&\s*a|q and a)\b/i.test(haystack);
  }
  return false;
};

export type PodcastIngestDecision =
  | { action: "skip"; reason: "duplicate" | "noise" | "unmatched" }
  | { action: "upsert" };

/** Decide whether auto ingest should commit a catalog row. Unmatched must not insert stubs. */
export const decidePodcastEpisodeIngest = (input: {
  sourceTitle: string;
  sourceIdentifier: string;
  existingTitles: Set<string>;
  preparedTitle: string;
  match?: { id: number } | null;
}): PodcastIngestDecision => {
  if (input.existingTitles.has(input.sourceTitle)) {
    return { action: "skip", reason: "duplicate" };
  }
  if (!input.preparedTitle || shouldSkipPodcastNoise(input.sourceIdentifier, input.sourceTitle, input.preparedTitle)) {
    return { action: "skip", reason: "noise" };
  }
  if (input.match === null) {
    return { action: "skip", reason: "unmatched" };
  }
  return { action: "upsert" };
};
