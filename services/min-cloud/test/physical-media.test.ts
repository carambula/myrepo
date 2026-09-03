import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { mergePhysicalMedia, normalizePhysicalMedia } from "../src/lib/physical-media.ts";

const criterion = {
  editions: [{ id: "criterion-bluRay-1104", label: "criterion", format: "bluRay", spineNumber: "1104", notes: null }],
  hasCriterion: true,
  has4K: false,
  hasBluRay: true,
  manualOverride: false
};

describe("physical media", () => {
  it("normalizes overlay records", () => {
    const media = normalizePhysicalMedia(criterion);
    assert.ok(media);
    assert.equal(media.hasCriterion, true);
    assert.equal(media.editions[0].spineNumber, "1104");
  });

  it("keeps a manual override", () => {
    const stored = normalizePhysicalMedia({ ...criterion, manualOverride: true, has4K: false });
    const inferred = normalizePhysicalMedia({ ...criterion, has4K: true, editions: [] });
    const merged = mergePhysicalMedia(stored, inferred);
    assert.equal(merged?.manualOverride, true);
    assert.equal(merged?.has4K, false);
  });

  it("unions inferred editions onto stored data", () => {
    const stored = normalizePhysicalMedia({
      editions: [],
      hasCriterion: false,
      has4K: true,
      hasBluRay: true,
      manualOverride: false
    });
    const merged = mergePhysicalMedia(stored, normalizePhysicalMedia(criterion));
    assert.equal(merged?.hasCriterion, true);
    assert.equal(merged?.has4K, true);
    assert.equal(merged?.editions.length, 1);
  });
});
