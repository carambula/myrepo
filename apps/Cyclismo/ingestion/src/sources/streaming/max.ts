import * as cheerio from "cheerio";
import { fetchHtml } from "../../scraper/fetcher.js";
import type { RaceStreamInput } from "./types.js";
import { parseMonthDayToIso } from "./normalize.js";

const MAX_CYCLING_URL = "https://www.max.com/sports/cycling";
const MAX_BASE = "https://www.max.com";

const year = new Date().getUTCFullYear();

/** Parse "Apr 5, 1:30pm" or "Apr 15, 11:50am" to ISO date */
const parseMaxDate = (s: string): string | null => {
  const m = s.match(/^([A-Za-z]+)\s+(\d{1,2})/);
  if (!m) return null;
  return parseMonthDayToIso(year, m[1], m[2]);
};

/** Extract race name from Max event text - e.g. "Cycling | Gran Premio Miguel Induráin | Men | ..." */
const extractRaceName = (text: string): string => {
  const parts = text.split("|").map((p) => p.trim());
  if (parts.length >= 2) {
    return parts[1]
      .replace(/\s*-\s*Men\s*$/, "")
      .replace(/\s*-\s*Women\s*$/, "")
      .replace(/\s*\|?\s*Men\s*$/, "")
      .replace(/\s*\|?\s*Women\s*$/, "")
      .trim();
  }
  return text.replace(/\s*\|\s*Men\s*$|\s*\|\s*Women\s*$/i, "").trim();
};

const parseHtml = (html: string): RaceStreamInput[] => {
  const results: RaceStreamInput[] = [];
  const $ = cheerio.load(html);

  $('a[href*="/sports/"]').each((_, el) => {
    const $el = $(el);
    const href = $el.attr("href");
    const text = $el.text().trim();
    if (!href || !text || !href.includes("sports/20")) return;

    const fullUrl = href.startsWith("http") ? href : `${MAX_BASE}${href}`;
    const dateFromUrl = href.match(/\/sports\/(\d{4})-(\d{1,2})-(\d{1,2})\//);
    let startDate = `${year}-01-01`;
    if (dateFromUrl) {
      const [, y, mo, d] = dateFromUrl;
      startDate = `${y}-${mo.padStart(2, "0")}-${d.padStart(2, "0")}`;
    } else {
      const datePart = text.split("|").pop()?.trim() ?? text;
      const parsed = parseMaxDate(datePart);
      if (parsed) startDate = parsed;
    }

    const raceName = extractRaceName(text);
    if (!raceName || raceName.length < 4) return;
    if (/cycling|stream|sign up|subscribe|br sports/i.test(raceName) && raceName.length < 30) return;

    results.push({
      raceName,
      startDate,
      endDate: startDate,
      streamerSlug: "max",
      regionCodes: ["US"],
      streamUrl: fullUrl,
      sourceUrl: MAX_CYCLING_URL,
      genderDivision: /\|\s*Women\s*$|Women\s*$|Femmes/i.test(text) ? "Women" : null
    });
  });

  return dedupe(results);
};

const dedupe = (items: RaceStreamInput[]): RaceStreamInput[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.raceName}__${item.startDate}__max`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

export const fetchMaxStreams = async (): Promise<RaceStreamInput[]> => {
  const options = {
    cacheDir: ".cache/streaming/max",
    cacheTtlMs: 1000 * 60 * 60 * 6,
    delayMs: 800
  };

  try {
    const html = await fetchHtml(MAX_CYCLING_URL, options);
    return parseHtml(html);
  } catch (e) {
    console.warn("Max cycling fetch failed", e);
    return [];
  }
};
