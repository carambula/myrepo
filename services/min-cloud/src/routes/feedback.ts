import { Router, type Request } from "express";
import { optionalUser, type AuthUser } from "../auth.js";
import { query, withTransaction } from "../db.js";
import {
  FeedbackInputError,
  mapFeedbackItem,
  normalizeBody,
  normalizeContext,
  normalizeDeviceId,
  normalizeTitle,
  parseFeedbackListQuery,
  voterKeyFor,
  type FeedbackRow
} from "../lib/feedback.js";
import { listFeedbackItems } from "../lib/feedback-store.js";

const router = Router();

const requestUser = (req: Request) => (req as Request & { user?: AuthUser }).user;

const fail = (res: import("express").Response, error: unknown) => {
  if (error instanceof FeedbackInputError) {
    res.status(error.status).json({ error: error.message });
    return;
  }
  throw error;
};

router.get("/feedback", optionalUser, async (req, res) => {
  try {
    const deviceId = typeof req.query.deviceId === "string" && req.query.deviceId.trim()
      ? normalizeDeviceId(req.query.deviceId)
      : null;
    const user = requestUser(req);
    const voterKey = deviceId || user ? voterKeyFor({ userId: user?.id, deviceId: deviceId || "anonymous" }) : null;
    const items = await listFeedbackItems({
      app: req.query.app,
      kind: req.query.kind,
      status: req.query.status,
      q: req.query.q,
      voterKey: deviceId || user ? voterKey : null
    });
    res.json({ items });
  } catch (error) {
    fail(res, error);
  }
});

router.get("/feedback/:id", optionalUser, async (req, res) => {
  try {
    const deviceId = typeof req.query.deviceId === "string" && req.query.deviceId.trim()
      ? normalizeDeviceId(req.query.deviceId)
      : null;
    const user = requestUser(req);
    const voterKey = deviceId || user ? voterKeyFor({ userId: user?.id, deviceId: deviceId || "anonymous" }) : null;
    const params: unknown[] = [req.params.id];
    const votedSelect = voterKey
      ? `, EXISTS (
           SELECT 1 FROM feedback_votes v
           WHERE v.item_id = feedback_items.id AND v.voter_key = $2
         ) AS voted`
      : ", FALSE AS voted";
    if (voterKey) {
      params.push(voterKey);
    }
    const result = await query(
      `
      SELECT id, app, kind, status, title, body, context, vote_count, author_handle, created_at, updated_at
             ${votedSelect}
      FROM feedback_items
      WHERE id = $1 AND status <> 'hidden'
      `,
      params
    );
    const row = result.rows[0] as FeedbackRow | undefined;
    if (!row) {
      res.status(404).json({ error: "Feedback not found." });
      return;
    }
    res.json({ item: mapFeedbackItem(row) });
  } catch (error) {
    fail(res, error);
  }
});

router.post("/feedback", optionalUser, async (req, res) => {
  try {
    const deviceId = normalizeDeviceId(req.body?.deviceId);
    const title = normalizeTitle(req.body?.title);
    const body = normalizeBody(req.body?.body);
    const context = normalizeContext(req.body?.context);
    const parsed = parseFeedbackListQuery({
      app: req.body?.app,
      kind: req.body?.kind
    });
    if (!parsed.app || !parsed.kind) {
      throw new FeedbackInputError("App and kind are required.");
    }
    const user = requestUser(req);
    const result = await query(
      `
      INSERT INTO feedback_items (
        app, kind, title, body, context, author_user_id, author_device_id, author_handle
      )
      VALUES ($1, $2, $3, $4, $5::jsonb, $6, $7, $8)
      RETURNING id, app, kind, status, title, body, context, vote_count, author_handle, created_at, updated_at
      `,
      [
        parsed.app,
        parsed.kind,
        title,
        body,
        JSON.stringify(context),
        user?.id ?? null,
        deviceId,
        user?.handle ?? null
      ]
    );
    res.status(201).json({ item: mapFeedbackItem(result.rows[0] as FeedbackRow) });
  } catch (error) {
    fail(res, error);
  }
});

router.post("/feedback/:id/vote", optionalUser, async (req, res) => {
  try {
    const deviceId = normalizeDeviceId(req.body?.deviceId ?? req.query.deviceId);
    const user = requestUser(req);
    const voterKey = voterKeyFor({ userId: user?.id, deviceId });
    const item = await withTransaction(async (client) => {
      const existing = await client.query(
        `SELECT id, status FROM feedback_items WHERE id = $1 FOR UPDATE`,
        [req.params.id]
      );
      if (!existing.rows[0] || existing.rows[0].status === "hidden") {
        throw new FeedbackInputError("Feedback not found.", 404);
      }
      const vote = await client.query(
        `SELECT 1 FROM feedback_votes WHERE item_id = $1 AND voter_key = $2`,
        [req.params.id, voterKey]
      );
      if (vote.rowCount) {
        await client.query(`DELETE FROM feedback_votes WHERE item_id = $1 AND voter_key = $2`, [
          req.params.id,
          voterKey
        ]);
      } else {
        await client.query(`INSERT INTO feedback_votes (item_id, voter_key) VALUES ($1, $2)`, [
          req.params.id,
          voterKey
        ]);
      }
      const counted = await client.query(
        `
        UPDATE feedback_items
        SET vote_count = (SELECT COUNT(*)::int FROM feedback_votes WHERE item_id = $1),
            updated_at = NOW()
        WHERE id = $1
        RETURNING id, app, kind, status, title, body, context, vote_count, author_handle, created_at, updated_at
        `,
        [req.params.id]
      );
      return {
        ...(counted.rows[0] as FeedbackRow),
        voted: !vote.rowCount
      };
    });
    res.json({ item: mapFeedbackItem(item) });
  } catch (error) {
    fail(res, error);
  }
});

export default router;
