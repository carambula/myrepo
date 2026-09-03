#!/usr/bin/env node
/**
 * Pull the live WatchedIt catalog from Min Cloud into bootstrap JSON.
 *
 * Usage:
 *   MIN_CLOUD_URL=https://min-cloud-production.up.railway.app \
 *     node scripts/export-bootstrap.mjs [output-path]
 *
 * Default output: apps/WatchedIt/WatchedIt/bootstrap_data.cloud.json
 * Public catalog — no admin token required.
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const defaultOut = path.resolve(here, "../../apps/WatchedIt/WatchedIt/bootstrap_data.cloud.json");

export const mapSource = (row) => ({
  identifier: String(row.identifier),
  name: String(row.name || row.identifier),
  type: String(row.type || "url"),
  url: row.url ?? null,
  isRankedList: Boolean(row.is_ranked ?? row.isRankedList),
  movieCount: Number(row.movie_count ?? row.movieCount ?? 0)
});

export const mapStreaming = (providers) => {
  if (!Array.isArray(providers)) {
    return [];
  }
  return providers
    .map((provider) => {
      const providerId = Number(provider.providerId ?? provider.id);
      const providerName = provider.providerName ?? provider.name;
      if (!Number.isFinite(providerId) || !providerName) {
        return null;
      }
      return {
        providerId,
        providerName: String(providerName),
        logoPath: provider.logoPath ?? null,
        displayPriority: Number(provider.displayPriority ?? 999)
      };
    })
    .filter(Boolean);
};

const mapCredits = (credits) => {
  if (!credits || typeof credits !== "object") {
    return null;
  }
  const cast = Array.isArray(credits.cast)
    ? credits.cast
        .filter((member) => member && member.id != null && member.name)
        .map((member) => ({
          id: Number(member.id),
          name: String(member.name),
          character: member.character ?? null,
          profilePath: member.profilePath ?? null
        }))
    : [];
  if (!credits.director && !cast.length) {
    return null;
  }
  return { director: credits.director ?? null, cast };
};

const mapTrailer = (trailer) => {
  if (!trailer || !trailer.youtubeKey) {
    return null;
  }
  return {
    id: String(trailer.id || trailer.youtubeKey),
    name: String(trailer.name || "Trailer"),
    youtubeKey: String(trailer.youtubeKey),
    isOfficial: Boolean(trailer.isOfficial)
  };
};

export const flattenMovie = (movie) => {
  const base = {
    title: String(movie.title || "Untitled"),
    tmdbId: movie.tmdbId ?? null,
    imdbId: movie.imdbId ?? null,
    year: movie.year ?? null,
    posterPath: movie.posterPath ?? null,
    backdropPath: movie.backdropPath ?? null,
    overview: movie.overview ?? null,
    mpaaRating: movie.mpaaRating ?? null,
    genres: Array.isArray(movie.genres) ? movie.genres : [],
    streamingServices: mapStreaming(movie.streamingServices),
    credits: mapCredits(movie.credits),
    trailer: mapTrailer(movie.trailer),
    oscarAwards: movie.oscarAwards ?? null,
    physicalMedia: movie.physicalMedia ?? null
  };
  const links = Array.isArray(movie.sources) ? movie.sources : [];
  if (!links.length) {
    return [
      {
        ...base,
        sourceIdentifier: "",
        rank: null,
        sourceTitle: null,
        episodeDate: null,
        podcastEpisodeDescription: null
      }
    ];
  }
  return links.map((link) => ({
    ...base,
    sourceIdentifier: String(link.identifier || ""),
    rank: link.rank ?? null,
    sourceTitle: link.sourceTitle ?? null,
    episodeDate: link.episodeDate ?? null,
    podcastEpisodeDescription: link.episode?.description ?? null
  }));
};

export const catalogToBootstrap = (catalog) => ({
  version: "1.0",
  generatedDate: catalog.generatedAt || new Date().toISOString(),
  revision: Number(catalog.revision || 0),
  dataSources: (catalog.sources || []).map(mapSource),
  movies: (catalog.movies || []).flatMap(flattenMovie)
});

export const localRevision = (payload) => {
  const value = payload?.revision;
  return Number.isFinite(Number(value)) ? Number(value) : null;
};

const fetchJson = async (url) => {
  const response = await fetch(url, { headers: { accept: "application/json" } });
  if (!response.ok) {
    throw new Error(`GET ${url} failed ${response.status}`);
  }
  return response.json();
};

export const fetchFullCatalog = async (baseURL, limit = 1000) => {
  const movies = [];
  let sources = [];
  let revision = 0;
  let generatedAt = null;
  let offset = 0;
  while (true) {
    const url = new URL("/v1/mov/catalog", `${baseURL}/`);
    url.searchParams.set("limit", String(limit));
    url.searchParams.set("offset", String(offset));
    const page = await fetchJson(url);
    revision = Number(page.revision || 0);
    generatedAt = page.generatedAt || generatedAt;
    if (Array.isArray(page.sources) && page.sources.length) {
      sources = page.sources;
    }
    const batch = Array.isArray(page.movies) ? page.movies : [];
    movies.push(...batch);
    if (page.truncated !== true || batch.length === 0) {
      break;
    }
    offset += batch.length;
  }
  return { revision, generatedAt, sources, movies };
};

const readLocalRevision = async (paths) => {
  for (const file of paths) {
    try {
      const payload = JSON.parse(await fs.readFile(file, "utf8"));
      const revision = localRevision(payload);
      if (revision != null) {
        return { revision, file };
      }
    } catch {
      // try next
    }
  }
  return { revision: null, file: null };
};

const run = async () => {
  const baseURL = (process.env.MIN_CLOUD_URL || "https://min-cloud-production.up.railway.app").replace(/\/$/, "");
  const outFile = path.resolve(process.argv[2] || process.env.BOOTSTRAP_CLOUD_PATH || defaultOut);
  const fallbackJson = path.resolve(path.dirname(outFile), "bootstrap_data.json");
  const force = process.env.FORCE_CLOUD_BOOTSTRAP === "1";

  const firstPage = await fetchJson(`${baseURL}/v1/mov/catalog?limit=1&offset=0`);
  const remoteRevision = Number(firstPage.revision || 0);
  const local = await readLocalRevision([outFile, fallbackJson]);
  if (!force && local.revision != null && local.revision === remoteRevision && (await exists(outFile))) {
    console.log(`bootstrap already at cloud revision ${remoteRevision} (${path.basename(local.file || outFile)})`);
    return { skipped: true, revision: remoteRevision, outFile };
  }

  console.log(`pulling catalog from ${baseURL} (revision ${remoteRevision})`);
  const catalog = await fetchFullCatalog(baseURL);
  const bootstrap = catalogToBootstrap(catalog);
  await fs.mkdir(path.dirname(outFile), { recursive: true });
  await fs.writeFile(outFile, `${JSON.stringify(bootstrap, null, 2)}\n`);
  console.log(
    `wrote ${bootstrap.movies.length} rows, ${bootstrap.dataSources.length} sources, revision ${bootstrap.revision} → ${outFile}`
  );
  return { skipped: false, revision: bootstrap.revision, outFile, movies: bootstrap.movies.length };
};

const exists = async (file) => {
  try {
    await fs.access(file);
    return true;
  } catch {
    return false;
  }
};

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  run().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  });
}
