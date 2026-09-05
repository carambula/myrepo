/**
 * Bug reports and ideas for all min apps.
 * Min Cloud stores the full report; GitHub issues are a redacted work queue
 * so public issues never carry a submitter's email or name.
 *
 * Ported from Cadence (CyclingData) feedback.py — see docs/FEEDBACK.md.
 */
import { createHmac, timingSafeEqual, randomUUID } from "node:crypto";
import { config } from "../config.js";
import { query } from "../db.js";

export class FeedbackError extends Error {
  status: number;
  constructor(status: number, detail: string) {
    super(detail);
    this.status = status;
  }
}

export const APPS = new Set(["mov", "pod", "vid", "cyc", "spin", "fit"]);
export const KINDS = new Set(["bug", "idea"]);

const STATUS = {
  received: "received",
  triaging: "triaging",
  needsApproval: "needs_approval",
  approved: "approved",
  building: "building",
  shipped: "shipped",
  declined: "declined"
} as const;

const PUBLIC_STATUS: Record<string, string> = {
  received: "received",
  triaging: "in review",
  needs_approval: "in review",
  approved: "building",
  building: "building",
  shipped: "shipped",
  declined: "declined"
};

const PENDING = [STATUS.received, STATUS.triaging];
const IN_FLIGHT_LABELS = [
  "triage-in-progress",
  "needs-approval",
  "approved-for-build",
  "in-progress"
];
const SWEEP_RETRY_HOURS = 6;
const BUILD_REPLAY_COOLDOWN_MS = 2 * 60 * 60 * 1000;
const BUILD_DRIP_MS = 180_000;
const EMAIL_RE = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi;
const FEEDBACK_ID_RE =
  /Feedback-Id:\s*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})/i;
const CRSR_RE = /(?:Bearer\s+)?(crsr_[A-Za-z0-9_-]+)/i;
const HTTP_URL_RE = /https?:\/\/[^\s,;<>]+/i;
const PICK_PREFIX = "(?:option|choice|#|go(?:\\s+with)?|do|pick|use|try)";

const OWN_COMMENT_MARKERS = [
  "min cloud opened this from in-app feedback",
  "cadence opened this from in-app feedback",
  "cursor is drafting options",
  "options are ready",
  "building **",
  "i'll comment them here",
  "approved **",
  "no build webhook",
  "no iterate webhook",
  "revising the options from your note",
  "queued behind another build",
  "starting the queued build",
  "build webhook failed",
  "cursor rejected the build webhook",
  "cloud agents api failed",
  "shipped in min cloud",
  "shipped in cadence",
  "starting a fix on the pr"
];

export type FeedbackRow = {
  id: string;
  app: string;
  user_id: string | null;
  device_id: string | null;
  kind: string;
  title: string;
  body: string;
  page: string;
  user_agent: string;
  status: string;
  github_issue_number: number | null;
  github_issue_url: string | null;
  proposal_json: string | null;
  chosen_option: string | null;
  pr_url: string | null;
  shipped_at: Date | null;
  last_dispatch_at: Date | null;
  last_build_at: Date | null;
  dispatch_error: string | null;
  created_at: Date;
  updated_at: Date;
  user_email?: string | null;
  user_name?: string | null;
};

type ProposalOption = { id: string; title: string; summary: string; risk: string | null };

const iso = (value: Date | string | null | undefined) => {
  if (!value) return "";
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return d.toISOString();
};

export const redact = (text: string | null | undefined, limit = 280) => {
  const cleaned = String(text || "")
    .replace(EMAIL_RE, "[email]")
    .replace(/\s+/g, " ")
    .trim();
  if (cleaned.length <= limit) return cleaned;
  return `${cleaned.slice(0, limit - 1).trimEnd()}…`;
};

const publicStatus = (status: string | null | undefined) =>
  PUBLIC_STATUS[(status || "").trim()] || "received";

const parseProposal = (raw: string | null | undefined): ProposalOption[] => {
  if (!raw) return [];
  try {
    const data = JSON.parse(raw) as unknown;
    const list = Array.isArray(data)
      ? data
      : data && typeof data === "object" && Array.isArray((data as { options?: unknown }).options)
        ? (data as { options: unknown[] }).options
        : [];
    return list.filter((item): item is ProposalOption => !!item && typeof item === "object");
  } catch {
    return [];
  }
};

export const serializePublic = (row: FeedbackRow) => ({
  id: row.id,
  app: row.app,
  kind: row.kind,
  title: row.title,
  status: publicStatus(row.status),
  status_raw: row.status,
  created_at: iso(row.created_at),
  shipped_at: iso(row.shipped_at) || null
});

export const serializeInternal = (row: FeedbackRow) => ({
  ...serializePublic(row),
  body: row.body || "",
  page: row.page || "",
  user_agent: row.user_agent || "",
  user_id: row.user_id,
  device_id: row.device_id,
  user_email: row.user_email ?? null,
  user_name: row.user_name ?? null,
  github_issue_number: row.github_issue_number,
  github_issue_url: row.github_issue_url,
  proposal: parseProposal(row.proposal_json),
  chosen_option: row.chosen_option,
  pr_url: row.pr_url,
  dispatch_error: row.dispatch_error,
  last_dispatch_at: iso(row.last_dispatch_at) || null,
  last_build_at: iso(row.last_build_at) || null,
  updated_at: iso(row.updated_at)
});

export const agentToken = (feedbackId: string) => {
  const secret = config.feedbackCronToken.trim();
  if (!secret || !feedbackId) return "";
  return createHmac("sha256", secret).update(`feedback:${feedbackId}`).digest("hex");
};

const tokenCandidates = (...values: Array<string | null | undefined>) => {
  const out: string[] = [];
  for (const value of values) {
    if (!value) continue;
    let text = value.trim();
    if (text.toLowerCase().startsWith("bearer ")) text = text.slice(7).trim();
    if (text) out.push(text);
  }
  return out;
};

const sameSecret = (left: string, right: string) => {
  if (!left || !right || left.length !== right.length) return false;
  try {
    return timingSafeEqual(Buffer.from(left), Buffer.from(right));
  } catch {
    return false;
  }
};

export const allowsCron = (...values: Array<string | null | undefined>) => {
  const cron = config.feedbackCronToken.trim();
  if (!cron) return false;
  return tokenCandidates(...values).some((tok) => sameSecret(tok, cron));
};

export const allowsFeedback = (feedbackId: string, ...values: Array<string | null | undefined>) => {
  if (allowsCron(...values)) return true;
  const scoped = agentToken(feedbackId);
  return tokenCandidates(...values).some((tok) => sameSecret(tok, scoped));
};

const mapRow = (row: Record<string, unknown>): FeedbackRow => ({
  id: String(row.id),
  app: String(row.app),
  user_id: row.user_id == null ? null : String(row.user_id),
  device_id: row.device_id == null ? null : String(row.device_id),
  kind: String(row.kind),
  title: String(row.title),
  body: String(row.body || ""),
  page: String(row.page || ""),
  user_agent: String(row.user_agent || ""),
  status: String(row.status),
  github_issue_number: row.github_issue_number == null ? null : Number(row.github_issue_number),
  github_issue_url: row.github_issue_url == null ? null : String(row.github_issue_url),
  proposal_json: row.proposal_json == null ? null : String(row.proposal_json),
  chosen_option: row.chosen_option == null ? null : String(row.chosen_option),
  pr_url: row.pr_url == null ? null : String(row.pr_url),
  shipped_at: row.shipped_at ? new Date(String(row.shipped_at)) : null,
  last_dispatch_at: row.last_dispatch_at ? new Date(String(row.last_dispatch_at)) : null,
  last_build_at: row.last_build_at ? new Date(String(row.last_build_at)) : null,
  dispatch_error: row.dispatch_error == null ? null : String(row.dispatch_error),
  created_at: new Date(String(row.created_at)),
  updated_at: new Date(String(row.updated_at)),
  user_email: row.user_email == null ? null : String(row.user_email),
  user_name: row.user_name == null ? null : String(row.user_name)
});

const getRow = async (id: string) => {
  const result = await query(
    `SELECT f.*, u.email AS user_email, u.display_name AS user_name
     FROM feedback f
     LEFT JOIN users u ON u.id = f.user_id
     WHERE f.id = $1`,
    [id]
  );
  if (!result.rows[0]) throw new FeedbackError(404, "Feedback not found");
  return mapRow(result.rows[0]);
};

const touch = async (id: string, fields: Record<string, unknown> = {}) => {
  const keys = Object.keys(fields);
  const sets = keys.map((key, i) => `${key} = $${i + 2}`);
  sets.push("updated_at = NOW()");
  const values = keys.map((key) => fields[key]);
  const result = await query(
    `UPDATE feedback SET ${sets.join(", ")} WHERE id = $1
     RETURNING *, NULL::text AS user_email, NULL::text AS user_name`,
    [id, ...values]
  );
  return mapRow(result.rows[0]);
};

const dailyLimit = () => Math.max(1, Number(config.feedbackDailyLimit || 20));

const isUnlimited = (email: string | null | undefined) =>
  !!email && config.feedbackUnlimitedEmails.includes(email.trim().toLowerCase());

const countToday = async (userId: string | null, deviceId: string | null, app: string) => {
  if (userId) {
    const result = await query(
      `SELECT COUNT(*)::int AS n FROM feedback
       WHERE user_id = $1 AND created_at >= NOW() - INTERVAL '24 hours'`,
      [userId]
    );
    return Number(result.rows[0]?.n || 0);
  }
  const result = await query(
    `SELECT COUNT(*)::int AS n FROM feedback
     WHERE device_id = $1 AND app = $2 AND created_at >= NOW() - INTERVAL '24 hours'`,
    [deviceId, app]
  );
  return Number(result.rows[0]?.n || 0);
};

export const createFeedback = async (input: {
  app: string;
  kind: string;
  title: string;
  body?: string;
  page?: string;
  userAgent?: string;
  userId?: string | null;
  userEmail?: string | null;
  deviceId?: string | null;
}) => {
  const app = (input.app || "").trim().toLowerCase();
  const kind = (input.kind || "").trim().toLowerCase();
  if (!APPS.has(app)) throw new FeedbackError(400, "app must be mov, pod, vid, cyc, spin, or fit");
  if (!KINDS.has(kind)) throw new FeedbackError(400, "kind must be bug or idea");
  const title = (input.title || "").trim();
  if (!title) throw new FeedbackError(400, "Give this a short title");
  const deviceId = (input.deviceId || "").trim() || null;
  if (!input.userId && !deviceId) {
    throw new FeedbackError(400, "Sign in or provide a device_id");
  }
  if (!isUnlimited(input.userEmail) && (await countToday(input.userId || null, deviceId, app)) >= dailyLimit()) {
    throw new FeedbackError(429, `You can send ${dailyLimit()} reports a day — try again tomorrow`);
  }
  const id = randomUUID();
  const result = await query(
    `INSERT INTO feedback (
       id, app, user_id, device_id, kind, title, body, page, user_agent, status
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,'received')
     RETURNING *, NULL::text AS user_email, NULL::text AS user_name`,
    [
      id,
      app,
      input.userId || null,
      deviceId,
      kind,
      title.slice(0, 200),
      (input.body || "").slice(0, 4000),
      (input.page || "").slice(0, 200),
      (input.userAgent || "").slice(0, 400)
    ]
  );
  let row = mapRow(result.rows[0]);
  row = await dispatchOutbound(row);
  return row;
};

export const listForCaller = async (input: {
  userId?: string | null;
  deviceId?: string | null;
  app?: string | null;
  limit?: number;
}) => {
  const limit = Math.max(1, Math.min(Number(input.limit || 50), 100));
  if (input.userId) {
    const result = await query(
      `SELECT * FROM feedback WHERE user_id = $1
       ORDER BY created_at DESC LIMIT $2`,
      [input.userId, limit]
    );
    return result.rows.map((row) => serializePublic(mapRow(row)));
  }
  const deviceId = (input.deviceId || "").trim();
  const app = (input.app || "").trim().toLowerCase();
  if (!deviceId || !APPS.has(app)) return [];
  const result = await query(
    `SELECT * FROM feedback WHERE device_id = $1 AND app = $2
     ORDER BY created_at DESC LIMIT $3`,
    [deviceId, app, limit]
  );
  return result.rows.map((row) => serializePublic(mapRow(row)));
};

export const listPending = async (retry = true) => {
  if (retry) {
    await sweepStale();
    await reconcileShippedGithub();
  }
  const result = await query(
    `SELECT f.*, u.email AS user_email, u.display_name AS user_name
     FROM feedback f
     LEFT JOIN users u ON u.id = f.user_id
     WHERE f.status = ANY($1::text[])
     ORDER BY f.created_at ASC`,
    [PENDING]
  );
  return result.rows.map((row) => serializeInternal(mapRow(row)));
};

export const getInternal = async (id: string) => serializeInternal(await getRow(id));

export const saveProposal = async (
  feedbackId: string,
  options: Array<Record<string, unknown>>,
  githubIssueNumber?: number | null
) => {
  const cleaned: ProposalOption[] = [];
  for (const option of options) {
    const oid = String(option.id || "").trim();
    const title = String(option.title || "").trim();
    if (!oid || !title) continue;
    cleaned.push({
      id: oid.slice(0, 40),
      title: title.slice(0, 120),
      summary: String(option.summary || "").slice(0, 2000),
      risk: String(option.risk || "").slice(0, 40) || null
    });
  }
  if (!cleaned.length) throw new FeedbackError(400, "Need at least one proposal option");
  const fields: Record<string, unknown> = {
    proposal_json: JSON.stringify({ options: cleaned }),
    status: STATUS.needsApproval
  };
  if (githubIssueNumber) fields.github_issue_number = Number(githubIssueNumber);
  let row = await touch(feedbackId, fields);
  try {
    await publishProposalOnGithub(row, cleaned);
  } catch (error) {
    console.error("GitHub proposal comment failed", feedbackId, error);
  }
  row = await getRow(feedbackId);
  return serializeInternal(row);
};

export const setStatus = async (
  feedbackId: string,
  status: string,
  chosenOption?: string | null,
  prUrl?: string | null
) => {
  let row = await getRow(feedbackId);
  if (row.status === STATUS.shipped) throw new FeedbackError(409, "This report already shipped");
  const fields: Record<string, unknown> = { status };
  if (chosenOption) fields.chosen_option = chosenOption.slice(0, 80);
  if (prUrl) fields.pr_url = prUrl.slice(0, 400);
  row = await touch(feedbackId, fields);
  if (status === STATUS.approved) {
    try {
      await enqueueOrStartBuild(row);
    } catch (error) {
      console.error("Build dispatch failed", feedbackId, error);
    }
  }
  return serializeInternal(await getRow(feedbackId));
};

export const isOwnComment = (body: string | null | undefined) => {
  const text = (body || "").toLowerCase();
  return OWN_COMMENT_MARKERS.some((marker) => text.includes(marker));
};

export const parseChoice = (body: string | null | undefined, options: ProposalOption[] = []) => {
  const text = String(body || "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return null;
  const ids = options.map((opt) => String(opt.id || "").trim()).filter(Boolean);
  for (const oid of ids) {
    const re = new RegExp(`(?<![a-z0-9_-])${oid.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?![a-z0-9_-])`, "i");
    if (re.test(text)) return oid;
  }
  const numbered = text.match(new RegExp(`\\b${PICK_PREFIX}\\s*([1-9])\\b`));
  if (numbered && options.length) {
    const idx = Number(numbered[1]) - 1;
    if (idx >= 0 && idx < options.length) return String(options[idx].id);
  }
  if (/^[1-9]$/.test(text) && options.length) {
    const idx = Number(text) - 1;
    if (idx >= 0 && idx < options.length) return String(options[idx].id);
  }
  for (const fallback of ["small", "medium", "full"]) {
    const re = new RegExp(`(?<![a-z0-9_-])${fallback}(?![a-z0-9_-])`);
    if (re.test(text)) return fallback;
  }
  return null;
};

export const isApprovalComment = (body: string | null | undefined, choice: string | null) => {
  if (!choice) return false;
  const text = String(body || "")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();
  const oid = choice.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  if (new RegExp(`^(?:option\\s+|choice\\s+|#)?${oid}[!.]?$`).test(text)) return true;
  if (new RegExp(`^${PICK_PREFIX}\\s*[1-9](?:\\s+(?:small|medium|full))?[!.]?$`).test(text)) return true;
  if (new RegExp(`^${PICK_PREFIX}\\s+${oid}(?:\\s+(?:small|medium|full))?[!.]?$`).test(text)) return true;
  if (/^[1-9]$/.test(text)) return true;
  return (
    /\b(approve(?:d)?|lgtm|ship it|build it|do it|go with|let'?s do)\b/.test(text) && text.length < 80
  );
};

const findByIssue = async (input: {
  issueNumber?: number | null;
  issueBody?: string | null;
  feedbackId?: string | null;
}) => {
  if (input.feedbackId) {
    try {
      return await getRow(input.feedbackId);
    } catch {
      return null;
    }
  }
  if (input.issueNumber) {
    const result = await query(
      `SELECT f.*, u.email AS user_email, u.display_name AS user_name
       FROM feedback f
       LEFT JOIN users u ON u.id = f.user_id
       WHERE f.github_issue_number = $1
       ORDER BY f.created_at DESC LIMIT 1`,
      [input.issueNumber]
    );
    if (result.rows[0]) return mapRow(result.rows[0]);
  }
  const match = FEEDBACK_ID_RE.exec(input.issueBody || "");
  if (match) {
    try {
      return await getRow(match[1]);
    } catch {
      return null;
    }
  }
  return null;
};

export const handleGithubComment = async (input: {
  issueNumber?: number | null;
  issueBody?: string | null;
  comment?: string;
  feedbackId?: string | null;
  prUrl?: string | null;
  prBranch?: string | null;
}) => {
  if (isOwnComment(input.comment)) return { action: "ignored", reason: "own_comment" };
  const row = await findByIssue(input);
  if (!row) throw new FeedbackError(404, "Feedback not found");
  if (row.status === STATUS.shipped || row.status === STATUS.declined) {
    return { action: "ignored", reason: row.status, id: row.id };
  }
  const options = parseProposal(row.proposal_json);
  const choice = parseChoice(input.comment, options);
  if (choice && isApprovalComment(input.comment, choice)) {
    if (
      row.status === STATUS.approved ||
      row.status === STATUS.building ||
      row.status === STATUS.shipped
    ) {
      if ((row.chosen_option || "").toLowerCase() === choice.toLowerCase()) {
        return replayApprovedBuild(row);
      }
    }
    const updated = await setStatus(row.id, STATUS.approved, choice);
    return { ...updated, action: "approved", chosen_option: choice };
  }
  if (row.status === STATUS.needsApproval) {
    const dest =
      config.feedbackCursorIterateWebhookUrl.trim() || config.feedbackCursorWebhookUrl.trim();
    try {
      await pingCursorWebhook(row, {
        event: "feedback.iterate",
        url: dest,
        extra: { comment: String(input.comment || "").slice(0, 2000) }
      });
    } catch (error) {
      console.error("Iterate webhook failed", row.id, error);
    }
    try {
      await commentOnGithub(row, iterateCommentMarkdown(Boolean(dest)));
    } catch (error) {
      console.error("GitHub iterate comment failed", row.id, error);
    }
    return { action: "iterate", id: row.id };
  }
  if (row.status === STATUS.approved || row.status === STATUS.building) {
    return pingPrFix(row, input.comment || "", {
      prUrl: input.prUrl,
      prBranch: input.prBranch
    });
  }
  return { action: "ignored", reason: "no_choice", id: row.id };
};

const fixCommentMarkdown = (started: boolean) =>
  started
    ? "Starting a fix on the PR from your note.\n"
    : "Got your note on the PR, but no Cloud Agents API key is set. Add `FEEDBACK_CURSOR_API_KEY` (cursor.com/dashboard → API Keys) and comment again.\n";

const pingPrFix = async (
  row: FeedbackRow,
  comment: string,
  extra: { prUrl?: string | null; prBranch?: string | null }
) => {
  const payload = {
    comment: comment.slice(0, 2000),
    pr_url: (extra.prUrl || row.pr_url || "").trim(),
    pr_branch: (extra.prBranch || "").trim()
  };
  if (!payload.pr_url && !payload.pr_branch) {
    return { action: "ignored", reason: "no_pr", id: row.id };
  }
  let started = false;
  try {
    started = Boolean(await launchCloudAgent(row, { event: "feedback.fix", extra: payload }));
    if (started) await touch(row.id, { dispatch_error: null });
  } catch (error) {
    console.error("PR fix kickoff failed", row.id, error);
    await noteBuildError(row, error);
  }
  try {
    await commentOnGithub(row, fixCommentMarkdown(started));
  } catch (error) {
    console.error("GitHub fix comment failed", row.id, error);
  }
  return { action: started ? "fix" : "ignored", reason: started ? null : "fix_failed", id: row.id };
};

const replayApprovedBuild = async (row: FeedbackRow) => {
  if (row.pr_url || row.status === STATUS.shipped) {
    return {
      action: "ignored",
      reason: "already_approved",
      id: row.id,
      chosen_option: row.chosen_option
    };
  }
  if (!buildKickoffConfigured()) {
    return {
      action: "ignored",
      reason: "already_approved",
      id: row.id,
      chosen_option: row.chosen_option
    };
  }
  await pingBuild(row, { announce: true });
  return {
    ...(await getInternal(row.id)),
    action: "approved",
    chosen_option: row.chosen_option,
    replayed: true
  };
};

export const markShipped = async (feedbackId: string, prUrl?: string | null) => {
  let row = await getRow(feedbackId);
  if (row.status !== STATUS.shipped) {
    const fields: Record<string, unknown> = {
      status: STATUS.shipped,
      shipped_at: new Date()
    };
    if (prUrl) fields.pr_url = prUrl.slice(0, 400);
    row = await touch(feedbackId, fields);
    try {
      await publishShippedOnGithub(row);
    } catch (error) {
      console.error("GitHub shipped update failed", row.id, error);
    }
  } else if (prUrl && !row.pr_url) {
    row = await touch(feedbackId, { pr_url: prUrl.slice(0, 400) });
  }
  return serializeInternal(await getRow(feedbackId));
};

export const dispatchOutbound = async (row: FeedbackRow) => {
  const errors: string[] = [];
  let current = row;
  try {
    if (!current.github_issue_number) {
      current = await createGithubIssue(current);
    }
  } catch (error) {
    console.error("GitHub issue failed", row.id, error);
    errors.push(`github: ${error instanceof Error ? error.message : String(error)}`);
  }
  try {
    await pingCursorWebhook(current);
  } catch (error) {
    console.error("Cursor webhook failed", row.id, error);
    errors.push(`webhook: ${error instanceof Error ? error.message : String(error)}`);
  }
  return touch(current.id, {
    github_issue_number: current.github_issue_number,
    github_issue_url: current.github_issue_url,
    last_dispatch_at: new Date(),
    dispatch_error: errors.join("; ").slice(0, 400) || null
  });
};

const staleDispatch = (row: FeedbackRow) => {
  if (!PENDING.includes(row.status as (typeof PENDING)[number])) return false;
  if (row.proposal_json) return false;
  if (!row.last_dispatch_at) return true;
  return Date.now() - row.last_dispatch_at.getTime() >= SWEEP_RETRY_HOURS * 3600_000;
};

export const sweepStale = async () => {
  const result = await query(
    `SELECT f.*, u.email AS user_email, u.display_name AS user_name
     FROM feedback f
     LEFT JOIN users u ON u.id = f.user_id
     WHERE f.status = ANY($1::text[])
     ORDER BY f.created_at ASC`,
    [PENDING]
  );
  let n = 0;
  for (const raw of result.rows) {
    const row = mapRow(raw);
    if (!staleDispatch(row)) continue;
    await dispatchOutbound(row);
    n += 1;
  }
  return n;
};

const buildKickoffConfigured = () =>
  Boolean(config.feedbackCursorApiKey.trim() || config.feedbackCursorBuildWebhookUrl.trim());

const buildLaneBusy = async (ignoreId?: string | null) => {
  const result = await query(
    `SELECT id FROM feedback
     WHERE last_build_at IS NOT NULL
       AND last_build_at > NOW() - ($1 * INTERVAL '1 millisecond')
       AND ($2::uuid IS NULL OR id <> $2)
     LIMIT 1`,
    [BUILD_DRIP_MS, ignoreId || null]
  );
  return Boolean(result.rows[0]);
};

const nextBuildCandidate = async () => {
  const result = await query(
    `SELECT f.*, u.email AS user_email, u.display_name AS user_name
     FROM feedback f
     LEFT JOIN users u ON u.id = f.user_id
     WHERE f.status = ANY($1::text[])
       AND f.pr_url IS NULL
     ORDER BY (f.last_build_at IS NULL) DESC, f.created_at ASC`,
    [[STATUS.approved, STATUS.building]]
  );
  const retryBefore = Date.now() - BUILD_REPLAY_COOLDOWN_MS;
  const authReady = Boolean(
    config.feedbackCursorApiKey.trim() || config.feedbackCursorBuildWebhookSecret.trim()
  );
  for (const raw of result.rows) {
    const row = mapRow(raw);
    if (!row.last_build_at || row.last_build_at.getTime() <= retryBefore) return row;
    const err = row.dispatch_error || "";
    if (authReady && (err.includes("401") || err.includes("403"))) return row;
  }
  return null;
};

const enqueueOrStartBuild = async (row: FeedbackRow) => {
  if (!buildKickoffConfigured()) {
    await startBuild(row, { ping: false });
    return;
  }
  if (await buildLaneBusy(row.id)) {
    await startBuild(row, { ping: false, queued: true });
    return;
  }
  await pingBuild(row, { announce: true });
};

export const dripBuilds = async () => {
  if (!buildKickoffConfigured()) return 0;
  if (await buildLaneBusy()) return 0;
  const row = await nextBuildCandidate();
  if (!row) return 0;
  const first = !row.last_build_at;
  await noteBuildPing(row);
  if (first) {
    try {
      await commentOnGithub(row, "Starting the queued build now.\n");
    } catch (error) {
      console.error("GitHub drip comment failed", row.id, error);
    }
  }
  return (await pingBuild(row, { announce: false })) ? 1 : 0;
};

const buildFailCommentMarkdown = (exc: unknown) => {
  const text = exc instanceof Error ? exc.message : String(exc);
  if (text.toLowerCase().includes("cloud agent")) {
    return (
      `Cloud Agents API failed (${text.split(":")[0].trim().slice(0, 80) || "error"}). ` +
      "Create a key at cursor.com/dashboard → API Keys and set `FEEDBACK_CURSOR_API_KEY` on Railway. " +
      "Then re-comment the same option.\n"
    );
  }
  if (text.includes("401") || text.includes("403")) {
    return (
      "Cursor rejected the Build webhook (401). Prefer `FEEDBACK_CURSOR_API_KEY` " +
      "(dashboard API key). Then re-comment the same option.\n"
    );
  }
  const detail = text.split(":")[0].trim().slice(0, 80) || "error";
  return `Build webhook failed (${detail}). Prefer \`FEEDBACK_CURSOR_API_KEY\`. Re-comment the same option after it is set.\n`;
};

const noteBuildError = async (row: FeedbackRow, exc: unknown) => {
  const msg = (exc instanceof Error ? exc.message : String(exc)).slice(0, 400);
  const changed = (row.dispatch_error || "") !== msg;
  await touch(row.id, { dispatch_error: msg });
  return changed;
};

const noteBuildPing = async (row: FeedbackRow) => {
  const now = new Date();
  await touch(row.id, { last_build_at: now, last_dispatch_at: now });
};

const pingBuild = async (row: FeedbackRow, opts: { announce: boolean }) => {
  if (opts.announce) {
    try {
      await startBuild(row, { ping: false });
    } catch (error) {
      console.error("GitHub approved comment failed", row.id, error);
    }
  }
  if (!buildKickoffConfigured()) {
    await noteBuildPing(row);
    return false;
  }
  await applyGithubLabels(row, ["approved-for-build"]);
  const extra = { chosen_option: row.chosen_option };
  try {
    if (await launchCloudAgent(row, { event: "feedback.approved", extra })) {
      await touch(row.id, { dispatch_error: null });
      await noteBuildPing(row);
      return true;
    }
    await pingCursorWebhook(row, {
      event: "feedback.approved",
      url: config.feedbackCursorBuildWebhookUrl.trim(),
      extra
    });
    await touch(row.id, { dispatch_error: null });
    await noteBuildPing(row);
    return true;
  } catch (error) {
    console.error("Build kickoff failed", row.id, error);
    await noteBuildPing(row);
    if (await noteBuildError(row, error)) {
      try {
        await commentOnGithub(row, buildFailCommentMarkdown(error));
      } catch (commentError) {
        console.error("GitHub build-fail comment failed", row.id, commentError);
      }
    }
    return false;
  }
};

const reconciledShipped = new Set<string>();

export const reconcileShippedGithub = async () => {
  const result = await query(
    `SELECT f.*, NULL::text AS user_email, NULL::text AS user_name
     FROM feedback f
     WHERE f.status = 'shipped' AND f.github_issue_number IS NOT NULL`
  );
  for (const raw of result.rows) {
    const row = mapRow(raw);
    if (reconciledShipped.has(row.id)) continue;
    try {
      await applyGithubLabels(row, ["shipped"]);
      await removeGithubLabels(row, IN_FLIGHT_LABELS);
      await closeGithubIssue(row);
      reconciledShipped.add(row.id);
    } catch (error) {
      console.error("GitHub shipped reconcile failed", row.id, error);
    }
  }
};

const githubHeaders = () => ({
  Authorization: `Bearer ${config.feedbackGithubToken.trim()}`,
  Accept: "application/vnd.github+json",
  "X-GitHub-Api-Version": "2022-11-28",
  "User-Agent": "MinCloud-Feedback/1.0"
});

const githubIssueApi = (row: FeedbackRow) => {
  const repo = config.feedbackGithubRepo.trim();
  if (!config.feedbackGithubToken.trim() || !repo || !row.github_issue_number) return null;
  return `${config.feedbackGithubApiUrl.replace(/\/$/, "")}/repos/${repo}/issues/${row.github_issue_number}`;
};

const githubFetch = async (url: string, init: RequestInit = {}) => {
  const response = await fetch(url, {
    ...init,
    headers: {
      ...githubHeaders(),
      ...(init.headers || {}),
      ...(init.body ? { "Content-Type": "application/json" } : {})
    }
  });
  return response;
};

const openedCommentMarkdown = () => {
  const notify = config.feedbackGithubNotifyUser.trim().replace(/^@/, "");
  const lines: string[] = [];
  if (notify) {
    lines.push(`@${notify} Min Cloud opened this from in-app feedback.`);
    lines.push("");
  }
  lines.push(
    "Cursor is drafting options. I'll comment them here and label `needs-approval` when they're ready."
  );
  return `${lines.join("\n").trim()}\n`;
};

export const webhookPrompt = (
  row: FeedbackRow,
  token: string,
  event = "feedback.created",
  extra: Record<string, unknown> = {}
) => {
  const publicUrl = config.publicUrl.replace(/\/$/, "");
  const fetchUrl = `${publicUrl}/internal/feedback/${row.id}`;
  const notify = config.feedbackGithubNotifyUser.trim().replace(/^@/, "") || "carambula";
  const issue =
    row.github_issue_url ||
    (row.github_issue_number ? `#${row.github_issue_number}` : "the GitHub issue");
  const number = row.github_issue_number;
  if (event === "feedback.approved") {
    const choice = String(extra.chosen_option || row.chosen_option || "the approved option");
    return (
      `Implement option ${choice} for Min Cloud feedback ${row.id}. Issue: ${issue}.\n` +
      `1. GET ${fetchUrl} with header X-Cron-Token: ${token}.\n` +
      `   Do not copy the submitter's name or email onto GitHub.\n` +
      `2. POST ${fetchUrl}/status {"status":"building","chosen_option":"${choice}"} with the same token.\n` +
      `3. Implement only that option. Open a PR whose body includes:\n` +
      `   Feedback-Id: ${row.id}\n` +
      `4. Do not use gh to comment or label. Do not merge the PR.\n`
    );
  }
  if (event === "feedback.iterate") {
    const note = redact(String(extra.comment || ""), 400);
    return (
      `The maintainer commented on Min Cloud feedback ${row.id}. Issue: ${issue}.\n` +
      `Comment: ${note || "(see GitHub)"}\n` +
      `1. GET ${fetchUrl} with header X-Cron-Token: ${token}.\n` +
      `2. Revise the 2-3 options. Do not start a PR.\n` +
      `3. POST ${fetchUrl}/proposal with the same token.\n` +
      `   Min Cloud will comment and mention @${notify}.\n`
    );
  }
  if (event === "feedback.fix") {
    const note = redact(String(extra.comment || ""), 400);
    const pr = String(extra.pr_url || row.pr_url || "the open PR");
    const branch = String(extra.pr_branch || "the PR branch");
    return (
      `The maintainer commented on the implementation PR for Min Cloud feedback ${row.id}.\n` +
      `PR: ${pr}\nBranch: ${branch}\nTheir note: ${note || "(see the PR)"}\n` +
      `1. You start on ${branch}. Fetch origin/main.\n` +
      `2. Rebase or merge main. Resolve conflicts.\n` +
      `3. Do what they asked and fix failing CI.\n` +
      `4. Push to the same branch. Do not open a new PR. Do not merge.\n` +
      `5. Keep this line in the PR body:\n   Feedback-Id: ${row.id}\n`
    );
  }
  return (
    `A ${row.app} min user sent a ${row.kind}. feedback_id=${row.id}. Issue: ${issue}.\n` +
    `1. GET ${fetchUrl} with header X-Cron-Token: ${token}\n` +
    `   Do not copy the submitter's name or email onto GitHub.\n` +
    `2. Draft 2-3 options (small / medium / full).\n` +
    `3. POST ${fetchUrl}/proposal with the same X-Cron-Token and JSON ` +
    `{"options":[...],"github_issue_number":${number}}.\n` +
    `   Min Cloud will comment on the issue and mention @${notify}.\n` +
    `4. Do not use gh to comment or label. Do not open a PR.\n`
  );
};

const proposalCommentMarkdown = (options: ProposalOption[]) => {
  const notify = config.feedbackGithubNotifyUser.trim().replace(/^@/, "");
  const lines: string[] = [];
  if (notify) {
    lines.push(`@${notify} options are ready.`);
    lines.push("");
  }
  options.forEach((option, i) => {
    lines.push(`${i + 1}. **${option.id}** — ${option.title}`);
    if (option.summary) lines.push(`   ${option.summary}`);
    if (option.risk) lines.push(`   Risk: ${option.risk}`);
    lines.push("");
  });
  lines.push(
    "Options are ready. Reply `small`, `medium`, `full`, `3`, or `Go 3` to start a build, or write a longer note to change the options."
  );
  return `${lines.join("\n").trim()}\n`;
};

const approvedCommentMarkdown = (row: FeedbackRow, queued = false) => {
  const notify = config.feedbackGithubNotifyUser.trim().replace(/^@/, "");
  const choice = row.chosen_option || "the chosen option";
  const lines: string[] = [];
  if (notify) {
    lines.push(`@${notify} building **${choice}**.`);
    lines.push("");
  }
  if (!buildKickoffConfigured()) {
    lines.push(
      "Approved, but no Build kickoff is configured. Set `FEEDBACK_CURSOR_API_KEY` or `FEEDBACK_CURSOR_BUILD_WEBHOOK_URL`."
    );
  } else if (queued) {
    lines.push(
      "Queued behind another build. Min Cloud starts one Build at a time and will ping Cursor next."
    );
  } else {
    lines.push("Cursor is opening a PR. I'll leave this issue open until it ships.");
  }
  return `${lines.join("\n").trim()}\n`;
};

const iterateCommentMarkdown = (started: boolean) =>
  started
    ? "Got it — revising the options from your note.\n"
    : "Got your note, but no iterate webhook is configured, so nothing started. Reply `small` / `medium` / `full` / `3` to approve, or set `FEEDBACK_CURSOR_ITERATE_WEBHOOK_URL`.\n";

const shippedCommentMarkdown = (row: FeedbackRow) =>
  `Shipped in Min Cloud via ${(row.pr_url || "").trim() || "a merged PR"}.\n`;

const removeGithubLabels = async (row: FeedbackRow, labels: string[]) => {
  const base = githubIssueApi(row);
  if (!base) return;
  for (const label of labels) {
    const response = await githubFetch(`${base}/labels/${encodeURIComponent(label)}`, {
      method: "DELETE"
    });
    if (response.status >= 300 && response.status !== 404) {
      console.warn("GitHub label remove failed", row.id, label, response.status);
    }
  }
};

const closeGithubIssue = async (row: FeedbackRow) => {
  const base = githubIssueApi(row);
  if (!base) return;
  const response = await githubFetch(base, {
    method: "PATCH",
    body: JSON.stringify({ state: "closed" })
  });
  if (response.status >= 300) {
    console.warn("GitHub close failed", row.id, response.status, await response.text());
  }
};

const publishShippedOnGithub = async (row: FeedbackRow) => {
  try {
    await commentOnGithub(row, shippedCommentMarkdown(row));
  } catch (error) {
    console.error("GitHub shipped comment failed", row.id, error);
  }
  await applyGithubLabels(row, ["shipped"]);
  await removeGithubLabels(row, IN_FLIGHT_LABELS);
  await closeGithubIssue(row);
};

const applyGithubLabels = async (row: FeedbackRow, labels: string[]) => {
  const base = githubIssueApi(row);
  if (!base) return;
  const response = await githubFetch(`${base}/labels`, {
    method: "POST",
    body: JSON.stringify({ labels })
  });
  if (response.status >= 300) {
    console.warn("GitHub label failed", row.id, response.status, await response.text());
  }
};

const startBuild = async (row: FeedbackRow, opts: { ping?: boolean; queued?: boolean } = {}) => {
  try {
    await commentOnGithub(row, approvedCommentMarkdown(row, opts.queued));
  } catch (error) {
    console.error("GitHub approved comment failed", row.id, error);
  }
  await applyGithubLabels(row, ["approved-for-build"]);
  const url = config.feedbackCursorBuildWebhookUrl.trim();
  if (!opts.ping || !url) return;
  await pingCursorWebhook(row, {
    event: "feedback.approved",
    url,
    extra: { chosen_option: row.chosen_option }
  });
};

const commentOnGithub = async (row: FeedbackRow, body: string) => {
  const base = githubIssueApi(row);
  if (!base) return;
  const response = await githubFetch(`${base}/comments`, {
    method: "POST",
    body: JSON.stringify({ body })
  });
  if (response.status >= 300) {
    throw new Error(`GitHub comment ${response.status}: ${(await response.text()).slice(0, 200)}`);
  }
};

const publishProposalOnGithub = async (row: FeedbackRow, options: ProposalOption[]) => {
  await commentOnGithub(row, proposalCommentMarkdown(options));
  await applyGithubLabels(row, ["needs-approval"]);
};

const createGithubIssue = async (row: FeedbackRow) => {
  const token = config.feedbackGithubToken.trim();
  const repo = config.feedbackGithubRepo.trim();
  if (!token || !repo) return row;
  const kindLabel = row.kind === "idea" ? "Idea" : "Bug";
  const title = `[${row.app}] [${kindLabel}] ${redact(row.title, 80) || kindLabel}`;
  const publicUrl = config.publicUrl.replace(/\/$/, "");
  const fetchUrl = `${publicUrl}/internal/feedback/${row.id}`;
  const excerpt = redact(row.body, 280);
  let body =
    `## Feedback\n\n` +
    `- **Id:** \`${row.id}\`\n` +
    `- **App:** ${row.app} min\n` +
    `- **Kind:** ${row.kind}\n` +
    `- **Page:** \`${redact(row.page, 120) || "unknown"}\`\n\n` +
    `Fetch the full report (submitter and description) from Min Cloud — ` +
    `do not put personal data on this issue:\n\n` +
    `\`GET ${fetchUrl}\`\n\n` +
    `Header: \`X-Cron-Token: $FEEDBACK_CRON_TOKEN\`\n\n` +
    `### Summary\n\n${redact(row.title, 200)}\n`;
  if (excerpt) body += `\n${excerpt}\n`;
  const notify = config.feedbackGithubNotifyUser.trim().replace(/^@/, "");
  if (notify) {
    body += `\nWhen options are ready, @${notify} — comment on this issue so they get a GitHub notification.\n`;
  }
  body += `\n---\nFeedback-Id: ${row.id}\n`;
  const url = `${config.feedbackGithubApiUrl.replace(/\/$/, "")}/repos/${repo}/issues`;
  const payload: Record<string, unknown> = {
    title: title.slice(0, 200),
    body,
    labels: ["feedback", row.kind, `app:${row.app}`]
  };
  if (notify) payload.assignees = [notify];
  let response = await githubFetch(url, { method: "POST", body: JSON.stringify(payload) });
  if (response.status === 422) {
    delete payload.assignees;
    delete payload.labels;
    response = await githubFetch(url, { method: "POST", body: JSON.stringify(payload) });
  }
  if (response.status >= 300) {
    throw new Error(`GitHub ${response.status}: ${(await response.text()).slice(0, 200)}`);
  }
  const data = (await response.json()) as { number?: number; html_url?: string };
  const updated = await touch(row.id, {
    github_issue_number: data.number ? Number(data.number) : null,
    github_issue_url: data.html_url ? String(data.html_url).slice(0, 400) : null
  });
  try {
    await commentOnGithub(updated, openedCommentMarkdown());
  } catch (error) {
    console.error("GitHub opened comment failed", row.id, error);
  }
  return updated;
};

const parseWebhookDest = (raw: string | null | undefined): [string, string | null] => {
  const text = String(raw || "")
    .trim()
    .replace(/^["']|["']$/g, "");
  if (!text) return ["", null];
  const urlMatch = HTTP_URL_RE.exec(text);
  let dest = urlMatch ? urlMatch[0] : text.split(/\s+/)[0];
  dest = dest.replace(/[>/]+$/, "");
  let token: string | null = null;
  const crsr = CRSR_RE.exec(text);
  if (crsr) token = crsr[1];
  else if (dest.startsWith("http")) {
    try {
      const qs = new URL(dest).searchParams;
      for (const key of ["token", "key", "api_key", "secret"]) {
        const value = qs.get(key);
        if (value) {
          token = value.replace(/^Bearer\s+/i, "").trim();
          break;
        }
      }
    } catch {
      /* ignore */
    }
  }
  return [dest, token];
};

const webhookAuthToken = (event: string, rawDest: string) => {
  const [, embedded] = parseWebhookDest(rawDest);
  let specific = "";
  if (event === "feedback.approved") specific = config.feedbackCursorBuildWebhookSecret.trim();
  else if (event === "feedback.iterate") specific = config.feedbackCursorIterateWebhookSecret.trim();
  const shared = config.feedbackCursorWebhookSecret.trim();
  const raw = specific || embedded || shared;
  if (!raw) return null;
  const crsr = CRSR_RE.exec(raw);
  if (crsr) return crsr[1];
  return raw.replace(/^Bearer\s+/i, "").trim() || null;
};

const webhookAuthAttempts = (token: string | null) => {
  const attempts: Array<Record<string, string>> = [];
  if (token) {
    const bearer: Record<string, string> = { Authorization: `Bearer ${token}` };
    if (!token.startsWith("crsr_")) bearer["X-Webhook-Secret"] = token;
    attempts.push(bearer);
    attempts.push({ Authorization: `Basic ${Buffer.from(`${token}:`).toString("base64")}` });
  }
  attempts.push({});
  return attempts;
};

export const launchCloudAgent = async (
  row: FeedbackRow,
  opts: { event: string; extra?: Record<string, unknown> }
) => {
  let key = config.feedbackCursorApiKey.trim();
  if (!key) return false;
  const crsr = CRSR_RE.exec(key);
  key = crsr ? crsr[1] : key.replace(/^Bearer\s+/i, "").trim();
  const dest = config.feedbackCursorAgentsApiUrl.trim();
  const repo = config.feedbackGithubRepo.trim();
  if (!repo) throw new Error("cloud agent: FEEDBACK_GITHUB_REPO is unset");
  const ideaToken = agentToken(row.id);
  const extra = opts.extra || {};
  const starting = String(extra.pr_branch || "").trim() || "main";
  const autoPr = opts.event !== "feedback.fix";
  const title = redact(row.title, 70) || "Min Cloud feedback";
  const payload = {
    prompt: { text: webhookPrompt(row, ideaToken, opts.event, extra) },
    name: (opts.event === "feedback.fix" ? `Fix: ${title}` : title).slice(0, 100),
    repos: [{ url: `https://github.com/${repo}`, startingRef: starting }],
    autoCreatePR: autoPr,
    skipReviewerRequest: true
  };
  let last: Response | null = null;
  for (const auth of [
    { Authorization: `Bearer ${key}` },
    { Authorization: `Basic ${Buffer.from(`${key}:`).toString("base64")}` }
  ]) {
    last = await fetch(dest, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "MinCloud-Feedback/1.0",
        ...auth
      },
      body: JSON.stringify(payload)
    });
    if (last.status < 300) return true;
    if (![401, 403].includes(last.status)) break;
  }
  const body = last ? (await last.text()).slice(0, 200) : "";
  throw new Error(`cloud agent ${last?.status}: ${body}`);
};

export const pingCursorWebhook = async (
  row: FeedbackRow,
  opts: { event?: string; url?: string | null; extra?: Record<string, unknown> } = {}
) => {
  const event = opts.event || "feedback.created";
  const raw = opts.url == null ? config.feedbackCursorWebhookUrl : opts.url || "";
  const [dest] = parseWebhookDest(raw);
  if (!dest) return;
  const token = webhookAuthToken(event, raw);
  const ideaToken = agentToken(row.id);
  const publicUrl = config.publicUrl.replace(/\/$/, "");
  const extra = opts.extra || {};
  const payload: Record<string, unknown> = {
    event,
    feedback_id: row.id,
    app: row.app,
    kind: row.kind,
    title: redact(row.title, 80),
    issue_url: row.github_issue_url,
    issue_number: row.github_issue_number,
    cadence_url: publicUrl,
    min_cloud_url: publicUrl,
    agent_token: ideaToken,
    chosen_option: extra.chosen_option || row.chosen_option,
    prompt: webhookPrompt(row, ideaToken, event, extra)
  };
  if (extra.comment) payload.comment = extra.comment;
  let last: Response | null = null;
  for (const auth of webhookAuthAttempts(token)) {
    last = await fetch(dest, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "MinCloud-Feedback/1.0",
        ...auth
      },
      body: JSON.stringify(payload)
    });
    if (last.status < 300) return;
    if (![401, 403].includes(last.status)) break;
  }
  const body = last ? (await last.text()).slice(0, 200) : "";
  throw new Error(`webhook ${last?.status}: ${body}`);
};
