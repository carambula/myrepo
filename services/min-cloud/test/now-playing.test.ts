import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { noteLooksLikeIMAX, releaseDatesHaveIMAX } from "../src/lib/now-playing.ts";

describe("now playing IMAX notes", () => {
  it("matches IMAX as a word in the release note", () => {
    assert.equal(noteLooksLikeIMAX("IMAX"), true);
    assert.equal(noteLooksLikeIMAX("Opening in IMAX and 70mm"), true);
    assert.equal(noteLooksLikeIMAX("Limited"), false);
    assert.equal(noteLooksLikeIMAX(""), false);
  });

  it("reads IMAX from regional theatrical notes", () => {
    const hasIMAX = releaseDatesHaveIMAX(
      {
        results: [
          {
            iso_3166_1: "US",
            release_dates: [
              { type: 3, note: "IMAX" },
              { type: 3, note: null }
            ]
          }
        ]
      },
      "US"
    );
    assert.equal(hasIMAX, true);
  });
});
