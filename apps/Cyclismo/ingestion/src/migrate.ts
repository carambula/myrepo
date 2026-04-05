import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { query, closePool } from "./db.js";

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export const waitForDb = async (retries = 30, delayMs = 1000) => {
  let lastError: unknown;
  for (let attempt = 0; attempt < retries; attempt += 1) {
    try {
      await query("SELECT 1");
      return;
    } catch (error) {
      lastError = error;
      await sleep(delayMs);
    }
  }
  throw lastError;
};

const ensureMigrationsTable = async () => {
  await query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      id SERIAL PRIMARY KEY,
      filename TEXT UNIQUE NOT NULL,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
};

const fetchAppliedMigrations = async () => {
  const result = await query("SELECT filename FROM schema_migrations");
  return new Set(result.rows.map((row) => row.filename as string));
};

const runMigrationFile = async (filePath: string, filename: string) => {
  const sql = await fs.readFile(filePath, "utf8");
  await query(sql);
  await query("INSERT INTO schema_migrations (filename) VALUES ($1)", [filename]);
};

export const runMigrations = async (migrationsDir: string) => {
  await waitForDb();
  await ensureMigrationsTable();
  const applied = await fetchAppliedMigrations();
  const files = (await fs.readdir(migrationsDir))
    .filter((file) => file.endsWith(".sql"))
    .sort();

  for (const file of files) {
    if (applied.has(file)) {
      continue;
    }
    await runMigrationFile(path.join(migrationsDir, file), file);
  }
};

const runIfCli = async () => {
  const isCli = fileURLToPath(import.meta.url) === process.argv[1];
  if (!isCli) {
    return;
  }
  const migrationsDir = path.resolve(process.cwd(), "../backend/db/migrations");
  try {
    await waitForDb();
    await runMigrations(migrationsDir);
  } finally {
    await closePool();
  }
};

runIfCli().catch((error) => {
  console.error("Migration failed:", error);
  process.exitCode = 1;
});
