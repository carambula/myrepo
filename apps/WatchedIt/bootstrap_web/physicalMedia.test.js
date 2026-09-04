"use strict";

const assert = require("assert");
const {
  emptyMedia,
  mergePhysicalMedia,
  isEmptyMedia,
  applyIndexToMovies,
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

console.log("physicalMedia tests passed");
