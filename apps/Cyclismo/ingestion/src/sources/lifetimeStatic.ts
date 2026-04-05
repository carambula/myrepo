import type { RaceInput } from "../normalize.js";

type LifetimeRaceSeed = {
  name: string;
  discipline: "Gravel" | "MTB";
  monthDay: string;
  locationCity: string;
};

const lifetimeSeeds: LifetimeRaceSeed[] = [
  {
    name: "Sea Otter Gravel",
    discipline: "Gravel",
    monthDay: "04-16",
    locationCity: "Monterey, CA"
  },
  {
    name: "UNBOUND Gravel 200",
    discipline: "Gravel",
    monthDay: "05-30",
    locationCity: "Emporia, KS"
  },
  {
    name: "Leadville Trail 100 MTB",
    discipline: "MTB",
    monthDay: "08-15",
    locationCity: "Leadville, CO"
  },
  {
    name: "Chequamegon MTB Fest",
    discipline: "MTB",
    monthDay: "09-19",
    locationCity: "Cable, WI"
  },
  {
    name: "Little Sugar MTB",
    discipline: "MTB",
    monthDay: "10-11",
    locationCity: "Bentonville, AR"
  },
  {
    name: "Big Sugar Gravel",
    discipline: "Gravel",
    monthDay: "10-17",
    locationCity: "Bentonville, AR"
  }
];

export const buildLifetimeGrandPrixRaces = (year: number): RaceInput[] =>
  lifetimeSeeds.map((seed) => {
    const date = `${year}-${seed.monthDay}`;
    return {
      name: seed.name,
      series: "Life Time Grand Prix",
      classification: "Grand Prix",
      discipline: seed.discipline,
      raceType: "One-day",
      startDate: date,
      endDate: date,
      locationCountry: "USA",
      locationCity: seed.locationCity,
      organizer: "Life Time",
      officialWebsite: null,
      genderDivision: null
    };
  });
