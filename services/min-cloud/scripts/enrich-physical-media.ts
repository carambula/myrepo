/**
 * Rebuild physical_media.json from Wikidata Criterion spines, the HD Report
 * Criterion 4K list, catalog source rows, and the small curated 4K set.
 *
 *   npx tsx scripts/enrich-physical-media.ts
 *   npx tsx scripts/enrich-physical-media.ts --update-bootstrap
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  applyCriterionSourcePhysicalMedia,
  applyIndexToMovies,
  overlayFromIndex,
  physicalMediaStats,
  seedCriterionFromSources,
  seedCurated4K
} from "../src/lib/physical-media.ts";
import { enrichPhysicalMediaIndex } from "../src/lib/physical-media-wikidata.ts";
import { seedCriterionCatalogTitles, type CriterionShopTitle } from "../src/lib/physical-media-criterion.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(here, "../../..");
const bootstrapPath = path.resolve(
  process.env.BOOTSTRAP_PATH || path.join(repoRoot, "apps/WatchedIt/WatchedIt/bootstrap_data.json")
);
const overlayPath = path.resolve(
  process.env.PHYSICAL_MEDIA_PATH || path.join(repoRoot, "apps/WatchedIt/WatchedIt/physical_media.json")
);
const snapshotPath = path.resolve(
  process.env.CRITERION_4K_PATH || path.join(repoRoot, "apps/WatchedIt/WatchedIt/criterion_4k_titles.json")
);

const loadFallbackTitles = async (): Promise<CriterionShopTitle[]> => {
  try {
    const raw = JSON.parse(await fs.readFile(snapshotPath, "utf8"));
    return Array.isArray(raw) ? raw : raw.titles || [];
  } catch {
    return [];
  }
};

const main = async () => {
  const bootstrap = JSON.parse(await fs.readFile(bootstrapPath, "utf8"));
  const movies = bootstrap.movies || [];
  console.log(`Loaded ${movies.length} bootstrap movies`);

  const fallbackTitles = await loadFallbackTitles();
  let { index, hits } = { index: new Map(), hits: [] as Awaited<ReturnType<typeof enrichPhysicalMediaIndex>>["hits"] };
  try {
    ({ index, hits } = await enrichPhysicalMediaIndex(fallbackTitles));
    console.log(`Wikidata + 4K catalog inferred ${index.size} titles`);
  } catch (error) {
    console.warn(`Live enrich failed (${error instanceof Error ? error.message : error}); using fallback 4K list only`);
    seedCriterionCatalogTitles(fallbackTitles, hits, index);
  }

  seedCriterionFromSources(movies, index);
  seedCurated4K(index);
  const sourceUpdated = applyCriterionSourcePhysicalMedia(movies);
  const overlay = overlayFromIndex(index);
  await fs.writeFile(overlayPath, `${JSON.stringify(overlay, null, 2)}\n`);
  console.log(`Wrote overlay with ${Object.keys(overlay.byTmdbId).length} titles to ${overlayPath}`);

  if (process.argv.includes("--write-4k-snapshot")) {
    try {
      const { fetchHdReportCriterion4K } = await import("../src/lib/physical-media-wikidata.ts");
      const titles = await fetchHdReportCriterion4K();
      await fs.writeFile(snapshotPath, `${JSON.stringify(titles, null, 2)}\n`);
      console.log(`Wrote ${titles.length} Criterion 4K titles to ${snapshotPath}`);
    } catch (error) {
      console.warn(`Could not refresh 4K snapshot (${error instanceof Error ? error.message : error})`);
    }
  }

  if (process.argv.includes("--update-bootstrap")) {
    const updated = applyIndexToMovies(movies, index);
    bootstrap.generatedDate = new Date().toISOString();
    await fs.writeFile(bootstrapPath, `${JSON.stringify(bootstrap, null, 2)}\n`);
    console.log(`Updated physicalMedia on ${updated} bootstrap rows (${sourceUpdated} Criterion source tags)`);
    console.log(JSON.stringify(physicalMediaStats(movies), null, 2));
  } else {
    const seededMovies = movies.map((movie: { tmdbId?: number; physicalMedia?: unknown }) => {
      const inferred = movie.tmdbId != null ? index.get(String(movie.tmdbId)) : null;
      return inferred ? { ...movie, physicalMedia: inferred } : movie;
    });
    console.log(JSON.stringify(physicalMediaStats(seededMovies), null, 2));
  }
};

await main();
