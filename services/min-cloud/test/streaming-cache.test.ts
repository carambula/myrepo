import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { isFreshStreamingCache, STREAMING_CACHE_MS } from "../src/lib/streaming-cache.ts";

describe("streaming cache freshness", () => {
  it("treats a missing timestamp as stale", () => {
    assert.equal(isFreshStreamingCache(null), false);
    assert.equal(isFreshStreamingCache(undefined), false);
  });

  it("treats rows older than the cache window as stale", () => {
    const now = Date.parse("2026-09-04T21:00:00.000Z");
    assert.equal(
      isFreshStreamingCache(new Date(now - STREAMING_CACHE_MS + 1000).toISOString(), now),
      true
    );
    assert.equal(
      isFreshStreamingCache(new Date(now - STREAMING_CACHE_MS - 1000).toISOString(), now),
      false
    );
  });
});
