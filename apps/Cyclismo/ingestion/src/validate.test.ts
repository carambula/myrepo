import { test } from "node:test";
import assert from "node:assert/strict";
import { raceSchema, teamSchema, athleteSchema } from "./validate.js";
import { sampleAthletes, sampleRaces, sampleTeams } from "./sources/sample.js";

test("sample races validate", () => {
  for (const race of sampleRaces) {
    assert.ok(raceSchema.safeParse(race).success);
  }
});

test("sample teams validate", () => {
  for (const team of sampleTeams) {
    assert.ok(teamSchema.safeParse(team).success);
  }
});

test("sample athletes validate", () => {
  for (const athlete of sampleAthletes) {
    assert.ok(athleteSchema.safeParse(athlete).success);
  }
});
