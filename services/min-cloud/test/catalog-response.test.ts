import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  catalogCacheHeaders,
  catalogMovieStats,
  catalogPageMeta,
  formatCatalogRefreshMessage,
  shouldFetchNextCatalogPage,
  shouldSkipIncrementalCatalogSync
} from "../src/lib/catalog-response.ts";

describe("catalog response helpers", () => {
  it("pages until total even when truncated is missing", () => {
    assert.equal(
      shouldFetchNextCatalogPage({ fetched: 400, batchLength: 400, truncated: undefined, total: 1865 }),
      true
    );
    assert.equal(
      shouldFetchNextCatalogPage({ fetched: 1865, batchLength: 65, truncated: false, total: 1865 }),
      false
    );
  });

  it("falls back to truncated when total is absent", () => {
    assert.equal(shouldFetchNextCatalogPage({ fetched: 400, batchLength: 400, truncated: true }), true);
    assert.equal(shouldFetchNextCatalogPage({ fetched: 400, batchLength: 400, truncated: false }), false);
    assert.equal(shouldFetchNextCatalogPage({ fetched: 400, batchLength: 0, truncated: true }), false);
  });

  it("computes truncated from total rather than page-size equality", () => {
    assert.deepEqual(catalogPageMeta(1865, 0, 400, 400), {
      total: 1865,
      offset: 0,
      limit: 400,
      truncated: true
    });
    assert.deepEqual(catalogPageMeta(400, 0, 400, 400), {
      total: 400,
      offset: 0,
      limit: 400,
      truncated: false
    });
  });

  it("never skips an explicit refresh, and does not skip when remote has more movies", () => {
    assert.equal(
      shouldSkipIncrementalCatalogSync({
        force: true,
        hasSyncedBefore: true,
        localRevision: 184,
        remoteRevision: 184,
        localCount: 1834,
        remoteCount: 1865
      }),
      false
    );
    assert.equal(
      shouldSkipIncrementalCatalogSync({
        force: false,
        hasSyncedBefore: true,
        localRevision: 184,
        remoteRevision: 184,
        localCount: 1834,
        remoteCount: 1865
      }),
      false
    );
    assert.equal(
      shouldSkipIncrementalCatalogSync({
        force: false,
        hasSyncedBefore: true,
        localRevision: 184,
        remoteRevision: 184,
        localCount: 1865,
        remoteCount: 1865
      }),
      true
    );
    assert.equal(
      shouldSkipIncrementalCatalogSync({
        force: false,
        hasSyncedBefore: true,
        localRevision: 184,
        remoteRevision: 185,
        localCount: 1865,
        remoteCount: 1866
      }),
      false
    );
  });

  it("describes added vs zero-new refreshes honestly", () => {
    assert.equal(
      formatCatalogRefreshMessage({
        added: 31,
        updated: 1834,
        unmatched: 13,
        catalogCount: 1865,
        revision: 184,
        incomplete: false,
        fetched: 1865
      }),
      "Added 31 new titles, updated 1834. Catalog 1865 titles, revision 184. 13 titles have no TMDB match."
    );
    assert.equal(
      formatCatalogRefreshMessage({
        added: 0,
        updated: 400,
        unmatched: 0,
        catalogCount: 1865,
        revision: 184,
        incomplete: true,
        fetched: 400
      }),
      "No new titles. Catalog 1865 titles, revision 184. Incomplete catalog: received 400 of 1865 titles."
    );
  });

  it("counts unmatched movies and emits no-store headers", () => {
    assert.equal(catalogMovieStats([{ tmdbId: 1 }, { tmdbId: null }, {}]).unmatchedCount, 2);
    const headers = catalogCacheHeaders(184, 1865);
    assert.equal(headers["Cache-Control"], "no-store, no-cache, must-revalidate");
    assert.equal(headers["X-Catalog-Revision"], "184");
    assert.equal(headers["X-Catalog-Total"], "1865");
  });
});
