export type StreamerSlug = "flobikes" | "peacock" | "max";

export type RaceStreamInput = {
  raceName: string;
  startDate: string;
  endDate?: string;
  streamerSlug: StreamerSlug;
  regionCodes: string[];
  streamUrl?: string | null;
  sourceUrl: string;
  genderDivision?: string | null;
};
