import { Router, type Request } from "express";
import { z } from "zod";
import {
  authenticateUser,
  createSession,
  createUser,
  optionalUser,
  requireUser,
  revokeSession,
  type AuthUser
} from "../auth.js";
import { query } from "../db.js";

const router = Router();

const credentialsSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
  handle: z.string().min(2).max(24).optional(),
  displayName: z.string().min(1).max(80).optional()
});

const getUser = (req: Request) => (req as Request & { user: AuthUser }).user;

router.post("/auth/register", async (req, res) => {
  const parsed = credentialsSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Valid email and password (8+ characters) required." });
    return;
  }
  try {
    const user = await createUser(parsed.data);
    const session = await createSession(user.id);
    res.status(201).json({ user, session });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Could not create account.";
    res.status(409).json({ error: message.includes("unique") ? "Email or handle already in use." : message });
  }
});

router.post("/auth/login", async (req, res) => {
  const parsed = credentialsSchema.pick({ email: true, password: true }).safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: "Email and password required." });
    return;
  }
  const user = await authenticateUser(parsed.data.email, parsed.data.password);
  if (!user) {
    res.status(401).json({ error: "Invalid email or password." });
    return;
  }
  const session = await createSession(user.id);
  res.json({ user, session });
});

router.post("/auth/logout", requireUser, async (req, res) => {
  const token = (req.header("authorization") || "").replace(/^Bearer\s+/i, "").trim();
  if (token) {
    await revokeSession(token);
  }
  res.json({ ok: true });
});

router.get("/me", requireUser, async (req, res) => {
  const user = getUser(req);
  res.json({ user });
});

router.patch("/me", requireUser, async (req, res) => {
  const user = getUser(req);
  const displayName = typeof req.body?.displayName === "string" ? req.body.displayName.trim() : null;
  const bio = typeof req.body?.bio === "string" ? req.body.bio.trim() : null;
  const handle = typeof req.body?.handle === "string" ? req.body.handle.trim().toLowerCase() : null;
  const result = await query(
    `
    UPDATE users
    SET display_name = COALESCE($2, display_name),
        bio = COALESCE($3, bio),
        handle = COALESCE($4, handle),
        updated_at = NOW()
    WHERE id = $1
    RETURNING id, email, handle, display_name, avatar_url, bio, is_admin
    `,
    [user.id, displayName, bio, handle]
  );
  res.json({
    user: {
      id: result.rows[0].id,
      email: result.rows[0].email,
      handle: result.rows[0].handle,
      displayName: result.rows[0].display_name,
      avatarUrl: result.rows[0].avatar_url,
      bio: result.rows[0].bio,
      isAdmin: result.rows[0].is_admin
    }
  });
});

router.put("/me/devices", requireUser, async (req, res) => {
  const user = getUser(req);
  const app = req.body?.app === "watchedit" ? "watchedit" : "podlink";
  const platform = String(req.body?.platform || "ios");
  const pushToken = req.body?.pushToken ? String(req.body.pushToken) : null;
  const timezone = req.body?.timezone ? String(req.body.timezone) : null;
  const result = await query(
    `
    INSERT INTO devices (user_id, app, platform, push_token, timezone)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING id, app, platform, timezone, created_at
    `,
    [user.id, app, platform, pushToken, timezone]
  );
  res.json({ device: result.rows[0] });
});

router.get("/me/notifications", requireUser, async (req, res) => {
  const user = getUser(req);
  const app = req.query.app === "watchedit" ? "watchedit" : "podlink";
  const prefs = await query(
    `SELECT preferences FROM notification_preferences WHERE user_id = $1 AND app = $2`,
    [user.id, app]
  );
  const inbox = await query(
    `
    SELECT id, app, type, title, body, payload, scheduled_for, sent_at, created_at
    FROM notification_queue
    WHERE user_id = $1 AND app = $2
    ORDER BY created_at DESC
    LIMIT 50
    `,
    [user.id, app]
  );
  res.json({
    preferences: prefs.rows[0]?.preferences ?? {},
    inbox: inbox.rows
  });
});

router.put("/me/notifications", requireUser, async (req, res) => {
  const user = getUser(req);
  const app = req.body?.app === "watchedit" ? "watchedit" : "podlink";
  const preferences = req.body?.preferences ?? {};
  await query(
    `
    INSERT INTO notification_preferences (user_id, app, preferences)
    VALUES ($1, $2, $3::jsonb)
    ON CONFLICT (user_id, app) DO UPDATE SET preferences = EXCLUDED.preferences
    `,
    [user.id, app, JSON.stringify(preferences)]
  );
  res.json({ ok: true, preferences });
});

router.get("/me/library/mov", requireUser, async (req, res) => {
  const user = getUser(req);
  const result = await query(
    `SELECT movie_id, is_watched, is_saved, is_rewatched, is_listened, rating, notes, updated_at
     FROM user_library_mov WHERE user_id = $1`,
    [user.id]
  );
  res.json({ items: result.rows });
});

router.put("/me/library/mov", requireUser, async (req, res) => {
  const user = getUser(req);
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  for (const item of items) {
    if (!item?.movieId) {
      continue;
    }
    await query(
      `
      INSERT INTO user_library_mov (
        user_id, movie_id, is_watched, is_saved, is_rewatched, is_listened, rating, notes, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
      ON CONFLICT (user_id, movie_id) DO UPDATE SET
        is_watched = EXCLUDED.is_watched,
        is_saved = EXCLUDED.is_saved,
        is_rewatched = EXCLUDED.is_rewatched,
        is_listened = EXCLUDED.is_listened,
        rating = EXCLUDED.rating,
        notes = EXCLUDED.notes,
        updated_at = NOW()
      `,
      [
        user.id,
        String(item.movieId),
        Boolean(item.isWatched),
        Boolean(item.isSaved),
        Boolean(item.isRewatched),
        Boolean(item.isListened),
        item.rating ?? null,
        item.notes ?? null
      ]
    );
  }
  res.json({ ok: true, count: items.length });
});

router.get("/me/library/pod", requireUser, async (req, res) => {
  const user = getUser(req);
  const result = await query(
    `SELECT podcast_id, feed_url, title, artwork_url, is_followed, notifications_enabled, playback, updated_at
     FROM user_library_pod WHERE user_id = $1`,
    [user.id]
  );
  res.json({ items: result.rows });
});

router.put("/me/library/pod", requireUser, async (req, res) => {
  const user = getUser(req);
  const items = Array.isArray(req.body?.items) ? req.body.items : [];
  for (const item of items) {
    if (!item?.podcastId) {
      continue;
    }
    await query(
      `
      INSERT INTO user_library_pod (
        user_id, podcast_id, feed_url, title, artwork_url, is_followed, notifications_enabled, playback, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8::jsonb,NOW())
      ON CONFLICT (user_id, podcast_id) DO UPDATE SET
        feed_url = EXCLUDED.feed_url,
        title = EXCLUDED.title,
        artwork_url = EXCLUDED.artwork_url,
        is_followed = EXCLUDED.is_followed,
        notifications_enabled = EXCLUDED.notifications_enabled,
        playback = EXCLUDED.playback,
        updated_at = NOW()
      `,
      [
        user.id,
        String(item.podcastId),
        item.feedUrl ?? null,
        item.title ?? null,
        item.artworkUrl ?? null,
        item.isFollowed !== false,
        Boolean(item.notificationsEnabled),
        JSON.stringify(item.playback ?? {})
      ]
    );
  }
  res.json({ ok: true, count: items.length });
});

router.get("/users/:handle", optionalUser, async (req, res) => {
  const result = await query(
    `SELECT id, handle, display_name, avatar_url, bio, created_at FROM users WHERE handle = $1`,
    [String(req.params.handle)]
  );
  if (!result.rowCount) {
    res.status(404).json({ error: "User not found." });
    return;
  }
  const profile = result.rows[0];
  const followers = await query(`SELECT COUNT(*)::int AS count FROM follows WHERE followee_id = $1`, [profile.id]);
  const following = await query(`SELECT COUNT(*)::int AS count FROM follows WHERE follower_id = $1`, [profile.id]);
  const activity = await query(
    `SELECT id, app, type, payload, created_at FROM activity WHERE user_id = $1 ORDER BY created_at DESC LIMIT 30`,
    [profile.id]
  );
  res.json({
    user: {
      handle: profile.handle,
      displayName: profile.display_name,
      avatarUrl: profile.avatar_url,
      bio: profile.bio,
      createdAt: profile.created_at
    },
    followers: followers.rows[0].count,
    following: following.rows[0].count,
    activity: activity.rows
  });
});

router.post("/social/follow", requireUser, async (req, res) => {
  const user = getUser(req);
  const handle = String(req.body?.handle || "");
  const target = await query(`SELECT id FROM users WHERE handle = $1`, [handle]);
  if (!target.rowCount) {
    res.status(404).json({ error: "User not found." });
    return;
  }
  if (target.rows[0].id === user.id) {
    res.status(400).json({ error: "You cannot follow yourself." });
    return;
  }
  await query(
    `INSERT INTO follows (follower_id, followee_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
    [user.id, target.rows[0].id]
  );
  await query(
    `INSERT INTO activity (user_id, app, type, payload) VALUES ($1, 'platform', 'follow', $2::jsonb)`,
    [user.id, JSON.stringify({ handle })]
  );
  res.json({ ok: true });
});

router.delete("/social/follow/:handle", requireUser, async (req, res) => {
  const user = getUser(req);
  const target = await query(`SELECT id FROM users WHERE handle = $1`, [String(req.params.handle)]);
  if (target.rowCount) {
    await query(`DELETE FROM follows WHERE follower_id = $1 AND followee_id = $2`, [user.id, target.rows[0].id]);
  }
  res.json({ ok: true });
});

router.get("/social/feed", requireUser, async (req, res) => {
  const user = getUser(req);
  const result = await query(
    `
    SELECT a.id, a.app, a.type, a.payload, a.created_at, u.handle, u.display_name
    FROM activity a
    JOIN users u ON u.id = a.user_id
    WHERE a.user_id = $1 OR a.user_id IN (SELECT followee_id FROM follows WHERE follower_id = $1)
    ORDER BY a.created_at DESC
    LIMIT 80
    `,
    [user.id]
  );
  res.json({ items: result.rows });
});

router.post("/social/activity", requireUser, async (req, res) => {
  const user = getUser(req);
  const app = ["watchedit", "podlink", "platform"].includes(req.body?.app) ? req.body.app : "platform";
  const type = String(req.body?.type || "update");
  await query(
    `INSERT INTO activity (user_id, app, type, payload) VALUES ($1, $2, $3, $4::jsonb)`,
    [user.id, app, type, JSON.stringify(req.body?.payload ?? {})]
  );
  res.status(201).json({ ok: true });
});

export default router;
