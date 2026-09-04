import { fetchJson, sleep } from "./http.js";
import {
  addPhysicalEdition,
  emptyPhysicalMedia,
  FORMAT_QIDS,
  mediaFromWikidataRow,
  mergePhysicalMedia,
  qidFromUri,
  reconcilePhysicalMedia,
  type PhysicalMedia
} from "./physical-media.js";

type SparqlBinding = Record<string, { value?: string }>;
type SparqlResult = { results?: { bindings?: SparqlBinding[] } };

const WIKIDATA_HEADERS = {
  "User-Agent": "MinCloud/0.1 (physical media catalog enricher)",
  Accept: "application/sparql-results+json"
};

const CRITERION_QUERY = `
SELECT ?tmdb ?spine WHERE {
  ?film wdt:P12279 ?spine .
  ?film wdt:P4947 ?tmdb .
}`.trim();

const FORMAT_QUERY = `
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

const PUBLISHER_QUERY = `
SELECT ?tmdb ?publisher ?publisherLabel WHERE {
  VALUES ?publisher { wd:Q1150316 wd:Q5187902 wd:Q4796236 wd:Q2277442 wd:Q6413894 }
  ?film wdt:P750 ?publisher .
  ?film wdt:P4947 ?tmdb .
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}`.trim();

const sparqlQueryOnce = (query: string) =>
  fetchJson<SparqlResult>(`https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(query)}`, WIKIDATA_HEADERS, {
    timeoutMs: 60000
  });

export const sparqlQuery = async (query: string) => {
  let lastError: unknown;
  for (const waitMs of [0, 8000, 15000]) {
    if (waitMs) {
      await sleep(waitMs);
    }
    try {
      return await sparqlQueryOnce(query);
    } catch (error) {
      lastError = error;
      const message = error instanceof Error ? error.message : "";
      if (!message.includes("429") && !message.includes("502") && !message.includes("503")) {
        throw error;
      }
    }
  }
  throw lastError;
};

export const buildPhysicalMediaIndexFromBindings = ({
  criterion,
  formats,
  publishers
}: {
  criterion: SparqlBinding[];
  formats: SparqlBinding[];
  publishers: SparqlBinding[];
}) => {
  const byTmdbId = new Map<string, PhysicalMedia>();
  const ensure = (tmdbId: string) => {
    if (!byTmdbId.has(tmdbId)) {
      byTmdbId.set(tmdbId, emptyPhysicalMedia());
    }
    return byTmdbId.get(tmdbId) as PhysicalMedia;
  };

  for (const binding of criterion) {
    const tmdbId = binding.tmdb?.value;
    if (!tmdbId) {
      continue;
    }
    const media = ensure(tmdbId);
    media.hasCriterion = true;
    addPhysicalEdition(media, {
      label: "criterion",
      format: "bluRay",
      spineNumber: binding.spine?.value || null
    });
    reconcilePhysicalMedia(media);
  }

  for (const binding of formats) {
    const tmdbId = binding.tmdb?.value;
    const format = FORMAT_QIDS[qidFromUri(binding.format?.value) || ""];
    if (!tmdbId || !format) {
      continue;
    }
    const media = ensure(tmdbId);
    addPhysicalEdition(media, { label: media.hasCriterion ? "criterion" : "other", format });
    reconcilePhysicalMedia(media);
  }

  for (const binding of publishers) {
    const tmdbId = binding.tmdb?.value;
    if (!tmdbId) {
      continue;
    }
    const inferred = mediaFromWikidataRow({
      publisherQid: qidFromUri(binding.publisher?.value),
      publisherLabel: binding.publisherLabel?.value || ""
    });
    byTmdbId.set(tmdbId, mergePhysicalMedia(byTmdbId.get(tmdbId), inferred) || inferred);
  }

  return byTmdbId;
};

export const fetchWikidataPhysicalMediaIndex = async () => {
  const criterion = await sparqlQuery(CRITERION_QUERY);
  const formats = await sparqlQuery(FORMAT_QUERY);
  const publishers = await sparqlQuery(PUBLISHER_QUERY);
  return buildPhysicalMediaIndexFromBindings({
    criterion: criterion.results?.bindings ?? [],
    formats: formats.results?.bindings ?? [],
    publishers: publishers.results?.bindings ?? []
  });
};
