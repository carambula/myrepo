import { fetchText, sleep } from "./http.js";
import {
  hasTicketLinks,
  normalizeTicketLinks,
  TICKET_SITES,
  type TheaterStay,
  type TicketLinks,
  type TicketSite
} from "./theater-stays-logic.js";
import { fetchTmdbAlternativeTitles } from "./tmdb.js";

export type TicketResolveHint = {
  tmdbId: number;
  title: string;
  year?: number;
  alternateTitles?: string[];
};

export type TicketUrlRecord = {
  url: string;
  slug: string;
  year?: number;
  junk: boolean;
};

export type TicketSiteCatalogs = Record<TicketSite, TicketUrlRecord[]>;

const JUNK_SLUG = /(?:^|-)(?:double-feature|fan-event|fan-first|early-access|opening-night|collectible|special-show|reissue|70mm|imax-reissue|on-apple-tv|live-in-imax|goes-to-the-movies|ttnuc)(?:-|$)/i;

const SITEMAP_ROOTS: Record<TicketSite, string[]> = {
  amc: ["https://www.amctheatres.com/sitemaps/sitemap-movies.xml"],
  fandango: ["https://www.fandango.com/sitemapindex-movies.xml"],
  atom: [
    "https://www.atomtickets.com/sitemap-movie-detail-pages-in-theaters-now.xml",
    "https://www.atomtickets.com/sitemap-movie-detail-pages-coming-soon.xml"
  ]
};

const MAX_SITEMAP_CHILDREN = 8;

let catalogCache: { at: number; catalogs: TicketSiteCatalogs } | null = null;

export const resetTicketLinkCatalogCacheForTests = () => {
  catalogCache = null;
};

export const titleToSlug = (title: string) =>
  String(title || "")
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

export const stripLeadingArticleSlug = (slug: string) => slug.replace(/^(?:the|a|an)-/, "");

export const parseSlugYear = (
  value: string,
  options: { stripNumericId?: boolean } = {}
): { slug: string; year?: number } => {
  let slug = String(value || "").replace(/^\/+|\/+$/g, "");
  if (options.stripNumericId !== false) {
    slug = slug.replace(/-\d{4,}$/, "");
  }
  const yearMatch = slug.match(/-(?:19|20)\d{2}$/);
  if (!yearMatch) {
    return { slug };
  }
  return { slug: slug.slice(0, -yearMatch[0].length), year: Number(yearMatch[0].slice(1)) };
};

export const extractSitemapLocs = (xml: string) => {
  const locs = [...String(xml || "").matchAll(/<loc>\s*([^<\s]+)\s*<\/loc>/gi)].map((match) =>
    match[1].replace(/&amp;/g, "&").trim()
  );
  if (/<sitemapindex/i.test(xml)) {
    return { sitemaps: locs, urls: [] as string[] };
  }
  return { sitemaps: [] as string[], urls: locs };
};

const moviePathForSite = (site: TicketSite, pathname: string) => {
  if (site === "amc") {
    const match = pathname.match(/^\/movies\/([^/]+)/i);
    return match?.[1] && !/^private-theatre-rental/i.test(match[1]) ? match[1] : null;
  }
  if (site === "atom") {
    const match = pathname.match(/^\/movies\/([^/]+)\/\d+\/?$/i);
    return match?.[1] ?? null;
  }
  const match = pathname.match(/^\/([^/]+)\/movie-overview\/?$/i);
  return match?.[1] ?? null;
};

export const ticketRecordFromUrl = (site: TicketSite, raw: string): TicketUrlRecord | null => {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return null;
  }
  const path = moviePathForSite(site, url.pathname);
  if (!path) {
    return null;
  }
  const parsed = parseSlugYear(path, { stripNumericId: site !== "atom" });
  if (!parsed.slug) {
    return null;
  }
  return {
    url: url.toString(),
    slug: parsed.slug,
    ...(parsed.year ? { year: parsed.year } : {}),
    junk: JUNK_SLUG.test(path)
  };
};

export const catalogFromUrls = (site: TicketSite, urls: string[]): TicketUrlRecord[] => {
  const records: TicketUrlRecord[] = [];
  for (const url of urls) {
    const record = ticketRecordFromUrl(site, url);
    if (record) {
      records.push(record);
    }
  }
  return records;
};

const lookupSlugs = (title: string) => {
  const slug = titleToSlug(title);
  if (!slug) {
    return [];
  }
  return [...new Set([slug, stripLeadingArticleSlug(slug)].filter(Boolean))];
};

export const matchTicketUrl = (
  title: string,
  year: number | undefined,
  catalog: TicketUrlRecord[],
  extraTitles: string[] = []
): string | undefined => {
  const slugs = new Set([...lookupSlugs(title), ...extraTitles.flatMap(lookupSlugs)]);
  if (!slugs.size) {
    return undefined;
  }
  let candidates = catalog.filter((record) => slugs.has(record.slug));
  if (!candidates.length) {
    return undefined;
  }
  const clean = candidates.filter((record) => !record.junk);
  if (clean.length) {
    candidates = clean;
  }
  if (year) {
    const dated = candidates.filter((record) => record.year === year);
    if (dated.length) {
      candidates = dated;
    } else if (candidates.some((record) => record.year)) {
      return undefined;
    }
  }
  const unique = [...new Map(candidates.map((record) => [record.url, record])).values()];
  if (unique.length !== 1) {
    return undefined;
  }
  return unique[0].url;
};

export const mergeTicketLinks = (existing?: TicketLinks, resolved?: TicketLinks): TicketLinks =>
  normalizeTicketLinks({
    ...normalizeTicketLinks(resolved),
    ...normalizeTicketLinks(existing)
  });

export const resolveTicketLinksForStay = (
  stay: TheaterStay,
  catalogs: TicketSiteCatalogs,
  hint?: TicketResolveHint
): TicketLinks => {
  const titles = [stay.title, hint?.title, ...(hint?.alternateTitles ?? [])].filter(Boolean) as string[];
  const year = hint?.year;
  const resolved: TicketLinks = {};
  for (const site of TICKET_SITES) {
    if (stay.ticketLinks?.[site]) {
      continue;
    }
    const url = matchTicketUrl(titles[0] || stay.title, year, catalogs[site], titles.slice(1));
    if (url) {
      resolved[site] = url;
    }
  }
  return mergeTicketLinks(stay.ticketLinks, resolved);
};

const emptyCatalogs = (): TicketSiteCatalogs => ({ amc: [], fandango: [], atom: [] });

const loadSitemapXml = async (url: string, getText: (url: string) => Promise<string>) => {
  let lastError: unknown;
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      return await getText(url);
    } catch (error) {
      lastError = error;
      await sleep(400 * (attempt + 1));
    }
  }
  throw lastError;
};

export const loadTicketSiteCatalogs = async (
  getText: (url: string) => Promise<string> = (url) => fetchText(url, {}, { timeoutMs: 45000 })
): Promise<TicketSiteCatalogs> => {
  if (catalogCache && Date.now() - catalogCache.at < 6 * 60 * 60 * 1000) {
    return catalogCache.catalogs;
  }
  const catalogs = emptyCatalogs();
  for (const site of TICKET_SITES) {
    const urls = new Set<string>();
    const queue = [...SITEMAP_ROOTS[site]];
    let children = 0;
    while (queue.length) {
      const next = queue.shift();
      if (!next) {
        break;
      }
      try {
        const xml = await loadSitemapXml(next, getText);
        const extracted = extractSitemapLocs(xml);
        for (const child of extracted.sitemaps) {
          if (children < MAX_SITEMAP_CHILDREN) {
            children += 1;
            queue.push(child);
          }
        }
        for (const loc of extracted.urls) {
          urls.add(loc);
        }
      } catch {
        // Keep other sites; this slate still falls back to search URLs.
      }
    }
    catalogs[site] = catalogFromUrls(site, [...urls]);
  }
  if (TICKET_SITES.some((site) => catalogs[site].length)) {
    catalogCache = { at: Date.now(), catalogs };
  }
  return catalogs;
};

const missingSites = (links?: TicketLinks) => TICKET_SITES.filter((site) => !links?.[site]);

export const attachResolvedTicketLinks = async (
  stays: TheaterStay[],
  hints: TicketResolveHint[],
  options: {
    catalogs?: TicketSiteCatalogs;
    fetchText?: (url: string) => Promise<string>;
    fetchAltTitles?: (tmdbId: number) => Promise<string[]>;
    apiKey?: string;
  } = {}
): Promise<{ stays: TheaterStay[]; withTicketLinks: number }> => {
  const hintById = new Map(hints.map((hint) => [hint.tmdbId, hint]));
  const catalogs =
    options.catalogs ??
    (await loadTicketSiteCatalogs(options.fetchText).catch(() => emptyCatalogs()));
  if (TICKET_SITES.every((site) => catalogs[site].length === 0)) {
    return { stays, withTicketLinks: stays.filter((stay) => hasTicketLinks(stay.ticketLinks)).length };
  }
  const firstPass = stays.map((stay) => {
    const nextLinks = resolveTicketLinksForStay(stay, catalogs, hintById.get(stay.tmdbId));
    return { ...stay, ticketLinks: hasTicketLinks(nextLinks) ? nextLinks : stay.ticketLinks };
  });

  const fetchAltTitles =
    options.fetchAltTitles ??
    (options.apiKey
      ? (tmdbId: number) => fetchTmdbAlternativeTitles(tmdbId, options.apiKey as string)
      : undefined);

  if (!fetchAltTitles) {
    return {
      stays: firstPass,
      withTicketLinks: firstPass.filter((stay) => hasTicketLinks(stay.ticketLinks)).length
    };
  }

  const secondPass: TheaterStay[] = [];
  for (const stay of firstPass) {
    if (!missingSites(stay.ticketLinks).length) {
      secondPass.push(stay);
      continue;
    }
    let extra: string[] = [];
    try {
      extra = await fetchAltTitles(stay.tmdbId);
    } catch {
      extra = [];
    }
    if (!extra.length) {
      secondPass.push(stay);
      continue;
    }
    const hint = hintById.get(stay.tmdbId);
    const nextLinks = resolveTicketLinksForStay(stay, catalogs, {
      tmdbId: stay.tmdbId,
      title: hint?.title || stay.title,
      year: hint?.year,
      alternateTitles: [...(hint?.alternateTitles ?? []), ...extra]
    });
    secondPass.push({ ...stay, ticketLinks: hasTicketLinks(nextLinks) ? nextLinks : stay.ticketLinks });
  }
  return {
    stays: secondPass,
    withTicketLinks: secondPass.filter((stay) => hasTicketLinks(stay.ticketLinks)).length
  };
};

export const hintsFromNowPlaying = (
  movies: Array<{ tmdbId: number; title: string; year?: number; originalTitle?: string }>
): TicketResolveHint[] =>
  movies.map((movie) => ({
    tmdbId: movie.tmdbId,
    title: movie.title,
    ...(movie.year ? { year: movie.year } : {}),
    ...(movie.originalTitle && movie.originalTitle !== movie.title
      ? { alternateTitles: [movie.originalTitle] }
      : {})
  }));
