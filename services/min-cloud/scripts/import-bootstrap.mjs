#!/usr/bin/env node
/**
 * Import WatchedIt bootstrap_data.json into Min Cloud.
 * Usage:
 *   ADMIN_TOKEN=... MIN_CLOUD_URL=https://min-cloud-production.up.railway.app \
 *     node scripts/import-bootstrap.mjs [path-to-bootstrap_data.json]
 */
import fs from "node:fs/promises";
import path from "node:path";

const baseURL = (process.env.MIN_CLOUD_URL || "https://min-cloud-production.up.railway.app").replace(/\/$/, "");
const token = process.env.ADMIN_TOKEN || "";
const file = path.resolve(
  process.argv[2] || "../../apps/WatchedIt/WatchedIt/bootstrap_data.json"
);
const batchSize = Number(process.env.IMPORT_BATCH || 40);

if (!token) {
  console.error("ADMIN_TOKEN is required");
  process.exit(1);
}

const slugId = (title) =>
  `title-${title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 80)}`;

const overlayPath = path.resolve(
  process.env.PHYSICAL_MEDIA_PATH || path.join(path.dirname(file), "physical_media.json")
);
let physicalMediaByTmdbId = {};
try {
  const overlay = JSON.parse(await fs.readFile(overlayPath, "utf8"));
  physicalMediaByTmdbId = overlay.byTmdbId || overlay.physicalMediaByTmdbId || {};
  console.log(`Loaded physical media overlay (${Object.keys(physicalMediaByTmdbId).length} titles)`);
} catch {
  console.log("No physical_media.json overlay found; importing movies only");
}

const payload = JSON.parse(await fs.readFile(file, "utf8"));
const movies = (payload.movies || []).map((movie) => ({
  ...movie,
  id: movie.id || (movie.tmdbId ? `tmdb-${movie.tmdbId}` : slugId(movie.title || "untitled"))
}));

const post = async (body) => {
  const response = await fetch(`${baseURL}/v1/admin/mov/import`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-admin-token": token
    },
    body: JSON.stringify(body)
  });
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`import failed ${response.status}: ${text.slice(0, 400)}`);
  }
  return JSON.parse(text);
};

const sources = payload.dataSources || [];
console.log(`Importing ${movies.length} movie rows, ${sources.length} sources, batch ${batchSize}`);
let importedMovies = 0;
let importedSources = 0;
for (let i = 0; i < movies.length; i += batchSize) {
  const batch = movies.slice(i, i + batchSize);
  const result = await post({
    dataSources: i === 0 ? sources : [],
    movies: batch
  });
  importedMovies += result.importedMovies || 0;
  importedSources += result.importedSources || 0;
  console.log(`  ${Math.min(i + batch.length, movies.length)}/${movies.length} rows  movies=${result.importedMovies}`);
}

let importedPhysicalMedia = 0;
if (Object.keys(physicalMediaByTmdbId).length) {
  const overlayResult = await post({ physicalMediaByTmdbId });
  importedPhysicalMedia = overlayResult.importedPhysicalMedia || 0;
  console.log(`physical media overlay applied to ${importedPhysicalMedia} titles`);
}

const health = await fetch(`${baseURL}/v1/admin/health`, {
  headers: { "x-admin-token": token }
});
console.log("done", { importedMovies, importedSources, importedPhysicalMedia, health: await health.json() });
