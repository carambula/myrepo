import fs from "node:fs/promises";
import path from "node:path";
import { createHash } from "node:crypto";

type FetchOptions = {
  cacheDir: string;
  cacheTtlMs: number;
  delayMs: number;
  retries: number;
  timeoutMs: number;
  useCacheOnly: boolean;
  userAgent: string;
};

const defaultOptions: FetchOptions = {
  cacheDir: ".cache/pcs",
  cacheTtlMs: 1000 * 60 * 60 * 6,
  delayMs: 500,
  retries: 2,
  timeoutMs: 15000,
  useCacheOnly: false,
  userAgent: "CyclismoBootstrap/1.0 (+https://github.com/)"
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const sha1 = (value: string) =>
  createHash("sha1").update(value).digest("hex");

const cachePathFor = (cacheDir: string, url: string) =>
  path.resolve(cacheDir, `${sha1(url)}.html`);

const readIfFresh = async (filePath: string, ttlMs: number) => {
  try {
    const stats = await fs.stat(filePath);
    if (Date.now() - stats.mtimeMs > ttlMs) {
      return null;
    }
    return await fs.readFile(filePath, "utf8");
  } catch {
    return null;
  }
};

const writeCache = async (filePath: string, html: string) => {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, html, "utf8");
};

const fetchWithTimeout = async (url: string, timeoutMs: number, headers: Record<string, string>) => {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { headers, signal: controller.signal });
    return response;
  } finally {
    clearTimeout(timeout);
  }
};

export const fetchHtml = async (url: string, options?: Partial<FetchOptions>) => {
  const config: FetchOptions = { ...defaultOptions, ...(options ?? {}) };
  const cachePath = cachePathFor(config.cacheDir, url);

  if (config.useCacheOnly) {
    const cached = await fs.readFile(cachePath, "utf8").catch(() => null);
    if (!cached) {
      throw new Error(`Cache miss for ${url}`);
    }
    return cached;
  }

  const cached = await readIfFresh(cachePath, config.cacheTtlMs);
  if (cached) {
    return cached;
  }

  const headers = {
    accept: "text/html",
    "accept-language": "en-US,en;q=0.9",
    "user-agent": config.userAgent
  };

  let lastError: unknown;
  for (let attempt = 0; attempt <= config.retries; attempt += 1) {
    try {
      if (attempt > 0) {
        await sleep(config.delayMs * attempt);
      }
      const response = await fetchWithTimeout(url, config.timeoutMs, headers);
      if (!response.ok) {
        throw new Error(`Request failed (${response.status}): ${url}`);
      }
      const html = await response.text();
      await writeCache(cachePath, html);
      await sleep(config.delayMs);
      return html;
    } catch (error) {
      lastError = error;
    }
  }

  throw lastError ?? new Error(`Failed to fetch ${url}`);
};

export const buildFetchOptions = (): FetchOptions => ({
  cacheDir: process.env.PCS_CACHE_DIR ?? defaultOptions.cacheDir,
  cacheTtlMs: Number(process.env.PCS_CACHE_TTL_MS ?? defaultOptions.cacheTtlMs),
  delayMs: Number(process.env.PCS_REQUEST_DELAY_MS ?? defaultOptions.delayMs),
  retries: Number(process.env.PCS_RETRIES ?? defaultOptions.retries),
  timeoutMs: Number(process.env.PCS_TIMEOUT_MS ?? defaultOptions.timeoutMs),
  useCacheOnly: process.env.PCS_USE_CACHE_ONLY === "true",
  userAgent: process.env.PCS_USER_AGENT ?? defaultOptions.userAgent
});
