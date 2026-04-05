import type { RaceInput, StageInput } from "../normalize.js";

type RawRecord = Record<string, unknown>;

const pickFirstString = (record: RawRecord, keys: string[]) => {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }
  return undefined;
};

const pickFirstNumber = (record: RawRecord, keys: string[]) => {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "number" && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === "string" && value.trim()) {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }
  return undefined;
};

const pickFirstBoolean = (record: RawRecord, keys: string[]) => {
  for (const key of keys) {
    const value = record[key];
    if (typeof value === "boolean") {
      return value;
    }
    if (typeof value === "string") {
      const normalized = value.trim().toLowerCase();
      if (["true", "yes", "1"].includes(normalized)) {
        return true;
      }
      if (["false", "no", "0"].includes(normalized)) {
        return false;
      }
    }
  }
  return undefined;
};

const inferStageNumber = (name?: string) => {
  if (!name) {
    return undefined;
  }
  const match = name.match(/\b(?:stage|etape|stg)\s*(\d{1,2})\b/i);
  if (!match?.[1]) {
    return undefined;
  }
  const value = Number(match[1]);
  return Number.isFinite(value) ? value : undefined;
};

const inferStageType = (name?: string) => {
  if (!name) {
    return undefined;
  }
  if (/\b(rest\s*day|jour\s+de\s+repos)\b/i.test(name)) {
    return "Rest day";
  }
  if (/\b(itt|individual time trial)\b/i.test(name)) {
    return "ITT";
  }
  if (/\b(ttt|team time trial)\b/i.test(name)) {
    return "TTT";
  }
  if (/\b(prologue)\b/i.test(name)) {
    return "Prologue";
  }
  return undefined;
};

const toRawRecord = (value: unknown): RawRecord | null =>
  value && typeof value === "object" ? (value as RawRecord) : null;

const collectStageRecords = (value: unknown, output: RawRecord[], depth = 0) => {
  if (depth > 2 || !value) {
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      const itemRecord = toRawRecord(item);
      if (itemRecord) {
        output.push(itemRecord);
      }
    }
    return;
  }
  const record = toRawRecord(value);
  if (!record) {
    return;
  }
  const stageKeys = ["stages", "stageList", "stage_list", "itinerary", "days", "etapes"];
  for (const key of stageKeys) {
    collectStageRecords(record[key], output, depth + 1);
  }
};

const buildStageInputs = (
  raceName: string,
  raceStartDate: string,
  stageRecords: RawRecord[]
): StageInput[] => {
  const stageInputs: StageInput[] = [];
  for (const stageRecord of stageRecords) {
    const name =
      pickFirstString(stageRecord, ["name", "title", "stage_name", "label"]) ??
      pickFirstString(stageRecord, ["description"]);
    const date = pickFirstString(stageRecord, ["date", "stageDate", "startDate", "start_date"]);
    const stageNumber =
      pickFirstNumber(stageRecord, ["stageNumber", "stage", "number", "stage_no"]) ??
      inferStageNumber(name);
    const stageType =
      pickFirstString(stageRecord, ["stageType", "type", "profile"]) ?? inferStageType(name);
    const isRestDay =
      pickFirstBoolean(stageRecord, ["isRestDay", "restDay", "is_rest_day", "rest"]) ??
      Boolean(name && /\b(rest\s*day|jour\s+de\s+repos)\b/i.test(name));
    if (!name && !isRestDay) {
      continue;
    }
    stageInputs.push({
      raceName,
      raceStartDate,
      sourceStageId: pickFirstString(stageRecord, ["id", "stageId", "stage_id", "uid"]),
      stageNumber,
      stageType,
      name: name ?? "Rest day",
      date,
      startLocation: pickFirstString(stageRecord, [
        "startLocation",
        "start_location",
        "startCity",
        "departure"
      ]),
      endLocation: pickFirstString(stageRecord, [
        "endLocation",
        "end_location",
        "finishCity",
        "arrival"
      ]),
      distanceKm: pickFirstNumber(stageRecord, ["distanceKm", "distance_km", "distance"]),
      departTimeLocal: pickFirstString(stageRecord, ["departTimeLocal", "startTimeLocal", "startTime"]),
      departTimezone: pickFirstString(stageRecord, ["departTimezone", "timezone", "timeZone"]),
      departDatetimeUtc: pickFirstString(stageRecord, [
        "departDatetimeUtc",
        "startDatetimeUtc",
        "start_datetime_utc"
      ]),
      isRestDay,
      sourceUrl: pickFirstString(stageRecord, ["sourceUrl", "url", "link"])
    });
  }
  return stageInputs;
};

export const mapRaceRecord = (record: RawRecord, defaults: Partial<RaceInput>): RaceInput | null => {
  const name = pickFirstString(record, ["name", "race_name", "event", "eventName", "title"]);
  const startDate = pickFirstString(record, ["startDate", "start_date", "start"]);
  const endDate = pickFirstString(record, ["endDate", "end_date", "end"]);

  if (!name || !startDate || !endDate) {
    return null;
  }

  const stageRecords: RawRecord[] = [];
  collectStageRecords(record, stageRecords);
  const stages = buildStageInputs(name, startDate, stageRecords);

  return {
    name,
    series: pickFirstString(record, ["series", "tour", "category", "classification"]) ?? defaults.series ?? "Unknown",
    classification: pickFirstString(record, ["classification", "uci_class", "level"]) ?? defaults.classification ?? null,
    discipline: pickFirstString(record, ["discipline", "type", "sport"]) ?? defaults.discipline ?? "Road",
    raceType: pickFirstString(record, ["raceType", "format", "race_type"]) ?? defaults.raceType ?? "Stage race",
    startDate,
    endDate,
    locationCountry: pickFirstString(record, ["country", "locationCountry", "nation"]),
    locationCity: pickFirstString(record, ["city", "locationCity"]),
    organizer: pickFirstString(record, ["organizer", "promoter"]),
    officialWebsite: pickFirstString(record, ["officialWebsite", "website", "url", "link"]),
    genderDivision: pickFirstString(record, ["genderDivision", "gender"]),
    stages: stages.length ? stages : undefined
  };
};

export const fetchJsonArray = async (url: string): Promise<RawRecord[]> => {
  const response = await fetch(url, { headers: { "accept": "application/json" } });
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}`);
  }
  const data = await response.json();
  if (Array.isArray(data)) {
    return data as RawRecord[];
  }
  if (Array.isArray((data as { data?: unknown }).data)) {
    return (data as { data: RawRecord[] }).data;
  }
  return [];
};
