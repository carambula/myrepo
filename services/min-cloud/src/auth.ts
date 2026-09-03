import type { Request, Response, NextFunction } from "express";
import { config } from "./config.js";
import { query } from "./db.js";
import { hashPassword, hashToken, normalizeHandle, randomToken, verifyPassword } from "./lib/passwords.js";

export type AuthUser = {
  id: string;
  email: string;
  handle: string;
  displayName: string;
  avatarUrl: string | null;
  bio: string | null;
  isAdmin: boolean;
};

const SESSION_DAYS = 90;

const mapUser = (row: Record<string, unknown>): AuthUser => ({
  id: String(row.id),
  email: String(row.email),
  handle: String(row.handle),
  displayName: String(row.display_name),
  avatarUrl: (row.avatar_url as string | null) ?? null,
  bio: (row.bio as string | null) ?? null,
  isAdmin: Boolean(row.is_admin)
});

export const createUser = async (input: {
  email: string;
  password: string;
  handle?: string;
  displayName?: string;
}) => {
  const email = input.email.trim().toLowerCase();
  const handleBase = normalizeHandle(input.handle || email.split("@")[0] || "user");
  const handle = handleBase || `user${randomToken(3)}`;
  const displayName = input.displayName?.trim() || handle;
  const isAdmin = config.adminEmails.includes(email);
  const result = await query(
    `
    INSERT INTO users (email, handle, display_name, password_hash, is_admin)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING id, email, handle, display_name, avatar_url, bio, is_admin
    `,
    [email, handle, displayName, hashPassword(input.password), isAdmin]
  );
  return mapUser(result.rows[0]);
};

export const authenticateUser = async (email: string, password: string) => {
  const result = await query(
    `SELECT id, email, handle, display_name, avatar_url, bio, is_admin, password_hash
     FROM users WHERE email = $1`,
    [email.trim().toLowerCase()]
  );
  const row = result.rows[0];
  if (!row || !verifyPassword(password, String(row.password_hash))) {
    return null;
  }
  return mapUser(row);
};

export const createSession = async (userId: string) => {
  const token = randomToken(32);
  const expires = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  await query(
    `INSERT INTO sessions (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
    [userId, hashToken(token), expires]
  );
  return { token, expiresAt: expires.toISOString() };
};

export const userFromToken = async (token: string | undefined | null) => {
  if (!token) {
    return null;
  }
  const result = await query(
    `
    SELECT u.id, u.email, u.handle, u.display_name, u.avatar_url, u.bio, u.is_admin
    FROM sessions s
    JOIN users u ON u.id = s.user_id
    WHERE s.token_hash = $1 AND s.expires_at > NOW()
    `,
    [hashToken(token)]
  );
  return result.rows[0] ? mapUser(result.rows[0]) : null;
};

export const revokeSession = async (token: string) => {
  await query(`DELETE FROM sessions WHERE token_hash = $1`, [hashToken(token)]);
};

const readBearer = (req: Request) => {
  const header = req.header("authorization") || "";
  if (header.toLowerCase().startsWith("bearer ")) {
    return header.slice(7).trim();
  }
  return (req.header("x-min-cloud-token") || "").trim() || null;
};

export const requireUser = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await userFromToken(readBearer(req));
    if (!user) {
      res.status(401).json({ error: "Sign in required." });
      return;
    }
    (req as Request & { user: AuthUser }).user = user;
    next();
  } catch (error) {
    next(error);
  }
};

export const optionalUser = async (req: Request, _res: Response, next: NextFunction) => {
  try {
    const user = await userFromToken(readBearer(req));
    if (user) {
      (req as Request & { user?: AuthUser }).user = user;
    }
    next();
  } catch (error) {
    next(error);
  }
};

export const requireAdmin = async (req: Request, res: Response, next: NextFunction) => {
  const adminHeader = req.header("x-admin-token") || "";
  if (config.adminToken && adminHeader && adminHeader === config.adminToken) {
    (req as Request & { adminActor: string }).adminActor = "admin-token";
    next();
    return;
  }
  const user = await userFromToken(readBearer(req));
  if (user?.isAdmin) {
    (req as Request & { adminActor: string }).adminActor = user.email;
    next();
    return;
  }
  res.status(401).json({ error: "Admin authorization required." });
};

export const requireCron = (req: Request, res: Response, next: NextFunction) => {
  const secret = req.header("x-cron-secret") || "";
  if (config.cronSecret && secret === config.cronSecret) {
    next();
    return;
  }
  if (config.adminToken && secret === config.adminToken) {
    next();
    return;
  }
  res.status(401).json({ error: "Cron authorization required." });
};
