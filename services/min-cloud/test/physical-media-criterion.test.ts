import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";
import { parseCriterionTmdbBindings } from "../src/lib/closet-picks-wikidata.ts";
import {
  inferCriterionFormat,
  parseCriterionShopCollection,
  parseHdReportCriterion4K,
  seedCriterionCatalogTitles,
  shopTitleVariants
} from "../src/lib/physical-media-criterion.ts";

const fixtures = path.join(path.dirname(fileURLToPath(import.meta.url)), "fixtures");

describe("criterion shop catalog", () => {
  it("parses HD Report 4K headings and expands the Anderson box set", () => {
    const html = readFileSync(path.join(fixtures, "hd-report-criterion-4k.html"), "utf8");
    const titles = parseHdReportCriterion4K(html);
    assert.equal(titles.some((item) => item.title === "Citizen Kane" && item.year === 1941), true);
    assert.equal(titles.some((item) => item.title === "A Hard Day's Night" || item.title === "A Hard Day\u2019s Night"), true);
    assert.equal(titles.some((item) => item.title === "Menace II Society" && item.year === 1993), true);
    assert.equal(titles.some((item) => item.title === "Rushmore" && item.format === "uhd4k"), true);
    assert.equal(titles.some((item) => item.title === "The French Dispatch"), true);
    assert.equal(
      titles.some((item) => item.title === "The Criterion Collection 4k Blu-ray Movies"),
      false
    );
  });

  it("parses Criterion shop collection cards and formats", () => {
    const html = readFileSync(path.join(fixtures, "criterion-shop-collection.html"), "utf8");
    const titles = parseCriterionShopCollection(html);
    assert.deepEqual(
      titles.map((item) => [item.title, item.format, item.year]),
      [
        ["Seven Samurai", "uhd4k", 1954],
        ["The 400 Blows", "bluRay", 1959]
      ]
    );
    assert.equal(inferCriterionFormat("Blu-ray/DVD Combo"), "bluRay");
  });

  it("seeds Criterion 4K onto the matching Wikidata TMDB id", () => {
    const hits = parseCriterionTmdbBindings([
      { tmdb: { value: "15" }, title: { value: "Citizen Kane" }, year: { value: "1941" } },
      { tmdb: { value: "346" }, title: { value: "Seven Samurai" }, year: { value: "1954" } }
    ]);
    const index = seedCriterionCatalogTitles(
      [
        { title: "Citizen Kane", year: 1941, format: "uhd4k" },
        { title: "The French Dispatch of the Liberty, Kansas Evening Sun", year: 2021, format: "uhd4k" }
      ],
      hits,
      new Map()
    );
    assert.equal(index.get("15")?.hasCriterion, true);
    assert.equal(index.get("15")?.has4K, true);
    assert.equal(shopTitleVariants("The French Dispatch of the Liberty, Kansas Evening Sun").includes("The French Dispatch"), true);
  });
});
