import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  filterIndexToCatalog,
  mediaFromWikidataRow,
  mergePhysicalMedia,
  normalizePhysicalMedia,
  overlayFromIndex,
  physicalMediaStats,
  qidFromUri,
  seedCriterionFromSources,
  seedCurated4K
} from "../src/lib/physical-media.ts";
import { buildPhysicalMediaIndexFromBindings } from "../src/lib/physical-media-wikidata.ts";

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

  it("builds a Wikidata index and seeds catalog-only overlay rows", () => {
    const index = buildPhysicalMediaIndexFromBindings({
      criterion: [{ tmdbId: undefined, tmdb: { value: "550" }, spine: { value: "42" } }],
      formats: [{ tmdb: { value: "550" }, format: { value: "http://www.wikidata.org/entity/Q20993976" } }],
      publishers: [
        {
          tmdb: { value: "238" },
          publisher: { value: "http://www.wikidata.org/entity/Q1150316" },
          publisherLabel: { value: "The Criterion Collection" }
        }
      ]
    });
    assert.equal(qidFromUri("http://www.wikidata.org/entity/Q20993976"), "Q20993976");
    assert.equal(index.get("550")?.hasCriterion, true);
    assert.equal(index.get("550")?.has4K, true);
    assert.equal(index.get("238")?.hasCriterion, true);

    seedCriterionFromSources(
      [
        { sourceIdentifier: "criterion", tmdbId: 13 },
        { sourceIdentifier: "criterion-closet-picks", tmdbId: 78 }
      ],
      index
    );
    seedCurated4K(index);
    assert.equal(index.get("13")?.hasCriterion, true);
    assert.equal(index.get("78")?.hasCriterion, true);
    assert.equal(index.get("155")?.has4K, true);

    const filtered = filterIndexToCatalog(index, [{ tmdbId: 550 }, { tmdbId: 13 }]);
    assert.equal(filtered.has("550"), true);
    assert.equal(filtered.has("13"), true);
    assert.equal(filtered.has("238"), false);
    assert.equal(Object.keys(overlayFromIndex(filtered).byTmdbId).length, 2);
  });

  it("infers publisher labels and reports catalog stats", () => {
    const arrow = mediaFromWikidataRow({ publisherLabel: "Arrow Video" });
    assert.equal(arrow.editions[0].label, "arrow");
    const stats = physicalMediaStats([
      { physicalMedia: criterion },
      { physicalMedia: null },
      { physicalMedia: { ...criterion, has4K: true, manualOverride: true } }
    ]);
    assert.equal(stats.withPhysicalMedia, 2);
    assert.equal(stats.withCriterion, 2);
    assert.equal(stats.manualOverrides, 1);
  });
});
