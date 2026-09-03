/**
 * Fetch Criterion Closet Picks, collapse unique films, and merge into bootstrap_data.json.
 *
 *   npx tsx scripts/ingest-closet-picks.ts
 *   npx tsx scripts/ingest-closet-picks.ts --limit 8 --snapshot-only
 *
 * Live criterion.com is often Cloudflare-blocked. The script falls back to a
 * Wayback Machine snapshot when the live index fails.
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  CLOSET_PICKS_INDEX_URL,
  CLOSET_PICKS_SOURCE_ID,
  collapseClosetPicks,
  closetPicksSourceRecord,
  parseClosetPicksEpisode,
  parseClosetPicksIndex,
  toClosetPicksCatalogItem,
  type ClosetPicksEpisode
} from "../src/lib/closet-picks-scrape.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../..");
const bootstrapPath = path.resolve(
  process.env.BOOTSTRAP_PATH || path.join(repoRoot, "apps/WatchedIt/WatchedIt/bootstrap_data.json")
);
const snapshotPath = path.resolve(
  process.env.SNAPSHOT_PATH || path.join(repoRoot, "apps/WatchedIt/WatchedIt/closet_picks_snapshot.json")
);
const waybackSnapshot = process.env.WAYBACK_SNAPSHOT || "20250101071625";
const args = new Set(process.argv.slice(2));
const limitArg = process.argv.find((value, index, all) => all[index - 1] === "--limit");
const episodeLimit = limitArg ? Number(limitArg) : Number(process.env.EPISODE_LIMIT || 0);

const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const waybackUrl = (url: string) =>
  `https://web.archive.org/web/${waybackSnapshot}id_/${url}`;

const fetchHtml = async (url: string) => {
  const response = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "text/html,application/xhtml+xml"
    }
  });
  if (!response.ok) {
    throw new Error(`GET ${url} failed ${response.status}`);
  }
  return response.text();
};

const looksLikeChallenge = (html: string) =>
  /cloudflare|just a moment|security verification|cf-mitigated/i.test(html) &&
  !/super-collection-header|filmWrap|Closet Picks/i.test(html);

const loadIndex = async () => {
  try {
    const html = await fetchHtml(CLOSET_PICKS_INDEX_URL);
    if (looksLikeChallenge(html)) {
      throw new Error("live index returned a bot challenge");
    }
    const episodes = parseClosetPicksIndex(html);
    if (!episodes.length) {
      throw new Error("live index had no episodes");
    }
    return { origin: "live" as const, html, episodes };
  } catch (error) {
    console.warn(`Live index failed (${error instanceof Error ? error.message : error}); trying Wayback`);
    const html = await fetchHtml(waybackUrl(CLOSET_PICKS_INDEX_URL));
    const episodes = parseClosetPicksIndex(html);
    if (!episodes.length) {
      throw new Error("Wayback index had no episodes");
    }
    return { origin: "wayback" as const, html, episodes };
  }
};

const loadEpisode = async (episode: ClosetPicksEpisode, origin: "live" | "wayback") => {
  const url = origin === "wayback" ? waybackUrl(episode.episodeUrl) : episode.episodeUrl;
  const html = await fetchHtml(url);
  if (looksLikeChallenge(html)) {
    throw new Error("challenge");
  }
  return parseClosetPicksEpisode(html);
};

const normalizeTitle = (title: string) =>
  title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

const mergeBootstrap = async (
  snapshot: {
    generatedDate: string;
    origin: string;
    episodeCount: number;
    movies: ReturnType<typeof toClosetPicksCatalogItem>[];
  }
) => {
  const payload = JSON.parse(await fs.readFile(bootstrapPath, "utf8")) as {
    dataSources: Array<{
      identifier: string;
      name: string;
      type: string;
      url?: string | null;
      isRankedList: boolean;
      movieCount: number;
    }>;
    movies: Array<Record<string, unknown>>;
    generatedDate?: string;
  };

  const source = closetPicksSourceRecord();
  source.movieCount = snapshot.movies.length;
  const sourceIndex = payload.dataSources.findIndex((row) => row.identifier === CLOSET_PICKS_SOURCE_ID);
  if (sourceIndex >= 0) {
    payload.dataSources[sourceIndex] = source;
  } else {
    payload.dataSources.push(source);
    payload.dataSources.sort((left, right) => left.name.localeCompare(right.name));
  }

  const enrichmentByTitle = new Map<string, Record<string, unknown>>();
  for (const movie of payload.movies) {
    const title = typeof movie.title === "string" ? normalizeTitle(movie.title) : "";
    if (!title || enrichmentByTitle.has(title)) {
      continue;
    }
    enrichmentByTitle.set(title, movie);
  }

  payload.movies = payload.movies.filter((movie) => movie.sourceIdentifier !== CLOSET_PICKS_SOURCE_ID);
  for (const item of snapshot.movies) {
    const existing = enrichmentByTitle.get(normalizeTitle(item.title)) || {};
    payload.movies.push({
      title: item.title,
      sourceIdentifier: item.sourceIdentifier,
      rank: item.rank,
      sourceTitle: item.sourceTitle,
      episodeDate: item.episodeDate,
      sourceUrl: item.sourceUrl,
      podcastEpisodeDescription: item.podcastEpisodeDescription,
      tmdbId: existing.tmdbId ?? null,
      year: existing.year ?? null,
      posterPath: existing.posterPath ?? null,
      backdropPath: existing.backdropPath ?? null,
      overview: existing.overview ?? null,
      mpaaRating: existing.mpaaRating ?? null,
      genres: existing.genres ?? [],
      streamingServices: existing.streamingServices ?? [],
      credits: existing.credits ?? null,
      trailer: existing.trailer ?? null
    });
  }

  payload.generatedDate = snapshot.generatedDate;
  await fs.writeFile(bootstrapPath, `${JSON.stringify(payload, null, 2)}\n`);
  const matched = snapshot.movies.filter((movie) => enrichmentByTitle.has(normalizeTitle(movie.title))).length;
  console.log(
    `Merged ${snapshot.movies.length} Closet Picks rows into bootstrap (${matched} copied enrichment from existing titles)`
  );
};

const main = async () => {
  const { origin, episodes } = await loadIndex();
  const selected = episodeLimit > 0 ? episodes.slice(0, episodeLimit) : episodes;
  console.log(`Loaded ${episodes.length} episodes from ${origin}; fetching ${selected.length}`);

  const visits: Array<{ episode: ClosetPicksEpisode; films: ReturnType<typeof parseClosetPicksEpisode> }> = [];
  for (const [index, episode] of selected.entries()) {
    try {
      const films = await loadEpisode(episode, origin);
      visits.push({ episode, films });
      if ((index + 1) % 10 === 0 || index === selected.length - 1) {
        console.log(`  ${index + 1}/${selected.length} ${episode.guestName} (${films.length} films)`);
      }
    } catch (error) {
      console.warn(`  skip ${episode.guestName}: ${error instanceof Error ? error.message : error}`);
    }
    await sleep(origin === "wayback" ? 250 : 150);
  }

  const collapsed = collapseClosetPicks(visits);
  const snapshot = {
    generatedDate: new Date().toISOString(),
    origin,
    waybackSnapshot: origin === "wayback" ? waybackSnapshot : null,
    episodeCount: visits.length,
    movies: collapsed.map((film) => toClosetPicksCatalogItem(film))
  };
  await fs.mkdir(path.dirname(snapshotPath), { recursive: true });
  await fs.writeFile(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`);
  console.log(`Wrote ${snapshot.movies.length} unique films to ${snapshotPath}`);

  if (!args.has("--snapshot-only")) {
    await mergeBootstrap(snapshot);
  }
};

await main();
