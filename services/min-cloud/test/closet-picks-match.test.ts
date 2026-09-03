import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  closetPicksMatchLooksWrong,
  directorsOverlap,
  prepareClosetPicksQuery,
  splitDirectorNames
} from "../src/lib/closet-picks-match.ts";
import { pickBestTmdbMatch } from "../src/lib/title-match.ts";
import { parseCriterionTmdbBindings, pickCriterionTmdbId } from "../src/lib/closet-picks-wikidata.ts";

describe("closet picks TMDB matching", () => {
  it("uses Criterion director and year instead of guest names", () => {
    const prepared = prepareClosetPicksQuery({
      title: "Naked",
      year: 1993,
      director: "Mike Leigh"
    });
    assert.equal(prepared.query, "Naked");
    assert.equal(prepared.year, 1993);
    assert.deepEqual(prepared.people, ["Mike Leigh"]);
    assert.equal(prepared.people.includes("Andrew Garfield"), false);
  });

  it("splits paired directors", () => {
    assert.deepEqual(splitDirectorNames("Jean-Pierre Dardenne and Luc Dardenne"), [
      "Jean-Pierre Dardenne",
      "Luc Dardenne"
    ]);
    assert.equal(directorsOverlap("Charles Chaplin", "Charlie Chaplin"), false);
    assert.equal(directorsOverlap("Francis Ford Coppola", "Francis Ford Coppola"), true);
    assert.equal(directorsOverlap("Joel and Ethan Coen", "Ethan Coen"), true);
  });

  it("flags a title-only remake match as wrong", () => {
    assert.equal(
      closetPicksMatchLooksWrong(
        { tmdbId: 522627, year: 2019, credits: { director: "Vincent D'Onofrio" } },
        { year: 1921, director: "Charles Chaplin" }
      ),
      true
    );
    assert.equal(
      closetPicksMatchLooksWrong(
        { tmdbId: 533, year: 1921, credits: { director: "Charles Chaplin" } },
        { year: 1921, director: "Charles Chaplin" }
      ),
      false
    );
  });

  it("prefers the Criterion year and director over a popular remake", () => {
    const match = pickBestTmdbMatch(
      "The Kid",
      [
        { id: 522627, title: "The Kid", release_date: "2019-03-08", popularity: 40, poster_path: "/new.jpg" },
        { id: 533, title: "The Kid", release_date: "1921-01-21", popularity: 12, poster_path: "/old.jpg" }
      ],
      {
        year: 1921,
        people: ["Charles Chaplin"],
        creditsById: {
          522627: { names: ["Vincent D'Onofrio", "Ethan Hawke"] },
          533: { names: ["Charles Chaplin", "Jackie Coogan"] }
        }
      }
    );
    assert.equal(match?.id, 533);
  });

  it("resolves a unique Wikidata Criterion title", () => {
    const hits = parseCriterionTmdbBindings([
      { tmdb: { value: "533" }, title: { value: "The Kid" }, year: { value: "1921" } },
      { tmdb: { value: "238" }, title: { value: "The Godfather" }, year: { value: "1972" } }
    ]);
    assert.equal(pickCriterionTmdbId(hits, "The Kid", 1921), 533);
    assert.equal(pickCriterionTmdbId(hits, "The Kid", 2019), null);
    assert.equal(pickCriterionTmdbId(hits, "Heat", 1995), null);
  });
});
