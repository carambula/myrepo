import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  closetPicksProgressLabel,
  formatJobElapsed,
  jobProgressLabel,
  withJobProgressLabel
} from "../src/lib/closet-picks-progress.ts";

const started = "2026-09-04T03:00:00.000Z";
const now = Date.parse("2026-09-04T03:12:05.000Z");

describe("closet picks rematch progress", () => {
  it("formats elapsed time", () => {
    assert.equal(formatJobElapsed(started, now), "12m 5s");
    assert.equal(formatJobElapsed(started, Date.parse("2026-09-04T03:00:09.000Z")), "9s");
    assert.equal(formatJobElapsed(started, Date.parse("2026-09-04T05:10:00.000Z")), "2h 10m");
    assert.equal(formatJobElapsed(null, now), "");
  });

  it("describes each rematch phase", () => {
    assert.equal(
      closetPicksProgressLabel(
        { status: "running", started_at: started, stats: { phase: "fetching-index" } },
        now
      ),
      "Fetching episode index (12m 5s)"
    );
    assert.equal(
      closetPicksProgressLabel(
        { status: "running", started_at: started, stats: { phase: "scraping-episodes", episodeDone: 45, episodeTotal: 226 } },
        now
      ),
      "Scraping episodes 45/226 (12m 5s)"
    );
    assert.equal(
      closetPicksProgressLabel(
        {
          status: "running",
          started_at: started,
          stats: { phase: "matching", matchDone: 210, matchTotal: 699, corrected: 4, missing: 12 }
        },
        now
      ),
      "Matching TMDB 210/699   4 corrected   12 missing (12m 5s)"
    );
  });

  it("summarizes a finished rematch", () => {
    assert.equal(
      closetPicksProgressLabel(
        {
          status: "ok",
          started_at: started,
          stats: { scanned: 687, corrected: 11, added: 2, missing: 12 }
        },
        now
      ),
      "Finished (12m 5s): 687 films   11 corrected   2 added   12 missing"
    );
  });

  it("shows elapsed even when a running rematch has no stats yet", () => {
    assert.equal(
      closetPicksProgressLabel({ status: "running", started_at: started, stats: null }, now),
      "Running (12m 5s)"
    );
  });

  it("attaches a progressLabel for health payloads", () => {
    const row = withJobProgressLabel(
      {
        name: "mov.closet.rematch",
        status: "running",
        started_at: started,
        stats: { phase: "loading-wikidata" }
      },
      now
    );
    assert.equal(row.progressLabel, "Loading Wikidata Criterion index (12m 5s)");
    assert.equal(
      jobProgressLabel({ name: "mov.feeds.refresh", status: "running", started_at: started, stats: {} }, now),
      "Running (12m 5s)"
    );
  });
});
