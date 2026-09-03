import { createPrivateKey, createSign } from "node:crypto";
import http2 from "node:http2";
import { config } from "../config.js";

export type ApnsApp = "watchedit" | "podlink";

export type ApnsPostResult = {
  status: number;
  reason?: string;
};

export type ApnsPost = (input: {
  host: string;
  token: string;
  topic: string;
  jwt: string;
  payload: Record<string, unknown>;
}) => Promise<ApnsPostResult>;

const APNS_PRODUCTION_HOST = "api.push.apple.com";
const APNS_SANDBOX_HOST = "api.sandbox.push.apple.com";
const JWT_TTL_MS = 45 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 15_000;

const sessions = new Map<string, http2.ClientHttp2Session>();
let cachedJwt: { token: string; expiresAt: number; fingerprint: string } | null = null;

export const isApnsConfigured = (
  cfg: Pick<typeof config, "apnsKeyId" | "apnsTeamId" | "apnsKey"> = config
) => Boolean(cfg.apnsKeyId && cfg.apnsTeamId && cfg.apnsKey);

export const topicForApp = (
  app: ApnsApp,
  cfg: Pick<typeof config, "apnsBundleIdMov" | "apnsBundleIdPod"> = config
) => (app === "watchedit" ? cfg.apnsBundleIdMov : cfg.apnsBundleIdPod);

export const normalizePem = (value: string) => {
  const trimmed = value.trim().replace(/\\n/g, "\n");
  if (trimmed.includes("BEGIN ")) {
    return trimmed;
  }
  const body = trimmed.replace(/\s+/g, "\n");
  return `-----BEGIN PRIVATE KEY-----\n${body}\n-----END PRIVATE KEY-----`;
};

export const normalizeDeviceToken = (value: string) => {
  const token = value.replace(/[<\s>]/g, "").toLowerCase();
  if (!/^[0-9a-f]{64,}$/.test(token)) {
    return null;
  }
  return token;
};

export const createApnsJwt = (input: { key: string; keyId: string; teamId: string; iat?: number }) => {
  const header = Buffer.from(JSON.stringify({ alg: "ES256", kid: input.keyId })).toString("base64url");
  const payload = Buffer.from(
    JSON.stringify({ iss: input.teamId, iat: input.iat ?? Math.floor(Date.now() / 1000) })
  ).toString("base64url");
  const unsigned = `${header}.${payload}`;
  const key = createPrivateKey(normalizePem(input.key));
  const signer = createSign("SHA256");
  signer.update(unsigned);
  signer.end();
  const signature = signer.sign({ key, dsaEncoding: "ieee-p1363" }).toString("base64url");
  return `${unsigned}.${signature}`;
};

const jwtFingerprint = () => `${config.apnsKeyId}:${config.apnsTeamId}:${config.apnsKey.length}`;

export const apnsJwt = () => {
  const now = Date.now();
  const fingerprint = jwtFingerprint();
  if (cachedJwt && cachedJwt.expiresAt > now && cachedJwt.fingerprint === fingerprint) {
    return cachedJwt.token;
  }
  const token = createApnsJwt({
    key: config.apnsKey,
    keyId: config.apnsKeyId,
    teamId: config.apnsTeamId
  });
  cachedJwt = { token, expiresAt: now + JWT_TTL_MS, fingerprint };
  return token;
};

export const buildApnsPayload = (input: {
  title: string;
  body: string;
  type: string;
  payload?: Record<string, unknown>;
}) => {
  const extra = input.payload ?? {};
  return {
    aps: {
      alert: {
        title: input.title,
        body: input.body
      },
      sound: "default"
    },
    type: input.type,
    podcastId: extra.podcastId ?? extra.podcast_id,
    episodeTitle: extra.episodeTitle ?? extra.episode_title,
    publishDate: extra.publishDate ?? extra.publish_date
  };
};

export const isTransientApnsStatus = (status: number) => status === 429 || status >= 500;

export const isInvalidDeviceToken = (result: ApnsPostResult) =>
  result.status === 410 || result.reason === "BadDeviceToken" || result.reason === "Unregistered";

const parseReason = (body: string) => {
  if (!body) {
    return undefined;
  }
  try {
    const parsed = JSON.parse(body) as { reason?: string };
    return parsed.reason;
  } catch {
    return undefined;
  }
};

const sessionFor = (host: string) => {
  const existing = sessions.get(host);
  if (existing && !existing.closed && !existing.destroyed) {
    return existing;
  }
  const session = http2.connect(`https://${host}`);
  session.on("error", () => {
    sessions.delete(host);
  });
  session.on("close", () => {
    sessions.delete(host);
  });
  sessions.set(host, session);
  return session;
};

export const postApns: ApnsPost = (input) =>
  new Promise((resolve, reject) => {
    const session = sessionFor(input.host);
    const request = session.request({
      ":method": "POST",
      ":path": `/3/device/${input.token}`,
      authorization: `bearer ${input.jwt}`,
      "apns-topic": input.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    });
    let body = "";
    let status = 0;
    const timer = setTimeout(() => {
      request.close();
      reject(new Error(`APNs request timed out for ${input.host}`));
    }, REQUEST_TIMEOUT_MS);
    request.setEncoding("utf8");
    request.on("response", (headers) => {
      status = Number(headers[":status"] ?? 0);
    });
    request.on("data", (chunk) => {
      body += chunk;
    });
    request.on("end", () => {
      clearTimeout(timer);
      resolve({ status, reason: parseReason(body) });
    });
    request.on("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    request.end(JSON.stringify(input.payload));
  });

const hostsToTry = (preferProduction: boolean, reason?: string) => {
  const primary = preferProduction ? APNS_PRODUCTION_HOST : APNS_SANDBOX_HOST;
  const fallback = preferProduction ? APNS_SANDBOX_HOST : APNS_PRODUCTION_HOST;
  if (reason === "BadDeviceToken") {
    return [fallback];
  }
  return [primary];
};

export const sendApnsNotification = async (
  input: {
    token: string;
    app: ApnsApp;
    title: string;
    body: string;
    type: string;
    payload?: Record<string, unknown>;
  },
  post: ApnsPost = postApns,
  deps: {
    jwt?: () => string;
    topic?: (app: ApnsApp) => string;
    production?: boolean;
  } = {}
): Promise<ApnsPostResult> => {
  const token = normalizeDeviceToken(input.token);
  if (!token) {
    return { status: 400, reason: "BadDeviceToken" };
  }
  const topic = (deps.topic ?? topicForApp)(input.app);
  const jwt = (deps.jwt ?? apnsJwt)();
  const production = deps.production ?? config.apnsProduction;
  const payload = buildApnsPayload(input);
  let result = await post({
    host: production ? APNS_PRODUCTION_HOST : APNS_SANDBOX_HOST,
    token,
    topic,
    jwt,
    payload
  });
  if (result.reason === "BadDeviceToken") {
    const [fallbackHost] = hostsToTry(production, result.reason);
    result = await post({
      host: fallbackHost,
      token,
      topic,
      jwt,
      payload
    });
  }
  return result;
};

export const closeApnsSessions = () => {
  for (const session of sessions.values()) {
    session.close();
  }
  sessions.clear();
};
