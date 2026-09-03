import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  mapWikidataCategory,
  mergeWikidataIntoOscar,
  parseOscarAwards,
  parseWikidataOscarBindings,
  runOscarOmdbBatch,
  runOscarWikidataBatch,
  selectOscarOmdbCandidates,
  selectOscarWikidataCandidates,
  uniqueMoviesByTmdbId
} from "../src/lib/oscar-awards.ts";

const movies = [
  { title: "No TMDB", tmdbId: null, oscarAwards: null },
  { title: "Heat", tmdbId: 949, year: 1995, oscarAwards: null },
  { title: "Heat again", tmdbId: 949, year: 1995, oscarAwards: null },
  {
    title: "Parasite",
    tmdbId: 496243,
    year: 2019,
    oscarAwards: { wins: [], nominations: [], totalWins: 4, totalNominations: 6, rawAwardsText: "Won 4 Oscars." }
  },
  {
    title: "Detailed",
    tmdbId: 13,
    oscarAwards: {
      wins: [{ id: "bp", category: "Best Picture", year: null }],
      nominations: [],
      totalWins: 1,
      totalNominations: 0
    }
  }
];

describe("oscar award parsing", () => {
  it("parses wins and nominations from OMDB awards text", () => {
    const parsed = parseOscarAwards("Won 4 Oscars. Another 142 wins & 228 nominations.");
    assert.ok(parsed);
    assert.equal(parsed.totalWins, 4);
    assert.equal(parsed.totalNominations, 0);
    assert.equal(parsed.rawAwardsText?.includes("Won 4 Oscars"), true);
    assert.deepEqual(parsed.wins, []);
  });

  it("parses singular oscar nomination text", () => {
    const parsed = parseOscarAwards("Nominated for 1 Oscar. Another 38 wins & 69 nominations.");
    assert.ok(parsed);
    assert.equal(parsed.totalWins, 0);
    assert.equal(parsed.totalNominations, 1);
  });

  it("returns null when the text has no Oscar counts", () => {
    assert.equal(parseOscarAwards("N/A"), null);
    assert.equal(parseOscarAwards("1 win & 2 nominations."), null);
    assert.equal(parseOscarAwards(""), null);
  });
});

describe("oscar candidate selection", () => {
  it("dedupes by tmdb id and skips movies without one", () => {
    const unique = uniqueMoviesByTmdbId(movies);
    assert.equal(unique.length, 3);
    assert.deepEqual(
      unique.map((movie) => movie.tmdbId),
      [949, 496243, 13]
    );
  });

  it("selects missing-award movies for OMDB enrich", () => {
    const missing = selectOscarOmdbCandidates(movies, "missing");
    assert.deepEqual(
      missing.map((movie) => movie.title),
      ["Heat"]
    );
    const all = selectOscarOmdbCandidates(movies, "all");
    assert.equal(all.length, 3);
  });

  it("selects award rows that still lack category detail for Wikidata", () => {
    const missing = selectOscarWikidataCandidates(movies, "missing");
    assert.deepEqual(
      missing.map((movie) => movie.title),
      ["Parasite"]
    );
  });
});

describe("wikidata oscar merge", () => {
  it("maps academy award labels and keeps OMDB raw text", () => {
    assert.equal(mapWikidataCategory("Academy Award for Best Picture"), "Best Picture");
    assert.equal(mapWikidataCategory("Academy Award for Best Foreign Language Film"), "Best International Feature Film");
    const parsed = parseWikidataOscarBindings([
      { awardLabel: { value: "Academy Award for Best Picture" }, type: { value: "won" } },
      {
        awardLabel: { value: "Academy Award for Best Director" },
        type: { value: "nominated" },
        recipientLabel: { value: "Bong Joon Ho" }
      },
      { awardLabel: { value: "Golden Globe Award for Best Picture" }, type: { value: "won" } }
    ]);
    assert.ok(parsed);
    assert.equal(parsed.totalWins, 1);
    assert.equal(parsed.totalNominations, 1);
    assert.equal(parsed.wins[0].category, "Best Picture");
    assert.equal(parsed.nominations[0].nominee, "Bong Joon Ho");
    const merged = mergeWikidataIntoOscar(
      { wins: [], nominations: [], totalWins: 4, totalNominations: 6, rawAwardsText: "Won 4 Oscars." },
      parsed
    );
    assert.ok(merged);
    assert.equal(merged.rawAwardsText, "Won 4 Oscars.");
    assert.equal(merged.totalWins, 1);
    assert.equal(merged.wins.length, 1);
  });
});

describe("oscar batch runners", () => {
  it("returns the batched OMDB payload the admin UI expects", async () => {
    const persisted: string[] = [];
    const result = await runOscarOmdbBatch(
      movies,
      { mode: "missing", delayMs: 0, batchSize: 100, offset: 0 },
      {
        fetchImdbId: async () => "tt0113277",
        fetchOmdbByImdb: async () => "Won 0 Oscars. Nominated for 1 Oscar.",
        fetchOmdbByTitle: async () => null,
        persist: async (movie) => {
          persisted.push(movie.title);
        },
        delay: async () => undefined
      }
    );
    assert.equal(result.success, true);
    assert.equal(result.totalEligible, 1);
    assert.equal(result.enrichedCount, 1);
    assert.equal(result.processedInBatch, 1);
    assert.equal(result.nextOffset, null);
    assert.equal(result.abortedDueToKey, false);
    assert.equal(result.report[0].status, "enriched");
    assert.equal(result.report[0].nominations, 1);
    assert.deepEqual(persisted, ["Heat"]);
  });

  it("aborts an OMDB batch on an invalid key without writing later movies", async () => {
    const result = await runOscarOmdbBatch(
      [
        { title: "One", tmdbId: 1, oscarAwards: null },
        { title: "Two", tmdbId: 2, oscarAwards: null }
      ],
      { mode: "missing", delayMs: 0 },
      {
        fetchImdbId: async () => "tt1",
        fetchOmdbByImdb: async () => {
          throw new Error("Invalid OMDB API key");
        },
        fetchOmdbByTitle: async () => null,
        delay: async () => undefined
      }
    );
    assert.equal(result.abortedDueToKey, true);
    assert.equal(result.failedCount, 1);
    assert.equal(result.enrichedCount, 0);
    assert.equal(result.report[0].status, "failed");
  });

  it("pages Wikidata enrich and reports no-imdb / enriched", async () => {
    const first = await runOscarWikidataBatch(
      [
        {
          title: "Parasite",
          tmdbId: 496243,
          imdbId: "tt6751668",
          oscarAwards: { wins: [], nominations: [], totalWins: 4, totalNominations: 6 }
        },
        {
          title: "Unknown",
          tmdbId: 2,
          oscarAwards: { wins: [], nominations: [], totalWins: 1, totalNominations: 0 }
        }
      ],
      { mode: "missing", delayMs: 0, batchSize: 1, offset: 0 },
      {
        fetchImdbId: async () => null,
        fetchWikidata: async () => ({
          wins: [{ id: "bp", category: "Best Picture", year: null }],
          nominations: [],
          totalWins: 1,
          totalNominations: 0
        }),
        delay: async () => undefined
      }
    );
    assert.equal(first.processedInBatch, 1);
    assert.equal(first.nextOffset, 1);
    assert.equal(first.enrichedCount, 1);
    assert.equal(first.report[0].status, "enriched");

    const second = await runOscarWikidataBatch(
      [
        {
          title: "Parasite",
          tmdbId: 496243,
          imdbId: "tt6751668",
          oscarAwards: { wins: [], nominations: [], totalWins: 4, totalNominations: 6 }
        },
        {
          title: "Unknown",
          tmdbId: 2,
          oscarAwards: { wins: [], nominations: [], totalWins: 1, totalNominations: 0 }
        }
      ],
      { mode: "missing", delayMs: 0, batchSize: 1, offset: 1 },
      {
        fetchImdbId: async () => null,
        fetchWikidata: async () => null,
        delay: async () => undefined
      }
    );
    assert.equal(second.nextOffset, null);
    assert.equal(second.noDataCount, 1);
    assert.equal(second.report[0].status, "no-imdb");
  });
});
