import * as cheerio from "cheerio";
import type {
  AthleteInput,
  RaceInput,
  RaceParticipantInput,
  TeamInput
} from "../normalize.js";

type HtmlField = {
  selector: string;
  attr?: string;
};

type HtmlRaceSource = {
  url: string;
  rowSelector: string;
  defaults?: Partial<RaceInput>;
  fields: {
    name: HtmlField;
    startDate: HtmlField;
    endDate?: HtmlField;
    series?: HtmlField;
    classification?: HtmlField;
    discipline?: HtmlField;
    raceType?: HtmlField;
    locationCountry?: HtmlField;
    locationCity?: HtmlField;
    organizer?: HtmlField;
    officialWebsite?: HtmlField;
    genderDivision?: HtmlField;
  };
};

type HtmlRosterSource = {
  url: string;
  rowSelector: string;
  defaults?: Partial<AthleteInput> & { teamName?: string; discipline?: string };
  fields: {
    athleteName: HtmlField;
    teamName?: HtmlField;
    nationality?: HtmlField;
    discipline?: HtmlField;
    dob?: HtmlField;
  };
};

type HtmlParticipantSource = {
  url: string;
  rowSelector: string;
  defaults?: Partial<RaceParticipantInput>;
  fields: {
    raceName: HtmlField;
    raceStartDate: HtmlField;
    athleteName: HtmlField;
    teamName?: HtmlField;
    role?: HtmlField;
  };
};

const fetchHtml = async (url: string) => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}`);
  }
  return response.text();
};

const extractValue = ($: cheerio.CheerioAPI, row: cheerio.Element, field?: HtmlField) => {
  if (!field) {
    return undefined;
  }
  const node = $(row).find(field.selector).first();
  if (!node.length) {
    return undefined;
  }
  if (field.attr) {
    const attr = node.attr(field.attr);
    return attr?.trim() || undefined;
  }
  return node.text().trim() || undefined;
};

const parseHtmlConfig = <T>(envKey: string): T[] => {
  const raw = process.env[envKey];
  if (!raw) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as T[]) : [];
  } catch (error) {
    console.warn(`Invalid JSON for ${envKey}:`, error);
    return [];
  }
};

export const fetchHtmlRaces = async (): Promise<RaceInput[]> => {
  const sources = parseHtmlConfig<HtmlRaceSource>("HTML_RACE_SOURCES_JSON");
  if (!sources.length) {
    return [];
  }

  const output: RaceInput[] = [];

  for (const source of sources) {
    const html = await fetchHtml(source.url);
    const $ = cheerio.load(html);
    $(source.rowSelector).each((_, row) => {
      const name = extractValue($, row, source.fields.name);
      const startDate = extractValue($, row, source.fields.startDate);
      const endDate = extractValue($, row, source.fields.endDate) ?? startDate;
      if (!name || !startDate || !endDate) {
        return;
      }

      output.push({
        name,
        series: extractValue($, row, source.fields.series) ?? source.defaults?.series ?? "Unknown",
        classification:
          extractValue($, row, source.fields.classification) ?? source.defaults?.classification ?? null,
        discipline: extractValue($, row, source.fields.discipline) ?? source.defaults?.discipline ?? "Road",
        raceType: extractValue($, row, source.fields.raceType) ?? source.defaults?.raceType ?? "Stage race",
        startDate,
        endDate,
        locationCountry:
          extractValue($, row, source.fields.locationCountry) ?? source.defaults?.locationCountry ?? null,
        locationCity:
          extractValue($, row, source.fields.locationCity) ?? source.defaults?.locationCity ?? null,
        organizer: extractValue($, row, source.fields.organizer) ?? source.defaults?.organizer ?? null,
        officialWebsite:
          extractValue($, row, source.fields.officialWebsite) ?? source.defaults?.officialWebsite ?? null,
        genderDivision:
          extractValue($, row, source.fields.genderDivision) ?? source.defaults?.genderDivision ?? null
      });
    });
  }

  return output;
};

export const fetchHtmlRosters = async (): Promise<{
  athletes: AthleteInput[];
  teams: TeamInput[];
}> => {
  const sources = parseHtmlConfig<HtmlRosterSource>("HTML_ROSTER_SOURCES_JSON");
  if (!sources.length) {
    return { athletes: [], teams: [] };
  }

  const athletes: AthleteInput[] = [];
  const teams = new Map<string, TeamInput>();

  for (const source of sources) {
    const html = await fetchHtml(source.url);
    const $ = cheerio.load(html);
    $(source.rowSelector).each((_, row) => {
      const fullName = extractValue($, row, source.fields.athleteName);
      if (!fullName) {
        return;
      }

      const teamName =
        extractValue($, row, source.fields.teamName) ??
        source.defaults?.teamName ??
        undefined;

      const discipline =
        extractValue($, row, source.fields.discipline) ??
        source.defaults?.discipline ??
        "Road";

      athletes.push({
        fullName,
        teamName: teamName ?? null,
        nationality: extractValue($, row, source.fields.nationality) ?? source.defaults?.nationality ?? null,
        discipline,
        dob: extractValue($, row, source.fields.dob) ?? source.defaults?.dob ?? null,
        socialHandles: null
      });

      if (teamName && !teams.has(teamName)) {
        teams.set(teamName, {
          name: teamName,
          discipline,
          region: null,
          website: null,
          uciCode: null,
          socialHandles: null,
          logoUrl: null
        });
      }
    });
  }

  return { athletes, teams: Array.from(teams.values()) };
};

export const fetchHtmlParticipants = async (): Promise<RaceParticipantInput[]> => {
  const sources = parseHtmlConfig<HtmlParticipantSource>("HTML_PARTICIPANT_SOURCES_JSON");
  if (!sources.length) {
    return [];
  }

  const output: RaceParticipantInput[] = [];

  for (const source of sources) {
    const html = await fetchHtml(source.url);
    const $ = cheerio.load(html);
    $(source.rowSelector).each((_, row) => {
      const raceName = extractValue($, row, source.fields.raceName) ?? source.defaults?.raceName;
      const raceStartDate =
        extractValue($, row, source.fields.raceStartDate) ?? source.defaults?.raceStartDate;
      const athleteName =
        extractValue($, row, source.fields.athleteName) ?? source.defaults?.athleteName;

      if (!raceName || !raceStartDate || !athleteName) {
        return;
      }

      output.push({
        raceName,
        raceStartDate,
        athleteName,
        teamName: extractValue($, row, source.fields.teamName) ?? source.defaults?.teamName ?? null,
        role: extractValue($, row, source.fields.role) ?? source.defaults?.role ?? null
      });
    });
  }

  return output;
};
