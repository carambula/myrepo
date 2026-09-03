import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  isFreshTheaterStaySnapshot,
  mergeTheaterStayRefresh,
  normalizeTheaterStayUpdate,
  theaterStayStats,
  toPublicMovies
} from "../src/lib/theater-stays-logic.ts";
import { CACHE_MS } from "../src/lib/now-playing.ts";

describe("theater stay merge and stats", () => {
  it("keeps manual pins and replaces inferred TMDB rows", () => {
    const existing = [
      { tmdbId: 1, title: "Pinned", hasIMAX: true, inCatalog: true, manualOverride: true },
      { tmdbId: 2, title: "Old inferred", hasIMAX: false, inCatalog: true, manualOverride: false }
    ];
    const incoming = [
      { tmdbId: 1, title: "Pinned From TMDB", hasIMAX: false },
      { tmdbId: 3, title: "New Stay", hasIMAX: true }
    ];
    const merged = mergeTheaterStayRefresh(existing, incoming, new Set([1, 3]));
    assert.deepEqual(
      merged.map((stay) => stay.tmdbId),
      [3, 1]
    );
    const pinned = merged.find((stay) => stay.tmdbId === 1);
    assert.equal(pinned?.title, "Pinned");
    assert.equal(pinned?.hasIMAX, true);
    assert.equal(pinned?.manualOverride, true);
    const fresh = merged.find((stay) => stay.tmdbId === 3);
    assert.equal(fresh?.inCatalog, true);
    assert.equal(fresh?.hasIMAX, true);
    assert.equal(merged.some((stay) => stay.tmdbId === 2), false);
  });

  it("counts catalog, IMAX, and manual stays", () => {
    const stats = theaterStayStats(
      [
        { tmdbId: 1, title: "A", hasIMAX: true, inCatalog: true, manualOverride: true },
        { tmdbId: 2, title: "B", hasIMAX: false, inCatalog: false, manualOverride: false }
      ],
      "2026-09-03T12:00:00.000Z",
      "US",
      "tmdb"
    );
    assert.equal(stats.inTheaters, 2);
    assert.equal(stats.inCatalog, 1);
    assert.equal(stats.withIMAX, 1);
    assert.equal(stats.manualOverrides, 1);
    assert.equal(stats.region, "US");
    assert.deepEqual(toPublicMovies([{ tmdbId: 1, title: "A", hasIMAX: true, inCatalog: true, manualOverride: false }]), [
      { tmdbId: 1, title: "A", hasIMAX: true }
    ]);
  });

  it("treats IMAX as in theaters and can remove a stay", () => {
    assert.equal(normalizeTheaterStayUpdate({ tmdbId: "nope" }), null);
    assert.deepEqual(normalizeTheaterStayUpdate({ tmdbId: 550, inTheaters: false, hasIMAX: false }), {
      tmdbId: 550,
      title: "",
      hasIMAX: false,
      remove: true
    });
    assert.deepEqual(normalizeTheaterStayUpdate({ tmdbId: 550, title: "Fight Club", hasIMAX: true }), {
      tmdbId: 550,
      title: "Fight Club",
      hasIMAX: true,
      remove: false
    });
  });

  it("treats snapshots older than the cache window as stale", () => {
    const now = Date.parse("2026-09-03T12:00:00.000Z");
    assert.equal(isFreshTheaterStaySnapshot(null, now), false);
    assert.equal(isFreshTheaterStaySnapshot(new Date(now - CACHE_MS + 1000).toISOString(), now), true);
    assert.equal(isFreshTheaterStaySnapshot(new Date(now - CACHE_MS - 1000).toISOString(), now), false);
  });
});
