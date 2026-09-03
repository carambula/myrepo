/**
 * Re-scrape Closet Picks and rematch each film to TMDB using Criterion year/director.
 *
 *   npx tsx scripts/rematch-closet-picks.ts
 *   npx tsx scripts/rematch-closet-picks.ts --dry-run --limit 12
 *
 * Production: POST /v1/admin/jobs/mov.closet.rematch
 */
import { rematchClosetPicks } from "../src/lib/closet-picks-rematch.ts";

const args = new Set(process.argv.slice(2));
const limitArg = process.argv.find((value, index, all) => all[index - 1] === "--limit");

const result = await rematchClosetPicks({
  dryRun: args.has("--dry-run"),
  episodeLimit: limitArg ? Number(limitArg) : 0,
  fetchFilmPages: !args.has("--skip-film-pages"),
  preferWayback: args.has("--wayback")
});

console.log(
  `Closet Picks rematch: scanned ${result.scanned}   matched ${result.matched}   corrected ${result.corrected}   added ${result.added}   unchanged ${result.unchanged}   missing ${result.missing}`
);
for (const item of result.items.filter((row) => row.status === "missing" || row.status === "corrected").slice(0, 40)) {
  console.log(`  ${item.status}  ${item.title}  ${item.year ?? "?"}  ${item.director ?? "?"}  tmdb ${item.previousTmdbId ?? "—"} → ${item.tmdbId ?? "—"}`);
}
