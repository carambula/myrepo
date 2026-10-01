import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, it } from "node:test";
import { scrapeListItems } from "../src/lib/list-scrape.ts";
import {
  DELTA_IN_FLIGHT_LETTERBOXD_URL,
  DELTA_IN_FLIGHT_PROVIDER,
  DELTA_IN_FLIGHT_SOURCE_ID,
  DELTA_IN_FLIGHT_URL,
  collectDeltaInFlightMovies,
  isDeltaInFlightLetterboxdUrl,
  isDeltaInFlightProvider,
  isDeltaInFlightUrl,
  letterboxdDeltaListPageCount,
  mergeDeltaInFlightMovies,
  parseDeltaTitle,
  scrapeDeltaInFlightMovies,
  scrapeLetterboxdDeltaInFlightMovies,
  withDeltaInFlightProvider
} from "../src/lib/delta-in-flight.ts";

const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), "fixtures");
const html = readFileSync(path.join(fixtures, "delta-current-movies.html"), "utf8");
const letterboxdHtml = readFileSync(path.join(fixtures, "delta-letterboxd-list.html"), "utf8");
const letterboxdPage2Html = readFileSync(path.join(fixtures, "delta-letterboxd-list-page-2.html"), "utf8");

describe("delta in-flight scrape", () => {
  it("recognizes the current-movies URL", () => {
    assert.equal(
      isDeltaInFlightUrl("https://www.delta.com/us/en/onboard/inflight-entertainment/current-movies"),
      true
    );
    assert.equal(
      isDeltaInFlightUrl("https://www.delta.com/us/en/onboard/inflight-entertainment/delta-studio"),
      false
    );
    assert.equal(isDeltaInFlightUrl("https://www.criterion.com/closet-picks"), false);
  });

  it("strips years and possessive credit prefixes", () => {
    assert.deepEqual(parseDeltaTitle("Moana (2026)"), { title: "Moana", year: 2026 });
    assert.deepEqual(parseDeltaTitle("Obsession ('26)"), { title: "Obsession", year: 2026 });
    assert.deepEqual(parseDeltaTitle("Lee Cronin's The Mummy", { stripPossessive: true }), {
      title: "The Mummy",
      year: null
    });
    assert.deepEqual(parseDeltaTitle("Lee Cronin&#39;s The Mummy", { stripPossessive: true }), {
      title: "The Mummy",
      year: null
    });
    assert.deepEqual(parseDeltaTitle("Ocean&#039;s Eleven (2001)"), { title: "Ocean's Eleven", year: 2001 });
  });

  it("reads unique titles and sections from the Delta page", () => {
    const movies = scrapeDeltaInFlightMovies(html);
    assert.deepEqual(
      movies.map((movie) => movie.title),
      ["Backrooms", "Moana", "The Mummy", "Coco", "The Prestige", "Obsession"]
    );
    assert.equal(movies[0]?.section, "New on Delta");
    assert.equal(movies[1]?.year, 2026);
    assert.equal(movies[3]?.section, "Popular on Delta");
    assert.equal(movies[5]?.year, 2026);
  });

  it("hooks the Delta page into list scrape", () => {
    const items = scrapeListItems(DELTA_IN_FLIGHT_URL, html);
    assert.deepEqual(
      items.map((item) => item.title),
      ["Backrooms", "Moana (2026)", "The Mummy", "Coco", "The Prestige", "Obsession (2026)"]
    );
  });

  it("reads Letterboxd list posters and page count", () => {
    assert.equal(isDeltaInFlightLetterboxdUrl(DELTA_IN_FLIGHT_LETTERBOXD_URL), true);
    assert.equal(isDeltaInFlightLetterboxdUrl(`${DELTA_IN_FLIGHT_LETTERBOXD_URL}page/2/`), true);
    assert.equal(isDeltaInFlightLetterboxdUrl("https://letterboxd.com/ebusch0320/list/other-list/"), false);
    assert.equal(letterboxdDeltaListPageCount(letterboxdHtml), 2);
    const movies = scrapeLetterboxdDeltaInFlightMovies(letterboxdHtml);
    assert.deepEqual(
      movies.map((movie) => `${movie.title} (${movie.year})`),
      [
        "10 Things I Hate About You (1999)",
        "Coco (2017)",
        "You, Me & Tuscany (2026)",
        "Ocean's Eleven (2001)",
        "The Prestige (2006)"
      ]
    );
    assert.equal(scrapeListItems(DELTA_IN_FLIGHT_LETTERBOXD_URL, letterboxdHtml).length, 5);
  });

  it("merges the official featured titles with the Letterboxd list", async () => {
    const official = scrapeDeltaInFlightMovies(html);
    const letterboxd = [
      ...scrapeLetterboxdDeltaInFlightMovies(letterboxdHtml),
      ...scrapeLetterboxdDeltaInFlightMovies(letterboxdPage2Html)
    ];
    const merged = mergeDeltaInFlightMovies(official, letterboxd);
    assert.equal(merged.some((movie) => movie.title === "Backrooms"), true);
    assert.equal(merged.some((movie) => movie.title === "10 Things I Hate About You"), true);
    assert.equal(merged.some((movie) => movie.title === "Zootopia 2"), true);
    assert.equal(merged.filter((movie) => movie.title === "Coco").length, 1);
    assert.equal(merged.filter((movie) => /tuscany/i.test(movie.title)).length, 1);
    assert.equal(merged.find((movie) => movie.title === "The Prestige")?.year, 2006);

    const collected = await collectDeltaInFlightMovies({
      officialHtml: html,
      letterboxdHtml: [letterboxdHtml, letterboxdPage2Html]
    });
    assert.equal(collected.official.length, 6);
    assert.equal(collected.letterboxd.length, 7);
    assert.equal(collected.movies.length, merged.length);
  });
});

describe("delta in-flight provider overlay", () => {
  it("adds the streamer when a movie is linked and strips it when not", () => {
    const tmdb = [{ id: "8", name: "Netflix", providerName: "Netflix" }];
    const linked = withDeltaInFlightProvider(tmdb, true);
    assert.equal(isDeltaInFlightProvider(linked[0] as { name: string }), true);
    assert.equal((linked[1] as { name: string }).name, "Netflix");
    assert.deepEqual(withDeltaInFlightProvider([...linked, DELTA_IN_FLIGHT_PROVIDER], false), tmdb);
    assert.equal(isDeltaInFlightProvider({ id: DELTA_IN_FLIGHT_SOURCE_ID, name: "Delta Studio" }), true);
  });
});
