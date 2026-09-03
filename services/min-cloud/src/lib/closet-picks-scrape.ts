import * as cheerio from "cheerio";

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
};

export type ClosetPicksFilm = {
  title: string;
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
  return !cleaned || cleaned.length > 160 || SKIP_FILM_TITLE.test(cleaned);
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

export const parseClosetPicksEpisode = (html: string): ClosetPicksFilm[] => {
  const $ = cheerio.load(html);
  const films: ClosetPicksFilm[] = [];
  const seen = new Set<string>();

  $(".filmWrap").each((_, element) => {
    const $wrap = $(element);
    if ($wrap.find('[data-product-type="boxset"]').length || $wrap.closest("li").find('[data-product-type="boxset"]').length) {
      return;
    }
    const title = decode($wrap.find("dt").first().text() || $wrap.find("img[alt]").attr("alt") || "");
    if (shouldSkipClosetPicksFilmTitle(title)) {
      return;
    }
    const key = normalizeClosetPicksTitle(title);
    if (!key || seen.has(key)) {
      return;
    }
    seen.add(key);
    films.push({ title });
  });

  if (!films.length) {
    $("a[href*='/films/']").each((_, element) => {
      const $link = $(element);
      if ($link.closest(".filmWrap").find('[data-product-type="boxset"]').length) {
        return;
      }
      const title = decode($link.find("dt").first().text() || $link.find("img[alt]").attr("alt") || $link.text());
      if (shouldSkipClosetPicksFilmTitle(title) || /quick shop/i.test(title)) {
        return;
      }
      const key = normalizeClosetPicksTitle(title);
      if (!key || seen.has(key)) {
        return;
      }
      seen.add(key);
      films.push({ title });
    });
  }

  return films;
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
          firstIndex: visitIndex
        });
        continue;
      }
      if (guest && !existing.guests.includes(guest)) {
        existing.guests.push(guest);
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
      episodeUrl: row.episodeUrl
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
  podcastEpisodeDescription: film.description
});

export const closetPicksWaybackUrl = (url: string, snapshot = "20250101071625") =>
  `https://web.archive.org/web/${snapshot}id_/${absoluteCriterionUrl(url)}`;

export const htmlLooksLikeClosetPicks = (html: string) =>
  /super-collection-header|filmWrap|header_lvl2|Closet Picks/i.test(html) &&
  !/cf-mitigated|just a moment|security verification/i.test(html);

export const closetPicksSourceRecord = () => ({
  identifier: CLOSET_PICKS_SOURCE_ID,
  name: CLOSET_PICKS_SOURCE_NAME,
  type: "url",
  url: CLOSET_PICKS_INDEX_URL,
  isRankedList: true,
  movieCount: 0
});
