import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { catalogMovieId, episodeFromImportMovie } from "../src/lib/catalog-import.ts";

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

  it("maps closet-picks guest copy onto the source-link episode description", () => {
    const episode = episodeFromImportMovie({
      title: "8½",
      sourceTitle: "Matthew McConaughey’s Closet Picks",
      episodeDate: "2026-02-01",
      sourceUrl: "https://www.criterion.com/closet-picks/matthew-mcconaughey",
      podcastEpisodeDescription: "Matthew McConaughey   also Christopher Nolan"
    });
    assert.deepEqual(episode, {
      title: "Matthew McConaughey’s Closet Picks",
      description: "Matthew McConaughey   also Christopher Nolan",
      publishDate: "2026-02-01",
      episodeId: "https://www.criterion.com/closet-picks/matthew-mcconaughey"
    });
  });
});
