import { fetchText } from "./http.js";
import { isAvailabilityBlurbTitle } from "./title-match.js";

export const DELTA_IN_FLIGHT_SOURCE_ID = "delta-in-flight";
export const DELTA_IN_FLIGHT_SOURCE_NAME = "Delta in-flight";
export const DELTA_IN_FLIGHT_URL =
  "https://www.delta.com/us/en/onboard/inflight-entertainment/current-movies";
export const DELTA_IN_FLIGHT_LETTERBOXD_URL =
  "https://letterboxd.com/ebusch0320/list/delta-in-flight-movies/";
export const DELTA_IN_FLIGHT_LETTERBOXD_SECTION = "Letterboxd";

export const DELTA_IN_FLIGHT_PROVIDER = {
  id: DELTA_IN_FLIGHT_SOURCE_ID,
  name: DELTA_IN_FLIGHT_SOURCE_NAME,
  logoPath: null,
  url: DELTA_IN_FLIGHT_URL,
  providerId: -1001,
  providerName: DELTA_IN_FLIGHT_SOURCE_NAME,
  displayPriority: 0
};

const BROWSER_UA =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const POSSESSIVE_CREDIT = /^[A-Z][A-Za-zÀ-ÿ.']+(?:\s+[A-Z][A-Za-zÀ-ÿ.']+)*['’]s\s+/;

export type DeltaInFlightMovie = {
  title: string;
  year: number | null;
  section: string | null;
};

const decodeEntities = (value: string) =>
  value
    .replace(/&nbsp;|&#160;|\u00a0/gi, " ")
    .replace(/&amp;/g, "&")
    .replace(/&#039;|&apos;|&#x27;/g, "'")
    .replace(/&rsquo;|&#8217;/g, "\u2019")
    .replace(/&lsquo;|&#8216;/g, "\u2018")
    .replace(/&quot;/g, '"')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/\s+/g, " ")
    .trim();

export const isDeltaInFlightUrl = (url: string) => {
  try {
    const parsed = new URL(url);
    return parsed.hostname.endsWith("delta.com") && /inflight-entertainment\/current-movies/i.test(parsed.pathname);
  } catch {
    return /delta\.com\/.+current-movies/i.test(url);
  }
};

export const isDeltaInFlightLetterboxdUrl = (url: string) => {
  try {
    const parsed = new URL(url);
    return parsed.hostname.endsWith("letterboxd.com") && /\/list\/delta-in-flight-movies/i.test(parsed.pathname);
  } catch {
    return /letterboxd\.com\/.+\/list\/delta-in-flight-movies/i.test(url);
  }
};

export const isDeltaInFlightProvider = (service: { name?: unknown; providerName?: unknown; id?: unknown }) => {
  const name = String(service.providerName ?? service.name ?? "")
    .trim()
    .toLowerCase()
    .replace(/[-_]+/g, " ");
  const id = String(service.id ?? "").trim().toLowerCase();
  return (
    id === DELTA_IN_FLIGHT_SOURCE_ID ||
    name === "delta in-flight" ||
    name === "delta in flight" ||
    name === "delta inflight" ||
    name === "delta studio"
  );
};

export const withDeltaInFlightProvider = (providers: unknown, linked: boolean) => {
  const list = Array.isArray(providers) ? [...providers] : [];
  const without = list.filter((item) => !isDeltaInFlightProvider((item ?? {}) as Record<string, unknown>));
  if (!linked) {
    return without;
  }
  return [DELTA_IN_FLIGHT_PROVIDER, ...without];
};

export const parseDeltaTitle = (rawTitle: string, options: { stripPossessive?: boolean } = {}) => {
  const decoded = decodeEntities(rawTitle);
  const yearMatch = decoded.match(/[\(\[]\s*(?:'|’)?((?:19|20)\d{2})\s*[\)\]]\s*$/);
  const shortYear = decoded.match(/[\(\[]\s*(?:'|’)?(\d{2})\s*[\)\]]\s*$/);
  let year: number | null = null;
  let title = decoded;
  if (yearMatch) {
    year = Number(yearMatch[1]);
    title = decoded.slice(0, yearMatch.index).trim();
  } else if (shortYear) {
    year = 2000 + Number(shortYear[1]);
    title = decoded.slice(0, shortYear.index).trim();
  }
  if (options.stripPossessive) {
    title = title.replace(POSSESSIVE_CREDIT, "").trim() || title;
  }
  return { title, year };
};

const isNoiseTitle = (title: string) => {
  if (!title || title.length < 2 || title.length > 120) {
    return true;
  }
  if (isAvailabilityBlurbTitle(title)) {
    return true;
  }
  return /^(movies|new on delta|popular on delta|delta studio|before you fly|featured movies)$/i.test(title);
};

export const scrapeDeltaInFlightMovies = (html: string): DeltaInFlightMovie[] => {
  const movies: DeltaInFlightMovie[] = [];
  const seen = new Set<string>();
  let section: string | null = null;

  const headingPattern = /<h2[^>]*>([^<]+)<\/h2>/gi;
  const imagePattern =
    /<img[^>]*src="[^"]*movie-thumbs\/[^"]*"[^>]*title="([^"]+)"[^>]*>/gi;
  const centeredPattern = /<p[^>]*text-align:\s*center[^>]*>\s*([^<]+?)\s*<\/p>/gi;

  const tokens: Array<{ kind: "section" | "title"; value: string; index: number }> = [];
  for (const match of html.matchAll(headingPattern)) {
    tokens.push({ kind: "section", value: decodeEntities(match[1]), index: match.index ?? 0 });
  }
  for (const match of html.matchAll(imagePattern)) {
    tokens.push({ kind: "title", value: decodeEntities(match[1]), index: match.index ?? 0 });
  }
  if (!tokens.some((token) => token.kind === "title")) {
    for (const match of html.matchAll(centeredPattern)) {
      tokens.push({ kind: "title", value: decodeEntities(match[1]), index: match.index ?? 0 });
    }
  }
  tokens.sort((left, right) => left.index - right.index);

  for (const token of tokens) {
    if (token.kind === "section") {
      section = token.value;
      continue;
    }
    const parsed = parseDeltaTitle(token.value, { stripPossessive: true });
    if (isNoiseTitle(parsed.title)) {
      continue;
    }
    const key = `${parsed.title.toLowerCase()}|${parsed.year ?? ""}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    movies.push({ title: parsed.title, year: parsed.year, section });
  }
  return movies;
};

export const foldDeltaTitle = (title: string) =>
  decodeEntities(title)
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const sameDeltaMovie = (left: DeltaInFlightMovie, right: DeltaInFlightMovie) => {
  if (foldDeltaTitle(left.title) !== foldDeltaTitle(right.title)) {
    return false;
  }
  if (left.year == null || right.year == null) {
    return true;
  }
  return left.year === right.year;
};

export const scrapeLetterboxdDeltaInFlightMovies = (html: string): DeltaInFlightMovie[] => {
  const movies: DeltaInFlightMovie[] = [];
  const seen = new Set<string>();
  const names = [
    ...html.matchAll(/data-item-full-display-name="([^"]+)"/gi),
    ...html.matchAll(/data-item-name="([^"]+)"/gi)
  ];
  for (const match of names) {
    const parsed = parseDeltaTitle(match[1]);
    if (isNoiseTitle(parsed.title)) {
      continue;
    }
    const key = `${foldDeltaTitle(parsed.title)}|${parsed.year ?? ""}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    movies.push({ title: parsed.title, year: parsed.year, section: DELTA_IN_FLIGHT_LETTERBOXD_SECTION });
  }
  return movies;
};

export const letterboxdDeltaListPageCount = (html: string) => {
  const pages = [...html.matchAll(/\/list\/delta-in-flight-movies\/page\/(\d+)\//gi)].map((match) => Number(match[1]));
  return Math.max(1, ...pages.filter((page) => Number.isFinite(page)));
};

export const mergeDeltaInFlightMovies = (
  official: DeltaInFlightMovie[],
  letterboxd: DeltaInFlightMovie[]
): DeltaInFlightMovie[] => {
  const merged: DeltaInFlightMovie[] = [];
  for (const movie of [...official, ...letterboxd]) {
    const existing = merged.find((row) => sameDeltaMovie(row, movie));
    if (!existing) {
      merged.push({ ...movie });
      continue;
    }
    if (existing.year == null && movie.year != null) {
      existing.year = movie.year;
    }
  }
  return merged;
};

const looksLikeChallenge = (html: string) =>
  /just a moment|cf-mitigated|security verification/i.test(html) &&
  !/data-item-full-display-name|movie-thumbs/i.test(html);

const fetchCatalogPage = async (url: string) => {
  const html = await fetchText(
    url,
    {
      "User-Agent": BROWSER_UA,
      Accept: "text/html,application/xhtml+xml",
      "Accept-Language": "en-US,en;q=0.9"
    },
    { timeoutMs: 20000 }
  );
  if (looksLikeChallenge(html)) {
    throw new Error(`GET ${url} returned a bot challenge`);
  }
  return html;
};

const letterboxdPageUrl = (page: number) => {
  const base = DELTA_IN_FLIGHT_LETTERBOXD_URL.endsWith("/")
    ? DELTA_IN_FLIGHT_LETTERBOXD_URL
    : `${DELTA_IN_FLIGHT_LETTERBOXD_URL}/`;
  return page <= 1 ? base : `${base}page/${page}/`;
};

export const fetchDeltaInFlightPage = async (url = DELTA_IN_FLIGHT_URL) => fetchCatalogPage(url);

export const fetchLetterboxdDeltaInFlightPages = async (htmlPages?: string[]) => {
  if (htmlPages) {
    return htmlPages;
  }
  const first = await fetchCatalogPage(letterboxdPageUrl(1));
  const pages = [first];
  const total = letterboxdDeltaListPageCount(first);
  for (let page = 2; page <= total; page += 1) {
    try {
      pages.push(await fetchCatalogPage(letterboxdPageUrl(page)));
    } catch {
      break;
    }
  }
  return pages;
};

export const collectDeltaInFlightMovies = async (options: {
  officialHtml?: string;
  letterboxdHtml?: string[];
} = {}) => {
  let official: DeltaInFlightMovie[] = [];
  let letterboxd: DeltaInFlightMovie[] = [];
  if (options.officialHtml) {
    official = scrapeDeltaInFlightMovies(options.officialHtml);
  } else {
    try {
      official = scrapeDeltaInFlightMovies(await fetchDeltaInFlightPage());
    } catch {
      official = [];
    }
  }
  try {
    const pages = await fetchLetterboxdDeltaInFlightPages(options.letterboxdHtml);
    letterboxd = pages.flatMap((page) => scrapeLetterboxdDeltaInFlightMovies(page));
  } catch {
    letterboxd = [];
  }
  return {
    official,
    letterboxd,
    movies: mergeDeltaInFlightMovies(official, letterboxd)
  };
};
