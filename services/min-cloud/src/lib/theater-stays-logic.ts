import { CACHE_MS, type NowPlayingMovie, type TicketLinks } from "./now-playing.js";

export type { TicketLinks };

export const TICKET_SITES = ["amc", "fandango", "atom"] as const;
export type TicketSite = (typeof TICKET_SITES)[number];

const TICKET_HOSTS: Record<TicketSite, string[]> = {
  amc: ["www.amctheatres.com", "amctheatres.com"],
  fandango: ["www.fandango.com", "fandango.com"],
  atom: ["www.atomtickets.com", "atomtickets.com"]
};

export const normalizeTicketUrl = (site: TicketSite, value: unknown): string | undefined => {
  const raw = String(value ?? "").trim();
  if (!raw) {
    return undefined;
  }
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return undefined;
  }
  if (url.protocol !== "https:") {
    return undefined;
  }
  if (!TICKET_HOSTS[site].includes(url.hostname.toLowerCase())) {
    return undefined;
  }
  if (site === "amc" && /\/movies\/[^/]+\/?$/.test(url.pathname)) {
    url.pathname = `${url.pathname.replace(/\/$/, "")}/showtimes`;
  }
  return url.toString();
};

export const normalizeTicketLinks = (value: unknown): TicketLinks => {
  const row = value && typeof value === "object" ? (value as Record<string, unknown>) : {};
  const links: TicketLinks = {};
  for (const site of TICKET_SITES) {
    const url = normalizeTicketUrl(site, row[site]);
    if (url) {
      links[site] = url;
    }
  }
  return links;
};

export const hasTicketLinks = (links?: TicketLinks | null) =>
  TICKET_SITES.some((site) => Boolean(links?.[site]));

export type TheaterStay = {
  tmdbId: number;
  title: string;
  hasIMAX: boolean;
  inCatalog: boolean;
  manualOverride: boolean;
  ticketLinks?: TicketLinks;
};

export type TheaterStaySnapshot = {
  region: string;
  stays: TheaterStay[];
  refreshedAt: string;
  source: string;
};

export type TheaterStayStats = {
  region: string;
  refreshedAt: string | null;
  source: string | null;
  inTheaters: number;
  inCatalog: number;
  withIMAX: number;
  manualOverrides: number;
  withTicketLinks: number;
};

export const theaterStayStats = (
  stays: TheaterStay[],
  refreshedAt: string | null,
  region: string,
  source: string | null = null
): TheaterStayStats => ({
  region,
  refreshedAt,
  source,
  inTheaters: stays.length,
  inCatalog: stays.filter((stay) => stay.inCatalog).length,
  withIMAX: stays.filter((stay) => stay.hasIMAX).length,
  manualOverrides: stays.filter((stay) => stay.manualOverride).length,
  withTicketLinks: stays.filter((stay) => hasTicketLinks(stay.ticketLinks)).length
});

export const toPublicMovies = (stays: TheaterStay[]): NowPlayingMovie[] =>
  stays.map((stay) => {
    const ticketLinks = normalizeTicketLinks(stay.ticketLinks);
    return {
      tmdbId: stay.tmdbId,
      title: stay.title,
      hasIMAX: stay.hasIMAX,
      ...(hasTicketLinks(ticketLinks) ? { ticketLinks } : {})
    };
  });

export const mergeTheaterStayRefresh = (
  existing: TheaterStay[],
  incoming: NowPlayingMovie[],
  catalogTmdbIds: Set<number>
): TheaterStay[] => {
  const previous = new Map(existing.map((stay) => [stay.tmdbId, stay]));
  const manuals = existing.filter((stay) => stay.manualOverride);
  const manualIds = new Set(manuals.map((stay) => stay.tmdbId));
  const fromTmdb = incoming
    .filter((movie) => !manualIds.has(movie.tmdbId))
    .map((movie) => ({
      tmdbId: movie.tmdbId,
      title: movie.title,
      hasIMAX: movie.hasIMAX,
      inCatalog: catalogTmdbIds.has(movie.tmdbId),
      manualOverride: false,
      ticketLinks: previous.get(movie.tmdbId)?.ticketLinks
    }));
  const nextManuals = manuals.map((stay) => ({
    ...stay,
    inCatalog: catalogTmdbIds.has(stay.tmdbId),
    title: stay.title || incoming.find((movie) => movie.tmdbId === stay.tmdbId)?.title || stay.title
  }));
  return [...nextManuals, ...fromTmdb].sort(
    (left, right) => left.title.localeCompare(right.title) || left.tmdbId - right.tmdbId
  );
};

export const normalizeTheaterStayUpdate = (body: {
  tmdbId?: unknown;
  title?: unknown;
  inTheaters?: unknown;
  hasIMAX?: unknown;
  ticketLinks?: unknown;
}): { tmdbId: number; title: string; hasIMAX: boolean; remove: boolean; ticketLinks?: TicketLinks } | null => {
  const tmdbId = Number(body.tmdbId);
  if (!Number.isFinite(tmdbId) || tmdbId <= 0) {
    return null;
  }
  const inTheaters = Boolean(body.inTheaters) || Boolean(body.hasIMAX);
  const hasIMAX = Boolean(body.hasIMAX);
  const hasTicketLinksField = Boolean(body && Object.prototype.hasOwnProperty.call(body, "ticketLinks"));
  const ticketLinks = hasTicketLinksField ? normalizeTicketLinks(body.ticketLinks) : undefined;
  if (!inTheaters) {
    return { tmdbId, title: String(body.title || "").trim(), hasIMAX: false, remove: true };
  }
  return {
    tmdbId,
    title: String(body.title || "").trim(),
    hasIMAX,
    remove: false,
    ...(hasTicketLinksField ? { ticketLinks } : {})
  };
};

export const isFreshTheaterStaySnapshot = (refreshedAt: string | null | undefined, now = Date.now()) => {
  if (!refreshedAt) {
    return false;
  }
  const at = Date.parse(refreshedAt);
  return Number.isFinite(at) && now - at < CACHE_MS;
};
