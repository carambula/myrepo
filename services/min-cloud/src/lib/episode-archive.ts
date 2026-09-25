export const PODCAST_ARCHIVE_CAP = 5000;

export type ArchiveEpisode = {
  id?: string | null;
  guid?: string | null;
  title?: string | null;
  audioUrl?: string | null;
  publishDate?: string | null;
};

const isUsableKey = (key: string) => Boolean(key) && key !== "g:" && key !== "a:" && key !== "t:";

export const episodeArchiveKeys = (episode: ArchiveEpisode) => {
  const guid = `g:${String(episode.guid || episode.id || "").trim().toLowerCase()}`;
  const audio = `a:${String(episode.audioUrl || "").trim().toLowerCase()}`;
  const title = `t:${String(episode.title || "").trim().toLowerCase()}`;
  const keys = [guid, audio].filter(isUsableKey);
  if (keys.length) {
    return keys;
  }
  return isUsableKey(title) ? [title] : [];
};

export const episodeArchiveKey = (episode: ArchiveEpisode) => episodeArchiveKeys(episode)[0] ?? "";

/** Postgres `Date` objects must go out as ISO-8601. `String(date)` is `Tue Mar 04 2025 …` and iOS cannot parse it. */
export const toIsoDateString = (value: unknown): string | null => {
  if (value == null || value === "") {
    return null;
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value.toISOString();
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    const fromNumber = new Date(value);
    return Number.isNaN(fromNumber.getTime()) ? null : fromNumber.toISOString();
  }
  const raw = String(value).trim();
  if (!raw) {
    return null;
  }
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? new Date(parsed).toISOString() : raw;
};

/** Union two episode lists by guid / audio URL / title. `primary` wins on duplicates unless its date is unusable. */
export const mergeEpisodeArchives = <T extends ArchiveEpisode>(primary: T[], extra: T[]): T[] => {
  const seen = new Map<string, number>();
  const merged: T[] = [];
  for (const episode of [...primary, ...extra]) {
    const keys = episodeArchiveKeys(episode);
    if (!keys.length) {
      continue;
    }
    const existingIndex = keys.map((key) => seen.get(key)).find((index) => index !== undefined);
    if (existingIndex !== undefined) {
      if (!hasUsablePublishDate(merged[existingIndex]) && hasUsablePublishDate(episode)) {
        merged[existingIndex] = episode;
      }
      continue;
    }
    const index = merged.length;
    merged.push(episode);
    for (const key of keys) {
      seen.set(key, index);
    }
  }
  merged.sort((left, right) => {
    const leftTime = Date.parse(left.publishDate || "");
    const rightTime = Date.parse(right.publishDate || "");
    const leftValid = Number.isFinite(leftTime);
    const rightValid = Number.isFinite(rightTime);
    if (leftValid && rightValid && leftTime !== rightTime) {
      return rightTime - leftTime;
    }
    if (leftValid !== rightValid) {
      return leftValid ? -1 : 1;
    }
    return String(right.title || "").localeCompare(String(left.title || ""));
  });
  return merged.slice(0, PODCAST_ARCHIVE_CAP);
};

const hasUsablePublishDate = (episode: ArchiveEpisode) => {
  const time = Date.parse(episode.publishDate || "");
  return Number.isFinite(time) && time > 0;
};
