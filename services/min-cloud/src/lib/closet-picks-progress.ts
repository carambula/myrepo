export type JobProgressRow = {
  name?: string;
  status?: string;
  started_at?: string | Date | null;
  finished_at?: string | Date | null;
  error?: string | null;
  stats?: Record<string, unknown> | null;
};

const toMs = (value: string | Date | null | undefined) => {
  if (!value) {
    return null;
  }
  const ms = value instanceof Date ? value.getTime() : Date.parse(String(value));
  return Number.isFinite(ms) ? ms : null;
};

export const formatJobElapsed = (startedAt: string | Date | null | undefined, now = Date.now()) => {
  const startMs = toMs(startedAt);
  if (startMs === null) {
    return "";
  }
  const sec = Math.max(0, Math.floor((now - startMs) / 1000));
  const hours = Math.floor(sec / 3600);
  const minutes = Math.floor((sec % 3600) / 60);
  const seconds = sec % 60;
  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  if (minutes > 0) {
    return `${minutes}m ${seconds}s`;
  }
  return `${seconds}s`;
};

const statsOf = (job: JobProgressRow) =>
  job.stats && typeof job.stats === "object" && !Array.isArray(job.stats) ? job.stats : {};

const count = (stats: Record<string, unknown>, key: string) => {
  const value = Number(stats[key]);
  return Number.isFinite(value) ? value : 0;
};

const ratio = (stats: Record<string, unknown>, doneKey: string, totalKey: string) => {
  const done = count(stats, doneKey);
  const total = stats[totalKey];
  if (total === undefined || total === null || total === "") {
    return String(done);
  }
  return `${done}/${total}`;
};

export const closetPicksProgressLabel = (job: JobProgressRow, now = Date.now()) => {
  const stats = statsOf(job);
  const elapsed = formatJobElapsed(job.started_at, now);
  const elapsedSuffix = elapsed ? ` (${elapsed})` : "";

  if (job.status === "ok") {
    return `Finished${elapsedSuffix}: ${count(stats, "scanned")} films   ${count(stats, "corrected")} corrected   ${count(stats, "added")} added   ${count(stats, "missing")} missing`;
  }
  if (job.status === "error") {
    return `Failed${elapsedSuffix}: ${job.error || "error"}`;
  }
  if (job.status === "already_running") {
    return `Already running${elapsedSuffix}`;
  }

  const phase = String(stats.phase || "");
  if (phase === "starting" || phase === "fetching-index") {
    return `Fetching episode index${elapsedSuffix}`;
  }
  if (phase === "scraping-episodes") {
    return `Scraping episodes ${ratio(stats, "episodeDone", "episodeTotal")}${elapsedSuffix}`;
  }
  if (phase === "fetching-film-pages") {
    return `Fetching film pages ${ratio(stats, "filmPageDone", "filmPageTotal")}${elapsedSuffix}`;
  }
  if (phase === "loading-wikidata") {
    return `Loading Wikidata Criterion index${elapsedSuffix}`;
  }
  if (phase === "matching") {
    return `Matching TMDB ${ratio(stats, "matchDone", "matchTotal")}   ${count(stats, "corrected")} corrected   ${count(stats, "missing")} missing${elapsedSuffix}`;
  }
  if (phase === "done") {
    return `Finishing${elapsedSuffix}`;
  }
  return `Running${elapsedSuffix}`;
};

const genericStatsLabel = (stats: Record<string, unknown>) =>
  Object.entries(stats)
    .filter(([, value]) => value !== undefined && value !== null && value !== "")
    .slice(0, 6)
    .map(([key, value]) => `${key} ${value}`)
    .join("   ");

export const jobProgressLabel = (job: JobProgressRow, now = Date.now()) => {
  if (job.name === "mov.closet.rematch") {
    return closetPicksProgressLabel(job, now);
  }
  const stats = statsOf(job);
  const elapsed = formatJobElapsed(job.started_at, now);
  if (job.status === "error") {
    return job.error || "error";
  }
  if (job.status === "running") {
    const detail = genericStatsLabel(stats);
    return detail ? `${detail}   (${elapsed || "0s"})` : `Running (${elapsed || "0s"})`;
  }
  return genericStatsLabel(stats);
};

export const withJobProgressLabel = <T extends JobProgressRow>(job: T, now = Date.now()) => ({
  ...job,
  progressLabel: jobProgressLabel(job, now)
});
