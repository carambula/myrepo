import type { AthleteInput, TeamInput } from "../normalize.js";

type RawRecord = Record<string, unknown>;

const parseNextData = (html: string): unknown | null => {
  const nextDataMatch = html.match(/<script[^>]*id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/i);
  if (nextDataMatch?.[1]) {
    try {
      return JSON.parse(nextDataMatch[1]);
    } catch {
      return null;
    }
  }

  const inlineMatch = html.match(/__NEXT_DATA__\s*=\s*({[\s\S]*?});/);
  if (inlineMatch?.[1]) {
    try {
      return JSON.parse(inlineMatch[1]);
    } catch {
      return null;
    }
  }

  return null;
};

const toStringValue = (value: unknown) =>
  typeof value === "string" && value.trim() ? value.trim() : undefined;

const getString = (record: RawRecord, keys: string[]) => {
  for (const key of keys) {
    const value = toStringValue(record[key]);
    if (value) {
      return value;
    }
  }
  return undefined;
};

const collectArraysByKey = (value: unknown, output: Array<{ key: string; items: unknown[] }>) => {
  if (Array.isArray(value)) {
    return;
  }
  if (value && typeof value === "object") {
    const record = value as RawRecord;
    for (const [key, child] of Object.entries(record)) {
      if (Array.isArray(child)) {
        output.push({ key, items: child });
      } else {
        collectArraysByKey(child, output);
      }
    }
  }
};

const extractTeamName = (record: RawRecord) => {
  const teamName = getString(record, ["teamName", "team", "team_name", "teamTitle", "name"]);
  if (teamName) {
    return teamName;
  }
  const teamObj = record.team;
  if (teamObj && typeof teamObj === "object") {
    return getString(teamObj as RawRecord, ["name", "teamName"]);
  }
  return undefined;
};

const isLikelyAthlete = (record: RawRecord) => {
  const hasName =
    !!getString(record, ["fullName", "full_name", "name"]) ||
    (!!getString(record, ["firstName", "first_name"]) && !!getString(record, ["lastName", "last_name"]));
  const hasTeamOrNation =
    !!extractTeamName(record) || !!getString(record, ["nationality", "country", "nation"]);
  return hasName && hasTeamOrNation;
};

const isLikelyTeam = (record: RawRecord) => {
  const name = getString(record, ["teamName", "name", "team"]);
  const hasCode = !!getString(record, ["uciCode", "uci_code", "teamCode", "code"]);
  const hasRoster = Array.isArray(record.riders) || Array.isArray(record.athletes);
  return !!name && (hasCode || hasRoster);
};

const mapAthlete = (record: RawRecord, discipline: string): AthleteInput => {
  const firstName = getString(record, ["firstName", "first_name"]);
  const lastName = getString(record, ["lastName", "last_name"]);
  const fullName =
    getString(record, ["fullName", "full_name", "name"]) ?? [firstName, lastName].filter(Boolean).join(" ");

  return {
    fullName: fullName || "Unknown",
    teamName: extractTeamName(record) ?? null,
    nationality: getString(record, ["nationality", "country", "nation"]) ?? null,
    discipline,
    dob: getString(record, ["dob", "dateOfBirth", "birthDate"]) ?? null,
    socialHandles: null
  };
};

const mapTeam = (record: RawRecord, discipline: string): TeamInput => ({
  name: getString(record, ["teamName", "name", "team"]) ?? "Unknown",
  uciCode: getString(record, ["uciCode", "uci_code", "teamCode", "code"]) ?? null,
  discipline,
  region: getString(record, ["region", "country"]) ?? null,
  website: getString(record, ["website", "url"]) ?? null,
  socialHandles: null,
  logoUrl: getString(record, ["logo", "logoUrl", "logo_url"]) ?? null
});

export const fetchUciRosters = async (
  url: string | undefined,
  discipline: string
): Promise<{ athletes: AthleteInput[]; teams: TeamInput[] }> => {
  if (!url) {
    return { athletes: [], teams: [] };
  }

  const response = await fetch(url, { headers: { accept: "text/html" } });
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}`);
  }

  const html = await response.text();
  const nextData = parseNextData(html);
  if (!nextData) {
    return { athletes: [], teams: [] };
  }

  const arrays: Array<{ key: string; items: unknown[] }> = [];
  collectArraysByKey(nextData, arrays);

  const athletes: AthleteInput[] = [];
  const teams: TeamInput[] = [];

  for (const { key, items } of arrays) {
    if (!/(rider|athlete|team)/i.test(key)) {
      continue;
    }
    for (const item of items) {
      if (!item || typeof item !== "object") {
        continue;
      }
      const record = item as RawRecord;
      if (isLikelyTeam(record)) {
        teams.push(mapTeam(record, discipline));
      } else if (isLikelyAthlete(record)) {
        athletes.push(mapAthlete(record, discipline));
      }
    }
  }

  return { athletes, teams };
};
