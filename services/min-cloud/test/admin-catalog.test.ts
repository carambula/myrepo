import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { adminCatalogHealth, buildDedupeGroups, type AdminMovie } from "../src/lib/admin-catalog.ts";

const movie = (overrides: Partial<AdminMovie>): AdminMovie => ({
  title: "Fargo",
  year: 1996,
  tmdbId: 275,
  sourceIdentifier: "rewatchables",
  sourceTitle: "Fargo",
  rank: 1,
  mpaaRating: "R",
  episodeDate: null,
  overview: "A crime story.",
  posterPath: "/x.jpg",
  backdropPath: "/y.jpg",
  genres: ["Crime"],
  streamingServices: [{ providerName: "Max" }],
  credits: { director: "Joel Coen" },
  trailer: { youtubeKey: "abc" },
  oscarAwards: null,
  physicalMedia: { hasCriterion: true },
  podcastEpisodeDescription: null,
  ...overrides
});

describe("admin catalog helpers", () => {
  it("counts missing catalog fields", () => {
    const health = adminCatalogHealth(
      [movie({ tmdbId: null, overview: null, genres: [], streamingServices: [], credits: null, trailer: null })],
      [{ identifier: "rewatchables", name: "The Rewatchables", type: "podcast", url: "https://example.com", isRankedList: false, movieCount: 1 }]
    );
    assert.equal(health.totalMovies, 1);
    assert.equal(health.missingTmdbId, 1);
    assert.equal(health.missingOverview, 1);
    assert.equal(health.missingGenres, 1);
  });

  it("groups duplicate source titles", () => {
    const groups = buildDedupeGroups(
      [movie({}), movie({ title: "Fargo (rewatch)", year: 1996 })],
      [{ identifier: "rewatchables", name: "The Rewatchables", type: "podcast", url: null, isRankedList: false, movieCount: 2 }]
    );
    assert.equal(groups.length, 1);
    assert.equal(groups[0].items.length, 2);
  });
});
