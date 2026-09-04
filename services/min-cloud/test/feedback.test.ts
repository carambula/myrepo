import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  FeedbackInputError,
  feedbackAppLabel,
  mapFeedbackItem,
  normalizeBody,
  normalizeContext,
  normalizeDeviceId,
  normalizeTitle,
  parseFeedbackListQuery,
  voterKeyFor
} from "../src/lib/feedback.ts";

describe("feedback helpers", () => {
  it("normalizes titles and rejects short or long ones", () => {
    assert.equal(normalizeTitle("  Dark  mode  "), "Dark mode");
    assert.throws(() => normalizeTitle("hi"), FeedbackInputError);
    assert.throws(() => normalizeTitle("x".repeat(121)), FeedbackInputError);
  });

  it("caps details and requires a device id", () => {
    assert.equal(normalizeBody("  a note  "), "a note");
    assert.throws(() => normalizeBody("n".repeat(4001)), FeedbackInputError);
    assert.equal(normalizeDeviceId("device-123"), "device-123");
    assert.throws(() => normalizeDeviceId(""), FeedbackInputError);
    assert.throws(() => normalizeDeviceId("bad id"), FeedbackInputError);
  });

  it("keeps a small allow-listed context bag", () => {
    assert.deepEqual(
      normalizeContext({
        appVersion: "1.2.3",
        build: "88",
        platform: "iOS",
        systemVersion: "18.0",
        secret: "nope",
        extra: 12
      }),
      {
        appVersion: "1.2.3",
        build: "88",
        platform: "iOS",
        systemVersion: "18.0"
      }
    );
  });

  it("prefers a signed-in voter key", () => {
    assert.equal(voterKeyFor({ userId: "abc", deviceId: "phone" }), "user:abc");
    assert.equal(voterKeyFor({ deviceId: "phone" }), "device:phone");
  });

  it("parses board filters and hides hidden from the public query", () => {
    assert.deepEqual(parseFeedbackListQuery({ app: "mov", kind: "idea", status: "open", q: " poster " }), {
      app: "mov",
      kind: "idea",
      status: "open",
      q: "poster"
    });
    assert.deepEqual(parseFeedbackListQuery({ app: "all", kind: "", status: "all" }), {
      app: null,
      kind: null,
      status: null,
      q: ""
    });
    assert.throws(() => parseFeedbackListQuery({ status: "hidden" }), FeedbackInputError);
    assert.equal(parseFeedbackListQuery({ status: "hidden", includeHidden: true }).status, "hidden");
    assert.throws(() => parseFeedbackListQuery({ app: "strava" }), FeedbackInputError);
  });

  it("maps a row for the board and labels each min app", () => {
    const item = mapFeedbackItem(
      {
        id: "1",
        app: "pod",
        kind: "bug",
        status: "planned",
        title: "Resume is slow",
        body: "Cold launch waits on RSS.",
        context: { platform: "iOS" },
        vote_count: "12",
        author_handle: "aaron",
        created_at: new Date("2026-09-04T12:00:00.000Z"),
        updated_at: "2026-09-04T13:00:00.000Z",
        voted: 1
      },
      { includeBody: false }
    );
    assert.equal(item.voteCount, 12);
    assert.equal(item.voted, true);
    assert.equal(item.body, undefined);
    assert.equal(item.authorHandle, "aaron");
    assert.equal(feedbackAppLabel("pod"), "pod min");
    assert.equal(feedbackAppLabel("fit"), "fit min");
  });
});
