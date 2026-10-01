import { fetchText } from "./http.js";
import { isAvailabilityBlurbTitle } from "./title-match.js";

export const DELTA_IN_FLIGHT_SOURCE_ID = "delta-in-flight";
export const DELTA_IN_FLIGHT_SOURCE_NAME = "Delta in-flight";
export const DELTA_IN_FLIGHT_URL =
  "https://www.delta.com/us/en/onboard/inflight-entertainment/current-movies";

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

export const parseDeltaTitle = (rawTitle: string) => {
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
  title = title.replace(POSSESSIVE_CREDIT, "").trim() || title;
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
    const parsed = parseDeltaTitle(token.value);
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

export const fetchDeltaInFlightPage = async (url = DELTA_IN_FLIGHT_URL) =>
  fetchText(
    url,
    {
      "User-Agent": BROWSER_UA,
      Accept: "text/html,application/xhtml+xml",
      "Accept-Language": "en-US,en;q=0.9"
    },
    { timeoutMs: 20000 }
  );
