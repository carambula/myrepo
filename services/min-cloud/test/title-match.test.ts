import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { scrapeListItems } from "../src/lib/list-scrape.ts";
import {
  buildTmdbSearchInput,
  cleanPodcastTitle,
  cleanTitle,
  determineItemStatus,
  pickBestTmdbMatch,
  prepareMovieQuery,
  shouldSkipPodcastNoise
} from "../src/lib/title-match.ts";

describe("title cleaning and matching", () => {
  it("strips guest lists and quotes from Rewatchables titles", () => {
    assert.equal(
      cleanPodcastTitle("‘Toy Story 5’ With Bill Simmons, Chris Ryan, and Van Lathan"),
      "Toy Story 5"
    );
    assert.equal(cleanPodcastTitle("'Taxi Driver' With Bill Simmons and Chris Ryan"), "Taxi Driver");
    assert.equal(cleanPodcastTitle("Heat (1995)"), "Heat");
  });

  it("does not treat franchise numbers as list numbering", () => {
    assert.equal(cleanTitle("10 Things I Hate About You"), "10 Things I Hate About You");
    assert.equal(cleanTitle("7. How to Lose a Guy in 10 Days"), "How to Lose a Guy in 10 Days");
  });

  it("builds a TMDB query and year from a cleaned title", () => {
    const prepared = prepareMovieQuery(
      "‘Toy Story 5’ With Bill Simmons, Chris Ryan, and Van Lathan",
      "The 2026 film from Pixar."
    );
    assert.equal(prepared.title, "Toy Story 5");
    assert.equal(prepared.query, "Toy Story 5");
    assert.equal(prepared.year, 2026);
    assert.equal(prepared.sourceTitle.includes("With Bill Simmons"), true);
  });

  it("extracts a trailing year for search without leaving it in the query", () => {
    const input = buildTmdbSearchInput("The Thing (1982)");
    assert.equal(input.query, "The Thing");
    assert.equal(input.year, 1982);
  });

  it("picks the exact title over a franchise sibling", () => {
    const match = pickBestTmdbMatch("Toy Story 5", [
      { id: 862, title: "Toy Story", release_date: "1995-11-22", poster_path: "/a.jpg" },
      { id: 106448, title: "Toy Story 5", release_date: "2026-06-19", poster_path: "/b.jpg" }
    ]);
    assert.equal(match?.id, 106448);
  });

  it("prefers the year hint when titles collide", () => {
    const match = pickBestTmdbMatch("Dune", [
      { id: 841, title: "Dune", release_date: "1984-12-14", poster_path: "/a.jpg" },
      { id: 438631, title: "Dune", release_date: "2021-10-22", poster_path: "/b.jpg" }
    ], 2021);
    assert.equal(match?.id, 438631);
  });

  it("marks core metadata as enriched and skips Big Picture noise", () => {
    assert.equal(
      determineItemStatus({
        tmdbId: 275,
        year: 1976,
        posterPath: "/x.jpg",
        overview: "A night in New York.",
        genres: ["Crime"]
      }),
      "enriched"
    );
    assert.equal(determineItemStatus({ tmdbId: 275, year: null, posterPath: null, overview: null, genres: [] }), "light");
    assert.equal(shouldSkipPodcastNoise("big-picture", "Oscars Mailbag 2026", "Oscars Mailbag 2026"), true);
    assert.equal(shouldSkipPodcastNoise("big-picture", "Heat", "Heat"), false);
  });

  it("scrapes IMDb title links and skips chrome", () => {
    const items = scrapeListItems(
      "https://www.imdb.com/list/ls042702401/",
      `<a href="/title/tt0075314/">Taxi Driver</a><a href="/chart">IMDb</a><a href="/title/tt0114709/">Toy Story</a>`
    );
    assert.deepEqual(items.map((item) => item.title), ["Taxi Driver", "Toy Story"]);
  });
});
