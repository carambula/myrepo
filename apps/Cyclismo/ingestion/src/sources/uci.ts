import type { RaceInput } from "../normalize.js";
import { mapRaceRecord } from "./utils.js";
import fs from "node:fs/promises";

type RawRecord = Record<string, unknown>;

const defaults = {
  series: "WorldTour",
  classification: "UCI WorldTour",
  discipline: "Road"
};

const hasStringField = (record: RawRecord, keys: string[]) =>
  keys.some((key) => typeof record[key] === "string" && String(record[key]).trim());

const hasDateField = (record: RawRecord) =>
  hasStringField(record, ["startDate", "start_date", "start", "endDate", "end_date", "end", "date"]);

const coerceRecordDates = (record: RawRecord) => {
  const updated: RawRecord = { ...record };
  const hasStart = hasStringField(updated, ["startDate", "start_date", "start"]);
  const hasEnd = hasStringField(updated, ["endDate", "end_date", "end"]);
  if (!hasStart && !hasEnd && typeof updated.date === "string") {
    updated.startDate = updated.date;
    updated.endDate = updated.date;
  }
  return updated;
};

const collectRaceRecords = (value: unknown, output: RawRecord[]) => {
  if (Array.isArray(value)) {
    for (const entry of value) {
      collectRaceRecords(entry, output);
    }
    return;
  }
  if (value && typeof value === "object") {
    const record = value as RawRecord;
    if (hasStringField(record, ["name", "race_name", "event", "eventName", "title"]) && hasDateField(record)) {
      output.push(record);
    }
    for (const key of Object.keys(record)) {
      collectRaceRecords(record[key], output);
    }
  }
};

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

const mapRecordsToRaces = (records: RawRecord[]) =>
  records
    .map((record) => mapRaceRecord(coerceRecordDates(record), defaults))
    .filter((race): race is RaceInput => race !== null);

export const fetchUciRaces = async (): Promise<RaceInput[]> => {
  const url = process.env.UCI_CALENDAR_URL;
  const htmlPath = process.env.UCI_CALENDAR_HTML_PATH;
  if (!url && !htmlPath) {
    return [];
  }

  let contentType = "";
  let text = "";
  if (htmlPath) {
    text = await fs.readFile(htmlPath, "utf8");
  } else if (url) {
    const response = await fetch(url, {
      headers: {
        accept: "application/json,text/html",
        "user-agent": "CyclismoBootstrap/1.0 (+https://github.com/)",
        "accept-language": "en-US,en;q=0.9"
      }
    });
    if (!response.ok) {
      throw new Error(`Failed to fetch ${url}`);
    }
    contentType = response.headers.get("content-type") ?? "";
    text = await response.text();
  }

  if (contentType.includes("application/json")) {
    try {
      const json = JSON.parse(text) as unknown;
      if (Array.isArray(json)) {
        return mapRecordsToRaces(json as RawRecord[]);
      }
      if (json && typeof json === "object") {
        const dataArray = (json as { data?: unknown }).data;
        if (Array.isArray(dataArray)) {
          return mapRecordsToRaces(dataArray as RawRecord[]);
        }
        const collected: RawRecord[] = [];
        collectRaceRecords(json, collected);
        return mapRecordsToRaces(collected);
      }
    } catch {
      return [];
    }
  }

  const nextData = parseNextData(text);
  if (!nextData) {
    return [];
  }

  const collected: RawRecord[] = [];
  collectRaceRecords(nextData, collected);
  return mapRecordsToRaces(collected);
};
