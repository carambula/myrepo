import * as cheerio from "cheerio";
import type { RaceInput, StageInput } from "../normalize.js";
import fs from "node:fs/promises";

const parseYear = (html: string) => {
  const match = html.match(/calendar\s+(\d{4})/i) || html.match(/UCI Cycling calendar\s+(\d{4})/i);
  if (match?.[1]) {
    return Number(match[1]);
  }
  return new Date().getUTCFullYear();
};

const parseListUrls = (raw: string | undefined) => {
  if (!raw) {
    return [];
  }
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
};

const parseListPaths = (raw: string | undefined) => {
  if (!raw) {
    return [];
  }
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
};

const toIsoDate = (year: number, value: string) => {
  const match = value.match(/(\d{1,2})\.(\d{1,2})/);
  if (!match) {
    return null;
  }
  const day = match[1].padStart(2, "0");
  const month = match[2].padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const parseDateRange = (year: number, value: string) => {
  const parts = value.split("-").map((part) => part.trim());
  if (parts.length === 1) {
    const single = toIsoDate(year, parts[0]);
    return single ? { start: single, end: single } : null;
  }
  const start = toIsoDate(year, parts[0]);
  const end = toIsoDate(year, parts[1]);
  if (!start || !end) {
    return null;
  }
  return { start, end };
};

const toIsoDateFlexible = (year: number, value: string) => {
  const iso = value.match(/(\d{4})-(\d{2})-(\d{2})/);
  if (iso) {
    return `${iso[1]}-${iso[2]}-${iso[3]}`;
  }
  const short = value.match(/(\d{1,2})[.\/-](\d{1,2})(?:[.\/-](\d{2,4}))?/);
  if (!short) {
    return null;
  }
  const day = short[1].padStart(2, "0");
  const month = short[2].padStart(2, "0");
  const parsedYear = short[3] ? Number(short[3].length === 2 ? `20${short[3]}` : short[3]) : year;
  if (!Number.isFinite(parsedYear)) {
    return null;
  }
  return `${parsedYear}-${month}-${day}`;
};

const parseStageRow = (
  rowText: string,
  raceName: string,
  raceStartDate: string,
  raceYear: number
): Omit<StageInput, "sourceUrl"> | null => {
  const compact = rowText.replace(/\s+/g, " ").trim();
  if (!compact) {
    return null;
  }
  const isRestDay = /\b(rest\s*day)\b/i.test(compact);
  const stageMatch = compact.match(/\b(?:stage|stg|etape)\s*(\d{1,2})\b/i);
  if (!isRestDay && !stageMatch) {
    return null;
  }
  const stageNumber = stageMatch?.[1] ? Number(stageMatch[1]) : null;
  const date = toIsoDateFlexible(raceYear, compact);
  const routeMatch = compact.match(/([A-Za-z0-9 .'\-()]+)\s+(?:to|>|-)\s+([A-Za-z0-9 .'\-()]+)$/i);
  const startLocation = routeMatch?.[1]?.trim() ?? null;
  const endLocation = routeMatch?.[2]?.trim() ?? null;
  const timeMatch = compact.match(/\b(\d{1,2}:\d{2})\b/);
  return {
    raceName,
    raceStartDate,
    sourceStageId: stageMatch ? `stage-${stageMatch[1]}` : date ? `rest-${date}` : null,
    stageNumber,
    stageType: /itt/i.test(compact)
      ? "ITT"
      : /ttt/i.test(compact)
        ? "TTT"
        : isRestDay
          ? "Rest day"
          : null,
    name: isRestDay ? "Rest day" : `Stage ${stageMatch?.[1] ?? ""}`.trim(),
    date,
    startLocation,
    endLocation,
    distanceKm: null,
    departTimeLocal: timeMatch?.[1] ?? null,
    departTimezone: null,
    departDatetimeUtc: null,
    isRestDay
  };
};

const fetchPcsStagesForRace = async (race: RaceInput): Promise<StageInput[]> => {
  if (race.raceType !== "Stage race" || !race.officialWebsite) {
    return [];
  }
  try {
    const response = await fetch(race.officialWebsite, {
      headers: {
        accept: "text/html",
        "user-agent": "CyclismoBootstrap/1.0 (+https://github.com/)",
        "accept-language": "en-US,en;q=0.9"
      }
    });
    if (!response.ok) {
      return [];
    }
    const html = await response.text();
    const year = Number(race.startDate.slice(0, 4));
    if (!Number.isFinite(year)) {
      return [];
    }
    const $ = cheerio.load(html);
    const stages: StageInput[] = [];
    $("table tr").each((_, row) => {
      const rowText = $(row).text();
      const parsed = parseStageRow(rowText, race.name, race.startDate, year);
      if (!parsed) {
        return;
      }
      const link = $(row).find("a").attr("href");
      const sourceUrl = link
        ? `https://www.procyclingstats.com/${link.replace(/^\//, "")}`
        : race.officialWebsite;
      stages.push({
        ...parsed,
        sourceUrl
      });
    });
    return stages;
  } catch {
    return [];
  }
};

const detectGender = (url: string, name: string, classification: string) => {
  if (url.includes("women=1")) {
    if (/women|femmes|dames|ladies/i.test(name) || /WWT/i.test(classification)) {
      return "Women";
    }
    return null;
  }
  if (/women|femmes|dames|ladies/i.test(name)) {
    return "Women";
  }
  if (/WWT/i.test(classification)) {
    return "Women";
  }
  return null;
};

export const fetchPcsRaces = async (): Promise<RaceInput[]> => {
  const urls = parseListUrls(process.env.PCS_RACES_URLS ?? process.env.PCS_RACES_URL);
  const htmlPaths = parseListPaths(process.env.PCS_RACES_HTML_PATHS ?? process.env.PCS_RACES_HTML_PATH);
  if (!urls.length && !htmlPaths.length) {
    return [];
  }

  const races: RaceInput[] = [];

  const parseHtml = (html: string, sourceLabel: string) => {
    const year = parseYear(html);
    const $ = cheerio.load(html);
    $("table tr").each((_, row) => {
      const cells = $(row).find("td");
      if (cells.length < 3) {
        return;
      }
      const dateRange = $(cells[0]).text().trim();
      const raceCell = $(cells[2]);
      const name = raceCell.text().trim();
      const classification = $(cells[cells.length - 1]).text().trim();

      if (!name || !dateRange) {
        return;
      }

      const parsed = parseDateRange(year, dateRange);
      if (!parsed) {
        return;
      }

      const raceType = parsed.start === parsed.end ? "One-day" : "Stage race";
      const link = raceCell.find("a").attr("href");
      const officialWebsite = link
        ? `https://www.procyclingstats.com/${link.replace(/^\//, "")}`
        : null;

      const genderDivision = detectGender(sourceLabel, name, classification);
      if (sourceLabel.includes("women=1") && !genderDivision) {
        return;
      }

      races.push({
        name,
        series: "PCS",
        classification: classification || null,
        discipline: "Road",
        raceType,
        startDate: parsed.start,
        endDate: parsed.end,
        locationCountry: null,
        locationCity: null,
        organizer: null,
        officialWebsite,
        genderDivision
      });
    });
  };

  for (const htmlPath of htmlPaths) {
    const html = await fs.readFile(htmlPath, "utf8");
    parseHtml(html, htmlPath);
  }

  for (const url of urls) {
    const response = await fetch(url, {
      headers: {
        accept: "text/html",
        "user-agent": "CyclismoBootstrap/1.0 (+https://github.com/)",
        "accept-language": "en-US,en;q=0.9"
      }
    });
    if (!response.ok) {
      throw new Error(`Failed to fetch ${url}`);
    }

    const html = await response.text();
    parseHtml(html, url);
  }

  const shouldFetchStageDetails = process.env.PCS_FETCH_STAGE_DETAILS !== "false";
  if (shouldFetchStageDetails) {
    const stageRaceLimitRaw = Number(process.env.PCS_STAGE_DETAIL_LIMIT ?? "20");
    const stageRaceLimit = Number.isFinite(stageRaceLimitRaw)
      ? Math.max(0, Math.floor(stageRaceLimitRaw))
      : 20;
    const stageRaceIndexes = races
      .map((race, index) => ({ race, index }))
      .filter(({ race }) => race.raceType === "Stage race" && !!race.officialWebsite)
      .slice(0, stageRaceLimit);
    await Promise.all(
      stageRaceIndexes.map(async ({ race, index }) => {
        const stages = await fetchPcsStagesForRace(race);
        if (stages.length) {
          races[index] = {
            ...races[index],
            stages
          };
        }
      })
    );
  }

  return races;
};
