import { query } from "./db.js";
import * as cheerio from "cheerio";

const WIKIDATA_API_URL = "https://www.wikidata.org/w/api.php";
const USER_AGENT = "CyclismoBackend/1.0 (+https://github.com/)";

type WikidataEntityClaim = {
  mainsnak?: {
    datavalue?: {
      value?: unknown;
    };
  };
  qualifiers?: Record<
    string,
    Array<{
      datavalue?: {
        value?: unknown;
      };
    }>
  >;
};

type WikidataEntity = {
  id: string;
  labels?: Record<string, { value: string }>;
  descriptions?: Record<string, { value: string }>;
  aliases?: Record<string, Array<{ value: string }>>;
  sitelinks?: Record<string, { title: string }>;
  claims?: Record<string, WikidataEntityClaim[]>;
};

type SearchResponse = {
  search?: Array<{ id: string }>;
};

type EntityResponse = {
  entities?: Record<string, WikidataEntity>;
};

type WikipediaSearchResponse = {
  query?: {
    search?: Array<{ title: string }>;
  };
};

type WikipediaRevisionsResponse = {
  query?: {
    pages?: Record<
      string,
      {
        revisions?: Array<{
          slots?: {
            main?: {
              "*": string;
              content?: string;
            };
          };
        }>;
      }
    >;
  };
};

export type RaceLookupRow = {
  race_id: string;
  name: string;
  start_date: string;
  end_date: string;
  race_type: string;
  gender_division: string | null;
  official_website?: string | null;
};

export type StageLookupRow = {
  stage_id: string;
  race_id: string;
  stage_number: number | null;
  name: string;
  date: string | null;
  is_rest_day: boolean;
};

type ResultSeed = {
  resultType: string;
  rank: number;
  athleteName: string;
  teamName: string | null;
  nationality: string | null;
  resultText: string | null;
  source: string;
  sourceUrl: string | null;
  metadata: Record<string, string | number | boolean | null>;
};

const normalize = (value: string): string =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const raceLooksCompleted = (race: RaceLookupRow): boolean => race.end_date < new Date().toISOString().slice(0, 10);

const stageLooksCompleted = (stage: StageLookupRow): boolean => {
  if (stage.is_rest_day || !stage.date) return false;
  return stage.date < new Date().toISOString().slice(0, 10);
};

const fetchJson = async <T>(url: URL): Promise<T | null> => {
  const response = await fetch(url.toString(), {
    headers: {
      "User-Agent": USER_AGENT,
      "Api-User-Agent": USER_AGENT,
      Accept: "application/json"
    }
  });
  if (!response.ok) {
    return null;
  }
  return (await response.json()) as T;
};

const fetchHtml = async (url: string): Promise<string | null> => {
  const response = await fetch(url, {
    headers: {
      "User-Agent": USER_AGENT,
      "Api-User-Agent": USER_AGENT,
      Accept: "text/html"
    }
  });
  if (!response.ok) {
    return null;
  }
  return response.text();
};

const searchEntityIds = async (search: string, limit = 6): Promise<string[]> => {
  const url = new URL(WIKIDATA_API_URL);
  url.searchParams.set("action", "wbsearchentities");
  url.searchParams.set("search", search);
  url.searchParams.set("language", "en");
  url.searchParams.set("type", "item");
  url.searchParams.set("limit", String(limit));
  url.searchParams.set("format", "json");
  const json = await fetchJson<SearchResponse>(url);
  return (json?.search ?? []).map((item) => item.id);
};

const fetchEntity = async (id: string): Promise<WikidataEntity | null> => {
  const url = new URL("https://www.wikidata.org/wiki/Special:EntityData");
  url.pathname = `/wiki/Special:EntityData/${id}.json`;
  const json = await fetchJson<EntityResponse>(url);
  return json?.entities?.[id] ?? null;
};

const fetchEntityLabels = async (ids: string[]): Promise<Map<string, string>> => {
  if (!ids.length) return new Map();
  const url = new URL(WIKIDATA_API_URL);
  url.searchParams.set("action", "wbgetentities");
  url.searchParams.set("ids", ids.join("|"));
  url.searchParams.set("languages", "en");
  url.searchParams.set("props", "labels");
  url.searchParams.set("format", "json");
  const json = await fetchJson<EntityResponse>(url);
  const out = new Map<string, string>();
  for (const [id, entity] of Object.entries(json?.entities ?? {})) {
    const label = entity.labels?.en?.value ?? null;
    if (label) out.set(id, label);
  }
  return out;
};

const getEntityIdClaim = (entity: WikidataEntity, propertyId: string): string | null => {
  const claims = entity.claims?.[propertyId] ?? [];
  for (const claim of claims) {
    const value = claim.mainsnak?.datavalue?.value as { id?: string } | undefined;
    if (value?.id) {
      return value.id;
    }
  }
  return null;
};

const OVERALL_WINNER_QUALIFIER_IDS = new Set(["Q20882667"]);

const getWinnerClaimEntityId = (entity: WikidataEntity): string | null => {
  const claims = entity.claims?.P1346 ?? [];
  if (!claims.length) return null;
  for (const claim of claims) {
    const qualifierValues = claim.qualifiers?.P2501 ?? [];
    const qualifierIds = qualifierValues
      .map((entry) => (entry.datavalue?.value as { id?: string } | undefined)?.id)
      .filter((id): id is string => !!id);
    if (!qualifierIds.some((id) => OVERALL_WINNER_QUALIFIER_IDS.has(id))) {
      continue;
    }
    const winnerId = (claim.mainsnak?.datavalue?.value as { id?: string } | undefined)?.id;
    if (winnerId) {
      return winnerId;
    }
  }
  return getEntityIdClaim(entity, "P1346");
};

const getEnglishLabel = (entity: WikidataEntity): string => entity.labels?.en?.value ?? "";

const getDescription = (entity: WikidataEntity): string => entity.descriptions?.en?.value ?? "";

const getAllNames = (entity: WikidataEntity): string[] => {
  const names = new Set<string>();
  const label = getEnglishLabel(entity);
  if (label) names.add(label);
  for (const alias of entity.aliases?.en ?? []) {
    if (alias.value) names.add(alias.value);
  }
  return Array.from(names);
};

const textContainsMostTokens = (haystack: string, needle: string, minimum = 2): boolean => {
  const hay = normalize(haystack);
  const tokens = normalize(needle)
    .split(" ")
    .filter((token) => token.length > 2);
  if (!tokens.length) return false;
  const matches = tokens.filter((token) => hay.includes(token)).length;
  return matches >= Math.min(minimum, tokens.length);
};

const wikidataItemUrl = (itemId: string): string => `https://www.wikidata.org/wiki/${itemId}`;

const wikipediaUrlFromEntity = (entity: WikidataEntity): string | null => {
  const enwikiTitle = entity.sitelinks?.enwiki?.title;
  if (!enwikiTitle) return null;
  return `https://en.wikipedia.org/wiki/${encodeURIComponent(enwikiTitle.replace(/ /g, "_"))}`;
};

const extractWinnerSeed = async (
  entity: WikidataEntity,
  resultType: string,
  contextMetadata: Record<string, string | number | null>
): Promise<ResultSeed | null> => {
  const winnerQid = getWinnerClaimEntityId(entity);
  if (!winnerQid) return null;
  const names = await fetchEntityLabels([winnerQid]);
  const athleteName = names.get(winnerQid);
  if (!athleteName) return null;
  return {
    resultType,
    rank: 1,
    athleteName,
    teamName: null,
    nationality: null,
    resultText: null,
    source: "wikidata",
    sourceUrl: wikipediaUrlFromEntity(entity) ?? wikidataItemUrl(entity.id),
    metadata: {
      ...contextMetadata,
      wikidataEventItemId: entity.id,
      wikidataWinnerItemId: winnerQid
    }
  };
};

const WIKIPEDIA_API_URL = "https://en.wikipedia.org/w/api.php";

const searchWikipediaTitles = async (search: string, limit = 5): Promise<string[]> => {
  const url = new URL(WIKIPEDIA_API_URL);
  url.searchParams.set("action", "query");
  url.searchParams.set("list", "search");
  url.searchParams.set("srsearch", search);
  url.searchParams.set("srlimit", String(limit));
  url.searchParams.set("format", "json");
  const json = await fetchJson<WikipediaSearchResponse>(url);
  return (json?.query?.search ?? []).map((entry) => entry.title).filter(Boolean);
};

const fetchWikipediaWikitext = async (title: string): Promise<string | null> => {
  const url = new URL(WIKIPEDIA_API_URL);
  url.searchParams.set("action", "query");
  url.searchParams.set("prop", "revisions");
  url.searchParams.set("rvprop", "content");
  url.searchParams.set("rvslots", "main");
  url.searchParams.set("titles", title);
  url.searchParams.set("format", "json");
  const json = await fetchJson<WikipediaRevisionsResponse>(url);
  const pages = json?.query?.pages;
  if (!pages) return null;
  const page = Object.values(pages)[0];
  const content = page?.revisions?.[0]?.slots?.main;
  return content?.content ?? content?.["*"] ?? null;
};

const sanitizeWinnerName = (raw: string): string | null => {
  const withoutLinks = raw
    .replace(/\[\[([^\]|]+)\|([^\]]+)\]\]/g, "$2")
    .replace(/\[\[([^\]]+)\]\]/g, "$1")
    .replace(/<[^>]+>/g, "")
    .replace(/\{\{[^}]+\}\}/g, "")
    .replace(/''+/g, "")
    .replace(/\s+/g, " ")
    .trim();
  if (!withoutLinks) return null;
  if (withoutLinks.toLowerCase() === "tbd") return null;
  return withoutLinks;
};

const extractWinnerFromWikitext = (wikitext: string): string | null => {
  const lines = wikitext.split(/\r?\n/);
  for (const line of lines) {
    const match = line.match(/^\|\s*(winner|first)\s*=\s*(.+)$/i);
    if (!match?.[2]) continue;
    const candidate = sanitizeWinnerName(match[2]);
    if (candidate && candidate.split(" ").length >= 2) {
      return candidate;
    }
  }
  return null;
};

const findRaceWinnerFromWikipedia = async (race: RaceLookupRow): Promise<ResultSeed | null> => {
  const year = race.start_date.slice(0, 4);
  const searchTerms = [
    `${year} ${race.name} cycling`,
    `${year} ${race.name}`,
    `${race.name} ${year}`
  ];
  const titles: string[] = [];
  for (const term of searchTerms) {
    const found = await searchWikipediaTitles(term, 6);
    for (const title of found) {
      if (!titles.includes(title)) titles.push(title);
    }
    if (titles.length >= 12) break;
  }
  for (const title of titles) {
    if (!textContainsMostTokens(title, race.name, 2)) continue;
    const wikitext = await fetchWikipediaWikitext(title);
    if (!wikitext) continue;
    const winner = extractWinnerFromWikitext(wikitext);
    if (!winner) continue;
    return {
      resultType: "general_classification",
      rank: 1,
      athleteName: winner,
      teamName: null,
      nationality: null,
      resultText: null,
      source: "wikipedia",
      sourceUrl: `https://en.wikipedia.org/wiki/${encodeURIComponent(title.replace(/ /g, "_"))}`,
      metadata: {
        parser: "wikipedia-wikitext",
        wikipediaTitle: title
      }
    };
  }
  return null;
};

const buildRaceSearchTerms = (race: RaceLookupRow): string[] => {
  const year = race.start_date.slice(0, 4);
  const gender = (race.gender_division ?? "").toLowerCase();
  const genderToken = gender.includes("women") ? "women" : gender.includes("men") ? "men" : "";
  return Array.from(
    new Set(
      [`${year} ${race.name} ${genderToken}`.trim(), `${race.name} ${year}`.trim(), race.name.trim()].filter(Boolean)
    )
  );
};

const findRaceWinnerFromWikidata = async (race: RaceLookupRow): Promise<ResultSeed | null> => {
  const year = race.start_date.slice(0, 4);
  const searchTerms = buildRaceSearchTerms(race);
  const candidateIds: string[] = [];
  for (const term of searchTerms) {
    const ids = await searchEntityIds(term);
    for (const id of ids) {
      if (!candidateIds.includes(id)) {
        candidateIds.push(id);
      }
    }
    if (candidateIds.length >= 12) break;
  }

  for (const id of candidateIds) {
    const entity = await fetchEntity(id);
    if (!entity) continue;
    const namesText = getAllNames(entity).join(" ");
    const description = getDescription(entity);
    const candidateText = `${namesText} ${description}`.trim();
    if (!textContainsMostTokens(candidateText, race.name)) continue;
    if (!candidateText.includes(year)) continue;
    const seed = await extractWinnerSeed(entity, "general_classification", {
      raceName: race.name,
      raceDate: race.start_date
    });
    if (seed) return seed;
  }

  return null;
};

const buildStageSearchTerms = (race: RaceLookupRow, stage: StageLookupRow): string[] => {
  const year = (stage.date ?? race.start_date).slice(0, 4);
  const stageToken =
    stage.stage_number !== null
      ? `stage ${stage.stage_number}`
      : stage.name.trim()
        ? stage.name.trim()
        : "stage";
  return Array.from(
    new Set(
      [
        `${year} ${race.name} ${stageToken}`.trim(),
        `${race.name} ${stageToken} ${year}`.trim(),
        `${race.name} ${stageToken}`.trim()
      ].filter(Boolean)
    )
  );
};

const findStageWinnerFromWikidata = async (race: RaceLookupRow, stage: StageLookupRow): Promise<ResultSeed | null> => {
  const searchTerms = buildStageSearchTerms(race, stage);
  const candidateIds: string[] = [];
  for (const term of searchTerms) {
    const ids = await searchEntityIds(term, 8);
    for (const id of ids) {
      if (!candidateIds.includes(id)) {
        candidateIds.push(id);
      }
    }
    if (candidateIds.length >= 16) break;
  }

  for (const id of candidateIds) {
    const entity = await fetchEntity(id);
    if (!entity) continue;
    const label = getEnglishLabel(entity);
    const desc = getDescription(entity);
    const combined = `${label} ${desc}`;
    if (!textContainsMostTokens(combined, race.name)) continue;
    if (stage.stage_number !== null && !normalize(combined).includes(`stage ${stage.stage_number}`)) continue;
    const seed = await extractWinnerSeed(entity, "stage", {
      raceName: race.name,
      stageName: stage.name,
      stageNumber: stage.stage_number,
      stageDate: stage.date
    });
    if (seed) return seed;
  }
  return null;
};

const collectWinnerNames = (value: unknown, names: string[]) => {
  if (!value) return;
  if (typeof value === "string") {
    if (value.trim()) names.push(value.trim());
    return;
  }
  if (Array.isArray(value)) {
    for (const entry of value) collectWinnerNames(entry, names);
    return;
  }
  if (typeof value !== "object") return;
  const obj = value as Record<string, unknown>;
  if (typeof obj.name === "string" && obj.name.trim()) {
    names.push(obj.name.trim());
  }
  for (const nested of Object.values(obj)) {
    collectWinnerNames(nested, names);
  }
};

const extractWinnerFromOfficialWebsite = async (race: RaceLookupRow): Promise<ResultSeed | null> => {
  if (!race.official_website) return null;
  const html = await fetchHtml(race.official_website);
  if (!html) return null;
  const $ = cheerio.load(html);
  const winners: string[] = [];
  $('script[type="application/ld+json"]').each((_, node) => {
    const payload = $(node).html();
    if (!payload?.trim()) return;
    try {
      const parsed = JSON.parse(payload);
      const candidate =
        (parsed as Record<string, unknown>).winner ??
        (parsed as Record<string, unknown>).winners ??
        (parsed as Record<string, unknown>).athlete;
      collectWinnerNames(candidate, winners);
    } catch {
      // Ignore malformed json-ld payloads.
    }
  });
  const uniqueNames = Array.from(new Set(winners));
  const athleteName = uniqueNames.find((name) => name.split(" ").length >= 2);
  if (!athleteName) return null;
  return {
    resultType: "general_classification",
    rank: 1,
    athleteName,
    teamName: null,
    nationality: null,
    resultText: null,
    source: "official",
    sourceUrl: race.official_website,
    metadata: { parser: "jsonld-winner" }
  };
};

const upsertRaceResult = async (raceId: string, seed: ResultSeed) => {
  await query(
    `
    INSERT INTO race_results (
      race_id, result_type, rank, athlete_name, team_name, nationality,
      result_text, source, source_url, metadata, synced_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, NOW())
    ON CONFLICT (race_id, result_type, rank)
    DO UPDATE SET
      athlete_name = EXCLUDED.athlete_name,
      team_name = EXCLUDED.team_name,
      nationality = EXCLUDED.nationality,
      result_text = EXCLUDED.result_text,
      source = EXCLUDED.source,
      source_url = EXCLUDED.source_url,
      metadata = EXCLUDED.metadata,
      synced_at = NOW(),
      updated_at = NOW()
    `,
    [
      raceId,
      seed.resultType,
      seed.rank,
      seed.athleteName,
      seed.teamName,
      seed.nationality,
      seed.resultText,
      seed.source,
      seed.sourceUrl,
      JSON.stringify(seed.metadata)
    ]
  );
};

const upsertStageResult = async (stageId: string, seed: ResultSeed) => {
  await query(
    `
    INSERT INTO stage_results (
      stage_id, result_type, rank, athlete_name, team_name, nationality,
      result_text, source, source_url, metadata, synced_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, NOW())
    ON CONFLICT (stage_id, result_type, rank)
    DO UPDATE SET
      athlete_name = EXCLUDED.athlete_name,
      team_name = EXCLUDED.team_name,
      nationality = EXCLUDED.nationality,
      result_text = EXCLUDED.result_text,
      source = EXCLUDED.source,
      source_url = EXCLUDED.source_url,
      metadata = EXCLUDED.metadata,
      synced_at = NOW(),
      updated_at = NOW()
    `,
    [
      stageId,
      seed.resultType,
      seed.rank,
      seed.athleteName,
      seed.teamName,
      seed.nationality,
      seed.resultText,
      seed.source,
      seed.sourceUrl,
      JSON.stringify(seed.metadata)
    ]
  );
};

export const ensureRaceWinnerResult = async (race: RaceLookupRow): Promise<void> => {
  if (!raceLooksCompleted(race)) return;
  const existing = await query(
    `SELECT race_result_id FROM race_results WHERE race_id = $1 AND result_type = 'general_classification' LIMIT 1`,
    [race.race_id]
  );
  if ((existing.rowCount ?? 0) > 0) return;
  const winner =
    (await findRaceWinnerFromWikidata(race)) ??
    (await findRaceWinnerFromWikipedia(race)) ??
    (await extractWinnerFromOfficialWebsite(race));
  if (!winner) return;
  await upsertRaceResult(race.race_id, winner);
};

export const ensureStageWinnerResult = async (race: RaceLookupRow, stage: StageLookupRow): Promise<void> => {
  if (!stageLooksCompleted(stage)) return;
  const existing = await query(
    `SELECT stage_result_id FROM stage_results WHERE stage_id = $1 AND result_type = 'stage' LIMIT 1`,
    [stage.stage_id]
  );
  if ((existing.rowCount ?? 0) > 0) return;
  const winner = await findStageWinnerFromWikidata(race, stage);
  if (!winner) return;
  await upsertStageResult(stage.stage_id, winner);
};
