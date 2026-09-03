import { sparqlQuery } from "./physical-media-wikidata.js";
import { normalizeClosetPicksTitle } from "./closet-picks-scrape.js";

const CRITERION_TMDB_QUERY = `
SELECT ?tmdb ?title ?year WHERE {
  ?film wdt:P4947 ?tmdb .
  { ?film wdt:P12279 ?spine } UNION { ?film wdt:P750 wd:Q1150316 }
  ?film rdfs:label ?title .
  FILTER(LANG(?title) = "en")
  OPTIONAL { ?film wdt:P577 ?date BIND(YEAR(?date) AS ?year) }
}`.trim();

export type CriterionTmdbHit = {
  tmdbId: number;
  title: string;
  year: number | null;
};

export const parseCriterionTmdbBindings = (
  bindings: Array<Record<string, { value?: string }>>
): CriterionTmdbHit[] => {
  const hits: CriterionTmdbHit[] = [];
  for (const row of bindings) {
    const tmdbId = Number(row.tmdb?.value);
    const title = String(row.title?.value || "").trim();
    const year = row.year?.value ? Number(row.year.value) : null;
    if (!Number.isFinite(tmdbId) || tmdbId <= 0 || !title) {
      continue;
    }
    hits.push({
      tmdbId,
      title,
      year: Number.isFinite(year) ? year : null
    });
  }
  return hits;
};

export const pickCriterionTmdbId = (hits: CriterionTmdbHit[], title: string, year?: number | null) => {
  const key = normalizeClosetPicksTitle(title);
  if (!key) {
    return null;
  }
  const matches = hits.filter((hit) => normalizeClosetPicksTitle(hit.title) === key);
  if (!matches.length) {
    return null;
  }
  const dated = matches.filter((hit) => hit.year != null);
  if (year && dated.length) {
    const yearHits = dated.filter((hit) => Math.abs((hit.year as number) - year) <= 1);
    const unique = [...new Set(yearHits.map((hit) => hit.tmdbId))];
    return unique.length === 1 ? unique[0] : null;
  }
  const unique = [...new Set(matches.map((hit) => hit.tmdbId))];
  return unique.length === 1 ? unique[0] : null;
};

export const loadCriterionTmdbIndex = async () => {
  const result = await sparqlQuery(CRITERION_TMDB_QUERY);
  return parseCriterionTmdbBindings(result.results?.bindings ?? []);
};
