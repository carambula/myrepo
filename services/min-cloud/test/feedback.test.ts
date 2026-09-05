import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  isApprovalComment,
  isOwnComment,
  parseChoice,
  redact
} from "../src/lib/feedback.js";

describe("feedback helpers", () => {
  it("redacts emails", () => {
    assert.equal(redact("hi me@example.com there", 80), "hi [email] there");
  });

  it("parses option choices", () => {
    const options = [
      { id: "small", title: "Small", summary: "", risk: null },
      { id: "medium", title: "Medium", summary: "", risk: null },
      { id: "full", title: "Full", summary: "", risk: null }
    ];
    assert.equal(parseChoice("small", options), "small");
    assert.equal(parseChoice("2", options), "medium");
    assert.equal(parseChoice("Go 3", options), "full");
  });

  it("treats bare option ids as approvals", () => {
    assert.equal(isApprovalComment("small", "small"), true);
    assert.equal(isApprovalComment("make small but prettier please", "small"), false);
  });

  it("ignores Min Cloud bot comments", () => {
    assert.equal(isOwnComment("Min Cloud opened this from in-app feedback."), true);
    assert.equal(isOwnComment("small"), false);
  });
});
