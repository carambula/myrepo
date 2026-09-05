import { Router } from "express";
import { optionalUser, type AuthUser } from "../auth.js";
import {
  FeedbackError,
  allowsCron,
  allowsFeedback,
  createFeedback,
  dripBuilds,
  getInternal,
  handleGithubComment,
  listForCaller,
  listPending,
  markShipped,
  saveProposal,
  setStatus,
  sweepStale
} from "../lib/feedback.js";

const router = Router();

type ReqUser = { user?: AuthUser };

const readCronTokens = (req: { header: (name: string) => string | undefined }) => [
  req.header("x-cron-token"),
  req.header("x-agent-token"),
  req.header("x-cron-secret"),
  req.header("authorization")
];

const handleError = (res: import("express").Response, error: unknown) => {
  if (error instanceof FeedbackError) {
    res.status(error.status).json({ error: error.message });
    return;
  }
  console.error(error);
  res.status(500).json({ error: "Unexpected feedback error." });
};

/** Public: submit a bug or idea (optional Min Cloud session; device_id required if unsigned). */
router.post("/v1/feedback", optionalUser, async (req, res) => {
  try {
    const user = (req as typeof req & ReqUser).user;
    const body = req.body || {};
    const row = await createFeedback({
      app: String(body.app || ""),
      kind: String(body.kind || ""),
      title: String(body.title || ""),
      body: String(body.body || ""),
      page: String(body.page || ""),
      userAgent: String(req.header("user-agent") || ""),
      userId: user?.id || null,
      userEmail: user?.email || null,
      deviceId: body.device_id == null ? null : String(body.device_id)
    });
    const { serializePublic } = await import("../lib/feedback.js");
    res.status(201).json(serializePublic(row));
  } catch (error) {
    handleError(res, error);
  }
});

/** Public: list the caller's own ideas. */
router.get("/v1/feedback", optionalUser, async (req, res) => {
  try {
    const user = (req as typeof req & ReqUser).user;
    const items = await listForCaller({
      userId: user?.id || null,
      deviceId: req.query.device_id == null ? null : String(req.query.device_id),
      app: req.query.app == null ? null : String(req.query.app),
      limit: req.query.limit == null ? 50 : Number(req.query.limit)
    });
    res.json({ items });
  } catch (error) {
    handleError(res, error);
  }
});

router.get("/internal/feedback/pending", async (req, res) => {
  try {
    if (!allowsCron(...readCronTokens(req))) {
      res.status(401).json({ error: "Cron authorization required." });
      return;
    }
    const items = await listPending(true);
    res.json({ items });
  } catch (error) {
    handleError(res, error);
  }
});

router.get("/internal/feedback/:id", async (req, res) => {
  try {
    const id = String(req.params.id);
    if (!allowsFeedback(id, ...readCronTokens(req))) {
      res.status(401).json({ error: "Authorization required." });
      return;
    }
    res.json(await getInternal(id));
  } catch (error) {
    handleError(res, error);
  }
});

router.post("/internal/feedback/:id/proposal", async (req, res) => {
  try {
    const id = String(req.params.id);
    if (!allowsFeedback(id, ...readCronTokens(req))) {
      res.status(401).json({ error: "Authorization required." });
      return;
    }
    const options = Array.isArray(req.body?.options) ? req.body.options : [];
    const issueNumber =
      req.body?.github_issue_number == null ? null : Number(req.body.github_issue_number);
    res.json(await saveProposal(id, options, issueNumber));
  } catch (error) {
    handleError(res, error);
  }
});

router.post("/internal/feedback/:id/status", async (req, res) => {
  try {
    const id = String(req.params.id);
    if (!allowsFeedback(id, ...readCronTokens(req))) {
      res.status(401).json({ error: "Authorization required." });
      return;
    }
    const status = String(req.body?.status || "");
    const allowed = new Set(["triaging", "needs_approval", "approved", "building", "declined"]);
    if (!allowed.has(status)) {
      res.status(400).json({ error: "Invalid status." });
      return;
    }
    res.json(
      await setStatus(
        id,
        status,
        req.body?.chosen_option == null ? null : String(req.body.chosen_option),
        req.body?.pr_url == null ? null : String(req.body.pr_url)
      )
    );
  } catch (error) {
    handleError(res, error);
  }
});

router.post("/internal/feedback/github-comment", async (req, res) => {
  try {
    if (!allowsCron(...readCronTokens(req))) {
      res.status(401).json({ error: "Cron authorization required." });
      return;
    }
    const result = await handleGithubComment({
      issueNumber: req.body?.issue_number == null ? null : Number(req.body.issue_number),
      issueBody: req.body?.issue_body == null ? null : String(req.body.issue_body),
      comment: String(req.body?.comment || ""),
      feedbackId: req.body?.feedback_id == null ? null : String(req.body.feedback_id),
      prUrl: req.body?.pr_url == null ? null : String(req.body.pr_url),
      prBranch: req.body?.pr_branch == null ? null : String(req.body.pr_branch)
    });
    res.json(result);
  } catch (error) {
    handleError(res, error);
  }
});

router.post("/internal/feedback/:id/shipped", async (req, res) => {
  try {
    const id = String(req.params.id);
    if (!allowsCron(...readCronTokens(req))) {
      res.status(401).json({ error: "Cron authorization required." });
      return;
    }
    res.json(
      await markShipped(id, req.body?.pr_url == null ? null : String(req.body.pr_url))
    );
  } catch (error) {
    handleError(res, error);
  }
});

/** Manual / cron tick: retry stale triage + drip one build. */
router.post("/internal/feedback/tick", async (req, res) => {
  try {
    if (!allowsCron(...readCronTokens(req))) {
      res.status(401).json({ error: "Cron authorization required." });
      return;
    }
    const swept = await sweepStale();
    const builds = await dripBuilds();
    res.json({ swept, builds });
  } catch (error) {
    handleError(res, error);
  }
});

export default router;
