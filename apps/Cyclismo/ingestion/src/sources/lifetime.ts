import type { RaceInput } from "../normalize.js";
import { fetchJsonArray, mapRaceRecord } from "./utils.js";

export const fetchLifetimeRaces = async (): Promise<RaceInput[]> => {
  const url = process.env.LIFETIME_GRAND_PRIX_URL;
  if (!url) {
    return [];
  }

  const records = await fetchJsonArray(url);
  return records
    .map((record) =>
      mapRaceRecord(record, {
        series: "Life Time Grand Prix",
        classification: "Grand Prix",
        discipline: "Gravel"
      })
    )
    .filter((race): race is RaceInput => race !== null);
};
