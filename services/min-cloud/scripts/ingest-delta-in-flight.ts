/**
 * Refresh the Delta in-flight catalog from the public current-movies page.
 *
 *   npx tsx scripts/ingest-delta-in-flight.ts
 *
 * Production: POST /v1/admin/jobs/mov.delta.refresh
 */
import { refreshDeltaInFlightCatalog } from "../src/lib/delta-in-flight-refresh.ts";
import { closePool } from "../src/db.ts";

const stats = await refreshDeltaInFlightCatalog();
console.log(JSON.stringify(stats, null, 2));
await closePool();
