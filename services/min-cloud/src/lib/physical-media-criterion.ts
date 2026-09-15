import { pickCriterionTmdbId, type CriterionTmdbHit } from "./closet-picks-wikidata.js";
import { normalizeClosetPicksTitle } from "./closet-picks-scrape.js";
import {
  addPhysicalEdition,
  emptyPhysicalMedia,
  reconcilePhysicalMedia,
  type PhysicalMedia
} from "./physical-media.js";

export type CriterionShopTitle = {
  title: string;
  year: number | null;
  format: "uhd4k" | "bluRay" | "dvd";
  spineNumber?: string | null;
};

const decodeEntities = (value: string) =>
  value
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#8217;|&rsquo;|&#x2019;/gi, "\u2019")
    .replace(/&#8211;|&ndash;|&#x2013;/gi, "-")
    .replace(/&#8212;|&mdash;|&#x2014;/gi, "-")
    .replace(/&#039;|&#x27;/g, "'")
    .replace(/\s+/g, " ")
    .trim();

export const inferCriterionFormat = (text: string): "uhd4k" | "bluRay" | "dvd" => {
  if (/4k|uhd|ultra\s*hd/i.test(text)) {
    return "uhd4k";
  }
  if (/\bdvd\b/i.test(text) && !/blu/i.test(text)) {
    return "dvd";
  }
  return "bluRay";
};

const BOXSET_FILMS: Record<string, Array<{ title: string; year: number }>> = {
  "the wes anderson archive": [
    { title: "Bottle Rocket", year: 1996 },
    { title: "Rushmore", year: 1998 },
    { title: "The Royal Tenenbaums", year: 2001 },
    { title: "The Life Aquatic with Steve Zissou", year: 2004 },
    { title: "The Darjeeling Limited", year: 2007 },
    { title: "Fantastic Mr. Fox", year: 2009 },
    { title: "Moonrise Kingdom", year: 2012 },
    { title: "The Grand Budapest Hotel", year: 2014 },
    { title: "Isle of Dogs", year: 2018 },
    { title: "The French Dispatch", year: 2021 }
  ],
  "the adventures of antoine doinel": [
    { title: "The 400 Blows", year: 1959 },
    { title: "Antoine and Colette", year: 1962 },
    { title: "Stolen Kisses", year: 1968 },
    { title: "Bed and Board", year: 1970 },
    { title: "Love on the Run", year: 1979 }
  ],
  "the three musketeers / the four musketeers: two films by richard lester": [
    { title: "The Three Musketeers", year: 1973 },
    { title: "The Four Musketeers", year: 1974 }
  ],
  "two films by claude berri: jean de florette + manon of the spring": [
    { title: "Jean de Florette", year: 1986 },
    { title: "Manon of the Spring", year: 1986 }
  ],
  "i walked with a zombie / the seventh victim": [
    { title: "I Walked with a Zombie", year: 1943 },
    { title: "The Seventh Victim", year: 1943 }
  ],
  "gregg araki s teen apocalypse trilogy": [
    { title: "Totally F***ed Up", year: 1993 },
    { title: "The Doom Generation", year: 1995 },
    { title: "Nowhere", year: 1997 }
  ],
  "the apu trilogy [pather panchali/aparajito/apur sansar]": [
    { title: "Pather Panchali", year: 1955 },
    { title: "Aparajito", year: 1956 },
    { title: "The World of Apu", year: 1959 }
  ],
  "moonage dream": [{ title: "Moonage Daydream", year: 2022 }],
  "the ranown westerns: five films directed by budd boetticher": [
    { title: "The Tall T", year: 1957 },
    { title: "Decision at Sundown", year: 1957 },
    { title: "Buchanan Rides Alone", year: 1958 },
    { title: "Ride Lonesome", year: 1959 },
    { title: "Comanche Station", year: 1960 }
  ],
  "three colors trilogy: blue, white, red": [
    { title: "Three Colors: Blue", year: 1993 },
    { title: "Three Colors: White", year: 1994 },
    { title: "Three Colors: Red", year: 1994 }
  ]
};

const boxsetKey = (title: string) =>
  normalizeClosetPicksTitle(title)
    .replace(/[*\u2019']/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const expandBoxset = (title: string, format: CriterionShopTitle["format"]): CriterionShopTitle[] => {
  const films = BOXSET_FILMS[boxsetKey(title)];
  if (!films) {
    return [];
  }
  return films.map((film) => ({ ...film, format }));
};

const TITLE_YEAR = /^(.+?)\s*\(((?:19|20)\d{2})\)\s*$/;
const SKIP_HEADING = /^(the criterion collection|related|latest|more|share|advertisement|comments?)\b/i;

const cleanShopTitle = (title: string) =>
  decodeEntities(title)
    .replace(/\s*[–—-]\s*director['\u2019]?s cut\s*$/i, "")
    .replace(/\s*\|\s*the criterion collection.*$/i, "")
    .trim();

export const shopTitleVariants = (title: string) => {
  const cleaned = cleanShopTitle(title);
  const variants = [cleaned];
  if (/french dispatch/i.test(cleaned) && !/^the french dispatch$/i.test(cleaned)) {
    variants.push("The French Dispatch");
  }
  const beforeColon = cleaned.split(":")[0]?.trim();
  if (beforeColon && beforeColon !== cleaned && beforeColon.length > 3) {
    variants.push(beforeColon);
  }
  return [...new Set(variants.filter(Boolean))];
};

const pushUnique = (titles: CriterionShopTitle[], next: CriterionShopTitle) => {
  const key = `${normalizeClosetPicksTitle(next.title)}|${next.year || ""}|${next.format}`;
  if (titles.some((item) => `${normalizeClosetPicksTitle(item.title)}|${item.year || ""}|${item.format}` === key)) {
    return;
  }
  titles.push(next);
};

export const parseHdReportCriterion4K = (html: string): CriterionShopTitle[] => {
  const titles: CriterionShopTitle[] = [];
  const headings = html.match(/<h[23][^>]*>[\s\S]*?<\/h[23]>/gi) || [];
  for (const heading of headings) {
    const text = cleanShopTitle(heading.replace(/<[^>]+>/g, " "));
    if (!text || SKIP_HEADING.test(text)) {
      continue;
    }
    const expanded = expandBoxset(text, "uhd4k");
    if (expanded.length) {
      for (const film of expanded) {
        pushUnique(titles, film);
      }
      continue;
    }
    const match = text.match(TITLE_YEAR);
    if (!match) {
      continue;
    }
    pushUnique(titles, {
      title: cleanShopTitle(match[1]),
      year: Number(match[2]),
      format: "uhd4k"
    });
  }
  return titles;
};

export const parseCriterionShopCollection = (html: string): CriterionShopTitle[] => {
  const titles: CriterionShopTitle[] = [];
  const wraps = html.match(/<div[^>]*class="[^"]*filmWrap[^"]*"[\s\S]*?<\/div>/gi) || [];
  for (const wrap of wraps) {
    const title =
      cleanShopTitle((wrap.match(/<dt[^>]*>([\s\S]*?)<\/dt>/i) || [])[1] || "") ||
      cleanShopTitle((wrap.match(/<img[^>]*alt="([^"]+)"/i) || [])[1] || "");
    if (!title || /collector['\u2019]?s set|box set|complete\s/i.test(title)) {
      const expanded = expandBoxset(title, inferCriterionFormat(wrap));
      for (const film of expanded) {
        pushUnique(titles, film);
      }
      continue;
    }
    const yearMatch = wrap.match(/\b((?:19|20)\d{2})\b/);
    pushUnique(titles, {
      title,
      year: yearMatch ? Number(yearMatch[1]) : null,
      format: inferCriterionFormat(wrap)
    });
  }
  if (titles.length) {
    return titles;
  }
  return parseCriterionShopCollectionText(html.replace(/<[^>]+>/g, " "));
};

export const parseCriterionShopCollectionText = (text: string): CriterionShopTitle[] => {
  const titles: CriterionShopTitle[] = [];
  const lines = decodeEntities(text).split(/\n+/);
  for (const line of lines) {
    const cleaned = line.replace(/\s+/g, " ").trim();
    if (!cleaned || !/blu-?ray|4k|uhd|dvd/i.test(cleaned)) {
      continue;
    }
    const withoutDate = cleaned.replace(/^date added:\s+[a-z]{3}\s+\d{1,2},\s+\d{4}\s+/i, "");
    const formatMatch = withoutDate.match(/\b(4k uhd(?:\+blu-ray)?(?: combo)?|blu-ray(?:\/dvd combo)?|dvd)\b/i);
    if (!formatMatch || formatMatch.index == null) {
      continue;
    }
    const beforeFormat = withoutDate.slice(0, formatMatch.index).trim();
    const yearMatch = beforeFormat.match(/\b((?:19|20)\d{2})\b/);
    const title = beforeFormat
      .replace(/\b((?:19|20)\d{2})\b/g, " ")
      .replace(/\s+/g, " ")
      .trim();
    // Director often follows the title; keep the full phrase for matching first,
    // then fall back to a shorter title if needed at seed time.
    if (!title || title.length > 160) {
      continue;
    }
    pushUnique(titles, {
      title,
      year: yearMatch ? Number(yearMatch[1]) : null,
      format: inferCriterionFormat(formatMatch[0])
    });
  }
  return titles;
};

export const pickShopTmdbId = (hits: CriterionTmdbHit[], title: string, year?: number | null) => {
  for (const variant of shopTitleVariants(title)) {
    const matched = pickCriterionTmdbId(hits, variant, year);
    if (matched) {
      return matched;
    }
  }
  return pickCriterionTmdbId(hits, title, null);
};

export const seedCriterionCatalogTitles = (
  titles: CriterionShopTitle[],
  hits: CriterionTmdbHit[],
  byTmdbId: Map<string, PhysicalMedia>
) => {
  for (const item of titles) {
    const tmdbId = pickShopTmdbId(hits, item.title, item.year);
    if (!tmdbId) {
      continue;
    }
    const existing = byTmdbId.get(String(tmdbId)) || emptyPhysicalMedia();
    existing.hasCriterion = true;
    addPhysicalEdition(existing, {
      label: "criterion",
      format: item.format,
      spineNumber: item.spineNumber ?? null
    });
    byTmdbId.set(String(tmdbId), reconcilePhysicalMedia(existing));
  }
  return byTmdbId;
};
