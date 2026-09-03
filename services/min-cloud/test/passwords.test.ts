import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  hashPassword,
  hashToken,
  movieIdFromTmdb,
  normalizeHandle,
  podcastIdFromFeed,
  verifyPassword
} from "../src/lib/passwords.ts";

describe("passwords", () => {
  it("hashes and verifies scrypt passwords", () => {
    const stored = hashPassword("correct horse");
    assert.equal(verifyPassword("correct horse", stored), true);
    assert.equal(verifyPassword("wrong", stored), false);
  });

  it("hashes tokens stably", () => {
    assert.equal(hashToken("abc"), hashToken("abc"));
    assert.notEqual(hashToken("abc"), hashToken("abcd"));
  });

  it("normalizes handles and catalog ids", () => {
    assert.equal(normalizeHandle("Aaron Cloud!"), "aaroncloud");
    assert.equal(movieIdFromTmdb(275), "tmdb-275");
    assert.match(podcastIdFromFeed("https://feeds.example.com/show"), /^feed-[a-f0-9]+$/);
  });
});
