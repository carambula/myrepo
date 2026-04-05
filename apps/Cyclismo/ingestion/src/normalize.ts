export type RaceInput = {
  name: string;
  series: string;
  classification?: string | null;
  colloquialCategories?: string[] | null;
  discipline: string;
  raceType: string;
  startDate: string;
  endDate: string;
  startTimeLocal?: string | null;
  startTimezone?: string | null;
  startDatetimeUtc?: string | null;
  locationCountry?: string | null;
  locationCity?: string | null;
  organizer?: string | null;
  officialWebsite?: string | null;
  genderDivision?: string | null;
  /** Optional artwork/hero image URL. If not provided, ingestion can assign a deterministic placeholder. */
  imageUrl?: string | null;
  stages?: StageInput[] | null;
};

export type StageInput = {
  raceName: string;
  raceStartDate: string;
  sourceStageId?: string | null;
  stageNumber?: number | null;
  stageType?: string | null;
  name: string;
  date?: string | null;
  startLocation?: string | null;
  endLocation?: string | null;
  distanceKm?: number | null;
  departTimeLocal?: string | null;
  departTimezone?: string | null;
  departDatetimeUtc?: string | null;
  isRestDay?: boolean | null;
  sourceUrl?: string | null;
};

export type TeamInput = {
  name: string;
  uciCode?: string | null;
  discipline: string;
  region?: string | null;
  website?: string | null;
  socialHandles?: Record<string, string> | null;
  logoUrl?: string | null;
};

export type AthleteInput = {
  fullName: string;
  teamName?: string | null;
  nationality?: string | null;
  discipline?: string | null;
  dob?: string | null;
  socialHandles?: Record<string, string> | null;
};

export type RaceParticipantInput = {
  raceName: string;
  raceStartDate: string;
  athleteName: string;
  teamName?: string | null;
  role?: string | null;
};

const normalizeNumber = (value?: number | string | null) => {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

const normalizeString = (value?: string | null) =>
  value ? value.trim().replace(/\s+/g, " ") : null;

const normalizeStringArray = (values?: string[] | null) => {
  if (!Array.isArray(values)) {
    return null;
  }
  const normalized = values
    .map((value) => normalizeString(value))
    .filter((value): value is string => typeof value === "string" && value.length > 0);
  if (!normalized.length) {
    return null;
  }
  return Array.from(new Set(normalized));
};

export const normalizeRace = (race: RaceInput) => ({
  name: normalizeString(race.name),
  series: normalizeString(race.series),
  classification: normalizeString(race.classification ?? null),
  colloquialCategories: normalizeStringArray(race.colloquialCategories ?? null),
  discipline: normalizeString(race.discipline),
  raceType: normalizeString(race.raceType),
  startDate: normalizeString(race.startDate),
  endDate: normalizeString(race.endDate),
  startTimeLocal: normalizeString(race.startTimeLocal ?? null),
  startTimezone: normalizeString(race.startTimezone ?? null),
  startDatetimeUtc: normalizeString(race.startDatetimeUtc ?? null),
  locationCountry: normalizeString(race.locationCountry ?? null),
  locationCity: normalizeString(race.locationCity ?? null),
  organizer: normalizeString(race.organizer ?? null),
  officialWebsite: normalizeString(race.officialWebsite ?? null),
  genderDivision: normalizeString(race.genderDivision ?? null),
  imageUrl: normalizeString(race.imageUrl ?? null),
  stages: race.stages ?? null
});

export const normalizeStage = (stage: StageInput) => ({
  raceName: normalizeString(stage.raceName),
  raceStartDate: normalizeString(stage.raceStartDate),
  sourceStageId: normalizeString(stage.sourceStageId ?? null),
  stageNumber: normalizeNumber(stage.stageNumber ?? null),
  stageType: normalizeString(stage.stageType ?? null),
  name: normalizeString(stage.name),
  date: normalizeString(stage.date ?? null),
  startLocation: normalizeString(stage.startLocation ?? null),
  endLocation: normalizeString(stage.endLocation ?? null),
  distanceKm: normalizeNumber(stage.distanceKm ?? null),
  departTimeLocal: normalizeString(stage.departTimeLocal ?? null),
  departTimezone: normalizeString(stage.departTimezone ?? null),
  departDatetimeUtc: normalizeString(stage.departDatetimeUtc ?? null),
  isRestDay: stage.isRestDay ?? false,
  sourceUrl: normalizeString(stage.sourceUrl ?? null)
});

export const normalizeTeam = (team: TeamInput) => ({
  name: normalizeString(team.name),
  uciCode: normalizeString(team.uciCode ?? null),
  discipline: normalizeString(team.discipline),
  region: normalizeString(team.region ?? null),
  website: normalizeString(team.website ?? null),
  socialHandles: team.socialHandles ?? null,
  logoUrl: normalizeString(team.logoUrl ?? null)
});

export const normalizeAthlete = (athlete: AthleteInput) => ({
  fullName: normalizeString(athlete.fullName),
  teamName: normalizeString(athlete.teamName ?? null),
  nationality: normalizeString(athlete.nationality ?? null),
  discipline: normalizeString(athlete.discipline ?? null),
  dob: normalizeString(athlete.dob ?? null),
  socialHandles: athlete.socialHandles ?? null
});

export const normalizeRaceParticipant = (participant: RaceParticipantInput) => ({
  raceName: normalizeString(participant.raceName),
  raceStartDate: normalizeString(participant.raceStartDate),
  athleteName: normalizeString(participant.athleteName),
  teamName: normalizeString(participant.teamName ?? null),
  role: normalizeString(participant.role ?? null)
});
