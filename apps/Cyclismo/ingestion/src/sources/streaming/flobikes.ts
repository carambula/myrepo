import * as cheerio from "cheerio";
import { fetchHtml } from "../../scraper/fetcher.js";
import type { RaceStreamInput } from "./types.js";
import { parseRegionCodes, parseDateRange } from "./normalize.js";

const FLOBIKES_EVENTS_URL = "https://www.flobikes.com/events";
const FLOBIKES_ARTICLE_URL =
  "https://www.flobikes.com/articles/13913935-the-2025-cycling-streaming-schedule-on-flobikes-what-to-know";

const year = new Date().getUTCFullYear();

const extractRegionFromLinkText = (linkText: string): string => {
  if (/streaming in usa|us territories.*canada/i.test(linkText)) return "US, CA";
  if (/streaming in canada only|canada only/i.test(linkText)) return "CA";
  if (/streaming in global|global/i.test(linkText)) return "GLOBAL";
  return "US, CA";
};

/** Parse FloBikes article page - has race list with dates and regions */
const parseArticleHtml = (html: string): RaceStreamInput[] => {
  const results: RaceStreamInput[] = [];
  const $ = cheerio.load(html);

  $('a[href*="/events/"]').each((_, el) => {
    const $el = $(el);
    const href = $el.attr("href");
    const text = $el.text();
    if (!href || !text.trim()) return;

    const fullUrl = href.startsWith("http") ? href : `https://www.flobikes.com${href}`;

    const regionStr = extractRegionFromLinkText(text);
    const regionCodes = parseRegionCodes(regionStr);

    const lines = text.split("\n").map((s) => s.trim()).filter(Boolean);
    let raceName = "";
    let dateStr = "";

    for (const line of lines) {
      if (/^[A-Za-z].*[a-z]$/.test(line) && line.length > 3 && !/streaming|available/i.test(line)) {
        if (!raceName) raceName = line;
        else if (/^\w+\s+\d{1,2}/.test(line) || /\d{1,2}-\d{1,2}/.test(line)) {
          dateStr = line;
          break;
        }
      }
    }

    if (!raceName) {
      const firstLine = lines[0];
      if (firstLine && !/streaming|available|not available/i.test(firstLine)) {
        raceName = firstLine;
      }
    }

    if (!raceName) return;

    const dateMatch = text.match(/([A-Za-z]+\s+\d{1,2}(?:\s*[-–]\s*\d{1,2})?)|(\d{1,2}\s*[-–]\s*\d{1,2})/);
    if (dateMatch) {
      dateStr = dateMatch[1] || dateMatch[2] || "";
    }

    const parsed = dateStr ? parseDateRange(year, dateStr) : null;
    const startDate = parsed?.start ?? `${year}-01-01`;
    const endDate = parsed?.end ?? startDate;

    results.push({
      raceName: raceName.replace(/\s+/g, " ").trim(),
      startDate,
      endDate,
      streamerSlug: "flobikes",
      regionCodes,
      streamUrl: fullUrl,
      sourceUrl: FLOBIKES_ARTICLE_URL,
      genderDivision: /women|femmes|ladies/i.test(raceName) ? "Women" : null
    });
  });

  return results;
};

/** Parse FloBikes events page if it has server-rendered content */
const parseEventsHtml = (html: string): RaceStreamInput[] => {
  const results: RaceStreamInput[] = [];
  const $ = cheerio.load(html);

  $('a[href*="/events/"]').each((_, el) => {
    const $el = $(el);
    const href = $el.attr("href");
    const text = $el.text().trim();
    if (!href || !text || text.length < 4) return;

    const fullUrl = href.startsWith("http") ? href : `https://www.flobikes.com${href}`;
    const regionCodes = parseRegionCodes(text);

    const namePart = text.split(/\d{1,2}:\d{2}|\d{1,2}\s*[-–]\s*\d{1,2}/)[0]?.trim();
    const raceName = namePart || text;
    const dateMatch = text.match(/([A-Za-z]+\s+\d{1,2}(?:\s*[-–]\s*[A-Za-z]+\s+\d{1,2})?)|(\d{1,2}\s*[-–]\s*\d{1,2})/);
    const parsed = dateMatch ? parseDateRange(year, dateMatch[1] || dateMatch[2]) : null;
    const startDate = parsed?.start ?? `${year}-01-01`;
    const endDate = parsed?.end ?? startDate;

    if (/streaming|available|sign up|subscribe/i.test(raceName)) return;

    results.push({
      raceName,
      startDate,
      endDate,
      streamerSlug: "flobikes",
      regionCodes: regionCodes.length ? regionCodes : ["GLOBAL"],
      streamUrl: fullUrl,
      sourceUrl: FLOBIKES_EVENTS_URL,
      genderDivision: /women|femmes|ladies/i.test(raceName) ? "Women" : null
    });
  });

  return results;
};

export const fetchFloBikesStreams = async (): Promise<RaceStreamInput[]> => {
  const options = {
    cacheDir: ".cache/streaming/flobikes",
    cacheTtlMs: 1000 * 60 * 60 * 6,
    delayMs: 800
  };

  try {
    const html = await fetchHtml(FLOBIKES_ARTICLE_URL, options);
    const parsed = parseArticleHtml(html);
    if (parsed.length > 0) return dedupeStreams(parsed);
  } catch (e) {
    console.warn("FloBikes article fetch failed, trying events page", e);
  }

  try {
    const html = await fetchHtml(FLOBIKES_EVENTS_URL, options);
    return dedupeStreams(parseEventsHtml(html));
  } catch (e) {
    console.warn("FloBikes events fetch failed", e);
    return [];
  }
};

const dedupeStreams = (items: RaceStreamInput[]): RaceStreamInput[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.raceName}__${item.startDate}__${item.streamerSlug}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};
