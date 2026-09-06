import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  closetPicksCollectionUrlFromText,
  closetPicksYouTubeGuestKey,
  closetPicksYouTubeVideoId,
  matchClosetPicksYouTubeVideo,
  parseClosetPicksYouTubeFeed,
  parseClosetPicksYouTubeLockups,
  parseClosetPicksYouTubePage
} from "../src/lib/closet-picks-youtube.ts";
import { attachClosetPicksYouTube } from "../src/lib/closet-picks-youtube.ts";

const lockup = (videoId: string, title: string) => ({
  lockupViewModel: {
    contentId: videoId,
    contentType: "LOCKUP_CONTENT_TYPE_VIDEO",
    metadata: { lockupMetadataViewModel: { title: { content: title } } }
  }
});

describe("closet picks YouTube matching", () => {
  it("reads YouTube ids from watch URLs", () => {
    assert.equal(closetPicksYouTubeVideoId("Sc6UrpZR3Z4"), "Sc6UrpZR3Z4");
    assert.equal(closetPicksYouTubeVideoId("https://www.youtube.com/watch?v=Sc6UrpZR3Z4"), "Sc6UrpZR3Z4");
    assert.equal(closetPicksYouTubeVideoId("https://youtu.be/Sc6UrpZR3Z4"), "Sc6UrpZR3Z4");
    assert.equal(closetPicksYouTubeVideoId("not-a-url"), "");
  });

  it("normalizes guest names including mobile closet titles", () => {
    assert.equal(closetPicksYouTubeGuestKey("Pamela Anderson’s Closet Picks"), "pamela anderson");
    assert.equal(
      closetPicksYouTubeGuestKey("Wes Anderson’s Criterion Mobile Closet Picks"),
      "wes anderson"
    );
    assert.equal(
      closetPicksYouTubeGuestKey("Marianne Jean-Baptiste & Mike Leigh’s Closet Picks"),
      "marianne jean baptiste and mike leigh"
    );
  });

  it("extracts Criterion collection URLs from episode descriptions", () => {
    assert.equal(
      closetPicksCollectionUrlFromText(
        "All are available from criterion.com: https://www.criterion.com/shop/collection/1002-jason-sudeikis-s-closet-picks"
      ),
      "https://www.criterion.com/shop/collection/1002-jason-sudeikis-s-closet-picks"
    );
  });

  it("parses playlist lockups and RSS entries", () => {
    const videos = parseClosetPicksYouTubeLockups({
      contents: [lockup("Sc6UrpZR3Z4", "Jason Sudeikis’s Closet Picks")]
    });
    assert.equal(videos[0]?.videoId, "Sc6UrpZR3Z4");
    assert.equal(videos[0]?.guestKey, "jason sudeikis");

    const feed = parseClosetPicksYouTubeFeed(`
      <feed>
        <entry>
          <title>Pamela Anderson’s Closet Picks</title>
          <yt:videoId>abcABCdef12</yt:videoId>
          <published>2025-12-01T00:00:00+00:00</published>
          <media:description>Shop https://www.criterion.com/shop/collection/757-pamela-anderson-s-closet-picks</media:description>
        </entry>
      </feed>
    `);
    assert.equal(feed[0]?.videoId, "abcABCdef12");
    assert.equal(
      feed[0]?.collectionUrl,
      "https://www.criterion.com/shop/collection/757-pamela-anderson-s-closet-picks"
    );
  });

  it("reads continuation tokens from playlist HTML", () => {
    const page = parseClosetPicksYouTubePage(`
      <script>ytcfg.set({"INNERTUBE_API_KEY":"testkey","INNERTUBE_CONTEXT":{"client":{"clientName":"WEB"}}});</script>
      <script>ytInitialData = ${JSON.stringify({
        contents: [
          lockup("Sc6UrpZR3Z4", "Jason Sudeikis’s Closet Picks"),
          { continuationCommand: { token: "4qmFsgJh".padEnd(120, "A"), request: "CONTINUATION_REQUEST_TYPE_BROWSE" } }
        ]
      })};</script>
    `);
    assert.equal(page.innertubeKey, "testkey");
    assert.equal(page.videos[0]?.videoId, "Sc6UrpZR3Z4");
    assert.equal(page.continuation.startsWith("4qmFsgJh"), true);
  });

  it("matches films by collection URL, guest name, and and/ampersand variants", () => {
    const videos = [
      {
        videoId: "pamela12345",
        title: "Pamela Anderson’s Closet Picks",
        watchUrl: "https://www.youtube.com/watch?v=pamela12345",
        published: null,
        description: "",
        collectionUrl: "https://www.criterion.com/shop/collection/757-pamela-anderson-s-closet-picks",
        guestKey: closetPicksYouTubeGuestKey("Pamela Anderson’s Closet Picks")
      },
      {
        videoId: "leigh123456",
        title: "Marianne Jean-Baptiste and Mike Leigh’s Closet Picks",
        watchUrl: "https://www.youtube.com/watch?v=leigh123456",
        published: null,
        description: "",
        collectionUrl: null,
        guestKey: closetPicksYouTubeGuestKey("Marianne Jean-Baptiste and Mike Leigh’s Closet Picks")
      }
    ];

    assert.equal(
      matchClosetPicksYouTubeVideo(
        { sourceUrl: "https://www.criterion.com/shop/collection/757-pamela-anderson-s-closet-picks" },
        videos
      )?.videoId,
      "pamela12345"
    );
    assert.equal(
      matchClosetPicksYouTubeVideo({ sourceTitle: "Pamela Anderson’s Closet Picks" }, videos)?.videoId,
      "pamela12345"
    );
    assert.equal(
      matchClosetPicksYouTubeVideo(
        { sourceTitle: "Marianne Jean-Baptiste & Mike Leigh’s Closet Picks" },
        videos
      )?.videoId,
      "leigh123456"
    );

    const attached = attachClosetPicksYouTube(
      [{ title: "La strada", sourceTitle: "Pamela Anderson’s Closet Picks", sourceUrl: null }],
      videos
    );
    assert.equal(attached[0]?.youtubeUrl, "https://www.youtube.com/watch?v=pamela12345");
  });
});
