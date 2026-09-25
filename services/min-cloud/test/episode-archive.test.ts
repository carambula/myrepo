import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  episodeArchiveKey,
  mergeEpisodeArchives,
  PODCAST_ARCHIVE_CAP
} from "../src/lib/episode-archive.ts";

describe("mergeEpisodeArchives", () => {
  it("unions a truncated catalog with the live RSS archive", () => {
    const catalog = [
      { guid: "ep-new", title: "Fargo", audioUrl: "https://example.com/fargo.mp3", publishDate: "2025-04-01T10:00:00.000Z" },
      { guid: "ep-overlap", title: "Heat", audioUrl: "https://example.com/heat.mp3", publishDate: "2025-03-01T10:00:00.000Z" }
    ];
    const live = [
      { guid: "ep-overlap", title: "Heat (live)", audioUrl: "https://example.com/heat.mp3", publishDate: "2025-03-01T10:00:00.000Z" },
      {
        guid: "ep-rocky",
        title: "‘Rocky’ With Bill Simmons, Chris Ryan, and Van Lathan",
        audioUrl: "https://example.com/rocky.mp3",
        publishDate: "2018-04-17T10:00:00.000Z"
      }
    ];

    const merged = mergeEpisodeArchives(catalog, live);
    assert.equal(merged.length, 3);
    assert.equal(merged[0].title, "Fargo");
    assert.equal(merged[1].title, "Heat");
    assert.equal(merged[2].guid, "ep-rocky");
  });

  it("dedupes by audio URL when guids differ", () => {
    const merged = mergeEpisodeArchives(
      [{ guid: "catalog-guid", title: "Rocky", audioUrl: "https://cdn.example.com/rocky.mp3", publishDate: "2018-04-17T10:00:00.000Z" }],
      [{ guid: "live-guid", title: "Rocky (live)", audioUrl: "https://cdn.example.com/rocky.mp3", publishDate: "2018-04-17T10:00:00.000Z" }]
    );
    assert.equal(merged.length, 1);
    assert.equal(merged[0].title, "Rocky");
  });

  it("keeps same-title episodes when guids differ", () => {
    const merged = mergeEpisodeArchives(
      [{ guid: "mailbag-1", title: "Mailbag", publishDate: "2025-01-01T00:00:00.000Z" }],
      [{ guid: "mailbag-2", title: "Mailbag", publishDate: "2024-01-01T00:00:00.000Z" }]
    );
    assert.equal(merged.length, 2);
  });

  it("dedupes by title when guid and audio are missing", () => {
    const merged = mergeEpisodeArchives(
      [{ title: "Rocky", publishDate: "2018-04-17T10:00:00.000Z" }],
      [{ title: "rocky", publishDate: "2018-04-17T10:00:00.000Z" }]
    );
    assert.equal(merged.length, 1);
    assert.equal(merged[0].title, "Rocky");
  });

  it("caps the merged archive", () => {
    const extra = Array.from({ length: PODCAST_ARCHIVE_CAP + 20 }, (_, index) => ({
      guid: `ep-${index}`,
      title: `Episode ${index}`,
      publishDate: new Date(Date.UTC(2017, 0, 1 + index)).toISOString()
    }));
    const merged = mergeEpisodeArchives([], extra);
    assert.equal(merged.length, PODCAST_ARCHIVE_CAP);
    assert.equal(merged[0].guid, `ep-${PODCAST_ARCHIVE_CAP + 19}`);
  });

  it("builds a stable identity key", () => {
    assert.equal(episodeArchiveKey({ guid: " ABC " }), "g:abc");
    assert.equal(episodeArchiveKey({ audioUrl: "HTTPS://CDN.EXAMPLE.COM/A.MP3" }), "a:https://cdn.example.com/a.mp3");
    assert.equal(episodeArchiveKey({ title: " Rocky " }), "t:rocky");
  });
});
