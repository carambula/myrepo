import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, it } from "node:test";
import { scrapeListItems } from "../src/lib/list-scrape.ts";
import {
  DELTA_IN_FLIGHT_PROVIDER,
  DELTA_IN_FLIGHT_SOURCE_ID,
  DELTA_IN_FLIGHT_URL,
  isDeltaInFlightProvider,
  isDeltaInFlightUrl,
  parseDeltaTitle,
  scrapeDeltaInFlightMovies,
  withDeltaInFlightProvider
} from "../src/lib/delta-in-flight.ts";

const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), "fixtures");
const html = readFileSync(path.join(fixtures, "delta-current-movies.html"), "utf8");

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
    assert.deepEqual(parseDeltaTitle("Lee Cronin's The Mummy"), { title: "The Mummy", year: null });
    assert.deepEqual(parseDeltaTitle("Lee Cronin&#39;s The Mummy"), { title: "The Mummy", year: null });
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
