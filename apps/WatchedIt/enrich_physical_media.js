#!/usr/bin/env node
"use strict";

const fs = require("fs/promises");
const path = require("path");
const {
  fetchWikidataPhysicalMediaIndex,
  seedCriterionFromSources,
  seedCurated4K,
  filterIndexToCatalog,
  applyIndexToMovies,
  overlayFromIndex,
  physicalMediaStats,
} = require("./bootstrap_web/physicalMedia");

async function main() {
  const root = __dirname;
  const bootstrapPath = path.join(root, "WatchedIt", "bootstrap_data.json");
  const overlayPath = path.join(root, "WatchedIt", "physical_media.json");

  const bootstrap = JSON.parse(await fs.readFile(bootstrapPath, "utf8"));
  const movies = bootstrap.movies || [];
  console.log(`Loaded ${movies.length} bootstrap movies`);

  console.log("Querying Wikidata for Criterion spines, 4K UHD editions, and boutique labels...");
  let index = new Map();
  try {
    index = await fetchWikidataPhysicalMediaIndex();
  } catch (error) {
    console.warn(`Wikidata lookup failed (${error.message}); seeding from Criterion list source only.`);
  }
  seedCriterionFromSources(movies, index);
  seedCurated4K(index);
  const catalogIndex = filterIndexToCatalog(index, movies);
  console.log(`Inferred physical media for ${index.size} Wikidata titles, ${catalogIndex.size} in catalog`);

  const overlay = overlayFromIndex(catalogIndex);
  await fs.writeFile(overlayPath, JSON.stringify(overlay, null, 2) + "\n");
  console.log(`Wrote overlay with ${Object.keys(overlay.byTmdbId).length} titles to ${overlayPath}`);

  if (process.argv.includes("--update-bootstrap")) {
    const updated = applyIndexToMovies(movies, catalogIndex);
    bootstrap.generatedDate = new Date().toISOString();
    await fs.writeFile(bootstrapPath, JSON.stringify(bootstrap, null, 2) + "\n");
    console.log(`Updated physicalMedia on ${updated} bootstrap rows`);
    console.log(JSON.stringify(physicalMediaStats(movies), null, 2));
  } else {
    const seededMovies = movies.map((movie) => {
      const inferred = catalogIndex.get(String(movie.tmdbId));
      return inferred ? { ...movie, physicalMedia: inferred } : movie;
    });
    console.log(JSON.stringify(physicalMediaStats(seededMovies), null, 2));
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
