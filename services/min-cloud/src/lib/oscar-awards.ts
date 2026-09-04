import { fetchJson, sleep } from "./http.js";

export type OscarAwardEntry = {
  id: string;
  category: string;
  year: number | null;
  recipient?: string | null;
  nominee?: string | null;
};

export type OscarAwards = {
  wins: OscarAwardEntry[];
  nominations: OscarAwardEntry[];
  totalWins: number;
  totalNominations: number;
  rawAwardsText?: string | null;
};

export type OscarMovie = {
  title: string;
  year?: number | null;
  tmdbId: number | null;
  imdbId?: string | null;
  oscarAwards?: OscarAwards | null | unknown;
};

export type OscarReportItem = {
  title: string;
  tmdbId: number | null;
  status: string;
  wins?: number;
  nominations?: number;
  method?: string | null;
  error?: string;
  rawAwards?: string | null;
  categories?: string[];
};

export type OscarOmdbBatchResult = {
  success: true;
  dryRun: boolean;
  abortedDueToKey: boolean;
  totalEligible: number;
  batchSize: number;
  offset: number;
  processedInBatch: number;
  nextOffset: number | null;
  enrichedCount: number;
  skippedCount: number;
  failedCount: number;
  noAwardsCount: number;
  report: OscarReportItem[];
};

export type OscarWikidataBatchResult = {
  success: true;
  totalEligible: number;
  batchSize: number;
  offset: number;
  processedInBatch: number;
  nextOffset: number | null;
  enrichedCount: number;
  noDataCount: number;
  failedCount: number;
  report: OscarReportItem[];
};

const OSCAR_CATEGORY_MAP: Record<string, string> = {
  "academy award for best picture": "Best Picture",
  "academy award for best director": "Best Director",
  "academy award for best actor": "Best Actor",
  "academy award for best actress": "Best Actress",
  "academy award for best actor in a leading role": "Best Actor",
  "academy award for best actress in a leading role": "Best Actress",
  "academy award for best supporting actor": "Best Supporting Actor",
  "academy award for best supporting actress": "Best Supporting Actress",
  "academy award for best actor in a supporting role": "Best Supporting Actor",
  "academy award for best actress in a supporting role": "Best Supporting Actress",
  "academy award for best original screenplay": "Best Original Screenplay",
  "academy award for best adapted screenplay": "Best Adapted Screenplay",
  "academy award for best writing, original screenplay": "Best Original Screenplay",
  "academy award for best writing, adapted screenplay": "Best Adapted Screenplay",
  "academy award for best cinematography": "Best Cinematography",
  "academy award for best film editing": "Best Film Editing",
  "academy award for best visual effects": "Best Visual Effects",
  "academy award for best original score": "Best Original Score",
  "academy award for best original song": "Best Original Song",
  "academy award for best sound editing": "Best Sound Editing",
  "academy award for best sound mixing": "Best Sound Mixing",
  "academy award for best sound": "Best Sound Editing",
  "academy award for best production design": "Best Production Design",
  "academy award for best art direction": "Best Production Design",
  "academy award for best costume design": "Best Costume Design",
  "academy award for best makeup and hairstyling": "Best Makeup and Hairstyling",
  "academy award for best makeup": "Best Makeup and Hairstyling",
  "academy award for best animated feature film": "Best Animated Feature",
  "academy award for best animated feature": "Best Animated Feature",
  "academy award for best international feature film": "Best International Feature Film",
  "academy award for best foreign language film": "Best International Feature Film",
  "academy award for best documentary feature film": "Best Documentary Feature",
  "academy award for best documentary feature": "Best Documentary Feature",
  "academy award for best documentary – feature": "Best Documentary Feature",
  "academy award for best live action short film": "Other",
  "academy award for best animated short film": "Other",
  "academy award for best documentary short film": "Other"
};

type OmdbResponse = {
  Response?: string;
  Error?: string;
  Awards?: string;
};

type WikidataBinding = {
  awardLabel?: { value?: string };
  type?: { value?: string };
  recipientLabel?: { value?: string };
};

const WIKIDATA_HEADERS = {
  "User-Agent": "MinCloud/0.1 (movie catalog)",
  Accept: "application/sparql-results+json"
};

export const parseOscarAwards = (awardsText?: string | null): OscarAwards | null => {
  if (!awardsText) {
    return null;
  }
  let totalWins = 0;
  let totalNominations = 0;
  const winsMatch = awardsText.match(/Won (\d+) Oscars?/);
  if (winsMatch) {
    totalWins = Number.parseInt(winsMatch[1], 10);
  }
  const nomsMatch = awardsText.match(/Nominated for (\d+) Oscars?/);
  if (nomsMatch) {
    totalNominations = Number.parseInt(nomsMatch[1], 10);
  }
  if (totalWins === 0 && totalNominations === 0) {
    return null;
  }
  return { wins: [], nominations: [], totalWins, totalNominations, rawAwardsText: awardsText };
};

export const mapWikidataCategory = (label: string) => OSCAR_CATEGORY_MAP[label.toLowerCase()] || "Other";

export const buildWikidataSparql = (imdbId: string) =>
  `
SELECT ?awardLabel ?type ?recipientLabel WHERE {
  ?film wdt:P345 "${imdbId}" .
  {
    ?film p:P166 ?stmt .
    ?stmt ps:P166 ?award .
    OPTIONAL { ?stmt pq:P1346 ?recipient . }
    BIND("won" AS ?type)
  } UNION {
    ?film p:P1411 ?stmt .
    ?stmt ps:P1411 ?award .
    OPTIONAL { ?stmt pq:P1346 ?recipient . }
    BIND("nominated" AS ?type)
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
}
ORDER BY ?type ?awardLabel`.trim();

export const uniqueMoviesByTmdbId = <T extends { tmdbId: number | null }>(movies: T[]): T[] => {
  const seen = new Set<number>();
  const out: T[] = [];
  for (const movie of movies) {
    if (movie.tmdbId == null || seen.has(movie.tmdbId)) {
      continue;
    }
    seen.add(movie.tmdbId);
    out.push(movie);
  }
  return out;
};

const oscarFromUnknown = (value: unknown): OscarAwards | null => {
  if (!value || typeof value !== "object") {
    return null;
  }
  return value as OscarAwards;
};

export const selectOscarOmdbCandidates = <T extends OscarMovie>(movies: T[], mode = "missing"): T[] =>
  uniqueMoviesByTmdbId(
    movies.filter((movie) => {
      if (!movie.tmdbId) {
        return false;
      }
      if (mode === "all") {
        return true;
      }
      return !movie.oscarAwards;
    })
  );

export const selectOscarWikidataCandidates = <T extends OscarMovie>(movies: T[], mode = "missing"): T[] =>
  uniqueMoviesByTmdbId(
    movies.filter((movie) => {
      if (!movie.tmdbId) {
        return false;
      }
      if (mode === "all") {
        return true;
      }
      const awards = oscarFromUnknown(movie.oscarAwards);
      if (!awards) {
        return false;
      }
      return (awards.wins?.length || 0) === 0 && (awards.nominations?.length || 0) === 0;
    })
  );

const requestOmdb = async (url: string): Promise<OmdbResponse> => {
  const data = await fetchJson<OmdbResponse>(url);
  if (data.Error === "Invalid API key!") {
    throw new Error("Invalid OMDB API key");
  }
  return data;
};

export const fetchOmdbAwards = async (imdbId: string, apiKey: string) => {
  if (!apiKey) {
    throw new Error("OMDB API key required");
  }
  const url = new URL("https://www.omdbapi.com/");
  url.searchParams.set("apikey", apiKey);
  url.searchParams.set("i", imdbId);
  const data = await requestOmdb(url.toString());
  if (data.Response !== "True") {
    return null;
  }
  return data.Awards || null;
};

export const fetchOmdbAwardsByTitle = async (title: string, year: number | null | undefined, apiKey: string) => {
  if (!apiKey) {
    throw new Error("OMDB API key required");
  }
  const url = new URL("https://www.omdbapi.com/");
  url.searchParams.set("apikey", apiKey);
  url.searchParams.set("t", title);
  if (year) {
    url.searchParams.set("y", String(year));
  }
  const data = await requestOmdb(url.toString());
  if (data.Response !== "True") {
    return null;
  }
  return data.Awards || null;
};

export const parseWikidataOscarBindings = (bindings: WikidataBinding[]): OscarAwards | null => {
  const wins: OscarAwardEntry[] = [];
  const nominations: OscarAwardEntry[] = [];
  const winCategories = new Set<string>();
  const nomCategories = new Set<string>();

  for (const binding of bindings) {
    const label = binding.awardLabel?.value || "";
    if (!label.toLowerCase().startsWith("academy award")) {
      continue;
    }
    const category = mapWikidataCategory(label);
    const recipient = binding.recipientLabel?.value || null;
    const type = binding.type?.value;
    const id = `${category}-${(recipient || "").toLowerCase().replace(/\s+/g, "-")}`.slice(0, 80);
    if (type === "won") {
      winCategories.add(category);
      wins.push({ id, category, year: null, recipient });
    } else {
      nomCategories.add(category);
      nominations.push({ id, category, year: null, nominee: recipient });
    }
  }

  if (!wins.length && !nominations.length) {
    return null;
  }
  return {
    wins,
    nominations,
    totalWins: winCategories.size,
    totalNominations: nomCategories.size
  };
};

export const fetchWikidataOscars = async (imdbId: string): Promise<OscarAwards | null> => {
  const url = `https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(buildWikidataSparql(imdbId))}`;
  const parsed = await fetchJson<{ results?: { bindings?: WikidataBinding[] } }>(url, WIKIDATA_HEADERS, {
    timeoutMs: 45000
  });
  return parseWikidataOscarBindings(parsed.results?.bindings ?? []);
};

export const mergeWikidataIntoOscar = (
  existing: OscarAwards | null | undefined,
  wikidata: OscarAwards | null | undefined
): OscarAwards | null => {
  if (!wikidata) {
    return existing ?? null;
  }
  return {
    wins: wikidata.wins,
    nominations: wikidata.nominations,
    totalWins: wikidata.totalWins,
    totalNominations: wikidata.totalNominations,
    rawAwardsText: existing?.rawAwardsText || null
  };
};

const nextOffsetFor = (offset: number, processed: number, total: number) => {
  const next = offset + processed;
  return next < total ? next : null;
};

export type OscarOmdbFetchers = {
  fetchImdbId: (tmdbId: number) => Promise<string | null>;
  fetchOmdbByImdb: (imdbId: string) => Promise<string | null>;
  fetchOmdbByTitle: (title: string, year: number | null) => Promise<string | null>;
  persist?: (movie: OscarMovie, awards: OscarAwards, imdbId?: string | null) => Promise<void>;
  delay?: (ms: number) => Promise<void>;
};

export const runOscarOmdbBatch = async (
  movies: OscarMovie[],
  options: {
    mode?: string;
    delayMs?: number;
    dryRun?: boolean;
    batchSize?: number;
    offset?: number;
  },
  fetchers: OscarOmdbFetchers
): Promise<OscarOmdbBatchResult> => {
  const mode = options.mode || "missing";
  const delayMs = Number(options.delayMs ?? 150);
  const dryRun = Boolean(options.dryRun);
  const batchSize = Math.min(Number(options.batchSize) || 100, 500);
  const offset = Math.max(Number(options.offset) || 0, 0);
  const candidates = selectOscarOmdbCandidates(movies, mode);
  const batch = candidates.slice(offset, offset + batchSize);
  let enrichedCount = 0;
  let skippedCount = 0;
  let failedCount = 0;
  let noAwardsCount = 0;
  let abortedDueToKey = false;
  const report: OscarReportItem[] = [];

  for (const movie of batch) {
    if (abortedDueToKey) {
      break;
    }
    let awardsText: string | null = null;
    let method: string | null = null;
    let imdbId = movie.imdbId || null;
    try {
      if (!imdbId && movie.tmdbId) {
        imdbId = await fetchers.fetchImdbId(movie.tmdbId);
      }
      if (imdbId) {
        awardsText = await fetchers.fetchOmdbByImdb(imdbId);
        method = "imdb";
      }
      if (!awardsText && movie.title && movie.year) {
        awardsText = await fetchers.fetchOmdbByTitle(movie.title, movie.year ?? null);
        method = "title";
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "failed";
      failedCount += 1;
      report.push({
        title: movie.title,
        tmdbId: movie.tmdbId,
        status: "failed",
        error:
          message === "Invalid OMDB API key"
            ? "Invalid OMDB API key — get a free key at https://www.omdbapi.com/apikey.aspx"
            : message
      });
      if (message === "Invalid OMDB API key") {
        abortedDueToKey = true;
        break;
      }
      if (delayMs > 0) {
        await (fetchers.delay ?? sleep)(delayMs);
      }
      continue;
    }

    const parsed = parseOscarAwards(awardsText);
    if (parsed) {
      if (!dryRun && fetchers.persist) {
        await fetchers.persist(movie, parsed, imdbId);
      }
      enrichedCount += 1;
      report.push({
        title: movie.title,
        tmdbId: movie.tmdbId,
        status: "enriched",
        wins: parsed.totalWins,
        nominations: parsed.totalNominations,
        method
      });
    } else {
      noAwardsCount += 1;
      report.push({
        title: movie.title,
        tmdbId: movie.tmdbId,
        status: "no-oscars",
        rawAwards: awardsText || null
      });
    }

    if (delayMs > 0) {
      await (fetchers.delay ?? sleep)(delayMs);
    }
  }

  return {
    success: true,
    dryRun,
    abortedDueToKey,
    totalEligible: candidates.length,
    batchSize,
    offset,
    processedInBatch: batch.length,
    nextOffset: nextOffsetFor(offset, batch.length, candidates.length),
    enrichedCount,
    skippedCount,
    failedCount,
    noAwardsCount,
    report
  };
};

export type OscarWikidataFetchers = {
  fetchImdbId: (tmdbId: number) => Promise<string | null>;
  fetchWikidata: (imdbId: string) => Promise<OscarAwards | null>;
  persist?: (movie: OscarMovie, awards: OscarAwards, imdbId?: string | null) => Promise<void>;
  persistImdb?: (movie: OscarMovie, imdbId: string) => Promise<void>;
  delay?: (ms: number) => Promise<void>;
};

export const runOscarWikidataBatch = async (
  movies: OscarMovie[],
  options: {
    mode?: string;
    delayMs?: number;
    batchSize?: number;
    offset?: number;
  },
  fetchers: OscarWikidataFetchers
): Promise<OscarWikidataBatchResult> => {
  const mode = options.mode || "missing";
  const delayMs = Math.max(Number(options.delayMs ?? 300), 0);
  const batchSize = Math.min(Number(options.batchSize) || 50, 200);
  const offset = Math.max(Number(options.offset) || 0, 0);
  const candidates = selectOscarWikidataCandidates(movies, mode);
  const batch = candidates.slice(offset, offset + batchSize);
  let enrichedCount = 0;
  let failedCount = 0;
  let noDataCount = 0;
  const report: OscarReportItem[] = [];

  for (const movie of batch) {
    try {
      let imdbId = movie.imdbId || null;
      if (!imdbId && movie.tmdbId) {
        imdbId = await fetchers.fetchImdbId(movie.tmdbId);
        if (imdbId && fetchers.persistImdb) {
          await fetchers.persistImdb(movie, imdbId);
        }
      }
      if (!imdbId) {
        noDataCount += 1;
        report.push({ title: movie.title, tmdbId: movie.tmdbId, status: "no-imdb" });
      } else {
        const wikidata = await fetchers.fetchWikidata(imdbId);
        if (wikidata) {
          const merged = mergeWikidataIntoOscar(oscarFromUnknown(movie.oscarAwards), wikidata);
          if (merged && fetchers.persist) {
            await fetchers.persist(movie, merged, imdbId);
          }
          enrichedCount += 1;
          report.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "enriched",
            wins: wikidata.wins.length,
            nominations: wikidata.nominations.length,
            categories: [...new Set([...wikidata.wins.map((win) => win.category), ...wikidata.nominations.map((nom) => nom.category)])]
          });
        } else {
          noDataCount += 1;
          report.push({ title: movie.title, tmdbId: movie.tmdbId, status: "no-wikidata" });
        }
      }
    } catch (error) {
      failedCount += 1;
      report.push({
        title: movie.title,
        tmdbId: movie.tmdbId,
        status: "failed",
        error: error instanceof Error ? error.message : "failed"
      });
    }
    if (delayMs > 0) {
      await (fetchers.delay ?? sleep)(delayMs);
    }
  }

  return {
    success: true,
    totalEligible: candidates.length,
    batchSize,
    offset,
    processedInBatch: batch.length,
    nextOffset: nextOffsetFor(offset, batch.length, candidates.length),
    enrichedCount,
    noDataCount,
    failedCount,
    report
  };
};
