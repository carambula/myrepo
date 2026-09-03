import { createHash, randomBytes, scryptSync, timingSafeEqual } from "node:crypto";

const SCRYPT_KEYLEN = 64;

export const hashPassword = (password: string) => {
  const salt = randomBytes(16).toString("hex");
  const derived = scryptSync(password, salt, SCRYPT_KEYLEN).toString("hex");
  return `scrypt$${salt}$${derived}`;
};

export const verifyPassword = (password: string, stored: string) => {
  const [scheme, salt, derived] = stored.split("$");
  if (scheme !== "scrypt" || !salt || !derived) {
    return false;
  }
  const candidate = scryptSync(password, salt, SCRYPT_KEYLEN);
  const expected = Buffer.from(derived, "hex");
  if (candidate.length !== expected.length) {
    return false;
  }
  return timingSafeEqual(candidate, expected);
};

export const randomToken = (bytes = 32) => randomBytes(bytes).toString("hex");

export const hashToken = (token: string) => createHash("sha256").update(token).digest("hex");

export const movieIdFromTmdb = (tmdbId: number) => `tmdb-${tmdbId}`;

export const podcastIdFromItunes = (itunesId: string) => `itunes-${itunesId}`;

export const podcastIdFromFeed = (feedUrl: string) => {
  const digest = createHash("sha1").update(feedUrl).digest("hex").slice(0, 16);
  return `feed-${digest}`;
};

export const normalizeHandle = (value: string) =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "")
    .slice(0, 24);
