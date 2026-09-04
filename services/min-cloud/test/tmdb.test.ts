import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { catalogMovieFromTmdb, mapStreamingProviders } from "../src/lib/tmdb.ts";

describe("mapStreamingProviders", () => {
  it("dedupes providers and prefers the requested region", () => {
    const providers = mapStreamingProviders(
      {
        results: {
          US: {
            link: "https://www.themoviedb.org/movie/275/watch",
            flatrate: [
              { provider_id: 1899, provider_name: "HBO Max", logo_path: "/hbo.jpg", display_priority: 2 },
              { provider_id: 1899, provider_name: "HBO Max", logo_path: "/hbo.jpg", display_priority: 2 }
            ],
            ads: [{ provider_id: 337, provider_name: "Disney Plus", logo_path: "/d.jpg", display_priority: 1 }]
          }
        }
      },
      "US"
    );
    assert.equal(providers.length, 2);
    assert.equal(providers[0].name, "Disney Plus");
    assert.equal(providers[1].id, "1899");
  });
});

describe("catalogMovieFromTmdb", () => {
  it("uses a deterministic tmdb- id", () => {
    const movie = catalogMovieFromTmdb({
      id: 275,
      title: "Fargo",
      release_date: "1996-04-05",
      poster_path: "/fargo.jpg",
      genres: [{ name: "Crime" }]
    });
    assert.equal(movie.id, "tmdb-275");
    assert.equal(movie.year, 1996);
    assert.deepEqual(movie.genres, ["Crime"]);
  });
});
