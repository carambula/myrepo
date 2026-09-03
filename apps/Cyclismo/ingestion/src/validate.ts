import { z } from "zod";

export const raceSchema = z.object({
  name: z.string().min(1),
  series: z.string().min(1),
  classification: z.string().nullable().optional(),
  colloquialCategories: z.array(z.string().min(1)).nullable().optional(),
  discipline: z.string().min(1),
  raceType: z.string().min(1),
  startDate: z.string().min(4),
  endDate: z.string().min(4),
  startTimeLocal: z.string().nullable().optional(),
  startTimezone: z.string().nullable().optional(),
  startDatetimeUtc: z.string().datetime().nullable().optional(),
  locationCountry: z.string().nullable().optional(),
  locationCity: z.string().nullable().optional(),
  organizer: z.string().nullable().optional(),
  officialWebsite: z.string().url().nullable().optional(),
  genderDivision: z.string().nullable().optional(),
  imageUrl: z.string().url().nullable().optional(),
  stages: z.array(z.unknown()).nullable().optional()
});

export const stageSchema = z.object({
  raceName: z.string().min(1),
  raceStartDate: z.string().min(4),
  sourceStageId: z.string().nullable().optional(),
  stageNumber: z.number().int().positive().nullable().optional(),
  stageType: z.string().nullable().optional(),
  name: z.string().min(1),
  date: z.string().min(4).nullable().optional(),
  startLocation: z.string().nullable().optional(),
  endLocation: z.string().nullable().optional(),
  distanceKm: z.number().nonnegative().nullable().optional(),
  departTimeLocal: z.string().nullable().optional(),
  departTimezone: z.string().nullable().optional(),
  departDatetimeUtc: z.string().datetime().nullable().optional(),
  isRestDay: z.boolean().nullable().optional(),
  sourceUrl: z.string().min(1).nullable().optional()
});

export const teamSchema = z.object({
  name: z.string().min(1),
  uciCode: z.string().nullable().optional(),
  discipline: z.string().min(1),
  region: z.string().nullable().optional(),
  website: z.string().url().nullable().optional(),
  socialHandles: z.record(z.string(), z.string()).nullable().optional(),
  logoUrl: z.string().url().nullable().optional()
});

export const athleteSchema = z.object({
  fullName: z.string().min(1),
  teamName: z.string().nullable().optional(),
  nationality: z.string().nullable().optional(),
  discipline: z.string().nullable().optional(),
  dob: z.string().nullable().optional(),
  socialHandles: z.record(z.string(), z.string()).nullable().optional()
});
