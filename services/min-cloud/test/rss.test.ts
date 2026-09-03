import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { newestEpisodesSince, parseRssDate, parseRssFeed } from "../src/lib/rss.ts";

const sampleFeed = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>The Rewatchables</title>
    <itunes:author>The Ringer</itunes:author>
    <description>Movies worth another look.</description>
    <language>en</language>
    <itunes:image href="https://example.com/art.jpg" />
    <item>
      <title>Fargo With Bill Simmons</title>
      <guid>ep-fargo</guid>
      <pubDate>Tue, 01 Apr 2025 10:00:00 GMT</pubDate>
      <itunes:duration>01:10:00</itunes:duration>
      <enclosure url="https://example.com/fargo.mp3" type="audio/mpeg" />
    </item>
    <item>
      <title>Heat</title>
      <guid>ep-heat</guid>
      <pubDate>Mon, 01 Jan 2024 10:00:00 GMT</pubDate>
      <enclosure url="https://example.com/heat.mp3" type="audio/mpeg" />
    </item>
  </channel>
</rss>`;

describe("parseRssFeed", () => {
  it("reads podcast metadata and episodes", () => {
    const parsed = parseRssFeed(sampleFeed);
    assert.equal(parsed.meta.title, "The Rewatchables");
    assert.equal(parsed.meta.author, "The Ringer");
    assert.equal(parsed.episodes.length, 2);
    assert.equal(parsed.episodes[0].guid, "ep-fargo");
    assert.equal(parsed.episodes[0].audioUrl, "https://example.com/fargo.mp3");
    assert.equal(parsed.episodes[0].durationSeconds, 4200);
  });

  it("filters episodes newer than a cutoff", () => {
    const parsed = parseRssFeed(sampleFeed);
    const fresh = newestEpisodesSince(parsed.episodes, "2025-01-01T00:00:00.000Z");
    assert.equal(fresh.length, 1);
    assert.equal(fresh[0].title, "Fargo With Bill Simmons");
  });

  it("parses RSS dates", () => {
    const iso = parseRssDate("Tue, 01 Apr 2025 10:00:00 GMT");
    assert.ok(iso);
    assert.equal(new Date(iso).getUTCFullYear(), 2025);
  });
});
