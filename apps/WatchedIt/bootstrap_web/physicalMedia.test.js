"use strict";

const assert = require("assert");
const {
  emptyMedia,
  mergePhysicalMedia,
  isEmptyMedia,
  applyIndexToMovies,
  applyCriterionSourcePhysicalMedia,
  parseHdReportCriterion4K,
  seedCriterion4KFromTitles,
  seedCriterionFromSources,
} = require("./physicalMedia");

const inferred = emptyMedia();
inferred.has4K = true;
inferred.editions.push({ id: "o-4k", label: "other", format: "uhd4k", spineNumber: null, notes: null });

const stored = emptyMedia();
stored.hasCriterion = true;
stored.manualOverride = true;

const kept = mergePhysicalMedia(stored, inferred);
assert.strictEqual(kept.manualOverride, true);
assert.strictEqual(kept.has4K, false);

const union = mergePhysicalMedia(emptyMedia(), inferred);
assert.strictEqual(union.has4K, true);
assert.strictEqual(isEmptyMedia(union), false);

const movies = [
  { title: "Seven Samurai", tmdbId: 346, sourceIdentifier: "criterion" },
  { title: "8½", tmdbId: 78, sourceIdentifier: "criterion-closet-picks" },
  { title: "Heat", tmdbId: 949, sourceIdentifier: "rewatchables" },
];
const index = new Map([["949", inferred]]);
seedCriterionFromSources(movies, index);
assert.strictEqual(index.get("346").hasCriterion, true);
assert.strictEqual(index.get("78").hasCriterion, true);
const updated = applyIndexToMovies(movies, index);
assert.ok(updated >= 2);
assert.strictEqual(movies[0].physicalMedia.hasCriterion, true);
assert.strictEqual(movies[1].physicalMedia.hasCriterion, true);
assert.strictEqual(movies[2].physicalMedia.has4K, true);

const untitled = [{ title: "Dekalog", sourceIdentifier: "criterion-closet-picks", tmdbId: null }];
assert.strictEqual(applyCriterionSourcePhysicalMedia(untitled), 1);
assert.strictEqual(untitled[0].physicalMedia.hasCriterion, true);

const fourK = parseHdReportCriterion4K(`
  <h3>Citizen Kane (1941)</h3>
  <h3>The Wes Anderson Archive</h3>
`);
assert.ok(fourK.some((item) => item.title === "Citizen Kane"));
assert.ok(fourK.some((item) => item.title === "Rushmore"));
const catalog = [{ title: "Citizen Kane", year: 1941, tmdbId: 15 }];
const fourKIndex = seedCriterion4KFromTitles(fourK, catalog, new Map());
assert.strictEqual(fourKIndex.get("15").has4K, true);
assert.strictEqual(fourKIndex.get("15").hasCriterion, true);

console.log("physicalMedia tests passed");
