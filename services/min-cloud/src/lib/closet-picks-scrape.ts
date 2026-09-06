import * as cheerio from "cheerio";
import { isAvailabilityBlurbTitle } from "./title-match.js";

export const CLOSET_PICKS_SOURCE_ID = "criterion-closet-picks";
export const CLOSET_PICKS_SOURCE_NAME = "Criterion Closet Picks";
export const CLOSET_PICKS_INDEX_URL = "https://www.criterion.com/closet-picks";

const CRITERION_ORIGIN = "https://www.criterion.com";
const WAYBACK_PREFIX = /^https?:\/\/web\.archive\.org\/web\/\d+(?:id_)?\//;

export type ClosetPicksEpisode = {
  guestName: string;
  episodeTitle: string;
  episodeUrl: string;
  date: string | null;
  youtubeUrl?: string | null;
};

export type ClosetPicksFilm = {
  title: string;
  filmUrl: string | null;
  director: string | null;
  year: number | null;
};

export type CollapsedClosetPick = {
  title: string;
  rank: number;
  pickCount: number;
  guests: string[];
  sourceTitle: string;
  description: string;
  episodeDate: string | null;
  episodeUrl: string;
  filmUrl: string | null;
  director: string | null;
  year: number | null;
  youtubeUrl?: string | null;
};

const decode = (value: string) =>
  value
    .replace(/&amp;/g, "&")
    .replace(/&#039;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&rsquo;/g, "\u2019")
    .replace(/&lsquo;/g, "\u2018")
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, " ")
    .trim();

export const stripWaybackPrefix = (url: string) => url.replace(WAYBACK_PREFIX, "");

export const absoluteCriterionUrl = (href: string) => {
  const cleaned = stripWaybackPrefix(href.trim());
  if (!cleaned) {
    return "";
  }
  try {
    return new URL(cleaned, CRITERION_ORIGIN).toString();
  } catch {
    return "";
  }
};

const pathnameOf = (url: string) => {
  try {
    return new URL(absoluteCriterionUrl(url)).pathname.replace(/\/$/, "") || "/";
  } catch {
    return "";
  }
};

export const isClosetPicksUrl = (url: string) => {
  const href = stripWaybackPrefix(url).toLowerCase();
  if (!href.includes("criterion.com") && !href.startsWith("/")) {
    return false;
  }
  return href.includes("/closet-picks") || /\/shop\/collection\/\d+-[^/\s]*closet-picks/.test(href);
};

export const isClosetPicksIndexUrl = (url: string) => {
  const path = pathnameOf(url);
  return path === "/closet-picks";
};

export const guestNameFromEpisodeTitle = (title: string) =>
  decode(title)
    .replace(/['\u2019]s\s+closet\s+picks\s*$/i, "")
    .replace(/\s+closet\s+picks\s*$/i, "")
    .trim();

export const formatClosetPicksDescription = (guests: string[]) => {
  const names = guests.map((guest) => decode(guest)).filter(Boolean);
  if (!names.length) {
    return "";
  }
  if (names.length === 1) {
    return names[0];
  }
  return `${names[0]}   also ${names.slice(1).join(", ")}`;
};

export const normalizeClosetPicksTitle = (title: string) =>
  decode(title)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

const SKIP_FILM_TITLE =
  /^(watch\s*&\s*shop)$|collector['\u2019]?s\s+set|collectors\s+set|box\s+set|^the complete\s|cinema\s+collection/i;

export const shouldSkipClosetPicksFilmTitle = (title: string) => {
  const cleaned = decode(title);
  return !cleaned || cleaned.length > 160 || SKIP_FILM_TITLE.test(cleaned) || isAvailabilityBlurbTitle(cleaned);
};

const titleFromCollectionSlug = (href: string) => {
  const slug = pathnameOf(href).split("/").pop() || "";
  const withoutId = slug.replace(/^\d+-/, "").replace(/-s-closet-picks$/i, "").replace(/-closet-picks$/i, "");
  if (!withoutId) {
    return "";
  }
  const guest = withoutId
    .split("-")
    .filter(Boolean)
    .map((part) => (part === "and" ? "and" : part.charAt(0).toUpperCase() + part.slice(1)))
    .join(" ");
  return `${guest}'s Closet Picks`;
};

const isEpisodeHref = (href: string) => {
  const path = pathnameOf(href);
  if (!path) {
    return false;
  }
  if (path === "/closet-picks" || path === "/closet-picks/search") {
    return false;
  }
  if (path.startsWith("/closet-picks/")) {
    return true;
  }
  return /\/shop\/collection\/\d+-[^/]*closet-picks$/i.test(path);
};

export const parseClosetPicksIndex = (html: string): ClosetPicksEpisode[] => {
  const $ = cheerio.load(html);
  const seen = new Set<string>();
  const episodes: ClosetPicksEpisode[] = [];

  $("a[href]").each((_, element) => {
    const href = String($(element).attr("href") || "");
    if (!isEpisodeHref(href)) {
      return;
    }
    const episodeUrl = absoluteCriterionUrl(href);
    if (!episodeUrl || seen.has(episodeUrl)) {
      return;
    }
    const $link = $(element);
    const captionTitle = decode(
      $link.find(".header_lvl2").first().text() ||
        $link.find("p.header_lvl2").first().text() ||
        $link.closest(".popbox, article, li, .card").find(".header_lvl2").first().text()
    );
    const textTitle = decode($link.text()).replace(/^watch\s*&\s*shop/i, "").trim();
    const episodeTitle =
      captionTitle ||
      (/closet picks/i.test(textTitle) ? textTitle : "") ||
      titleFromCollectionSlug(href);
    if (!episodeTitle) {
      return;
    }
    seen.add(episodeUrl);
    episodes.push({
      guestName: guestNameFromEpisodeTitle(episodeTitle),
      episodeTitle,
      episodeUrl,
      date: null
    });
  });

  return episodes;
};

export const parseClosetPicksCreditLine = (text: string) => {
  const cleaned = decode(text);
  const yearMatch = cleaned.match(/\b((?:19|20)\d{2})\b/);
  const year = yearMatch ? Number(yearMatch[1]) : null;
  const director = cleaned
    .replace(/\b(?:19|20)\d{2}\b/g, "")
    .replace(/[,–—\-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  return {
    director: director && !/^\d+$/.test(director) ? director : null,
    year
  };
};

const filmFromCard = ($: cheerio.CheerioAPI, node: Parameters<cheerio.CheerioAPI>[0], href?: string): ClosetPicksFilm | null => {
  const $node = $(node);
  const title = decode(
    $node.find("dt").first().text() || $node.find("img[alt]").attr("alt") || $node.text()
  );
  if (shouldSkipClosetPicksFilmTitle(title) || /quick shop/i.test(title)) {
    return null;
  }
  const credit = parseClosetPicksCreditLine($node.find("dd").first().text());
  const filmUrl = href && /\/films\//i.test(href) ? absoluteCriterionUrl(href) : null;
  return {
    title,
    filmUrl,
    director: credit.director,
    year: credit.year
  };
};

export const parseClosetPicksEpisode = (html: string): ClosetPicksFilm[] => {
  const $ = cheerio.load(html);
  const films: ClosetPicksFilm[] = [];
  const seen = new Set<string>();

  const addFilm = (film: ClosetPicksFilm | null) => {
    if (!film) {
      return;
    }
    const key = normalizeClosetPicksTitle(film.title);
    if (!key || seen.has(key)) {
      return;
    }
    seen.add(key);
    films.push(film);
  };

  $(".filmWrap").each((_, element) => {
    const $wrap = $(element);
    if ($wrap.find('[data-product-type="boxset"]').length || $wrap.closest("li").find('[data-product-type="boxset"]').length) {
      return;
    }
    const href = $wrap.find("a[href]").first().attr("href") || "";
    addFilm(filmFromCard($, element, href));
  });

  if (!films.length) {
    $("a[href*='/films/']").each((_, element) => {
      const $link = $(element);
      if ($link.closest(".filmWrap").find('[data-product-type="boxset"]').length) {
        return;
      }
      addFilm(filmFromCard($, element, String($link.attr("href") || "")));
    });
  }

  return films;
};

export const parseCriterionFilmPage = (html: string) => {
  const $ = cheerio.load(html);
  let title = decode(
    $('meta[property="og:title"]').attr("content") ||
      $("h1").first().text() ||
      $("title").first().text()
  ).replace(/\s*\|\s*the criterion collection.*$/i, "");
  let year: number | null = null;
  let director: string | null = null;
  let originalTitle: string | null = null;

  const titleYear = title.match(/\(\s*((?:19|20)\d{2})\s*\)\s*$/);
  if (titleYear) {
    year = Number(titleYear[1]);
    title = title.replace(/\(\s*(?:19|20)\d{2}\s*\)\s*$/, "").trim();
  }

  $("script[type='application/ld+json']").each((_, element) => {
    try {
      const parsed = JSON.parse($(element).text());
      const nodes = Array.isArray(parsed) ? parsed : [parsed];
      for (const node of nodes) {
        const type = String(node?.["@type"] || "");
        if (!/movie|videoobject/i.test(type) && !node?.director && !node?.dateCreated) {
          continue;
        }
        if (!title && node.name) {
          title = decode(String(node.name));
        }
        if (!year) {
          const raw = String(node.dateCreated || node.datePublished || "");
          const match = raw.match(/\b((?:19|20)\d{2})\b/);
          if (match) {
            year = Number(match[1]);
          }
        }
        const nodeDirector = node.director;
        if (!director && nodeDirector) {
          const names = Array.isArray(nodeDirector)
            ? nodeDirector.map((item: { name?: string }) => item?.name).filter(Boolean)
            : [nodeDirector.name || nodeDirector];
          director = names.map((name: string) => decode(String(name))).filter(Boolean).join(" and ") || null;
        }
        if (!originalTitle && node.alternateName) {
          originalTitle = decode(String(node.alternateName));
        }
      }
    } catch {
      // ignore malformed JSON-LD
    }
  });

  if (!director) {
    const labeled =
      decode($('[itemprop="director"]').first().text()) ||
      decode($(".director, .film-director, .product-director").first().text()) ||
      decode($("a[href*='/explore/directors/']").first().text());
    director = labeled || null;
  }
  if (!year) {
    const labeled =
      $('[itemprop="dateCreated"], [itemprop="datePublished"]').first().attr("content") ||
      $('[itemprop="dateCreated"], [itemprop="datePublished"]').first().text() ||
      $(".year, .release-year, .film-year").first().text();
    const match = String(labeled || "").match(/\b((?:19|20)\d{2})\b/);
    if (match) {
      year = Number(match[1]);
    }
  }

  return {
    title: title || "",
    year,
    director,
    originalTitle
  };
};

export const collapseClosetPicks = (
  visits: Array<{ episode: ClosetPicksEpisode; films: ClosetPicksFilm[] }>
): CollapsedClosetPick[] => {
  const byTitle = new Map<
    string,
    {
      title: string;
      guests: string[];
      sourceTitle: string;
      episodeUrl: string;
      episodeDate: string | null;
      filmUrl: string | null;
      director: string | null;
      year: number | null;
      youtubeUrl: string | null;
      firstIndex: number;
    }
  >();

  visits.forEach((visit, visitIndex) => {
    const guest = visit.episode.guestName || guestNameFromEpisodeTitle(visit.episode.episodeTitle);
    for (const film of visit.films) {
      const key = normalizeClosetPicksTitle(film.title);
      if (!key) {
        continue;
      }
      const existing = byTitle.get(key);
      if (!existing) {
        byTitle.set(key, {
          title: film.title,
          guests: guest ? [guest] : [],
          sourceTitle: visit.episode.episodeTitle,
          episodeUrl: visit.episode.episodeUrl,
          episodeDate: visit.episode.date,
          filmUrl: film.filmUrl ?? null,
          director: film.director ?? null,
          year: film.year ?? null,
          youtubeUrl: visit.episode.youtubeUrl ?? null,
          firstIndex: visitIndex
        });
        continue;
      }
      if (guest && !existing.guests.includes(guest)) {
        existing.guests.push(guest);
      }
      if (!existing.filmUrl && film.filmUrl) {
        existing.filmUrl = film.filmUrl;
      }
      if (!existing.director && film.director) {
        existing.director = film.director;
      }
      if (!existing.year && film.year) {
        existing.year = film.year;
      }
      if (!existing.youtubeUrl && visit.episode.youtubeUrl) {
        existing.youtubeUrl = visit.episode.youtubeUrl;
      }
    }
  });

  return [...byTitle.values()]
    .sort((left, right) => {
      const pickDelta = right.guests.length - left.guests.length;
      if (pickDelta !== 0) {
        return pickDelta;
      }
      if (left.firstIndex !== right.firstIndex) {
        return left.firstIndex - right.firstIndex;
      }
      return left.title.localeCompare(right.title);
    })
    .map((row, index) => ({
      title: row.title,
      rank: index + 1,
      pickCount: row.guests.length,
      guests: row.guests,
      sourceTitle: row.sourceTitle,
      description: formatClosetPicksDescription(row.guests),
      episodeDate: row.episodeDate,
      episodeUrl: row.episodeUrl,
      filmUrl: row.filmUrl,
      director: row.director,
      year: row.year,
      youtubeUrl: row.youtubeUrl
    }));
};

export const toClosetPicksCatalogItem = (
  film: CollapsedClosetPick,
  sourceIdentifier = CLOSET_PICKS_SOURCE_ID
) => ({
  title: film.title,
  sourceIdentifier,
  rank: film.rank,
  sourceTitle: film.sourceTitle,
  episodeDate: film.episodeDate,
  sourceUrl: film.episodeUrl,
  filmUrl: film.filmUrl,
  director: film.director,
  year: film.year,
  podcastEpisodeDescription: film.description,
  youtubeUrl: film.youtubeUrl ?? null
});

export const CLOSET_PICKS_FETCH_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  Accept: "text/html,application/xhtml+xml"
};

export const closetPicksWaybackUrl = (url: string, snapshot = "20250101071625") =>
  `https://web.archive.org/web/${snapshot}id_/${absoluteCriterionUrl(url)}`;

export const htmlLooksLikeClosetPicks = (html: string) =>
  /super-collection-header|filmWrap|header_lvl2|Closet Picks/i.test(html) &&
  !/cf-mitigated|just a moment|security verification/i.test(html);

export const looksLikeClosetPicksChallenge = (html: string) =>
  /cloudflare|just a moment|security verification|cf-mitigated/i.test(html) &&
  !htmlLooksLikeClosetPicks(html);

export const fetchClosetPicksPage = async (
  url: string,
  options: { preferWayback?: boolean; waybackSnapshot?: string } = {}
) => {
  const snapshot = options.waybackSnapshot || "20250101071625";
  const candidates = options.preferWayback
    ? [closetPicksWaybackUrl(url, snapshot), closetPicksWaybackUrl(url, "2"), url]
    : [url, closetPicksWaybackUrl(url, snapshot), closetPicksWaybackUrl(url, "2")];
  let lastError: unknown;
  for (const candidate of candidates) {
    try {
      const response = await fetch(candidate, {
        headers: CLOSET_PICKS_FETCH_HEADERS,
        signal: AbortSignal.timeout(12000)
      });
      if (!response.ok) {
        throw new Error(`GET ${candidate} failed ${response.status}`);
      }
      const html = await response.text();
      if (looksLikeClosetPicksChallenge(html)) {
        throw new Error("challenge");
      }
      return html;
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error(`Failed to fetch ${url}`);
};

export const closetPicksSourceRecord = () => ({
  identifier: CLOSET_PICKS_SOURCE_ID,
  name: CLOSET_PICKS_SOURCE_NAME,
  type: "url",
  url: CLOSET_PICKS_INDEX_URL,
  isRankedList: true,
  movieCount: 0
});
