import { Router, type Request } from "express";
import { requireAdmin, requireUser, type AuthUser } from "../auth.js";
import {
  AgentHttpError,
  createAgentConnection,
  invokeForToken,
  listToolsForToken,
  parseInvoke
} from "../lib/agent.js";
import { query } from "../db.js";

const router = Router();

const readBearer = (req: Request) => {
  const header = req.header("authorization") || "";
  if (header.toLowerCase().startsWith("bearer ")) {
    return header.slice(7).trim();
  }
  return (req.header("x-min-cloud-token") || "").trim() || null;
};

const fail = (res: import("express").Response, error: unknown) => {
  if (error instanceof AgentHttpError) {
    res.status(error.status).json(error.toJSON());
    return;
  }
  res.status(500).json({ error: "error", message: error instanceof Error ? error.message : "Unexpected error." });
};

router.get("/tools", async (req, res) => {
  try {
    res.json(await listToolsForToken(readBearer(req)));
  } catch (error) {
    fail(res, error);
  }
});

router.post("/invoke", async (req, res) => {
  try {
    const body = req.body && typeof req.body === "object" ? req.body : {};
    const { name, args } = parseInvoke(body);
    res.json(await invokeForToken(readBearer(req), name, args));
  } catch (error) {
    fail(res, error);
  }
});

router.get("/v1/whoami", async (req, res) => {
  try {
    res.json(await invokeForToken(readBearer(req), "whoami", {}));
  } catch (error) {
    fail(res, error);
  }
});

router.post("/v1/agent/connections", requireUser, async (req, res) => {
  try {
    const user = (req as Request & { user: AuthUser }).user;
    const created = await createAgentConnection({
      userId: user.id,
      name: typeof req.body?.name === "string" ? req.body.name : "VM agent"
    });
    res.status(201).json(created);
  } catch (error) {
    fail(res, error);
  }
});

router.post("/v1/admin/agent/connections", requireAdmin, async (req, res) => {
  try {
    const email = String(req.body?.email || "").trim().toLowerCase();
    if (!email) {
      res.status(400).json({ error: "email required." });
      return;
    }
    const user = await query(`SELECT id FROM users WHERE lower(email) = $1`, [email]);
    if (!user.rows[0]) {
      res.status(404).json({ error: "User not found." });
      return;
    }
    const created = await createAgentConnection({
      userId: String(user.rows[0].id),
      name: typeof req.body?.name === "string" ? req.body.name : "VM agent"
    });
    res.status(201).json(created);
  } catch (error) {
    fail(res, error);
  }
});

export default router;
