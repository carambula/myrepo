import type { RaceInput } from "../normalize.js";
import { fetchJsonArray, mapRaceRecord } from "./utils.js";

export const fetchOlympicsRaces = async (): Promise<RaceInput[]> => {
  const url = process.env.OLYMPICS_CYCLING_URL;
  if (!url) {
    return [];
  }

  const records = await fetchJsonArray(url);
  return records
    .map((record) =>
      mapRaceRecord(record, {
        series: "Olympics",
        classification: "Olympics",
        discipline: "Road"
      })
    )
    .filter((race): race is RaceInput => race !== null);
};
