import * as cheerio from "cheerio";
import { fetchHtml } from "../../scraper/fetcher.js";
import type { RaceStreamInput } from "./types.js";
import { parseDateRange } from "./normalize.js";

const PEACOCK_CYCLING_URL = "https://www.peacocktv.com/sports/cycling";
const year = new Date().getUTCFullYear();

/** Parse "March 24-30" or "April 12-27" into start/end */
const parsePeacockDateRange = (s: string): { start: string; end: string } | null => {
  const m = s.match(/^([A-Za-z]+)\s+(\d{1,2})\s*[-–]\s*(\d{1,2})$/i);
  if (m) {
    return parseDateRange(year, `${m[1]} ${m[2]}-${m[3]}`);
  }
  const m2 = s.match(/^([A-Za-z]+)\s+(\d{1,2})$/i);
  if (m2) {
    const r = parseDateRange(year, `${m2[1]} ${m2[2]}`);
    return r ? { start: r.start, end: r.start } : null;
  }
  return null;
};

const parseHtml = (html: string): RaceStreamInput[] => {
  const results: RaceStreamInput[] = [];
  const $ = cheerio.load(html);

  const table = $("table").first();
  if (table.length === 0) {
    $("tr, .schedule-row, [data-event]").each((_, row) => {
      const $row = $(row);
      const cells = $row.find("td, th, [data-event-name], [data-date]");
      if (cells.length < 2) return;

      const eventCell = $row.find("[data-event-name], td:first-child, th:first-child").first();
      const dateCell = $row.find("[data-date], td:nth-child(2), th:nth-child(2)").first();
      const name = eventCell.text().trim();
      const dateStr = dateCell.text().trim();
      if (!name || !dateStr || !/peacock/i.test($row.text())) return;

      const parsed = parsePeacockDateRange(dateStr);
      if (!parsed) return;

      results.push({
        raceName: name,
        startDate: parsed.start,
        endDate: parsed.end,
        streamerSlug: "peacock",
        regionCodes: ["US"],
        streamUrl: null,
        sourceUrl: PEACOCK_CYCLING_URL,
        genderDivision: null
      });
    });
    return dedupe(results);
  }

  table.find("tr").each((_, row) => {
    const cells = $(row).find("td");
    if (cells.length < 2) return;

    const eventCell = cells.eq(0);
    const dateCell = cells.eq(1);
    const name = eventCell.text().trim();
    const dateStr = dateCell.text().trim();
    if (!name || !dateStr) return;

    const parsed = parsePeacockDateRange(dateStr);
    if (!parsed) return;

    results.push({
      raceName: name,
      startDate: parsed.start,
      endDate: parsed.end,
      streamerSlug: "peacock",
      regionCodes: ["US"],
      streamUrl: null,
      sourceUrl: PEACOCK_CYCLING_URL,
      genderDivision: /women|femmes|ladies/i.test(name) ? "Women" : null
    });
  });

  return dedupe(results);
};

const dedupe = (items: RaceStreamInput[]): RaceStreamInput[] => {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.raceName}__${item.startDate}__peacock`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
};

export const fetchPeacockStreams = async (): Promise<RaceStreamInput[]> => {
  const options = {
    cacheDir: ".cache/streaming/peacock",
    cacheTtlMs: 1000 * 60 * 60 * 6,
    delayMs: 800
  };

  try {
    const html = await fetchHtml(PEACOCK_CYCLING_URL, options);
    return parseHtml(html);
  } catch (e) {
    console.warn("Peacock cycling fetch failed", e);
    return [];
  }
};
