import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { randomUUID } from "node:crypto";
import dotenv from "dotenv";
import xlsx from "xlsx";
import {
  normalizeAthlete,
  normalizeRace,
  normalizeTeam
} from "./normalize.js";
import type { RaceInput } from "./normalize.js";
import {
  sampleAthletes,
  sampleRaces,
  sampleTeams
} from "./sources/sample.js";
import { buildLifetimeGrandPrixRaces } from "./sources/lifetimeStatic.js";
import { buildUciManualRaces } from "./sources/uciManual.js";
import { enrichRacesWithWikimediaImages } from "./sources/wikimediaImages.js";
import { enrichRaceStartTimes } from "./sources/raceStartTimes.js";
import { inferColloquialCategories } from "./sources/colloquialCategories.js";
import { mergeManualRaceStageData } from "./sources/raceStageTypes.js";
import {
  getConfiguredPodcastSources,
  matchPodcastEpisodesToRaces,
  scrapePodcastEpisodes
} from "./sources/podcasts.js";
import { normalizeRaceTitleForStreamingFallback } from "./streamingFallbackNormalize.js";
type BootstrapRace = ReturnType<typeof normalizeRace> & { raceId: string };
type BootstrapTeam = ReturnType<typeof normalizeTeam> & { teamId: string };
type BootstrapAthlete = ReturnType<typeof normalizeAthlete> & {
  athleteId: string;
  teamId: string | null;
};
type BootstrapPodcastSource = {
  sourceId: string;
  slug: string;
  name: string;
  feedUrl: string;
  websiteUrl: string | null;
};
type BootstrapPodcastEpisode = {
  episodeId: string;
  sourceId: string;
  guid: string | null;
  title: string;
  rawTitle: string | null;
  description: string | null;
  episodeUrl: string | null;
  publishedAt: string | null;
};
type BootstrapRacePodcastEpisode = {
  raceId: string;
  episodeId: string;
  matchedBy: string | null;
};
type BootstrapStage = {
  stageId: string;
  raceId: string;
  sourceStageId: string | null;
  stageNumber: number | null;
  stageType: string | null;
  name: string;
  date: string | null;
  startLocation: string | null;
  endLocation: string | null;
  distanceKm: number | null;
  departTimeLocal: string | null;
  departTimezone: string | null;
  departDatetimeUtc: string | null;
  isRestDay: boolean;
  sourceUrl: string | null;
};
type BootstrapStagePodcastEpisode = {
  stageId: string;
  episodeId: string;
  matchedBy: string | null;
};
type BootstrapRaceResult = {
  raceResultId: string;
  raceId: string;
  resultType: string;
  rank: number;
  athleteName: string;
  teamName: string | null;
  nationality: string | null;
  resultText: string | null;
  source: string;
  sourceUrl: string | null;
  metadata: Record<string, unknown> | null;
  syncedAt: string;
  createdAt: string;
  updatedAt: string;
};
type BootstrapStageResult = {
  stageResultId: string;
  stageId: string;
  resultType: string;
  rank: number;
  athleteName: string;
  teamName: string | null;
  nationality: string | null;
  resultText: string | null;
  source: string;
  sourceUrl: string | null;
  metadata: Record<string, unknown> | null;
  syncedAt: string;
  createdAt: string;
  updatedAt: string;
};

const hasValue = (value: string | null | undefined) => typeof value === "string" && value.trim().length > 0;

/** Deterministic artwork URL per race; prefers location for seed when available. */
const getArtworkUrl = (race: {
  name: string;
  startDate: string;
  discipline: string;
  locationCountry?: string | null;
  locationCity?: string | null;
}) => {
  const loc = [race.locationCity, race.locationCountry].filter(Boolean).join("|");
  const seedStr = loc ? loc : `${race.name}|${race.startDate}|${race.discipline}`;
  const seed = crypto.createHash("md5").update(seedStr).digest("hex").slice(0, 12);
  return `https://picsum.photos/seed/${seed}/800/400`;
};

const toIsoDate = (value: unknown): string | null => {
  if (value instanceof Date) {
    return value.toISOString().slice(0, 10);
  }
  if (typeof value === "number") {
    const parsed = xlsx.SSF.parse_date_code(value);
    if (!parsed) return null;
    const month = String(parsed.m).padStart(2, "0");
    const day = String(parsed.d).padStart(2, "0");
    return `${parsed.y}-${month}-${day}`;
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return null;
    if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return trimmed;
    const parsed = new Date(trimmed);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString().slice(0, 10);
    }
  }
  return null;
};

const loadUciRacesFromXls = (paths: string[], seasonYear: number) => {
  const races: RaceInput[] = [];
  for (const filePath of paths) {
    const yearMatch = filePath.match(/(20\d{2})/);
    const fallbackYear = Number.isFinite(seasonYear)
      ? seasonYear
      : yearMatch
        ? Number(yearMatch[1])
        : new Date().getUTCFullYear();
    const workbook = xlsx.readFile(filePath, { cellDates: true });

    for (const sheetName of workbook.SheetNames) {
      const sheet = workbook.Sheets[sheetName];
      const rows = xlsx.utils.sheet_to_json<Array<unknown>>(sheet, { header: 1, defval: "" });
      if (!rows.length) continue;

      const headerIndex = rows.findIndex((row) =>
        row.some((cell) => String(cell).trim().toLowerCase() === "date") &&
        row.some((cell) => String(cell).trim().toLowerCase() === "race")
      );
      if (headerIndex < 0) {
        continue;
      }

      const headers = rows[headerIndex].map((cell) => String(cell).trim().toLowerCase());
      const dateIdx = headers.indexOf("date");
      const raceIdx = headers.indexOf("race");
      const classIdx = headers.indexOf("class");
      const countryIdx = headers.indexOf("country");
      const cityIdx = headers.indexOf("city");

      for (let i = headerIndex + 1; i < rows.length; i += 1) {
        const row = rows[i];
        if (!row || row.length === 0) continue;
        const dateRaw = String(row[dateIdx] ?? "").trim();
        const name = String(row[raceIdx] ?? "").trim();
        if (!dateRaw || !name) continue;

        let finalStart: string | null = null;
        let finalEnd: string | null = null;
        const parts = dateRaw.split("-").map((part) => part.trim());
        const parsePart = (part: string, defaultMonth?: string) => {
          const match = part.match(/(\d{1,2})\.(\d{1,2})/);
          if (!match) return null;
          const day = match[1].padStart(2, "0");
          const month = match[2]?.padStart(2, "0") ?? defaultMonth;
          if (!month) return null;
          return `${fallbackYear}-${month}-${day}`;
        };
        const startParsed = parsePart(parts[0]);
        const endParsed = parts.length > 1 ? parsePart(parts[1], startParsed?.slice(5, 7)) : startParsed;
        finalStart = startParsed;
        finalEnd = endParsed;

        if (!finalStart || !finalEnd) continue;

        const classification = classIdx >= 0 ? String(row[classIdx] ?? "").trim() : "";
        const genderDivision =
          /WWT/i.test(classification) || /women/i.test(sheetName) ? "Women" :
          /UWT/i.test(classification) || /men/i.test(sheetName) ? "Men" :
          null;

        const country = countryIdx >= 0 ? String(row[countryIdx] ?? "").trim() : "";
        const city = cityIdx >= 0 ? String(row[cityIdx] ?? "").trim() : "";

        races.push({
          name,
          series: "UCI",
          classification: classification || null,
          discipline: "Road",
          raceType: finalStart === finalEnd ? "One-day" : "Stage race",
          startDate: finalStart,
          endDate: finalEnd,
          locationCountry: country || null,
          locationCity: city || null,
          organizer: null,
          officialWebsite: null,
          genderDivision,
          imageUrl: null
        });
      }
    }
  }
  return races;
};

dotenv.config();

const outputPath =
  process.env.BOOTSTRAP_OUTPUT_PATH ??
  path.resolve(process.cwd(), "../Cyclismo/bootstrap_database.json");

const ensureDefaultEnv = () => {
  if (!process.env.UCI_CALENDAR_URL) {
    process.env.UCI_CALENDAR_URL = "https://www.uci.org/calendar/all/2jnxYAuvjgttyHi6YQ94EJ";
  }
  if (!process.env.UCI_ROAD_RIDERS_URL) {
    process.env.UCI_ROAD_RIDERS_URL =
      "https://www.uci.org/riders/road-riders-teams/4uEfOErsvL4hkRJriqkdiw?tab=riders-list-teams";
  }
  if (!process.env.UCI_CX_RIDERS_URL) {
    process.env.UCI_CX_RIDERS_URL =
      "https://www.uci.org/riders/cyclo-cross-riders-and-teams/3jXe3jZAo10WPTzww80yOo";
  }
  if (!process.env.UCI_MTB_RIDERS_URL) {
    process.env.UCI_MTB_RIDERS_URL =
      "https://www.uci.org/riders/mountain-bike-riders-teams/1V5hGPnEvXzbIqkjUHmFuw";
  }
  if (!process.env.UCI_XLS_PATHS) {
    process.env.UCI_XLS_PATHS = "";
  }
  if (!process.env.UCI_SEASON_YEAR) {
    process.env.UCI_SEASON_YEAR = String(new Date().getUTCFullYear());
  }
};

const generateBootstrap = async () => {
  ensureDefaultEnv();
  const seasonYear = Number(process.env.UCI_SEASON_YEAR ?? new Date().getUTCFullYear());
  const uciPaths = (process.env.UCI_XLS_PATHS ?? "").split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  const uciRaces = uciPaths.length
    ? loadUciRacesFromXls(uciPaths, seasonYear)
    : [];
  const manual = buildUciManualRaces(seasonYear);
  const manualPrevious = buildUciManualRaces(seasonYear - 1);
  const lifetimeGrandPrixRaces = buildLifetimeGrandPrixRaces(seasonYear);

  const mergedRacesInput = mergeManualRaceStageData([
    ...uciRaces,
    ...manual.championships,
    ...manual.men,
    ...manual.women,
    ...manualPrevious.championships,
    ...manualPrevious.men,
    ...manualPrevious.women,
    ...lifetimeGrandPrixRaces
  ]);
  const finalRacesInput = mergedRacesInput.length ? mergedRacesInput : sampleRaces;
  const fallbackTeams = sampleTeams;
  const fallbackAthletes = sampleAthletes;

  let races = finalRacesInput
    .map(normalizeRace)
    .map((race) => ({
      ...race,
      colloquialCategories:
        race.colloquialCategories && race.colloquialCategories.length > 0
          ? race.colloquialCategories
          : inferColloquialCategories(race.name ?? "")
    }))
    .filter((race) => hasValue(race.name) && hasValue(race.series) && hasValue(race.discipline))
    .map((race) => ({
      ...race,
      raceId: randomUUID(),
      imageUrl: race.imageUrl ?? null
    })) as BootstrapRace[];

  await enrichRaceStartTimes(races);

  if (process.env.WIKIMEDIA_ENRICH !== "false") {
    await enrichRacesWithWikimediaImages(races);
  }

  races = races.map((race) => ({
    ...race,
    imageUrl: race.imageUrl ?? getArtworkUrl(race as Parameters<typeof getArtworkUrl>[0])
  })) as BootstrapRace[];

  const teams = [...fallbackTeams]
    .map(normalizeTeam)
    .filter((team) => hasValue(team.name) && hasValue(team.discipline))
    .map((team) => ({ ...team, teamId: randomUUID() })) as BootstrapTeam[];

  const teamIdByName = new Map<string, string>();
  for (const team of teams) {
    teamIdByName.set(team.name ?? "", team.teamId);
  }

  const athletes = [...fallbackAthletes]
    .map(normalizeAthlete)
    .filter((athlete) => hasValue(athlete.fullName))
    .map((athlete) => ({
      ...athlete,
      athleteId: randomUUID(),
      teamId: athlete.teamName ? teamIdByName.get(athlete.teamName) ?? null : null
    })) as BootstrapAthlete[];

  const streamers = [
    { streamerId: "flobikes-001", name: "FloSports", slug: "flobikes", websiteUrl: "https://www.flobikes.com" },
    { streamerId: "peacock-001", name: "Peacock", slug: "peacock", websiteUrl: "https://www.peacocktv.com" },
    { streamerId: "max-001", name: "Max", slug: "max", websiteUrl: "https://www.max.com" }
  ];
  const streamerIds = { flobikes: "flobikes-001", peacock: "peacock-001", max: "max-001" };

  /** Patterns use spaces; titles are normalized (hyphens, accents, years) before test. */
  const raceStreamRules: Array<{ namePattern: RegExp; streamer: keyof typeof streamerIds; regions: string[] }> = [
    { namePattern: /tour de france/i, streamer: "peacock", regions: ["US"] },
    { namePattern: /vuelta a espana|vuelta espana/i, streamer: "peacock", regions: ["US"] },
    {
      namePattern:
        /paris nice|criterium du dauphine|paris roubaix|dauphine|volta\s+ciclista\s+a\s+catalunya|volta\s+a\s+catalunya|volta catalunya/i,
      streamer: "peacock",
      regions: ["US"]
    },
    {
      namePattern:
        /giro d'italia|milano san ?remo|milan san ?remo|sanremo donne|strade bianche|tirreno adriatico|uae tour|trofeo alfredo binda|nokere koerse|milano torino|e3 saxo|bredene koksijde|grand prix de denain|itzulia|basque country|ronde van brugge/i,
      streamer: "max",
      regions: ["US"]
    },
    { namePattern: /world championships|uci road world/i, streamer: "flobikes", regions: ["US", "CA"] },
    {
      namePattern:
        /omloop\s*(het\s*)?nieuwsblad|tour of flanders|ronde van vlaanderen|amstel gold|gent wevelgem|in flanders fields|wevelgem|dwars door vlaanderen|scheldeprijs|brabantse pijl|kuurne brussel|brussels cycling classic|deutschland tour|tour of turkey|clasica san sebastian|bretagne classic|gp de plouay|gp industria|coppa sabatini|giro della toscana|fourmies|super 8|kampioenschap van vlaanderen|wallonie|tour de luxembourg|chrono gatineau|fleche wallonne|liege bastogne liege|tour de romandie/i,
      streamer: "flobikes",
      regions: ["US", "CA"]
    }
  ];

  const raceStreams: Array<{ raceId: string; streamerId: string; regionCodes: string[]; streamUrl: string | null; sourceUrl: string | null }> = [];
  for (const race of races) {
    const name = race.name ?? "";
    const normalizedName = normalizeRaceTitleForStreamingFallback(name);
    for (const rule of raceStreamRules) {
      if (rule.namePattern.test(normalizedName)) {
        raceStreams.push({
          raceId: race.raceId,
          streamerId: streamerIds[rule.streamer],
          regionCodes: rule.regions,
          streamUrl: null,
          sourceUrl: "https://cyclismo.app"
        });
      }
    }
  }

  const podcastSources: BootstrapPodcastSource[] = [];
  const podcastEpisodes: BootstrapPodcastEpisode[] = [];
  const racePodcastEpisodes: BootstrapRacePodcastEpisode[] = [];
  const stagePodcastEpisodes: BootstrapStagePodcastEpisode[] = [];
  const raceResults: BootstrapRaceResult[] = [];
  const stageResults: BootstrapStageResult[] = [];
  const raceLookup = races.map((race) => ({
    raceId: race.raceId,
    name: race.name ?? "",
    startDate: race.startDate ?? ""
  }));
  const stages: BootstrapStage[] = races.flatMap((race) => {
    const raceName = race.name ?? "";
    const raceStartDate = race.startDate ?? "";
    const inputStages = race.stages ?? [];
    return inputStages
      .filter((stage) => stage.raceName === raceName && stage.raceStartDate === raceStartDate)
      .map((stage) => ({
        stageId: randomUUID(),
        raceId: race.raceId,
        sourceStageId:
          stage.sourceStageId ??
          `${stage.stageNumber ?? "x"}|${stage.date ?? "x"}|${stage.isRestDay ? "rest" : "race"}|${stage.name}`,
        stageNumber: stage.stageNumber ?? null,
        stageType: stage.stageType ?? null,
        name: stage.name ?? "",
        date: stage.date ?? null,
        startLocation: stage.startLocation ?? null,
        endLocation: stage.endLocation ?? null,
        distanceKm: stage.distanceKm ?? null,
        departTimeLocal: stage.departTimeLocal ?? null,
        departTimezone: stage.departTimezone ?? null,
        departDatetimeUtc: stage.departDatetimeUtc ?? null,
        isRestDay: stage.isRestDay ?? false,
        sourceUrl: stage.sourceUrl ?? null
      }));
  });
  const stageLookup = stages.map((stage) => {
    const race = races.find((item) => item.raceId === stage.raceId);
    return {
      stageId: stage.stageId,
      raceId: stage.raceId,
      raceName: race?.name ?? "",
      raceStartDate: race?.startDate ?? "",
      stageNumber: stage.stageNumber,
      name: stage.name,
      date: stage.date,
      isRestDay: stage.isRestDay,
      stageType: stage.stageType
    };
  });

  try {
    const resolvedPodcastSources = await getConfiguredPodcastSources();
    for (const source of resolvedPodcastSources) {
      const sourceId = randomUUID();
      podcastSources.push({
        sourceId,
        slug: source.slug,
        name: source.name,
        feedUrl: source.feedUrl,
        websiteUrl: source.websiteUrl
      });

      const episodes = await scrapePodcastEpisodes(source);
      const matches = matchPodcastEpisodesToRaces(source, episodes, raceLookup, stageLookup, 4);
      const matchByKey = new Map<
        string,
        Array<{ raceId: string; matchedBy: string; stageId?: string; stageMatchedBy?: string }>
      >();
      for (const match of matches) {
        const key = `${match.episode.guid ?? ""}::${match.episode.episodeUrl ?? ""}`;
        const existing = matchByKey.get(key) ?? [];
        existing.push({
          raceId: match.raceId,
          matchedBy: match.matchedBy,
          stageId: match.stageId,
          stageMatchedBy: match.stageMatchedBy
        });
        matchByKey.set(key, existing);
      }

      for (const episode of episodes) {
        const episodeId = randomUUID();
        podcastEpisodes.push({
          episodeId,
          sourceId,
          guid: episode.guid,
          title: episode.title,
          rawTitle: episode.rawTitle,
          description: episode.description,
          episodeUrl: episode.episodeUrl,
          publishedAt: episode.publishedAt
        });
        const key = `${episode.guid ?? ""}::${episode.episodeUrl ?? ""}`;
        const matchedList = matchByKey.get(key) ?? [];
        for (const matched of matchedList) {
          racePodcastEpisodes.push({
            raceId: matched.raceId,
            episodeId,
            matchedBy: matched.matchedBy
          });
          if (matched.stageId && matched.stageMatchedBy) {
            stagePodcastEpisodes.push({
              stageId: matched.stageId,
              episodeId,
              matchedBy: matched.stageMatchedBy
            });
          }
        }
      }
    }
  } catch (error) {
    console.warn("Podcast scrape skipped:", error);
  }

  const payload = {
    races,
    teams,
    athletes,
    participants: [] as Array<{
      raceId: string;
      athleteId: string;
      teamId: string | null;
      role: string | null;
    }>,
    streamers,
    raceStreams,
    podcastSources,
    podcastEpisodes,
    racePodcastEpisodes,
    stages,
    stagePodcastEpisodes,
    raceResults,
    stageResults
  };

  await fs.writeFile(outputPath, JSON.stringify(payload, null, 2), "utf8");
  console.log(`Bootstrap JSON written to ${outputPath}`);
};

generateBootstrap().catch((error) => {
  console.error("Generate bootstrap failed:", error);
  process.exitCode = 1;
});
