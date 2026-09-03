import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  SNAPSHOT_KEEP,
  isCatalogPayload,
  pruneUnlabeledSnapshotIds,
  revertKind,
  rowTargetFromAction,
  shouldSkipDebouncedSnapshot
} from "../src/lib/admin-history.ts";

describe("catalog history helpers", () => {
  it("classifies revert of create, update, and delete", () => {
    assert.equal(revertKind(null, { title: "Fargo" }), "delete");
    assert.equal(revertKind({ title: "Fargo" }, { title: "Fargo 1996" }), "restore");
    assert.equal(revertKind({ title: "Fargo" }, null), "restore");
    assert.equal(revertKind(null, null), "none");
  });

  it("only treats movie and source edits as single-row reverts", () => {
    assert.equal(rowTargetFromAction("movie.create"), "movie");
    assert.equal(rowTargetFromAction("movie.delete"), "movie");
    assert.equal(rowTargetFromAction("source.update"), "source");
    assert.equal(rowTargetFromAction("catalog.ingest"), null);
    assert.equal(rowTargetFromAction("catalog.restore"), null);
    assert.equal(rowTargetFromAction("mov.import"), null);
  });

  it("requires sources, movies, streaming, and links in a snapshot payload", () => {
    assert.equal(isCatalogPayload({ sources: [], movies: [], streaming: [], links: [] }), true);
    assert.equal(isCatalogPayload({ sources: [], movies: [] }), false);
    assert.equal(isCatalogPayload(null), false);
    assert.equal(isCatalogPayload("nope"), false);
  });

  it("prunes unlabeled snapshots after the keep limit and never drops labeled ones", () => {
    const snapshots = [
      ...Array.from({ length: 42 }, (_, index) => ({
        id: `auto-${index}`,
        label: null,
        createdAt: new Date(2026, 0, 1, 0, index).toISOString()
      })),
      { id: "keep-me", label: "Before restore of abc", createdAt: "2025-01-01T00:00:00.000Z" }
    ];
    const pruned = pruneUnlabeledSnapshotIds(snapshots, SNAPSHOT_KEEP);
    assert.equal(pruned.length, 2);
    assert.ok(!pruned.includes("keep-me"));
    assert.ok(pruned.includes("auto-0"));
    assert.ok(pruned.includes("auto-1"));
    assert.ok(!pruned.includes("auto-41"));
  });

  it("debounces automatic snapshots for two minutes", () => {
    const now = Date.parse("2026-09-03T12:00:00.000Z");
    assert.equal(shouldSkipDebouncedSnapshot(null, now), false);
    assert.equal(shouldSkipDebouncedSnapshot("2026-09-03T11:59:00.000Z", now), true);
    assert.equal(shouldSkipDebouncedSnapshot("2026-09-03T11:57:00.000Z", now), false);
  });
});
