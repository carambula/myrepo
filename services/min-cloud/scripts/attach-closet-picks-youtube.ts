/**
 * Attach Closet Picks YouTube episode URLs to the local snapshot.
 *
 *   npx tsx scripts/attach-closet-picks-youtube.ts
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { attachClosetPicksYouTube, fetchClosetPicksYouTubeVideos } from "../src/lib/closet-picks-youtube.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../../..");
const snapshotPath = path.resolve(
  process.env.SNAPSHOT_PATH || path.join(repoRoot, "apps/WatchedIt/WatchedIt/closet_picks_snapshot.json")
);

const main = async () => {
  const snapshot = JSON.parse(await fs.readFile(snapshotPath, "utf8")) as {
    generatedDate?: string;
    movies: Array<{
      sourceTitle?: string | null;
      sourceUrl?: string | null;
      youtubeUrl?: string | null;
      [key: string]: unknown;
    }>;
  };
  const videos = await fetchClosetPicksYouTubeVideos();
  const movies = attachClosetPicksYouTube(snapshot.movies, videos);
  const linked = movies.filter((movie) => movie.youtubeUrl).length;
  snapshot.movies = movies;
  snapshot.generatedDate = new Date().toISOString();
  await fs.writeFile(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`);
  console.log(`Wrote ${linked}/${movies.length} YouTube episode links to ${snapshotPath} (${videos.length} videos)`);
};

await main();
