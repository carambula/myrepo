import path from "node:path";
import { fileURLToPath } from "node:url";
import { query, closePool } from "./db.js";

const __filename = fileURLToPath(import.meta.url);
import {
  fetchFloBikesStreams,
  fetchMaxStreams,
  fetchPeacockStreams,
  type RaceStreamInput
} from "./sources/streaming/index.js";
import { normalizeRaceTitleForStreamingFallback } from "./streamingFallbackNormalize.js";

type RaceRow = {
  race_id: string;
  name: string;
  start_date: string;
  end_date: string | null;
  gender_division: string | null;
};
type StreamerRow = { streamer_id: string; slug: string };
type FallbackRule = { namePattern: RegExp; streamer: "flobikes" | "peacock" | "max"; regions: string[] };

/** Patterns use spaces (not hyphens); race names are normalized before test. */
const fallbackRaceStreamRules: FallbackRule[] = [
  { namePattern: /tour de france/i, streamer: "peacock", regions: ["US"] },
  { namePattern: /vuelta a espana|vuelta espana/i, streamer: "peacock", regions: ["US"] },
  {
    namePattern:
      /paris nice|criterium du dauphine|dauphine|paris roubaix|volta\s+ciclista\s+a\s+catalunya|volta\s+a\s+catalunya|volta catalunya/i,
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

const normalizeForMatch = (s: string): string => normalizeRaceTitleForStreamingFallback(s);

const datesOverlap = (
  raceStart: string,
  raceEnd: string,
  streamStart: string,
  streamEnd: string
): boolean => {
  const rS = new Date(raceStart).getTime();
  const rE = new Date(raceEnd || raceStart).getTime();
  const sS = new Date(streamStart).getTime();
  const sE = new Date(streamEnd || streamStart).getTime();
  return rS <= sE && sS <= rE;
};

const findMatchingRace = (
  stream: RaceStreamInput,
  races: RaceRow[]
): RaceRow | null => {
  const streamNorm = normalizeForMatch(stream.raceName);
  const streamEnd = stream.endDate ?? stream.startDate;

  for (const race of races) {
    const raceNorm = normalizeForMatch(race.name);
    const matches =
      raceNorm === streamNorm ||
      streamNorm.includes(raceNorm) ||
      raceNorm.includes(streamNorm) ||
      raceNorm.replace(/\s+/g, "").includes(streamNorm.replace(/\s+/g, "")) ||
      streamNorm.replace(/\s+/g, "").includes(raceNorm.replace(/\s+/g, ""));

    if (!matches) continue;

    const genderMatch =
      !stream.genderDivision ||
      !race.gender_division ||
      stream.genderDivision === race.gender_division;

    if (!genderMatch) continue;

    if (datesOverlap(race.start_date, race.end_date ?? race.start_date, stream.startDate, streamEnd)) {
      return race;
    }
  }

  return null;
};

const upsertRaceStream = async (
  raceId: string,
  streamerId: string,
  regionCodes: string[],
  streamUrl: string | null,
  sourceUrl: string
) => {
  await query(
    `
    INSERT INTO race_streams (race_id, streamer_id, region_codes, stream_url, source_url)
    VALUES ($1, $2, $3, $4, $5)
    ON CONFLICT (race_id, streamer_id)
    DO UPDATE SET
      region_codes = EXCLUDED.region_codes,
      stream_url = EXCLUDED.stream_url,
      source_url = EXCLUDED.source_url,
      scraped_at = NOW()
    `,
    [raceId, streamerId, regionCodes, streamUrl, sourceUrl]
  );
};

const insertFallbackRaceStream = async (
  raceId: string,
  streamerId: string,
  regionCodes: string[]
) => {
  await query(
    `
    INSERT INTO race_streams (race_id, streamer_id, region_codes, stream_url, source_url)
    VALUES ($1, $2, $3, NULL, $4)
    ON CONFLICT (race_id, streamer_id)
    DO NOTHING
    `,
    [raceId, streamerId, regionCodes, "https://cyclismo.app"]
  );
};

const seedFallbackRaceStreams = async (
  races: RaceRow[],
  streamerBySlug: Map<string, string>
): Promise<number> => {
  let inserted = 0;
  for (const race of races) {
    for (const rule of fallbackRaceStreamRules) {
      if (!rule.namePattern.test(normalizeRaceTitleForStreamingFallback(race.name))) continue;
      const streamerId = streamerBySlug.get(rule.streamer);
      if (!streamerId) continue;
      await insertFallbackRaceStream(race.race_id, streamerId, rule.regions);
      inserted += 1;
    }
  }
  return inserted;
};

export const runStreamingIngestion = async () => {
  const safeFetch = async <T>(label: string, fn: () => Promise<T>, fallback: T): Promise<T> => {
    try {
      return await fn();
    } catch (error) {
      console.warn(`Streaming fetch failed: ${label}`, error);
      return fallback;
    }
  };

  const [floBikesStreams, maxStreams, peacockStreams] = await Promise.all([
    safeFetch("FloBikes", () => fetchFloBikesStreams(), []),
    safeFetch("Max", () => fetchMaxStreams(), []),
    safeFetch("Peacock", () => fetchPeacockStreams(), [])
  ]);

  const allStreams: RaceStreamInput[] = [
    ...floBikesStreams,
    ...maxStreams,
    ...peacockStreams
  ];

  const racesResult = await query(
    `SELECT race_id, name, start_date, end_date, gender_division FROM races ORDER BY start_date DESC`
  );
  const races = racesResult.rows as RaceRow[];

  const streamersResult = await query(
    `SELECT streamer_id, slug FROM streamers WHERE slug IN ('flobikes','peacock','max')`
  );
  const streamerBySlug = new Map<string, string>();
  for (const row of streamersResult.rows as StreamerRow[]) {
    streamerBySlug.set(row.slug, row.streamer_id);
  }

  if (allStreams.length === 0) {
    const seeded = await seedFallbackRaceStreams(races, streamerBySlug);
    console.log(`No streaming data scraped; seeded ${seeded} fallback race-stream links`);
    return;
  }

  let matched = 0;
  let skipped = 0;

  for (const stream of allStreams) {
    const streamerId = streamerBySlug.get(stream.streamerSlug);
    if (!streamerId) continue;

    const race = findMatchingRace(stream, races);
    if (!race) {
      skipped += 1;
      continue;
    }

    await upsertRaceStream(
      race.race_id,
      streamerId,
      stream.regionCodes,
      stream.streamUrl ?? null,
      stream.sourceUrl
    );
    matched += 1;
  }

  const fallbackSeeded = await seedFallbackRaceStreams(races, streamerBySlug);
  console.log(
    `Streaming ingestion: ${matched} race-stream links saved, ${skipped} unmatched (no DB race), ${fallbackSeeded} fallback links seeded, ${allStreams.length} total scraped`
  );
};

const isCli = path.resolve(process.argv[1] ?? "") === __filename;
if (isCli) {
  runStreamingIngestion()
    .catch((error) => {
      console.error("Streaming ingestion failed:", error);
      process.exitCode = 1;
    })
    .finally(async () => {
      await closePool();
    });
}
