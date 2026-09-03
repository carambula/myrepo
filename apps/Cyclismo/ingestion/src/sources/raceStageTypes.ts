import type { RaceInput, StageInput } from "../normalize.js";

type ManualStageSeed = {
  date: string;
  stageNumber: number;
  stageType: string;
  name?: string;
  departTimeLocal?: string;
};

type ManualStageRaceSeed = {
  aliases: string[];
  startDate: string;
  timezone?: string;
  raceStartTimeLocal?: string;
  stages: ManualStageSeed[];
};

const normalizeName = (value: string) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const MANUAL_STAGE_SEEDS: ManualStageRaceSeed[] = [
  {
    aliases: ["santos tour down under", "tour down under"],
    startDate: "2026-01-20",
    timezone: "Australia/Adelaide",
    raceStartTimeLocal: "11:00",
    stages: [
      { date: "2026-01-20", stageNumber: 1, stageType: "Flat", departTimeLocal: "11:00" },
      { date: "2026-01-21", stageNumber: 2, stageType: "Rolling", departTimeLocal: "11:00" },
      { date: "2026-01-22", stageNumber: 3, stageType: "Sprint", departTimeLocal: "11:00" },
      { date: "2026-01-23", stageNumber: 4, stageType: "Hilly", departTimeLocal: "11:00" },
      { date: "2026-01-24", stageNumber: 5, stageType: "Summit finish", departTimeLocal: "11:00" },
      { date: "2026-01-25", stageNumber: 6, stageType: "Circuit", departTimeLocal: "11:00" }
    ]
  },
  {
    aliases: ["uae tour"],
    startDate: "2026-02-16",
    timezone: "Asia/Dubai",
    raceStartTimeLocal: "12:00",
    stages: [
      { date: "2026-02-16", stageNumber: 1, stageType: "Sprint", departTimeLocal: "12:00" },
      { date: "2026-02-17", stageNumber: 2, stageType: "Mountain (Jebel Jais)", departTimeLocal: "12:00" },
      { date: "2026-02-18", stageNumber: 3, stageType: "Flat", departTimeLocal: "12:00" },
      { date: "2026-02-19", stageNumber: 4, stageType: "ITT", departTimeLocal: "12:00" },
      { date: "2026-02-20", stageNumber: 5, stageType: "Sprint", departTimeLocal: "12:00" },
      { date: "2026-02-21", stageNumber: 6, stageType: "Desert sprint", departTimeLocal: "12:00" },
      { date: "2026-02-22", stageNumber: 7, stageType: "Mountain (Jebel Hafeet)", departTimeLocal: "12:00" }
    ]
  },
  {
    aliases: ["paris nice", "paris-nice"],
    startDate: "2026-03-08",
    timezone: "Europe/Paris",
    raceStartTimeLocal: "11:00",
    stages: [
      { date: "2026-03-08", stageNumber: 1, stageType: "Hilly", departTimeLocal: "11:00" },
      { date: "2026-03-09", stageNumber: 2, stageType: "Sprint", departTimeLocal: "11:00" },
      { date: "2026-03-10", stageNumber: 3, stageType: "TTT", departTimeLocal: "11:00" },
      { date: "2026-03-11", stageNumber: 4, stageType: "Medium mountain", departTimeLocal: "11:00" },
      { date: "2026-03-12", stageNumber: 5, stageType: "Rolling", departTimeLocal: "11:00" },
      { date: "2026-03-13", stageNumber: 6, stageType: "Mountain", departTimeLocal: "11:00" },
      { date: "2026-03-14", stageNumber: 7, stageType: "Summit", departTimeLocal: "11:00" },
      { date: "2026-03-15", stageNumber: 8, stageType: "Short mountain", departTimeLocal: "11:00" }
    ]
  },
  {
    aliases: ["tirreno adriatico", "tirreno-adriatico"],
    startDate: "2026-03-09",
    timezone: "Europe/Rome",
    stages: [
      { date: "2026-03-09", stageNumber: 1, stageType: "ITT" },
      { date: "2026-03-10", stageNumber: 2, stageType: "Sprint" },
      { date: "2026-03-11", stageNumber: 3, stageType: "Rolling" },
      { date: "2026-03-12", stageNumber: 4, stageType: "Mountain" },
      { date: "2026-03-13", stageNumber: 5, stageType: "Sprint" },
      { date: "2026-03-14", stageNumber: 6, stageType: "Summit" },
      { date: "2026-03-15", stageNumber: 7, stageType: "Time trial" }
    ]
  },
  {
    aliases: ["giro d'italia", "giro ditalia", "giro d italia"],
    startDate: "2026-05-08",
    timezone: "Europe/Rome",
    stages: [
      { date: "2026-05-08", stageNumber: 1, stageType: "Flat" },
      { date: "2026-05-09", stageNumber: 2, stageType: "Sprint" },
      { date: "2026-05-10", stageNumber: 3, stageType: "Rolling" },
      { date: "2026-05-11", stageNumber: 4, stageType: "ITT" },
      { date: "2026-05-12", stageNumber: 5, stageType: "Flat" },
      { date: "2026-05-13", stageNumber: 6, stageType: "Mountain" },
      { date: "2026-05-14", stageNumber: 7, stageType: "Summit" },
      { date: "2026-05-15", stageNumber: 8, stageType: "Flat" },
      { date: "2026-05-16", stageNumber: 9, stageType: "Gravel" },
      { date: "2026-05-18", stageNumber: 10, stageType: "Sprint" },
      { date: "2026-05-19", stageNumber: 11, stageType: "Mountain" },
      { date: "2026-05-20", stageNumber: 12, stageType: "Rolling" },
      { date: "2026-05-21", stageNumber: 13, stageType: "Sprint" },
      { date: "2026-05-22", stageNumber: 14, stageType: "Alpine" },
      { date: "2026-05-23", stageNumber: 15, stageType: "Mountain" },
      { date: "2026-05-25", stageNumber: 16, stageType: "ITT" },
      { date: "2026-05-26", stageNumber: 17, stageType: "Summit" },
      { date: "2026-05-27", stageNumber: 18, stageType: "Flat" },
      { date: "2026-05-28", stageNumber: 19, stageType: "Alpine" },
      { date: "2026-05-29", stageNumber: 20, stageType: "Queen stage" },
      { date: "2026-05-31", stageNumber: 21, stageType: "Sprint finale" }
    ]
  },
  {
    aliases: ["tour auvergne rhone alpes", "criterium du dauphine", "critérium du dauphiné"],
    startDate: "2026-06-07",
    timezone: "Europe/Paris",
    stages: [
      { date: "2026-06-07", stageNumber: 1, stageType: "Rolling" },
      { date: "2026-06-08", stageNumber: 2, stageType: "Sprint" },
      { date: "2026-06-09", stageNumber: 3, stageType: "ITT" },
      { date: "2026-06-10", stageNumber: 4, stageType: "Hilly" },
      { date: "2026-06-11", stageNumber: 5, stageType: "Mountain" },
      { date: "2026-06-12", stageNumber: 6, stageType: "Summit" },
      { date: "2026-06-13", stageNumber: 7, stageType: "Alpine" },
      { date: "2026-06-14", stageNumber: 8, stageType: "Summit" }
    ]
  },
  {
    aliases: ["tour de france"],
    startDate: "2026-07-04",
    timezone: "Europe/Paris",
    stages: [
      { date: "2026-07-04", stageNumber: 1, stageType: "Team TT" },
      { date: "2026-07-05", stageNumber: 2, stageType: "Hilly" },
      { date: "2026-07-06", stageNumber: 3, stageType: "Mountain" },
      { date: "2026-07-07", stageNumber: 4, stageType: "Hilly" },
      { date: "2026-07-08", stageNumber: 5, stageType: "Flat" },
      { date: "2026-07-09", stageNumber: 6, stageType: "Mountain" },
      { date: "2026-07-10", stageNumber: 7, stageType: "Sprint" },
      { date: "2026-07-11", stageNumber: 8, stageType: "Rolling" },
      { date: "2026-07-12", stageNumber: 9, stageType: "Mountain" },
      { date: "2026-07-14", stageNumber: 10, stageType: "Summit" },
      { date: "2026-07-15", stageNumber: 11, stageType: "Sprint" },
      { date: "2026-07-16", stageNumber: 12, stageType: "Alpine" },
      { date: "2026-07-17", stageNumber: 13, stageType: "ITT" },
      { date: "2026-07-18", stageNumber: 14, stageType: "Mountain" },
      { date: "2026-07-19", stageNumber: 15, stageType: "Summit" },
      { date: "2026-07-21", stageNumber: 16, stageType: "Rolling" },
      { date: "2026-07-22", stageNumber: 17, stageType: "Alpine" },
      { date: "2026-07-23", stageNumber: 18, stageType: "Mountain" },
      { date: "2026-07-24", stageNumber: 19, stageType: "Summit" },
      { date: "2026-07-25", stageNumber: 20, stageType: "TT" },
      { date: "2026-07-26", stageNumber: 21, stageType: "Champs-Elysees" }
    ]
  },
  {
    aliases: ["la vuelta ciclista a espana", "vuelta a espana", "vuelta a españa"],
    startDate: "2026-08-22",
    timezone: "Europe/Madrid",
    stages: [
      { date: "2026-08-22", stageNumber: 1, stageType: "TTT" },
      { date: "2026-08-23", stageNumber: 2, stageType: "Sprint" },
      { date: "2026-08-24", stageNumber: 3, stageType: "Rolling" },
      { date: "2026-08-25", stageNumber: 4, stageType: "Mountain" },
      { date: "2026-08-26", stageNumber: 5, stageType: "Sprint" },
      { date: "2026-08-27", stageNumber: 6, stageType: "Summit" },
      { date: "2026-08-28", stageNumber: 7, stageType: "Flat" },
      { date: "2026-08-29", stageNumber: 8, stageType: "Mountain" },
      { date: "2026-08-30", stageNumber: 9, stageType: "Summit" },
      { date: "2026-09-01", stageNumber: 10, stageType: "ITT" },
      { date: "2026-09-02", stageNumber: 11, stageType: "Rolling" },
      { date: "2026-09-03", stageNumber: 12, stageType: "Sprint" },
      { date: "2026-09-04", stageNumber: 13, stageType: "Mountain" },
      { date: "2026-09-05", stageNumber: 14, stageType: "Summit" },
      { date: "2026-09-06", stageNumber: 15, stageType: "Mountain" },
      { date: "2026-09-08", stageNumber: 16, stageType: "Sprint" },
      { date: "2026-09-09", stageNumber: 17, stageType: "Summit" },
      { date: "2026-09-10", stageNumber: 18, stageType: "Rolling" },
      { date: "2026-09-11", stageNumber: 19, stageType: "Mountain" },
      { date: "2026-09-12", stageNumber: 20, stageType: "Queen stage" },
      { date: "2026-09-13", stageNumber: 21, stageType: "Madrid finale" }
    ]
  }
];

const findManualSeed = (race: RaceInput): ManualStageRaceSeed | null => {
  const raceName = normalizeName(race.name);
  const aliasMatches = (seed: ManualStageRaceSeed) =>
    seed.aliases.some((alias) => {
      const normalizedAlias = normalizeName(alias);
      return (
        raceName === normalizedAlias ||
        raceName.includes(normalizedAlias) ||
        normalizedAlias.includes(raceName)
      );
    });

  return (
    MANUAL_STAGE_SEEDS.find((seed) => seed.startDate === race.startDate && aliasMatches(seed)) ??
    MANUAL_STAGE_SEEDS.find((seed) => aliasMatches(seed)) ??
    null
  );
};

const shiftSeedDateToRaceSeason = (
  stageDate: string,
  seedStartDate: string,
  raceStartDate: string
): string => {
  const seedStart = new Date(`${seedStartDate}T00:00:00Z`);
  const stage = new Date(`${stageDate}T00:00:00Z`);
  const raceStart = new Date(`${raceStartDate}T00:00:00Z`);
  if (Number.isNaN(seedStart.getTime()) || Number.isNaN(stage.getTime()) || Number.isNaN(raceStart.getTime())) {
    return stageDate;
  }
  const offsetDays = Math.round((stage.getTime() - seedStart.getTime()) / (24 * 60 * 60 * 1000));
  const shifted = new Date(raceStart.getTime() + offsetDays * 24 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
};

const sortStages = (stages: StageInput[]) =>
  [...stages].sort((left, right) => {
    const leftDate = left.date ?? "9999-12-31";
    const rightDate = right.date ?? "9999-12-31";
    if (leftDate !== rightDate) return leftDate.localeCompare(rightDate);
    const leftNumber = left.stageNumber ?? Number.MAX_SAFE_INTEGER;
    const rightNumber = right.stageNumber ?? Number.MAX_SAFE_INTEGER;
    if (leftNumber !== rightNumber) return leftNumber - rightNumber;
    return left.name.localeCompare(right.name);
  });

export const mergeManualRaceStageData = (races: RaceInput[]): RaceInput[] =>
  races.map((race) => {
    const seed = findManualSeed(race);
    if (!seed) return race;

    const existingStages = [...(race.stages ?? [])];
    const mergedStages = [...existingStages];

    for (const stageSeed of seed.stages) {
      const index = mergedStages.findIndex(
        (stage) =>
          (stage.date && stage.date === stageSeed.date) ||
          (stage.stageNumber && stage.stageNumber === stageSeed.stageNumber)
      );
      const fallbackName = `Stage ${stageSeed.stageNumber}`;
      const stageBase: StageInput = {
        raceName: race.name,
        raceStartDate: race.startDate,
        sourceStageId: `manual-${stageSeed.stageNumber}-${stageSeed.date}`,
        stageNumber: stageSeed.stageNumber,
        stageType: stageSeed.stageType,
        name: stageSeed.name ?? fallbackName,
        date: shiftSeedDateToRaceSeason(stageSeed.date, seed.startDate, race.startDate),
        startLocation: null,
        endLocation: null,
        distanceKm: null,
        departTimeLocal: stageSeed.departTimeLocal ?? null,
        departTimezone: seed.timezone ?? null,
        departDatetimeUtc: null,
        isRestDay: false,
        sourceUrl: "manual:2026-race-schedule"
      };

      if (index < 0) {
        mergedStages.push(stageBase);
        continue;
      }

      const current = mergedStages[index];
      mergedStages[index] = {
        ...current,
        stageNumber: current.stageNumber ?? stageBase.stageNumber,
        stageType: stageBase.stageType ?? current.stageType,
        name: current.name?.trim() ? current.name : stageBase.name,
        date: current.date ?? stageBase.date,
        departTimeLocal: current.departTimeLocal ?? stageBase.departTimeLocal,
        departTimezone: current.departTimezone ?? stageBase.departTimezone,
        sourceStageId: current.sourceStageId ?? stageBase.sourceStageId,
        sourceUrl: current.sourceUrl ?? stageBase.sourceUrl
      };
    }

    return {
      ...race,
      startTimeLocal: race.startTimeLocal ?? seed.raceStartTimeLocal ?? null,
      startTimezone: race.startTimezone ?? seed.timezone ?? null,
      stages: sortStages(mergedStages)
    };
  });
