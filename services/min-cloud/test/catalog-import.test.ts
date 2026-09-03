import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { catalogMovieId } from "../src/lib/catalog-import.ts";

describe("catalogMovieId", () => {
  it("uses tmdb ids when present", () => {
    assert.equal(catalogMovieId({ title: "Fargo", tmdbId: 275 }), "tmdb-275");
  });

  it("keeps an explicit id", () => {
    assert.equal(catalogMovieId({ id: "custom-1", title: "Fargo" }), "custom-1");
  });

  it("slugs titles when TMDB is missing", () => {
    assert.equal(catalogMovieId({ title: "Good Will Hunting" }), "title-good-will-hunting");
  });
});
