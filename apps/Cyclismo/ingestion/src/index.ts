import { closePool } from "./db.js";
import { runIngestion } from "./runIngestion.js";

runIngestion()
  .catch((error) => {
    console.error("Ingestion failed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await closePool();
  });
