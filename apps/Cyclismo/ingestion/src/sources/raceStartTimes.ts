import * as cheerio from "cheerio";
import fs from "node:fs/promises";
import { fetchHtml, buildFetchOptions } from "../scraper/fetcher.js";

type RaceLike = {
  name: string | null;
  startDate: string | null;
  endDate?: string | null;
  raceType?: string | null;
  locationCountry?: string | null;
  locationCity?: string | null;
  genderDivision?: string | null;
  startTimeLocal?: string | null;
  startTimezone?: string | null;
  startDatetimeUtc?: string | null;
};

const PCS_SEARCH_URL = "https://www.procyclingstats.com/search.php?term=";
const PCS_START_FINISH_URL = "https://www.procyclingstats.com/calendar/uci/start-finish-schedule";
const MAX_LOOKUPS = Number(process.env.PCS_START_TIME_MAX_LOOKUPS ?? "90");

const timezoneForRace = (race: Pick<RaceLike, "locationCountry" | "locationCity">): string | null => {
  const country = (race.locationCountry ?? "").toLowerCase();
  const city = (race.locationCity ?? "").toLowerCase();
  if (country.includes("australia")) return "Australia/Adelaide";
  if (country.includes("united arab emirates")) return "Asia/Dubai";
  if (country.includes("belgium")) return "Europe/Brussels";
  if (country.includes("france")) return "Europe/Paris";
  if (country.includes("italy")) return "Europe/Rome";
  if (country.includes("spain")) return "Europe/Madrid";
  if (country.includes("switzerland")) return "Europe/Zurich";
  if (country.includes("germany")) return "Europe/Berlin";
  if (country.includes("netherlands")) return "Europe/Amsterdam";
  if (country.includes("denmark")) return "Europe/Copenhagen";
  if (country.includes("poland")) return "Europe/Warsaw";
  if (country.includes("united kingdom")) return "Europe/London";
  if (country.includes("china")) return "Asia/Shanghai";
  if (country.includes("canada")) return city.includes("montreal") || city.includes("quebec")
    ? "America/Toronto"
    : "America/Toronto";
  if (country.includes("usa")) {
    if (city.includes("california") || city.includes("ca")) return "America/Los_Angeles";
    if (city.includes("colorado") || city.includes("co")) return "America/Denver";
    if (city.includes("arkansas") || city.includes("wisconsin") || city.includes("kansas")) {
      return "America/Chicago";
    }
  }
  return null;
};

const normalizeName = (value: string) =>
  value
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/\(.*?\)/g, " ")
    .replace(/femmes|feminine/g, "women")
    .replace(/hauts-de-france/g, "")
    .replace(/\/|-/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const buildSearchTerm = (race: Pick<RaceLike, "name" | "startDate">) => {
  const year = race.startDate?.slice(0, 4) ?? "";
  return `${race.name ?? ""} ${year}`.trim();
};

const extractCandidateRaceUrls = (searchHtml: string, year: string): string[] => {
  const seen = new Set<string>();
  const urls: string[] = [];
  const regex = /href="(\/race\/[^"]+)"/g;
  let match: RegExpExecArray | null = regex.exec(searchHtml);
  while (match) {
    const href = match[1];
    if (href.includes(`/${year}`) && !href.includes("/calendar/")) {
      const full = `https://www.procyclingstats.com${href}`;
      if (!seen.has(full)) {
        seen.add(full);
        urls.push(full);
      }
    }
    match = regex.exec(searchHtml);
  }
  return urls;
};

const isRacePageMatch = (html: string, raceName: string): boolean => {
  const bodyText = cheerio.load(html)("body").text().replace(/\s+/g, " ").trim();
  const normBody = normalizeName(bodyText);
  const normRace = normalizeName(raceName);
  if (!normRace) return false;
  return normBody.includes(normRace) || normRace.split(" ").every((token) => normBody.includes(token));
};

const extractStartTime = (raceHtml: string): string | null => {
  const text = cheerio.load(raceHtml)("body").text();
  const match = text.match(/Start time:\s*([0-2]?\d:[0-5]\d)/i);
  if (!match?.[1]) return null;
  return match[1].padStart(5, "0");
};

type StartTimeResult = { startTimeLocal: string; startTimezone: string | null };
type OfficialFallbackSource = {
  match: RegExp;
  urls: string[];
  timezone: string | null;
};
type ScheduleEntry = {
  date: string;
  raceName: string;
  raceNameNorm: string;
  startTime: string;
};
type BaselineTimeHint = {
  aliases: string[];
  startTimeLocal: string;
  timezone: string;
};

const BASELINE_TIME_HINTS: BaselineTimeHint[] = [
  { aliases: ["tour down under", "santos tour down under"], startTimeLocal: "11:00", timezone: "Australia/Adelaide" },
  {
    aliases: ["cadel evans great ocean road race", "mapei cadel evans great ocean road race"],
    startTimeLocal: "11:00",
    timezone: "Australia/Adelaide"
  },
  { aliases: ["world championships"], startTimeLocal: "10:00", timezone: "America/Toronto" },
  { aliases: ["uae tour"], startTimeLocal: "12:00", timezone: "Asia/Dubai" },
  { aliases: ["omloop nieuwsblad", "omloop het nieuwsblad"], startTimeLocal: "11:15", timezone: "Europe/Brussels" },
  { aliases: ["strade bianche"], startTimeLocal: "11:30", timezone: "Europe/Rome" },
  { aliases: ["paris nice"], startTimeLocal: "11:00", timezone: "Europe/Paris" },
  { aliases: ["tirreno adriatico"], startTimeLocal: "12:00", timezone: "Europe/Rome" },
  { aliases: ["milano sanremo", "milan san remo"], startTimeLocal: "10:00", timezone: "Europe/Rome" },
  { aliases: ["trofeo alfredo binda"], startTimeLocal: "13:00", timezone: "Europe/Rome" },
  { aliases: ["volta ciclista a catalunya", "volta a catalunya"], startTimeLocal: "12:00", timezone: "Europe/Madrid" },
  {
    aliases: ["classic brugge de panne", "ronde van brugge", "tour of bruges"],
    startTimeLocal: "12:00",
    timezone: "Europe/Brussels"
  },
  { aliases: ["e3 saxo classic"], startTimeLocal: "12:30", timezone: "Europe/Brussels" },
  {
    aliases: ["gent wevelgem", "in flanders fields from middelkerke to wevelgem", "in flanders fields in wevelgem"],
    startTimeLocal: "11:00",
    timezone: "Europe/Brussels"
  },
  { aliases: ["dwars door vlaanderen"], startTimeLocal: "12:00", timezone: "Europe/Brussels" },
  { aliases: ["tour of flanders", "ronde van vlaanderen"], startTimeLocal: "10:30", timezone: "Europe/Brussels" },
  {
    aliases: ["tour of the basque country", "itzulia basque country"],
    startTimeLocal: "12:30",
    timezone: "Europe/Madrid"
  },
  { aliases: ["paris roubaix"], startTimeLocal: "11:00", timezone: "Europe/Paris" },
  { aliases: ["amstel gold race"], startTimeLocal: "10:40", timezone: "Europe/Amsterdam" },
  { aliases: ["la fleche wallonne"], startTimeLocal: "11:30", timezone: "Europe/Brussels" },
  { aliases: ["liege bastogne liege"], startTimeLocal: "10:15", timezone: "Europe/Brussels" },
  { aliases: ["tour de romandie"], startTimeLocal: "13:00", timezone: "Europe/Zurich" },
  { aliases: ["eschborn frankfurt"], startTimeLocal: "12:00", timezone: "Europe/Berlin" },
  { aliases: ["giro d italia", "giro d'italia"], startTimeLocal: "12:00", timezone: "Europe/Rome" },
  { aliases: ["giro d italia women", "giro d'italia women"], startTimeLocal: "12:00", timezone: "Europe/Rome" },
  {
    aliases: ["criterium du dauphine", "tour auvergne rhone alpes"],
    startTimeLocal: "12:30",
    timezone: "Europe/Paris"
  },
  { aliases: ["copenhagen sprint"], startTimeLocal: "12:00", timezone: "Europe/Copenhagen" },
  { aliases: ["tour de suisse"], startTimeLocal: "12:30", timezone: "Europe/Zurich" },
  { aliases: ["tour de france"], startTimeLocal: "12:00", timezone: "Europe/Paris" },
  {
    aliases: ["clasica de san sebastian", "donostia san sebastian klasikoa", "dssk"],
    startTimeLocal: "11:30",
    timezone: "Europe/Madrid"
  },
  {
    aliases: ["vuelta espana femenina", "vuelta españa femenina", "vuelta espana femenina by carrefour es"],
    startTimeLocal: "13:00",
    timezone: "Europe/Madrid"
  },
  { aliases: ["itzulia women"], startTimeLocal: "12:30", timezone: "Europe/Madrid" },
  { aliases: ["vuelta a burgos feminas"], startTimeLocal: "12:30", timezone: "Europe/Madrid" },
  { aliases: ["lloyds tour of britain women"], startTimeLocal: "11:00", timezone: "Europe/London" },
  { aliases: ["classic lorient agglomeration"], startTimeLocal: "11:00", timezone: "Europe/Paris" },
  { aliases: ["tour of chongming island"], startTimeLocal: "12:00", timezone: "Asia/Shanghai" },
  { aliases: ["tour de pologne"], startTimeLocal: "12:00", timezone: "Europe/Warsaw" },
  { aliases: ["hamburg cyclassics", "adac cyclassics"], startTimeLocal: "12:00", timezone: "Europe/Berlin" },
  { aliases: ["renewi tour"], startTimeLocal: "13:00", timezone: "Europe/Brussels" },
  { aliases: ["vuelta a espana", "la vuelta ciclista a espana"], startTimeLocal: "13:00", timezone: "Europe/Madrid" },
  { aliases: ["bretagne classic"], startTimeLocal: "11:00", timezone: "Europe/Paris" },
  { aliases: ["grand prix cycliste de quebec"], startTimeLocal: "11:00", timezone: "America/Toronto" },
  { aliases: ["grand prix cycliste de montreal"], startTimeLocal: "11:00", timezone: "America/Toronto" },
  { aliases: ["il lombardia"], startTimeLocal: "10:30", timezone: "Europe/Rome" },
  { aliases: ["tour of guangxi"], startTimeLocal: "12:00", timezone: "Asia/Shanghai" },
  { aliases: ["sea otter gravel"], startTimeLocal: "08:00", timezone: "America/Los_Angeles" },
  { aliases: ["unbound gravel 200", "unbound gravel"], startTimeLocal: "06:00", timezone: "America/Chicago" },
  { aliases: ["leadville trail 100 mtb"], startTimeLocal: "06:00", timezone: "America/Denver" },
  { aliases: ["chequamegon mtb fest"], startTimeLocal: "10:00", timezone: "America/Chicago" },
  { aliases: ["little sugar mtb"], startTimeLocal: "08:00", timezone: "America/Chicago" },
  { aliases: ["big sugar gravel"], startTimeLocal: "09:00", timezone: "America/Chicago" }
];

const OFFICIAL_FALLBACK_SOURCES: OfficialFallbackSource[] = [
  {
    match: /tour de france femmes/i,
    urls: ["https://www.letourfemmes.fr/en"],
    timezone: "Europe/Paris"
  },
  {
    match: /tour de france/i,
    urls: ["https://www.letour.fr/en"],
    timezone: "Europe/Paris"
  },
  {
    match: /paris-roubaix/i,
    urls: ["https://www.paris-roubaix.fr/en/"],
    timezone: "Europe/Paris"
  },
  {
    match: /milano-sanremo|strade bianche/i,
    urls: ["https://www.rcs-sport.it/en/"],
    timezone: "Europe/Rome"
  },
  {
    match: /giro d'italia/i,
    urls: ["https://www.giroditalia.it/en/"],
    timezone: "Europe/Rome"
  },
  {
    match: /vuelta/i,
    urls: ["https://www.lavuelta.es/en"],
    timezone: "Europe/Madrid"
  },
  {
    match: /ronde van vlaanderen|omloop|e3|dwars door|gent-wevelgem|flanders/i,
    urls: ["https://www.flandersclassics.be/en/races"],
    timezone: "Europe/Brussels"
  },
  {
    match: /world championships/i,
    urls: ["https://www.montreal2026.org/en/"],
    timezone: "America/Toronto"
  },
  {
    match: /sea otter gravel/i,
    urls: ["https://www.seaotterclassic.com/gravel/"],
    timezone: "America/Los_Angeles"
  },
  {
    match: /unbound gravel/i,
    urls: ["https://www.unboundgravel.com/"],
    timezone: "America/Chicago"
  },
  {
    match: /leadville trail/i,
    urls: ["https://www.leadvilleraceseries.com/mtb/leadvilletrail100mtb/"],
    timezone: "America/Denver"
  }
];

let scheduleIndexPromise: Promise<Map<string, ScheduleEntry[]> | null> | null = null;

const isClock = (value: string) => /^[0-2]?\d:[0-5]\d$/.test(value.trim());

const toDayMonth = (isoDate: string): string => {
  const parts = isoDate.split("-");
  if (parts.length < 3) return "";
  return `${parts[2].padStart(2, "0")}/${parts[1].padStart(2, "0")}`;
};

const scheduleRowNameVariants = (name: string): string[] => {
  const trimmed = name.trim();
  if (!trimmed) return [];
  const split = trimmed.split("|").map((part) => part.trim()).filter(Boolean);
  const variants = new Set<string>([trimmed]);
  if (split.length > 0) variants.add(split[0]);
  for (const part of split) {
    if (part.length > 3) variants.add(part);
  }
  return Array.from(variants);
};

const STOP_TOKENS = new Set([
  "uci",
  "worldtour",
  "world",
  "tour",
  "race",
  "classic",
  "stage",
  "result",
  "women",
  "men",
  "the",
  "de",
  "la",
  "a",
  "of",
  "and"
]);

const tokenize = (value: string): string[] =>
  normalizeName(value)
    .split(" ")
    .map((token) => token.trim())
    .filter((token) => token.length > 1 && !STOP_TOKENS.has(token));

const containsWomenMarker = (value: string): boolean =>
  /\b(women|femmes|donne|ladies|we)\b/i.test(value);

const containsMenMarker = (value: string): boolean =>
  /\b(men|me)\b/i.test(value);

const isLikelyStageEntry = (value: string): boolean =>
  /\b(stage|etape|etapa)\b/i.test(value);

const mentionsStageOne = (value: string): boolean =>
  /\b(stage|etape|etapa)\s*1\b/i.test(value) || /\bstage\s*one\b/i.test(value);

const raceLooksWomen = (race: RaceLike): boolean => {
  if (containsWomenMarker(race.name ?? "")) return true;
  return (race.genderDivision ?? "").toLowerCase() === "women";
};

const raceLooksMen = (race: RaceLike): boolean => {
  if (containsMenMarker(race.name ?? "")) return true;
  return (race.genderDivision ?? "").toLowerCase() === "men";
};

const isStageRace = (race: RaceLike): boolean => {
  const type = (race.raceType ?? "").toLowerCase();
  if (type.includes("stage")) return true;
  if (race.startDate && race.endDate) return race.startDate != race.endDate;
  return false;
};

const scoreScheduleEntry = (race: RaceLike, entryName: string): number => {
  const raceTokens = tokenize(race.name ?? "");
  const entryTokens = new Set(tokenize(entryName));
  if (!raceTokens.length || !entryTokens.size) return 0;
  let overlap = 0;
  for (const token of raceTokens) {
    if (entryTokens.has(token)) overlap += 1;
  }
  return overlap / raceTokens.length;
};

const matchBaselineHint = (raceName: string): BaselineTimeHint | null => {
  const normalizedRace = normalizeName(raceName);
  for (const hint of BASELINE_TIME_HINTS) {
    for (const alias of hint.aliases) {
      const normalizedAlias = normalizeName(alias);
      if (
        normalizedRace === normalizedAlias ||
        normalizedRace.includes(normalizedAlias) ||
        normalizedAlias.includes(normalizedRace)
      ) {
        return hint;
      }
    }
  }
  return null;
};

const applyBaselineTimes = <T extends RaceLike>(races: T[]): void => {
  for (const race of races) {
    if (!race.name || race.startTimeLocal) continue;
    const hint = matchBaselineHint(race.name);
    if (!hint) continue;
    race.startTimeLocal = hint.startTimeLocal;
    race.startTimezone = race.startTimezone ?? hint.timezone;
    race.startDatetimeUtc = race.startDatetimeUtc ?? null;
  }
};

const parseScheduleIndex = (html: string): Map<string, ScheduleEntry[]> => {
  const $ = cheerio.load(html);
  const index = new Map<string, ScheduleEntry[]>();
  $("table tr").each((_, row) => {
    const cells = $(row).find("td");
    if (cells.length < 4) return;
    const date = cells.eq(0).text().trim();
    const localStart = cells.eq(1).text().trim();
    const raceName = cells.eq(2).text().trim();
    const startTime = cells.eq(3).text().trim();
    const chosen = isClock(localStart) ? localStart : isClock(startTime) ? startTime : "";
    if (!date || !raceName || !chosen) return;
    const entries = index.get(date) ?? [];
    entries.push({
      date,
      raceName,
      raceNameNorm: normalizeName(raceName),
      startTime: chosen.padStart(5, "0")
    });
    index.set(date, entries);
  });
  return index;
};

const parseScheduleIndexFromMarkdown = (content: string): Map<string, ScheduleEntry[]> => {
  const index = new Map<string, ScheduleEntry[]>();
  const lines = content.split(/\r?\n/);
  const rowRegex =
    /^\|\s*(\d{2}\/\d{2})\s*\|\s*([^|]+)\|\s*\[(.*?)\]\([^)]+\)\s*\|\s*([^|]+)\|\s*([^|]+)\|/;
  for (const line of lines) {
    const match = line.match(rowRegex);
    if (!match) continue;
    const date = match[1].trim();
    const localStart = match[2].trim();
    const raceName = match[3].trim();
    const startTime = match[4].trim();
    const chosen = isClock(localStart) ? localStart : isClock(startTime) ? startTime : "";
    if (!date || !raceName || !chosen) continue;
    const entries = index.get(date) ?? [];
    entries.push({
      date,
      raceName,
      raceNameNorm: normalizeName(raceName),
      startTime: chosen.padStart(5, "0")
    });
    index.set(date, entries);
  }
  return index;
};

const loadScheduleIndex = async (
  options: ReturnType<typeof buildFetchOptions>
): Promise<Map<string, ScheduleEntry[]> | null> => {
  const snapshotPath = process.env.PCS_START_FINISH_SCHEDULE_HTML_PATH;
  if (snapshotPath) {
    try {
      const html = await fs.readFile(snapshotPath, "utf8");
      const parsedHtml = parseScheduleIndex(html);
      if (parsedHtml.size > 0) return parsedHtml;
      const parsedMd = parseScheduleIndexFromMarkdown(html);
      return parsedMd.size > 0 ? parsedMd : null;
    } catch {
      return null;
    }
  }
  try {
    const html = await fetchHtml(PCS_START_FINISH_URL, {
      ...options,
      cacheDir: ".cache/pcs-start-times-schedule"
    });
    const parsed = parseScheduleIndex(html);
    if (parsed.size > 0) return parsed;
    const parsedMd = parseScheduleIndexFromMarkdown(html);
    return parsedMd.size > 0 ? parsedMd : null;
  } catch {
    return null;
  }
};

const findScheduleFallbackTime = async (
  race: RaceLike,
  options: ReturnType<typeof buildFetchOptions>
): Promise<StartTimeResult | null> => {
  if (!race.name || !race.startDate) return null;
  if (!scheduleIndexPromise) {
    scheduleIndexPromise = loadScheduleIndex(options);
  }
  const schedule = await scheduleIndexPromise;
  if (!schedule) return null;

  const dayMonth = toDayMonth(race.startDate);
  const entries = schedule.get(dayMonth) ?? [];
  if (!entries.length) return null;

  const womenRace = raceLooksWomen(race);
  const menRace = raceLooksMen(race);
  const stageRace = isStageRace(race);
  const candidates: Array<{ entry: ScheduleEntry; score: number }> = [];

  for (const entry of entries) {
    const variants = scheduleRowNameVariants(entry.raceName);
    const rowText = variants.join(" ");
    const rowWomen = containsWomenMarker(rowText);
    if (womenRace && !rowWomen) continue;
    if (menRace && rowWomen) continue;

    if (!stageRace && isLikelyStageEntry(rowText)) continue;
    if (stageRace && isLikelyStageEntry(rowText) && !mentionsStageOne(rowText)) continue;

    let bestScore = 0;
    for (const variant of variants) {
      const score = scoreScheduleEntry(race, variant);
      if (score > bestScore) bestScore = score;
    }
    if (bestScore < 0.6) continue;
    candidates.push({ entry, score: bestScore });
  }

  if (!candidates.length) return null;
  candidates.sort((a, b) => b.score - a.score);
  const top = candidates[0];
  const second = candidates[1];
  if (second && top.score - second.score < 0.1 && top.entry.startTime !== second.entry.startTime) {
    return null;
  }
  return {
    startTimeLocal: top.entry.startTime,
    startTimezone: timezoneForRace(race)
  };
};

const normalizeClock = (value: string): string | null => {
  const cleaned = value.replace(".", ":").trim();
  if (!/^[0-2]?\d:[0-5]\d$/.test(cleaned)) return null;
  return cleaned.padStart(5, "0");
};

const extractClockFromText = (text: string): string | null => {
  const keywordRegex =
    /(?:start(?:\s*time)?|race\s*starts?|departure|depart(?:ure)?|roll[\s-]?out)\D{0,48}([0-2]?\d[:.][0-5]\d)/i;
  const keywordMatch = text.match(keywordRegex);
  if (keywordMatch?.[1]) {
    const normalized = normalizeClock(keywordMatch[1]);
    if (normalized) return normalized;
  }
  return null;
};

const extractClockFromIsoDateTime = (value: string): string | null => {
  const match = value.match(/T([0-2]\d:[0-5]\d)/);
  if (!match?.[1]) return null;
  return match[1];
};

const collectStructuredTimeCandidates = (value: unknown, out: string[]) => {
  if (!value) return;
  if (Array.isArray(value)) {
    for (const entry of value) collectStructuredTimeCandidates(entry, out);
    return;
  }
  if (typeof value !== "object") return;
  const obj = value as Record<string, unknown>;
  for (const key of ["startDate", "startTime"]) {
    const raw = obj[key];
    if (typeof raw === "string" && raw.trim()) {
      const fromIso = extractClockFromIsoDateTime(raw);
      if (fromIso) out.push(fromIso);
      const direct = normalizeClock(raw);
      if (direct) out.push(direct);
    }
  }
  for (const nested of Object.values(obj)) {
    collectStructuredTimeCandidates(nested, out);
  }
};

const extractClockFromStructuredData = ($: cheerio.CheerioAPI): string | null => {
  const candidates: string[] = [];
  $('script[type="application/ld+json"]').each((_, script) => {
    const payload = $(script).html();
    if (!payload?.trim()) return;
    try {
      const parsed = JSON.parse(payload);
      collectStructuredTimeCandidates(parsed, candidates);
    } catch {
      // Ignore invalid JSON-LD.
    }
  });
  const unique = Array.from(new Set(candidates));
  return unique[0] ?? null;
};

const fetchOfficialFallbackTime = async (
  race: RaceLike,
  options: ReturnType<typeof buildFetchOptions>
): Promise<StartTimeResult | null> => {
  if (!race.name || process.env.OFFICIAL_START_TIME_ENRICH === "false") return null;
  if (isStageRace(race)) return null;
  const source = OFFICIAL_FALLBACK_SOURCES.find((entry) => entry.match.test(race.name ?? ""));
  if (!source) return null;

  for (const url of source.urls) {
    try {
      const html = await fetchHtml(url, {
        ...options,
        cacheDir: ".cache/race-official-start-times",
        cacheTtlMs: Number(process.env.OFFICIAL_START_TIME_CACHE_TTL_MS ?? 1000 * 60 * 60 * 12),
        delayMs: Number(process.env.OFFICIAL_START_TIME_DELAY_MS ?? 1000),
        retries: Number(process.env.OFFICIAL_START_TIME_RETRIES ?? 1)
      });
      const $ = cheerio.load(html);
      const structured = extractClockFromStructuredData($);
      if (structured) {
        return {
          startTimeLocal: structured,
          startTimezone: source.timezone ?? timezoneForRace(race)
        };
      }

      const pageText = $("body").text().replace(/\s+/g, " ").trim();
      const textClock = extractClockFromText(pageText);
      if (textClock) {
        return {
          startTimeLocal: textClock,
          startTimezone: source.timezone ?? timezoneForRace(race)
        };
      }
    } catch {
      // Try next source URL.
    }
  }
  return null;
};

const fetchRaceStartTime = async (race: RaceLike): Promise<StartTimeResult | null> => {
  if (!race.name || !race.startDate) return null;
  const options = {
    ...buildFetchOptions(),
    cacheDir: ".cache/race-official-start-times",
    cacheTtlMs: Number(process.env.OFFICIAL_START_TIME_CACHE_TTL_MS ?? 1000 * 60 * 60 * 12),
    delayMs: Number(process.env.OFFICIAL_START_TIME_DELAY_MS ?? 1000),
    retries: Number(process.env.OFFICIAL_START_TIME_RETRIES ?? 1)
  };
  return fetchOfficialFallbackTime(race, options);
};

export const enrichRaceStartTimes = async <T extends RaceLike>(races: T[]): Promise<T[]> => {
  if (!races.length) return races;
  if (process.env.PCS_START_TIME_ENRICH === "false") return races;

  // Tier 0: trusted baseline schedule hints from curated table.
  applyBaselineTimes(races);

  const dedupe = new Map<string, T[]>();
  for (const race of races) {
    if (!race.name || !race.startDate) continue;
    const key = `${race.name}__${race.startDate}`;
    const list = dedupe.get(key) ?? [];
    list.push(race);
    dedupe.set(key, list);
  }

  let attempts = 0;
  for (const [key, grouped] of dedupe.entries()) {
    if (attempts >= MAX_LOOKUPS) break;
    const sample = grouped[0];
    if (!sample.name || !sample.startDate) continue;
    if (sample.startTimeLocal) continue;

    attempts += 1;
    const found = await fetchRaceStartTime(sample);
    if (!found) continue;

    for (const race of grouped) {
      race.startTimeLocal = found.startTimeLocal;
      race.startTimezone = found.startTimezone;
      race.startDatetimeUtc = race.startDatetimeUtc ?? null;
    }
    dedupe.set(key, grouped);
  }

  return races;
};
