import path from "node:path";
import { fileURLToPath } from "node:url";
import cors from "cors";
import express from "express";
import { config } from "./config.js";
import { query } from "./db.js";
import { defaultMigrationsDir, runMigrations } from "./migrate.js";
import { requireAdmin, requireCron } from "./auth.js";
import { runNamedJob, startJobScheduler } from "./jobs.js";
import platformRouter from "./routes/platform.js";
import movRouter from "./routes/mov.js";
import podRouter from "./routes/pod.js";
import adminRouter from "./routes/admin.js";

const app = express();
const here = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.resolve(here, "../public");

app.use(cors());
app.use(express.json({ limit: "20mb" }));
app.use(express.static(publicDir));

app.get("/health", async (_req, res) => {
  try {
    await query("SELECT 1");
    res.json({
      ok: true,
      service: "min-cloud",
      apps: ["watchedit", "podlink"]
    });
  } catch {
    res.status(503).json({ ok: false, error: "database unavailable" });
  }
});

app.use("/v1", platformRouter);
app.use("/v1/mov", movRouter);
app.use("/v1/pod", podRouter);
app.use("/v1/admin", requireAdmin, adminRouter);

app.post("/internal/jobs/:name", requireCron, async (req, res) => {
  try {
    const result = await runNamedJob(String(req.params.name));
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : "Job failed." });
  }
});

app.get("/admin", (_req, res) => {
  res.sendFile(path.join(publicDir, "admin.html"));
});

app.get("/app", (_req, res) => {
  res.sendFile(path.join(publicDir, "index.html"));
});

app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error(error);
  res.status(500).json({ error: "Unexpected server error." });
});

const start = async () => {
  await runMigrations(defaultMigrationsDir());
  app.listen(config.port, () => {
    console.log(`Min Cloud listening on ${config.port}`);
    startJobScheduler();
  });
};

start().catch((error) => {
  console.error("Failed to start Min Cloud:", error);
  process.exit(1);
});
