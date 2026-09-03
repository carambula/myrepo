import crypto from "node:crypto";
import { query } from "./db.js";
import {
  normalizeAthlete,
  normalizeRace,
  normalizeStage,
  normalizeRaceParticipant,
  normalizeTeam
} from "./normalize.js";
import {
  sampleAthletes,
  sampleParticipants,
  sampleRaces,
  sampleTeams
} from "./sources/sample.js";
import { fetchLifetimeRaces } from "./sources/lifetime.js";
import { fetchOlympicsRaces } from "./sources/olympics.js";
import { fetchUciRaces } from "./sources/uci.js";
import { buildLifetimeGrandPrixRaces } from "./sources/lifetimeStatic.js";
import { buildUciManualRaces } from "./sources/uciManual.js";
import { fetchHtmlParticipants, fetchHtmlRaces, fetchHtmlRosters } from "./sources/html.js";
import { fetchUciRosters } from "./sources/uciRosters.js";
import { enrichRaceStartTimes } from "./sources/raceStartTimes.js";
import { inferColloquialCategories } from "./sources/colloquialCategories.js";
import { mergeManualRaceStageData } from "./sources/raceStageTypes.js";
import { athleteSchema, raceSchema, stageSchema, teamSchema } from "./validate.js";

/** Deterministic artwork URL per race; prefers location for seed when available. */
const getArtworkUrl = (race: {
  name: string | null;
  startDate: string | null;
  discipline: string | null;
  locationCountry?: string | null;
  locationCity?: string | null;
}): string => {
  const loc = [race.locationCity, race.locationCountry].filter(Boolean).join("|");
  const seedStr = loc ? loc : `${race.name}|${race.startDate}|${race.discipline}`;
  const seed = crypto.createHash("md5").update(seedStr).digest("hex").slice(0, 12);
  return `https://picsum.photos/seed/${seed}/800/400`;
};

const validateWithAi = async <T>(items: T[]): Promise<T[]> => {
  if (!process.env.OPENAI_API_KEY) {
    return items;
  }

  // Placeholder for GPT validation. For now, we keep data as-is.
  return items;
};

const upsertTeam = async (team: ReturnType<typeof normalizeTeam>) => {
  const result = await query(
    `
    INSERT INTO teams (name, uci_code, discipline, region, website, social_handles, logo_url)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    ON CONFLICT (name, uci_code)
    DO UPDATE SET
      discipline = EXCLUDED.discipline,
      region = EXCLUDED.region,
      website = EXCLUDED.website,
      social_handles = EXCLUDED.social_handles,
      logo_url = EXCLUDED.logo_url
    RETURNING team_id, name
    `,
    [
      team.name,
      team.uciCode,
      team.discipline,
      team.region,
      team.website,
      team.socialHandles,
      team.logoUrl
    ]
  );
  return result.rows[0] as { team_id: string; name: string };
};

const upsertRace = async (race: ReturnType<typeof normalizeRace> & { imageUrl?: string | null }) => {
  const imageUrl = race.imageUrl ?? getArtworkUrl(race);
  const colloquialCategories = race.colloquialCategories ?? [];
  const result = await query(
    `
    INSERT INTO races (
      name, series, classification, discipline, race_type,
      start_date, end_date, start_time_local, start_timezone, start_datetime_utc,
      location_country, location_city, organizer, official_website, gender_division, image_url, colloquial_categories
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
    ON CONFLICT (name, start_date, discipline)
    DO UPDATE SET
      series = EXCLUDED.series,
      classification = EXCLUDED.classification,
      race_type = EXCLUDED.race_type,
      end_date = EXCLUDED.end_date,
      start_time_local = EXCLUDED.start_time_local,
      start_timezone = EXCLUDED.start_timezone,
      start_datetime_utc = EXCLUDED.start_datetime_utc,
      location_country = EXCLUDED.location_country,
      location_city = EXCLUDED.location_city,
      organizer = EXCLUDED.organizer,
      official_website = EXCLUDED.official_website,
      colloquial_categories = EXCLUDED.colloquial_categories,
      image_url = EXCLUDED.image_url,
      data_timestamp = NOW()
    RETURNING race_id, name, start_date
    `,
    [
      race.name,
      race.series,
      race.classification,
      race.discipline,
      race.raceType,
      race.startDate,
      race.endDate,
      race.startTimeLocal,
      race.startTimezone,
      race.startDatetimeUtc,
      race.locationCountry,
      race.locationCity,
      race.organizer,
      race.officialWebsite,
      race.genderDivision,
      imageUrl,
      colloquialCategories
    ]
  );
  return result.rows[0] as { race_id: string; name: string; start_date: string };
};

const upsertAthlete = async (
  athlete: ReturnType<typeof normalizeAthlete>,
  teamIdByName: Map<string, string>
) => {
  const teamId = athlete.teamName ? teamIdByName.get(athlete.teamName) ?? null : null;
  const result = await query(
    `
    INSERT INTO athletes (
      full_name, team_id, nationality, discipline, dob, social_handles
    )
    VALUES ($1, $2, $3, $4, $5, $6)
    ON CONFLICT (full_name, dob)
    DO UPDATE SET
      team_id = EXCLUDED.team_id,
      nationality = EXCLUDED.nationality,
      discipline = EXCLUDED.discipline,
      social_handles = EXCLUDED.social_handles
    RETURNING athlete_id, full_name
    `,
    [
      athlete.fullName,
      teamId,
      athlete.nationality,
      athlete.discipline,
      athlete.dob,
      athlete.socialHandles
    ]
  );
  return result.rows[0] as { athlete_id: string; full_name: string };
};

const buildFallbackStageId = (stage: ReturnType<typeof normalizeStage>) => {
  const stageNumber = stage.stageNumber ?? "x";
  const stageDate = stage.date ?? "x";
  const restDay = stage.isRestDay ? "rest" : "race";
  return `${stageNumber}|${stageDate}|${restDay}|${stage.name}`;
};

const upsertStage = async (
  stage: ReturnType<typeof normalizeStage>,
  raceIdByKey: Map<string, string>
) => {
  if (!stage.raceName || !stage.raceStartDate || !stage.name) {
    return;
  }
  const raceKey = `${stage.raceName}__${stage.raceStartDate}`;
  const raceId = raceIdByKey.get(raceKey);
  if (!raceId) {
    return;
  }

  const sourceStageId = stage.sourceStageId ?? buildFallbackStageId(stage);
  await query(
    `
    INSERT INTO race_stages (
      race_id, source_stage_id, stage_number, stage_type, name, date,
      start_location, end_location, distance_km, depart_time_local,
      depart_timezone, depart_datetime_utc, is_rest_day, source_url
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
    ON CONFLICT (race_id, source_stage_id)
    DO UPDATE SET
      stage_number = EXCLUDED.stage_number,
      stage_type = EXCLUDED.stage_type,
      name = EXCLUDED.name,
      date = EXCLUDED.date,
      start_location = EXCLUDED.start_location,
      end_location = EXCLUDED.end_location,
      distance_km = EXCLUDED.distance_km,
      depart_time_local = EXCLUDED.depart_time_local,
      depart_timezone = EXCLUDED.depart_timezone,
      depart_datetime_utc = EXCLUDED.depart_datetime_utc,
      is_rest_day = EXCLUDED.is_rest_day,
      source_url = EXCLUDED.source_url,
      updated_at = NOW()
    `,
    [
      raceId,
      sourceStageId,
      stage.stageNumber,
      stage.stageType,
      stage.name,
      stage.date,
      stage.startLocation,
      stage.endLocation,
      stage.distanceKm,
      stage.departTimeLocal,
      stage.departTimezone,
      stage.departDatetimeUtc,
      stage.isRestDay,
      stage.sourceUrl
    ]
  );
};

const upsertParticipant = async (
  participant: ReturnType<typeof normalizeRaceParticipant>,
  raceIdByKey: Map<string, string>,
  athleteIdByName: Map<string, string>,
  teamIdByName: Map<string, string>
) => {
  if (!participant.raceName || !participant.raceStartDate || !participant.athleteName) {
    return;
  }
  const raceKey = `${participant.raceName}__${participant.raceStartDate}`;
  const raceId = raceIdByKey.get(raceKey);
  const athleteId = athleteIdByName.get(participant.athleteName);
  const teamId = participant.teamName ? teamIdByName.get(participant.teamName) ?? null : null;

  if (!raceId || !athleteId) {
    return;
  }

  await query(
    `
    INSERT INTO race_participants (race_id, athlete_id, team_id, role)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (race_id, athlete_id)
    DO UPDATE SET
      team_id = EXCLUDED.team_id,
      role = EXCLUDED.role
    `,
    [raceId, athleteId, teamId, participant.role]
  );
};

export const runIngestion = async () => {
  const safeFetch = async <T>(label: string, fn: () => Promise<T>, fallback: T) => {
    try {
      return await fn();
    } catch (error) {
      console.warn(`Fetch failed: ${label}`, error);
      return fallback;
    }
  };

  const [
    uciRaces,
    olympicsRaces,
    lifetimeRaces,
    htmlRaces,
    htmlRosters,
    htmlParticipants,
    roadRosters,
    cxRosters,
    mtbRosters
  ] = await Promise.all([
    safeFetch("uciRaces", () => fetchUciRaces(), []),
    safeFetch("olympicsRaces", () => fetchOlympicsRaces(), []),
    safeFetch("lifetimeRaces", () => fetchLifetimeRaces(), []),
    safeFetch("htmlRaces", () => fetchHtmlRaces(), []),
    safeFetch("htmlRosters", () => fetchHtmlRosters(), { teams: [], athletes: [] }),
    safeFetch("htmlParticipants", () => fetchHtmlParticipants(), []),
    safeFetch(
      "uciRoadRosters",
      () => fetchUciRosters(process.env.UCI_ROAD_RIDERS_URL, "Road"),
      { teams: [], athletes: [] }
    ),
    safeFetch(
      "uciCxRosters",
      () => fetchUciRosters(process.env.UCI_CX_RIDERS_URL, "Cyclo-cross"),
      { teams: [], athletes: [] }
    ),
    safeFetch(
      "uciMtbRosters",
      () => fetchUciRosters(process.env.UCI_MTB_RIDERS_URL, "Mountain Bike"),
      { teams: [], athletes: [] }
    )
  ]);

  const raceSources = [...uciRaces, ...olympicsRaces, ...lifetimeRaces, ...htmlRaces];
  const seasonYear = Number(process.env.UCI_SEASON_YEAR ?? new Date().getUTCFullYear());
  const normalizedSeasonYear = Number.isFinite(seasonYear) ? seasonYear : new Date().getUTCFullYear();
  const manual = buildUciManualRaces(normalizedSeasonYear);
  const manualPrevious = buildUciManualRaces(normalizedSeasonYear - 1);
  const lifetimeGrandPrixRaces = buildLifetimeGrandPrixRaces(
    normalizedSeasonYear
  );
  const staticRaces = [
    ...manual.championships,
    ...manual.men,
    ...manual.women,
    ...manualPrevious.championships,
    ...manualPrevious.men,
    ...manualPrevious.women,
    ...lifetimeGrandPrixRaces
  ];
  const baseRacesInput = raceSources.length ? [...raceSources, ...staticRaces] : [...staticRaces, ...sampleRaces];
  const racesInput = mergeManualRaceStageData(baseRacesInput);

  const rosterTeams = [
    ...htmlRosters.teams,
    ...roadRosters.teams,
    ...cxRosters.teams,
    ...mtbRosters.teams
  ];
  const rosterAthletes = [
    ...htmlRosters.athletes,
    ...roadRosters.athletes,
    ...cxRosters.athletes,
    ...mtbRosters.athletes
  ];
  const fallbackTeams = rosterTeams.length ? rosterTeams : sampleTeams;
  const fallbackAthletes = rosterAthletes.length ? rosterAthletes : sampleAthletes;

  const normalizedRaceInput = racesInput
    .map(normalizeRace)
    .map((race) => ({
      ...race,
      colloquialCategories:
        race.colloquialCategories && race.colloquialCategories.length > 0
          ? race.colloquialCategories
          : inferColloquialCategories(race.name ?? "")
    }))
    .filter((race) => raceSchema.safeParse(race).success);
  await enrichRaceStartTimes(normalizedRaceInput);
  const normalizedRaces = await validateWithAi(normalizedRaceInput);
  const normalizedTeams = await validateWithAi(
    [...sampleTeams, ...fallbackTeams]
      .map(normalizeTeam)
      .filter((team) => teamSchema.safeParse(team).success)
  );
  const normalizedAthletes = await validateWithAi(
    [...sampleAthletes, ...fallbackAthletes]
      .map(normalizeAthlete)
      .filter((athlete) => athleteSchema.safeParse(athlete).success)
  );
  const normalizedParticipants = [
    ...sampleParticipants,
    ...htmlParticipants
  ].map(normalizeRaceParticipant);
  const normalizedStages = racesInput
    .flatMap((race) => race.stages ?? [])
    .map(normalizeStage)
    .filter((stage) => stageSchema.safeParse(stage).success);

  const teamIdByName = new Map<string, string>();
  const raceIdByKey = new Map<string, string>();
  const athleteIdByName = new Map<string, string>();

  for (const team of normalizedTeams) {
    const saved = await upsertTeam(team);
    teamIdByName.set(saved.name, saved.team_id);
  }

  for (const race of normalizedRaces) {
    const saved = await upsertRace(race);
    const key = `${saved.name}__${saved.start_date}`;
    raceIdByKey.set(key, saved.race_id);
  }

  for (const stage of normalizedStages) {
    await upsertStage(stage, raceIdByKey);
  }

  const stageCountResult = await query(`SELECT COUNT(*)::int AS count FROM race_stages`);
  const stageCount = Number(stageCountResult.rows[0]?.count ?? 0);
  if (stageCount <= 0) {
    throw new Error(
      "Sanity check failed: race_stages is empty after ingestion. Aborting to prevent publishing broken stage data."
    );
  }

  for (const athlete of normalizedAthletes) {
    const saved = await upsertAthlete(athlete, teamIdByName);
    athleteIdByName.set(saved.full_name, saved.athlete_id);
  }

  for (const participant of normalizedParticipants) {
    await upsertParticipant(participant, raceIdByKey, athleteIdByName, teamIdByName);
  }
};
