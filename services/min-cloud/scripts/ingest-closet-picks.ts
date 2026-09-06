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
  parseClosetPicksEpisode,
  parseClosetPicksIndex,
  toClosetPicksCatalogItem,
  type ClosetPicksEpisode
} from "../src/lib/closet-picks-scrape.ts";
import { attachClosetPicksYouTube, fetchClosetPicksYouTubeVideos } from "../src/lib/closet-picks-youtube.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../../..");
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

const waybackUrl = (url: string, snapshot = waybackSnapshot) =>
  `https://web.archive.org/web/${snapshot}id_/${url}`;

const fetchHtml = async (url: string) => {
  const response = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "text/html,application/xhtml+xml"
    },
    signal: AbortSignal.timeout(12000)
  });
  if (!response.ok) {
    throw new Error(`GET ${url} failed ${response.status}`);
  }
  return response.text();
};

const mapPool = async <T, R>(items: T[], concurrency: number, worker: (item: T, index: number) => Promise<R>) => {
  const results: R[] = [];
  let next = 0;
  const run = async () => {
    while (next < items.length) {
      const index = next;
      next += 1;
      results[index] = await worker(items[index], index);
    }
  };
  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, run));
  return results;
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
  const candidates =
    origin === "wayback"
      ? [waybackUrl(episode.episodeUrl), waybackUrl(episode.episodeUrl, "2"), episode.episodeUrl]
      : [episode.episodeUrl, waybackUrl(episode.episodeUrl), waybackUrl(episode.episodeUrl, "2")];
  let lastError: unknown;
  for (const url of candidates) {
    try {
      const html = await fetchHtml(url);
      if (looksLikeChallenge(html)) {
        throw new Error("challenge");
      }
      return parseClosetPicksEpisode(html);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError instanceof Error ? lastError : new Error("episode fetch failed");
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
    movies: Array<Record<string, unknown>>;
  };
  if (payload.movies.some((movie) => movie.sourceIdentifier === CLOSET_PICKS_SOURCE_ID)) {
    throw new Error(
      "bootstrap_data.json already has criterion-closet-picks rows; remove them before merging or use --snapshot-only"
    );
  }

  const enrichmentByTitle = new Map<string, Record<string, unknown>>();
  for (const movie of payload.movies) {
    const title = typeof movie.title === "string" ? normalizeTitle(movie.title) : "";
    if (!title || enrichmentByTitle.has(title)) {
      continue;
    }
    enrichmentByTitle.set(title, movie);
  }

  const rows = snapshot.movies.map((item) => {
    const existing = enrichmentByTitle.get(normalizeTitle(item.title)) || {};
    return {
      title: item.title,
      sourceIdentifier: item.sourceIdentifier,
      rank: item.rank,
      sourceTitle: item.sourceTitle,
      episodeDate: item.episodeDate,
      sourceUrl: item.sourceUrl,
      youtubeUrl: item.youtubeUrl ?? null,
      podcastEpisodeDescription: item.podcastEpisodeDescription,
      tmdbId: existing.tmdbId ?? null,
      year: item.year ?? existing.year ?? null,
      director: item.director ?? null,
      filmUrl: item.filmUrl ?? null,
      posterPath: existing.posterPath ?? null,
      backdropPath: existing.backdropPath ?? null,
      overview: existing.overview ?? null,
      mpaaRating: existing.mpaaRating ?? null,
      genres: existing.genres ?? [],
      streamingServices: existing.streamingServices ?? [],
      credits: existing.credits ?? null,
      trailer: existing.trailer ?? null
    };
  });

  let text = await fs.readFile(bootstrapPath, "utf8");
  text = text.replace(
    /("identifier": "criterion-closet-picks",\s*"isRankedList": true,\s*"movieCount": )(\d+)/,
    `$1${rows.length}`
  );
  const indentRow = (row: (typeof rows)[number]) =>
    JSON.stringify(row, null, 2)
      .split("\n")
      .map((line) => `    ${line}`)
      .join("\n");
  const appended = rows.map(indentRow).join(",\n");
  const moviesClose = `\n  ],\n  "version": "1.0"\n}`;
  if (!text.endsWith(moviesClose) && !text.includes(moviesClose)) {
    throw new Error("bootstrap_data.json ending did not match the expected movies/version footer");
  }
  text = text.replace(moviesClose, `,\n${appended}\n  ],\n  "version": "1.0"\n}`);
  await fs.writeFile(bootstrapPath, text.endsWith("\n") ? text : `${text}\n`);
  const matched = snapshot.movies.filter((movie) => enrichmentByTitle.has(normalizeTitle(movie.title))).length;
  console.log(
    `Merged ${rows.length} Closet Picks rows into bootstrap (${matched} copied enrichment from existing titles)`
  );
};

const main = async () => {
  const { origin, episodes } = await loadIndex();
  const selected = episodeLimit > 0 ? episodes.slice(0, episodeLimit) : episodes;
  console.log(`Loaded ${episodes.length} episodes from ${origin}; fetching ${selected.length}`);

  const concurrency = Number(process.env.FETCH_CONCURRENCY || 6);
  const visits: Array<{ episode: ClosetPicksEpisode; films: ReturnType<typeof parseClosetPicksEpisode> }> = [];
  let finished = 0;
  await mapPool(selected, concurrency, async (episode) => {
    try {
      const films = await loadEpisode(episode, origin);
      visits.push({ episode, films });
    } catch (error) {
      console.warn(`  skip ${episode.guestName}: ${error instanceof Error ? error.message : error}`);
    }
    finished += 1;
    if (finished % 20 === 0 || finished === selected.length) {
      console.log(`  ${finished}/${selected.length} fetched (${visits.length} ok)`);
    }
  });

  const collapsed = collapseClosetPicks(visits);
  let withYouTube = collapsed;
  try {
    const videos = await fetchClosetPicksYouTubeVideos();
    withYouTube = attachClosetPicksYouTube(collapsed, videos);
    const linked = withYouTube.filter((film) => film.youtubeUrl).length;
    console.log(`Matched ${linked}/${withYouTube.length} films to Closet Picks YouTube episodes`);
  } catch (error) {
    console.warn(`YouTube playlist attach failed (${error instanceof Error ? error.message : error})`);
  }
  const snapshot = {
    generatedDate: new Date().toISOString(),
    origin,
    waybackSnapshot: origin === "wayback" ? waybackSnapshot : null,
    episodeCount: visits.length,
    movies: withYouTube.map((film) => toClosetPicksCatalogItem(film))
  };
  await fs.mkdir(path.dirname(snapshotPath), { recursive: true });
  await fs.writeFile(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`);
  console.log(`Wrote ${snapshot.movies.length} unique films to ${snapshotPath}`);

  if (!args.has("--snapshot-only")) {
    await mergeBootstrap(snapshot);
  }
};

await main();
