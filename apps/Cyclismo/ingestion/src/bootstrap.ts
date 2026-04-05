import path from "node:path";
import { fileURLToPath } from "node:url";
import { runMigrations, waitForDb } from "./migrate.js";
import { closePool } from "./db.js";
import { runIngestion } from "./runIngestion.js";
import { runStreamingIngestion } from "./runStreamingIngestion.js";
import { runPodcastIngestion } from "./runPodcastIngestion.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const migrationsDir =
  process.env.MIGRATIONS_DIR ?? path.resolve(__dirname, "../../backend/db/migrations");

const run = async () => {
  await waitForDb();
  await runMigrations(migrationsDir);
  await runIngestion();
  await runStreamingIngestion();
  await runPodcastIngestion();
};

run()
  .catch((error) => {
    console.error("Bootstrap failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closePool();
  });
