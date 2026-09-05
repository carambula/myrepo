import path from "node:path";
import { fileURLToPath } from "node:url";
import cors from "cors";
import express from "express";
import { config } from "./config.js";
import { query } from "./db.js";
import { defaultMigrationsDir, runMigrations } from "./migrate.js";
import { requireAdmin, requireCron } from "./auth.js";
import { markInterruptedJobs, runNamedJob, startJobScheduler } from "./jobs.js";
import platformRouter from "./routes/platform.js";
import movRouter from "./routes/mov.js";
import podRouter from "./routes/pod.js";
import adminRouter from "./routes/admin.js";
import adminLocalRouter from "./routes/admin-local.js";
import agentRouter from "./routes/agent.js";
import feedbackRouter from "./routes/feedback.js";
import { ensureBootstrapAgent } from "./lib/agent.js";
import { dripBuilds, sweepStale } from "./lib/feedback.js";

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

app.use(agentRouter);
app.use(feedbackRouter);
app.use("/v1", platformRouter);
app.use("/v1/mov", movRouter);
app.use("/v1/pod", podRouter);
app.use("/v1/admin", requireAdmin, adminRouter);

const allowedImageHosts = new Set([
  "image.tmdb.org",
  "is1-ssl.mzstatic.com",
  "is2-ssl.mzstatic.com",
  "is3-ssl.mzstatic.com",
  "is4-ssl.mzstatic.com",
  "is5-ssl.mzstatic.com"
]);
app.get("/api/image-proxy", (req, res) => {
  const raw = String(req.query.url || "");
  try {
    const url = new URL(raw);
    if (!allowedImageHosts.has(url.hostname)) {
      res.status(400).end();
      return;
    }
    res.redirect(url.toString());
  } catch {
    res.status(400).end();
  }
});
app.use("/api", requireAdmin, adminLocalRouter);

app.post("/internal/jobs/:name", requireCron, async (req, res) => {
  try {
    const result = await runNamedJob(String(req.params.name));
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : "Job failed." });
  }
});

app.get("/admin", (_req, res) => {
  res.sendFile(path.join(publicDir, "mov-admin/index.html"));
});

app.get("/admin/jobs", (_req, res) => {
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
  await ensureBootstrapAgent();
  await markInterruptedJobs();
  app.listen(config.port, () => {
    console.log(`Min Cloud listening on ${config.port}`);
    startJobScheduler();
    // Feedback: retry untriaged rows every few hours; drip one Build every 3 minutes.
    setInterval(() => {
      void sweepStale().catch((error) => console.error("feedback sweep failed", error));
    }, 3 * 60 * 60 * 1000);
    setInterval(() => {
      void dripBuilds().catch((error) => console.error("feedback drip failed", error));
    }, 3 * 60 * 1000);
  });
};

start().catch((error) => {
  console.error("Failed to start Min Cloud:", error);
  process.exit(1);
});
