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

/** Union two episode lists by guid / audio URL / title. `primary` wins on duplicates. */
export const mergeEpisodeArchives = <T extends ArchiveEpisode>(primary: T[], extra: T[]): T[] => {
  const seen = new Set<string>();
  const merged: T[] = [];
  for (const episode of [...primary, ...extra]) {
    const keys = episodeArchiveKeys(episode);
    if (!keys.length || keys.some((key) => seen.has(key))) {
      continue;
    }
    for (const key of keys) {
      seen.add(key);
    }
    merged.push(episode);
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
