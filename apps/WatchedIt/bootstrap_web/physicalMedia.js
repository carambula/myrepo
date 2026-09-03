"use strict";

const https = require("https");

const FORMAT_QIDS = {
  Q20993976: "uhd4k",
  Q188808: "bluRay",
  Q34467: "dvd",
};

const LABEL_QIDS = {
  Q1150316: "criterion",
  Q5187902: "criterion",
  Q4796236: "arrow",
  Q2277442: "shoutFactory",
  Q6413894: "kinoLorber",
};

const LABEL_NAME_HINTS = [
  { pattern: /criterion/i, label: "criterion" },
  { pattern: /arrow (video|films|academy)/i, label: "arrow" },
  { pattern: /shout!? factory/i, label: "shoutFactory" },
  { pattern: /kino lorber/i, label: "kinoLorber" },
];

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function sparqlQueryOnce(query) {
  const url = `https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(query)}`;
  return new Promise((resolve, reject) => {
    https
      .get(
        url,
        {
          headers: {
            "User-Agent": "WatchedIt/1.0 (physical media catalog enricher)",
            Accept: "application/sparql-results+json",
          },
        },
        (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            if (res.statusCode && res.statusCode >= 400) {
              return reject(new Error(`Wikidata HTTP ${res.statusCode}: ${data.slice(0, 240)}`));
            }
            try {
              resolve(JSON.parse(data));
            } catch (error) {
              reject(error);
            }
          });
        }
      )
      .on("error", reject);
  });
}

async function sparqlQuery(query) {
  let lastError;
  for (const waitMs of [0, 65000, 65000]) {
    if (waitMs) await delay(waitMs);
    try {
      return await sparqlQueryOnce(query);
    } catch (error) {
      lastError = error;
      const message = String(error.message || "");
      if (!message.includes("429") && !message.includes("502") && !message.includes("503")) {
        throw error;
      }
    }
  }
  throw lastError;
}

function qidFromUri(value) {
  if (!value) return null;
  const match = String(value).match(/\/(Q\d+)$/);
  return match ? match[1] : null;
}

function emptyMedia() {
  return {
    editions: [],
    hasCriterion: false,
    has4K: false,
    hasBluRay: false,
    manualOverride: false,
  };
}

function addEdition(media, edition) {
  const key = [edition.label, edition.format, edition.spineNumber || "", edition.notes || ""].join("|");
  if (media.editions.some((existing) => [existing.label, existing.format, existing.spineNumber || "", existing.notes || ""].join("|") === key)) {
    return;
  }
  media.editions.push({
    id: edition.id || `${edition.label}-${edition.format}-${edition.spineNumber || "none"}`,
    label: edition.label,
    format: edition.format,
    spineNumber: edition.spineNumber || null,
    notes: edition.notes || null,
  });
}

function reconcile(media) {
  if (media.editions.some((edition) => edition.label === "criterion")) media.hasCriterion = true;
  if (media.editions.some((edition) => edition.format === "uhd4k")) media.has4K = true;
  if (media.editions.some((edition) => edition.format === "bluRay" || edition.format === "uhd4k")) {
    media.hasBluRay = true;
  }
  return media;
}

function isEmptyMedia(media) {
  return !media || (!media.hasCriterion && !media.has4K && !media.hasBluRay && !(media.editions || []).length);
}

function mergePhysicalMedia(existing, inferred) {
  if (!inferred || isEmptyMedia(inferred)) return existing || null;
  if (existing?.manualOverride) return existing;
  const merged = emptyMedia();
  merged.manualOverride = Boolean(existing?.manualOverride);
  merged.hasCriterion = Boolean(existing?.hasCriterion || inferred.hasCriterion);
  merged.has4K = Boolean(existing?.has4K || inferred.has4K);
  merged.hasBluRay = Boolean(existing?.hasBluRay || inferred.hasBluRay);
  for (const edition of [...(existing?.editions || []), ...(inferred.editions || [])]) {
    addEdition(merged, edition);
  }
  return reconcile(merged);
}

function mediaFromWikidataRow({ spine, formatQid, publisherQid, publisherLabel }) {
  const media = emptyMedia();
  const format = FORMAT_QIDS[formatQid] || null;
  let label = LABEL_QIDS[publisherQid] || null;
  if (!label && publisherLabel) {
    const hint = LABEL_NAME_HINTS.find((item) => item.pattern.test(publisherLabel));
    if (hint) label = hint.label;
  }
  if (spine) {
    media.hasCriterion = true;
    addEdition(media, {
      label: "criterion",
      format: format || "bluRay",
      spineNumber: String(spine),
    });
  }
  if (label === "criterion") {
    media.hasCriterion = true;
  }
  if (format === "uhd4k") media.has4K = true;
  if (format === "bluRay" || format === "uhd4k") media.hasBluRay = true;
  if (label || format) {
    addEdition(media, {
      label: label || "other",
      format: format || "bluRay",
    });
  }
  return reconcile(media);
}

async function fetchWikidataPhysicalMediaIndex() {
  const criterionQuery = `
SELECT ?tmdb ?spine WHERE {
  ?film wdt:P12279 ?spine .
  ?film wdt:P4947 ?tmdb .
}`.trim();

  const formatQuery = `
SELECT DISTINCT ?tmdb ?format WHERE {
  VALUES ?format { wd:Q20993976 }
  {
    ?film wdt:P437 ?format .
    ?film wdt:P4947 ?tmdb .
  } UNION {
    ?edition wdt:P437 ?format .
    ?film wdt:P4947 ?tmdb .
    { ?edition wdt:P921 ?film } UNION { ?film wdt:P747 ?edition } UNION { ?edition wdt:P361 ?film } UNION { ?edition wdt:P179 ?film }
  }
}`.trim();

  const publisherQuery = `
SELECT ?tmdb ?publisher ?publisherLabel WHERE {
  VALUES ?publisher { wd:Q1150316 wd:Q5187902 wd:Q4796236 wd:Q2277442 wd:Q6413894 }
  ?film wdt:P750 ?publisher .
  ?film wdt:P4947 ?tmdb .
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}`.trim();

  const criterion = await sparqlQuery(criterionQuery);
  const formats = await sparqlQuery(formatQuery);
  const publishers = await sparqlQuery(publisherQuery);

  const byTmdbId = new Map();

  function ensure(tmdbId) {
    const key = String(tmdbId);
    if (!byTmdbId.has(key)) byTmdbId.set(key, emptyMedia());
    return byTmdbId.get(key);
  }

  for (const binding of criterion.results?.bindings || []) {
    const tmdbId = binding.tmdb?.value;
    if (!tmdbId) continue;
    const media = ensure(tmdbId);
    media.hasCriterion = true;
    addEdition(media, {
      label: "criterion",
      format: "bluRay",
      spineNumber: binding.spine?.value || null,
    });
    reconcile(media);
  }

  for (const binding of formats.results?.bindings || []) {
    const tmdbId = binding.tmdb?.value;
    const format = FORMAT_QIDS[qidFromUri(binding.format?.value)];
    if (!tmdbId || !format) continue;
    const media = ensure(tmdbId);
    addEdition(media, { label: media.hasCriterion ? "criterion" : "other", format });
    reconcile(media);
  }

  for (const binding of publishers.results?.bindings || []) {
    const tmdbId = binding.tmdb?.value;
    if (!tmdbId) continue;
    const publisherQid = qidFromUri(binding.publisher?.value);
    const publisherLabel = binding.publisherLabel?.value || "";
    const inferred = mediaFromWikidataRow({
      publisherQid,
      publisherLabel,
    });
    byTmdbId.set(String(tmdbId), mergePhysicalMedia(byTmdbId.get(String(tmdbId)), inferred));
  }

  return byTmdbId;
}

const CURATED_4K_TMDB_IDS = [
  62, 155, 238, 280, 346, 348, 539, 550, 578, 603, 679, 680, 694, 769, 947, 949,
  1091, 1949, 6977, 7345, 9693, 27205, 37799, 438631, 76341, 157336, 244786,
  273481, 361743, 503919,
];

function seedCurated4K(byTmdbId) {
  for (const tmdbId of CURATED_4K_TMDB_IDS) {
    const existing = byTmdbId.get(String(tmdbId)) || emptyMedia();
    existing.has4K = true;
    existing.hasBluRay = true;
    const has4KEdition = (existing.editions || []).some((edition) => edition.format === "uhd4k");
    if (!has4KEdition) {
      addEdition(existing, {
        label: existing.hasCriterion ? "criterion" : "other",
        format: "uhd4k",
      });
    }
    byTmdbId.set(String(tmdbId), reconcile(existing));
  }
  return byTmdbId;
}

function seedCriterionFromSources(movies, byTmdbId) {
  for (const movie of movies || []) {
    if (movie.sourceIdentifier !== "criterion" || !movie.tmdbId) continue;
    const existing = byTmdbId.get(String(movie.tmdbId)) || emptyMedia();
    existing.hasCriterion = true;
    const hasCriterionEdition = (existing.editions || []).some((edition) => edition.label === "criterion");
    if (!hasCriterionEdition) {
      addEdition(existing, { label: "criterion", format: "bluRay" });
    }
    byTmdbId.set(String(movie.tmdbId), reconcile(existing));
  }
  return byTmdbId;
}

function applyIndexToMovies(movies, byTmdbId, { overwriteManual = false } = {}) {
  let updated = 0;
  for (const movie of movies || []) {
    if (!movie.tmdbId) continue;
    const inferred = byTmdbId.get(String(movie.tmdbId));
    if (!inferred || isEmptyMedia(inferred)) continue;
    if (movie.physicalMedia?.manualOverride && !overwriteManual) continue;
    const merged = mergePhysicalMedia(movie.physicalMedia, inferred);
    if (JSON.stringify(merged) !== JSON.stringify(movie.physicalMedia || null)) {
      movie.physicalMedia = merged;
      updated += 1;
    }
  }
  return updated;
}

function overlayFromMovies(movies) {
  const byTmdbId = {};
  for (const movie of movies || []) {
    if (!movie.tmdbId || isEmptyMedia(movie.physicalMedia)) continue;
    byTmdbId[String(movie.tmdbId)] = movie.physicalMedia;
  }
  return { byTmdbId };
}

function isUsefulMedia(media) {
  if (!media || isEmptyMedia(media)) return false;
  if (media.hasCriterion || media.has4K) return true;
  return (media.editions || []).some((edition) => edition.label && edition.label !== "other");
}

function filterIndexToCatalog(byTmdbId, movies) {
  const catalog = new Set(
    (movies || [])
      .map((movie) => (movie.tmdbId != null ? String(movie.tmdbId) : ""))
      .filter(Boolean)
  );
  const filtered = new Map();
  for (const [tmdbId, media] of byTmdbId.entries()) {
    if (catalog.has(String(tmdbId)) && isUsefulMedia(media)) {
      filtered.set(String(tmdbId), media);
    }
  }
  return filtered;
}

function overlayFromIndex(byTmdbId) {
  const mapped = {};
  for (const [tmdbId, media] of byTmdbId.entries()) {
    if (isUsefulMedia(media)) mapped[tmdbId] = media;
  }
  return { byTmdbId: mapped };
}

function physicalMediaStats(movies) {
  const withMedia = (movies || []).filter((movie) => !isEmptyMedia(movie.physicalMedia));
  return {
    totalMovies: movies?.length || 0,
    withPhysicalMedia: withMedia.length,
    withCriterion: withMedia.filter((movie) => movie.physicalMedia.hasCriterion).length,
    with4K: withMedia.filter((movie) => movie.physicalMedia.has4K).length,
    withBluRay: withMedia.filter((movie) => movie.physicalMedia.hasBluRay).length,
    manualOverrides: withMedia.filter((movie) => movie.physicalMedia.manualOverride).length,
  };
}

module.exports = {
  emptyMedia,
  isEmptyMedia,
  isUsefulMedia,
  mergePhysicalMedia,
  fetchWikidataPhysicalMediaIndex,
  seedCriterionFromSources,
  seedCurated4K,
  filterIndexToCatalog,
  applyIndexToMovies,
  overlayFromMovies,
  overlayFromIndex,
  physicalMediaStats,
};
