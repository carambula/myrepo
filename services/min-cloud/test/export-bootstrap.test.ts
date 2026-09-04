import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { catalogToBootstrap, flattenMovie, localRevision, mapSource } from "../scripts/export-bootstrap.mjs";

describe("export bootstrap", () => {
  it("flattens catalog movies into one bootstrap row per source link", () => {
    const rows = flattenMovie({
      title: "Fargo",
      tmdbId: 275,
      year: 1996,
      sources: [
        { identifier: "rewatchables", sourceTitle: "Fargo", rank: null },
        { identifier: "afi-100-1998", sourceTitle: "Fargo", rank: 84 }
      ]
    });
    assert.equal(rows.length, 2);
    assert.equal(rows[0].sourceIdentifier, "rewatchables");
    assert.equal(rows[1].sourceIdentifier, "afi-100-1998");
    assert.equal(rows[1].rank, 84);
    assert.equal(rows[0].tmdbId, 275);
  });

  it("keeps a movie with no source links", () => {
    const rows = flattenMovie({ title: "Orphan", tmdbId: 1, sources: [] });
    assert.equal(rows.length, 1);
    assert.equal(rows[0].sourceIdentifier, "");
    assert.equal(rows[0].title, "Orphan");
  });

  it("maps catalog sources and payload shape", () => {
    const bootstrap = catalogToBootstrap({
      revision: 70,
      generatedAt: "2026-09-03T00:00:00.000Z",
      sources: [{ identifier: "rewatchables", name: "The Rewatchables", type: "podcast", is_ranked: false, movie_count: 497 }],
      movies: [{ title: "Fargo", tmdbId: 275, sources: [{ identifier: "rewatchables" }] }]
    });
    assert.equal(bootstrap.version, "1.0");
    assert.equal(bootstrap.revision, 70);
    assert.deepEqual(mapSource(bootstrap.dataSources[0]), bootstrap.dataSources[0]);
    assert.equal(bootstrap.dataSources[0].isRankedList, false);
    assert.equal(bootstrap.movies.length, 1);
    assert.equal(localRevision(bootstrap), 70);
    assert.equal(localRevision({}), null);
  });
});
