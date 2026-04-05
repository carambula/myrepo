const http = require("http");
const https = require("https");
const { randomUUID } = require("crypto");
const path = require("path");
const fs = require("fs/promises");
const fsSync = require("fs");

const PROJECT_ROOT = path.resolve(__dirname, "..");
const DEFAULT_PODCASTS_PATH = path.join(PROJECT_ROOT, "PodLink", "Resources", "DefaultPodcasts.json");
const MEDIA_PATTERNS_PATH = path.join(PROJECT_ROOT, "PodLink", "Resources", "MediaPatterns.json");
const THEME_PRESETS_PATH = path.join(PROJECT_ROOT, "PodLink", "theme_presets.json");
const DESIGN_SYSTEM_PATH = path.join(PROJECT_ROOT, "PodLink", "DesignSystem", "DesignSystem.swift");
const PUBLIC_DIR = path.join(__dirname, "public");

const PORT = process.env.PORT || 4189;

// ---- SSE Live Reload ----

const WATCHED_SOURCES = {
  designSystem: { path: DESIGN_SYSTEM_PATH, label: "DesignSystem.swift" },
  defaultPodcasts: { path: DEFAULT_PODCASTS_PATH, label: "DefaultPodcasts.json" },
  mediaPatterns: { path: MEDIA_PATTERNS_PATH, label: "MediaPatterns.json" },
  themes: { path: THEME_PRESETS_PATH, label: "theme_presets.json" },
};

const sseClients = new Set();
const fileHashes = new Map();
const watchDebounce = new Map();

async function hashFile(filePath) {
  try {
    const stat = await fs.stat(filePath);
    return `${stat.mtimeMs}:${stat.size}`;
  } catch {
    return null;
  }
}

async function initFileHashes() {
  for (const [key, src] of Object.entries(WATCHED_SOURCES)) {
    fileHashes.set(key, await hashFile(src.path));
  }
}

function broadcastSSE(event, data) {
  const msg = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const client of sseClients) {
    try { client.write(msg); } catch { sseClients.delete(client); }
  }
}

function startFileWatchers() {
  for (const [key, src] of Object.entries(WATCHED_SOURCES)) {
    try {
      fsSync.watch(src.path, { persistent: false }, () => {
        if (watchDebounce.has(key)) clearTimeout(watchDebounce.get(key));
        watchDebounce.set(key, setTimeout(async () => {
          watchDebounce.delete(key);
          const newHash = await hashFile(src.path);
          const oldHash = fileHashes.get(key);
          if (newHash && newHash !== oldHash) {
            fileHashes.set(key, newHash);
            console.log(`🔄 [LIVE] ${src.label} changed`);
            broadcastSSE("file-change", { source: key, file: src.label, timestamp: Date.now() });
          }
        }, 300));
      });
      console.log(`👁️  [LIVE] Watching ${src.label}`);
    } catch (err) {
      console.log(`⚠️ [LIVE] Cannot watch ${src.label}: ${err.message}`);
    }
  }
}

initFileHashes().then(startFileWatchers);

// ---- Helpers ----

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) });
  res.end(body);
}

function sendText(res, status, text) {
  res.writeHead(status, { "Content-Type": "text/plain" });
  res.end(text);
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  const body = Buffer.concat(chunks).toString("utf8");
  return body ? JSON.parse(body) : null;
}

function requestJson(url) {
  const transport = url.startsWith("http://") ? http : https;
  return new Promise((resolve, reject) => {
    transport
      .get(url, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if (res.statusCode && res.statusCode >= 400) {
            return reject(new Error(`Request failed (${res.statusCode}): ${data.slice(0, 200)}`));
          }
          try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
        });
      })
      .on("error", reject);
  });
}

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => resolve(data));
    }).on("error", reject);
  });
}

// ---- Data Access ----

async function loadDefaultPodcasts() {
  const data = await fs.readFile(DEFAULT_PODCASTS_PATH, "utf8");
  return JSON.parse(data);
}

async function saveDefaultPodcasts(catalog) {
  const json = JSON.stringify(catalog, null, 2);
  await fs.writeFile(DEFAULT_PODCASTS_PATH, `${json}\n`, "utf8");
}

async function loadMediaPatterns() {
  const data = await fs.readFile(MEDIA_PATTERNS_PATH, "utf8");
  return JSON.parse(data);
}

async function saveMediaPatterns(patterns) {
  const json = JSON.stringify(patterns, null, 2);
  await fs.writeFile(MEDIA_PATTERNS_PATH, `${json}\n`, "utf8");
}

async function loadThemePresets() {
  try {
    const data = await fs.readFile(THEME_PRESETS_PATH, "utf8");
    const parsed = JSON.parse(data);
    return Array.isArray(parsed) ? parsed : [];
  } catch (error) {
    if (error && error.code === "ENOENT") return [];
    throw error;
  }
}

async function saveThemePresets(themePresets) {
  const json = JSON.stringify(themePresets, null, 2);
  await fs.writeFile(THEME_PRESETS_PATH, `${json}\n`, "utf8");
}

// ---- Theme Normalization ----

function clampColorChannel(value, fallback = 0) {
  if (typeof value !== "number" || Number.isNaN(value)) return fallback;
  return Math.max(0, Math.min(1, value));
}

function normalizeThemeColor(input) {
  const source = input && typeof input === "object" ? input : {};
  return {
    red: clampColorChannel(source.red),
    green: clampColorChannel(source.green),
    blue: clampColorChannel(source.blue),
    alpha: clampColorChannel(source.alpha, 1),
  };
}

function mixThemeColors(baseColor, targetColor, ratio) {
  const r = Math.max(0, Math.min(1, Number(ratio) || 0));
  return {
    red: clampColorChannel(baseColor.red * (1 - r) + targetColor.red * r),
    green: clampColorChannel(baseColor.green * (1 - r) + targetColor.green * r),
    blue: clampColorChannel(baseColor.blue * (1 - r) + targetColor.blue * r),
    alpha: clampColorChannel(baseColor.alpha, 1),
  };
}

function normalizeThemePresetPayload(payload, existing = null) {
  if (!payload || typeof payload !== "object") return null;
  const nowIso = new Date().toISOString();
  const name = String(payload.name || "").trim().slice(0, 80);
  if (!name) return null;

  const headlineFontStyle = payload.headlineFontStyle ? String(payload.headlineFontStyle).trim().slice(0, 64) : "system-default";
  const bodyFontStyle = payload.bodyFontStyle ? String(payload.bodyFontStyle).trim().slice(0, 64) : "system-default";
  const darkModeHeadlineColor = normalizeThemeColor(payload.darkModeHeadlineColor || payload.headlineColor);
  const lightModeHeadlineColor = normalizeThemeColor(payload.lightModeHeadlineColor || payload.headlineColor);
  const darkModeBackground = normalizeThemeColor(payload.darkModeBackground);
  const lightModeBackground = normalizeThemeColor(payload.lightModeBackground);

  return {
    id: existing?.id || payload.id || randomUUID(),
    name,
    builtInThemeName: payload.builtInThemeName ? String(payload.builtInThemeName).trim().slice(0, 80) : null,
    headlineFontStyle,
    bodyFontStyle,
    accent: normalizeThemeColor(payload.accent),
    secondaryAccent: normalizeThemeColor(payload.secondaryAccent),
    headlineColor: darkModeHeadlineColor,
    darkModeHeadlineColor,
    lightModeHeadlineColor,
    backgroundTint: mixThemeColors(darkModeBackground, { red: 1, green: 1, blue: 1, alpha: 1 }, 0.03),
    darkModeBackgroundTint: mixThemeColors(darkModeBackground, { red: 1, green: 1, blue: 1, alpha: 1 }, 0.03),
    lightModeBackgroundTint: mixThemeColors(lightModeBackground, { red: 0, green: 0, blue: 0, alpha: 1 }, 0.03),
    darkModeBackground,
    lightModeBackground,
    supportsLightMode: Boolean(payload.supportsLightMode),
    createdAt: existing?.createdAt || nowIso,
    lastUpdated: nowIso,
  };
}

// ---- Design System Token Parsing ----

function extractBraceBlock(source, openBraceIndex) {
  if (openBraceIndex < 0 || openBraceIndex >= source.length) return "";
  let depth = 0;
  for (let i = openBraceIndex; i < source.length; i++) {
    if (source[i] === "{") depth++;
    else if (source[i] === "}") { depth--; if (depth === 0) return source.slice(openBraceIndex + 1, i); }
  }
  return "";
}

function extractEnumBody(source, enumName) {
  const idx = source.indexOf(`enum ${enumName}`);
  if (idx < 0) { const structIdx = source.indexOf(`struct ${enumName}`); if (structIdx < 0) return ""; const braceIdx = source.indexOf("{", structIdx); return extractBraceBlock(source, braceIdx); }
  const braceIdx = source.indexOf("{", idx);
  return extractBraceBlock(source, braceIdx);
}

function parseNumericTokens(body) {
  const tokens = {};
  const regex = /static let (\w+):\s*CGFloat\s*=\s*([0-9.]+)/g;
  let m; while ((m = regex.exec(body))) tokens[m[1]] = Number(m[2]);
  return tokens;
}

function parseTypographyFunctions(source) {
  const tokens = {};
  const funcRegex = /static func (\w+)\(\)\s*->\s*Font\s*\{[\s\S]*?\.system\(size:\s*([0-9.]+)(?:,\s*weight:\s*\.([a-zA-Z]+))?/g;
  let m; while ((m = funcRegex.exec(source))) {
    tokens[m[1]] = { size: Number(m[2]), weight: m[3] || "regular", source: "func" };
  }
  const letRegex = /static (?:let|var) (\w+)\s*(?::\s*Font\s*)?=\s*\.system\(size:\s*([0-9.]+)(?:,\s*weight:\s*\.([a-zA-Z]+))?/g;
  while ((m = letRegex.exec(source))) {
    if (!tokens[m[1]]) tokens[m[1]] = { size: Number(m[2]), weight: m[3] || "regular", source: "let" };
  }
  return tokens;
}

async function loadDesignSystemTokens() {
  try {
    const source = await fs.readFile(DESIGN_SYSTEM_PATH, "utf8");
    const typography = parseTypographyFunctions(source);
    return { generatedAt: new Date().toISOString(), sourceFile: "PodLink/DesignSystem/DesignSystem.swift", typography };
  } catch {
    return { generatedAt: new Date().toISOString(), error: "Could not read DesignSystem.swift" };
  }
}

// ---- RSS Feed Parsing ----

function parseRssItems(xml) {
  const items = [];
  const itemBlocks = xml.match(/<item[\s\S]*?<\/item>/gi) || [];
  const titleRe = /<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>|<title>([\s\S]*?)<\/title>/i;
  const pubDateRe = /<pubDate>([\s\S]*?)<\/pubDate>/i;
  const descRe = /<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>|<description>([\s\S]*?)<\/description>/i;
  const encRe = /<enclosure[^>]+url="([^"]+)"/i;
  const durRe = /<itunes:duration>([\s\S]*?)<\/itunes:duration>/i;

  for (const block of itemBlocks) {
    const titleMatch = block.match(titleRe);
    const rawTitle = (titleMatch?.[1] || titleMatch?.[2] || "").trim();
    if (!rawTitle) continue;
    const dateMatch = block.match(pubDateRe);
    const descMatch = block.match(descRe);
    const encMatch = block.match(encRe);
    const durMatch = block.match(durRe);
    items.push({
      title: rawTitle,
      pubDate: (dateMatch?.[1] || "").trim(),
      description: (descMatch?.[1] || descMatch?.[2] || "").trim().slice(0, 500),
      audioUrl: encMatch?.[1] || null,
      duration: (durMatch?.[1] || "").trim() || null,
    });
  }
  return items;
}

function parseFeedMeta(xml) {
  const titleMatch = xml.match(/<channel[\s\S]*?<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>|<channel[\s\S]*?<title>([\s\S]*?)<\/title>/i);
  const descMatch = xml.match(/<channel[\s\S]*?<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>|<channel[\s\S]*?<description>([\s\S]*?)<\/description>/i);
  const artMatch = xml.match(/<itunes:image\s+href="([^"]+)"/i) || xml.match(/<image>[\s\S]*?<url>([\s\S]*?)<\/url>/i);
  return {
    title: (titleMatch?.[1] || titleMatch?.[2] || "").trim(),
    description: (descMatch?.[1] || descMatch?.[2] || "").trim().slice(0, 500),
    artworkUrl: (artMatch?.[1] || "").trim() || null,
  };
}

// ---- iTunes Lookup ----

async function itunesLookup(itunesID) {
  const url = `https://itunes.apple.com/lookup?id=${encodeURIComponent(itunesID)}&entity=podcast`;
  const data = await requestJson(url);
  const result = data?.results?.[0];
  if (!result) return null;
  return {
    itunesID: String(result.collectionId || itunesID),
    name: result.collectionName || result.trackName || "",
    feedUrl: result.feedUrl || null,
    artworkUrl: result.artworkUrl600 || result.artworkUrl100 || null,
    artist: result.artistName || null,
    genres: result.genres || [],
  };
}

async function itunesSearch(term, limit = 10) {
  const url = `https://itunes.apple.com/search?entity=podcast&limit=${limit}&term=${encodeURIComponent(term)}`;
  const data = await requestJson(url);
  return (data?.results || []).map((r) => ({
    itunesID: String(r.collectionId || ""),
    name: r.collectionName || r.trackName || "",
    feedUrl: r.feedUrl || null,
    artworkUrl: r.artworkUrl600 || r.artworkUrl100 || null,
    artist: r.artistName || null,
    genres: r.genres || [],
  }));
}

// ---- Content Type ----

function getContentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html";
  if (filePath.endsWith(".js")) return "text/javascript";
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".svg")) return "image/svg+xml";
  if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) return "image/jpeg";
  if (filePath.endsWith(".png")) return "image/png";
  return "application/octet-stream";
}

// ---- HTTP Server ----

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  const pathname = parsedUrl.pathname.replace(/\/+$/, "") || "/";

  try {
    // Bootstrap data (podcasts catalog)
    if (pathname === "/api/bootstrap" && req.method === "GET") {
      const catalog = await loadDefaultPodcasts();
      return sendJson(res, 200, catalog);
    }

    // Data health
    if (pathname === "/api/health" && req.method === "GET") {
      const catalog = await loadDefaultPodcasts();
      const categories = catalog.categories || [];
      const totalPodcasts = categories.reduce((sum, cat) => sum + (cat.podcasts?.length || 0), 0);
      const podcastsWithId = categories.reduce((sum, cat) =>
        sum + (cat.podcasts || []).filter((p) => p.itunesID).length, 0);
      const emptyCategories = categories.filter((cat) => !cat.podcasts || cat.podcasts.length === 0).length;
      let patterns = null;
      try { patterns = await loadMediaPatterns(); } catch {}
      return sendJson(res, 200, {
        totalCategories: categories.length,
        totalPodcasts,
        podcastsWithItunesId: podcastsWithId,
        podcastsMissingId: totalPodcasts - podcastsWithId,
        emptyCategories,
        mediaPatternTypes: patterns?.patterns?.length || 0,
      });
    }

    // Add category
    if (pathname === "/api/categories" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const name = String(payload?.name || "").trim();
      if (!name) return sendJson(res, 400, { error: "Missing category name" });
      const catalog = await loadDefaultPodcasts();
      if (!catalog.categories) catalog.categories = [];
      const exists = catalog.categories.some((c) => c.name.toLowerCase() === name.toLowerCase());
      if (exists) return sendJson(res, 409, { error: "Category already exists" });
      catalog.categories.push({ name, podcasts: [] });
      catalog.categories.sort((a, b) => a.name.localeCompare(b.name));
      await saveDefaultPodcasts(catalog);
      return sendJson(res, 200, { success: true });
    }

    // Rename category
    if (pathname.startsWith("/api/categories/") && req.method === "PUT") {
      const oldName = decodeURIComponent(pathname.slice("/api/categories/".length));
      const payload = await readRequestBody(req);
      const newName = String(payload?.name || "").trim();
      if (!newName) return sendJson(res, 400, { error: "Missing new name" });
      const catalog = await loadDefaultPodcasts();
      const cat = (catalog.categories || []).find((c) => c.name === oldName);
      if (!cat) return sendJson(res, 404, { error: "Category not found" });
      cat.name = newName;
      catalog.categories.sort((a, b) => a.name.localeCompare(b.name));
      await saveDefaultPodcasts(catalog);
      return sendJson(res, 200, { success: true });
    }

    // Delete category
    if (pathname.startsWith("/api/categories/") && req.method === "DELETE") {
      const name = decodeURIComponent(pathname.slice("/api/categories/".length));
      const catalog = await loadDefaultPodcasts();
      const before = (catalog.categories || []).length;
      catalog.categories = (catalog.categories || []).filter((c) => c.name !== name);
      if (catalog.categories.length === before) return sendJson(res, 404, { error: "Category not found" });
      await saveDefaultPodcasts(catalog);
      return sendJson(res, 200, { success: true });
    }

    // Add podcast to category
    if (pathname === "/api/podcasts" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const category = String(payload?.category || "").trim();
      const itunesID = String(payload?.itunesID || "").trim();
      const name = String(payload?.name || "").trim();
      if (!category || !name) return sendJson(res, 400, { error: "Missing category or name" });
      const catalog = await loadDefaultPodcasts();
      const cat = (catalog.categories || []).find((c) => c.name === category);
      if (!cat) return sendJson(res, 404, { error: "Category not found" });
      if (!cat.podcasts) cat.podcasts = [];
      const exists = cat.podcasts.some((p) => p.itunesID === itunesID || p.name.toLowerCase() === name.toLowerCase());
      if (exists) return sendJson(res, 409, { error: "Podcast already in category" });
      cat.podcasts.push({ itunesID: itunesID || null, name });
      await saveDefaultPodcasts(catalog);
      return sendJson(res, 200, { success: true });
    }

    // Remove podcast from category
    if (pathname === "/api/podcasts" && req.method === "DELETE") {
      const payload = await readRequestBody(req);
      const category = String(payload?.category || "").trim();
      const itunesID = String(payload?.itunesID || "").trim();
      if (!category || !itunesID) return sendJson(res, 400, { error: "Missing category or itunesID" });
      const catalog = await loadDefaultPodcasts();
      const cat = (catalog.categories || []).find((c) => c.name === category);
      if (!cat) return sendJson(res, 404, { error: "Category not found" });
      const before = (cat.podcasts || []).length;
      cat.podcasts = (cat.podcasts || []).filter((p) => p.itunesID !== itunesID);
      if (cat.podcasts.length === before) return sendJson(res, 404, { error: "Podcast not found" });
      await saveDefaultPodcasts(catalog);
      return sendJson(res, 200, { success: true });
    }

    // iTunes search
    if (pathname === "/api/itunes/search" && req.method === "GET") {
      const term = parsedUrl.searchParams.get("term");
      if (!term) return sendJson(res, 400, { error: "Missing term" });
      const results = await itunesSearch(term);
      return sendJson(res, 200, { results });
    }

    // iTunes lookup
    if (pathname === "/api/itunes/lookup" && req.method === "GET") {
      const id = parsedUrl.searchParams.get("id");
      if (!id) return sendJson(res, 400, { error: "Missing id" });
      const result = await itunesLookup(id);
      if (!result) return sendJson(res, 404, { error: "Podcast not found" });
      return sendJson(res, 200, result);
    }

    // RSS feed preview
    if (pathname === "/api/feeds/preview" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const itunesID = payload?.itunesID;
      const feedUrl = payload?.feedUrl;
      let url = feedUrl;
      if (!url && itunesID) {
        const lookup = await itunesLookup(itunesID);
        url = lookup?.feedUrl;
      }
      if (!url) return sendJson(res, 400, { error: "No feed URL found" });
      const xml = await fetchText(url);
      const meta = parseFeedMeta(xml);
      const episodes = parseRssItems(xml).slice(0, 25);
      return sendJson(res, 200, { feedUrl: url, meta, episodes });
    }

    // Enrich all podcasts with iTunes metadata
    if (pathname === "/api/podcasts/enrich" && req.method === "POST") {
      const catalog = await loadDefaultPodcasts();
      let enriched = 0;
      let failed = 0;
      for (const cat of catalog.categories || []) {
        for (const podcast of cat.podcasts || []) {
          if (!podcast.itunesID) continue;
          try {
            const info = await itunesLookup(podcast.itunesID);
            if (info) {
              if (info.name) podcast.name = info.name;
              if (info.artworkUrl) podcast.artworkUrl = info.artworkUrl;
              if (info.feedUrl) podcast.feedUrl = info.feedUrl;
              if (info.artist) podcast.artist = info.artist;
              enriched++;
            }
          } catch { failed++; }
          await new Promise((r) => setTimeout(r, 200));
        }
      }
      await saveDefaultPodcasts(catalog);
      return sendJson(res, 200, { success: true, enriched, failed });
    }

    // Media patterns
    if (pathname === "/api/media-patterns" && req.method === "GET") {
      const patterns = await loadMediaPatterns();
      return sendJson(res, 200, patterns);
    }

    if (pathname === "/api/media-patterns" && req.method === "PUT") {
      const payload = await readRequestBody(req);
      if (!payload) return sendJson(res, 400, { error: "Missing body" });
      await saveMediaPatterns(payload);
      return sendJson(res, 200, { success: true });
    }

    // Design system tokens
    if (pathname === "/api/design-system/tokens" && req.method === "GET") {
      const tokens = await loadDesignSystemTokens();
      return sendJson(res, 200, tokens);
    }

    // SSE live changes
    if (pathname === "/api/live/changes" && req.method === "GET") {
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
        "X-Accel-Buffering": "no",
      });
      res.write(`event: connected\ndata: ${JSON.stringify({ watching: Object.entries(WATCHED_SOURCES).map(([k, v]) => ({ key: k, file: v.label })), timestamp: Date.now() })}\n\n`);
      sseClients.add(res);
      req.on("close", () => sseClients.delete(res));
      const keepAlive = setInterval(() => {
        try { res.write(": keepalive\n\n"); } catch { clearInterval(keepAlive); sseClients.delete(res); }
      }, 30000);
      req.on("close", () => clearInterval(keepAlive));
      return;
    }

    // Themes CRUD
    if (pathname === "/api/themes" && req.method === "GET") {
      const themes = await loadThemePresets();
      return sendJson(res, 200, { themes });
    }

    if (pathname === "/api/themes" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const themes = await loadThemePresets();
      const normalized = normalizeThemePresetPayload(payload);
      if (!normalized) return sendJson(res, 400, { error: "Invalid theme payload" });
      if (themes.some((t) => t.name.toLowerCase() === normalized.name.toLowerCase())) {
        return sendJson(res, 409, { error: "Theme name already exists" });
      }
      themes.push(normalized);
      themes.sort((a, b) => a.name.localeCompare(b.name));
      await saveThemePresets(themes);
      return sendJson(res, 200, { success: true, theme: normalized });
    }

    if (pathname.startsWith("/api/themes/") && req.method === "PUT") {
      const themeId = decodeURIComponent(pathname.split("/").pop() || "");
      const payload = await readRequestBody(req);
      const themes = await loadThemePresets();
      const index = themes.findIndex((t) => String(t.id) === themeId);
      if (index < 0) return sendJson(res, 404, { error: "Theme not found" });
      const normalized = normalizeThemePresetPayload(payload, themes[index]);
      if (!normalized) return sendJson(res, 400, { error: "Invalid theme payload" });
      if (themes.some((t, i) => i !== index && t.name.toLowerCase() === normalized.name.toLowerCase())) {
        return sendJson(res, 409, { error: "Theme name already exists" });
      }
      themes[index] = normalized;
      themes.sort((a, b) => a.name.localeCompare(b.name));
      await saveThemePresets(themes);
      return sendJson(res, 200, { success: true, theme: normalized });
    }

    if (pathname.startsWith("/api/themes/") && req.method === "DELETE") {
      const themeId = decodeURIComponent(pathname.split("/").pop() || "");
      const themes = await loadThemePresets();
      const filtered = themes.filter((t) => String(t.id) !== themeId);
      if (filtered.length === themes.length) return sendJson(res, 404, { error: "Theme not found" });
      await saveThemePresets(filtered);
      return sendJson(res, 200, { success: true });
    }

    // Static files
    if (req.method === "GET") {
      const filePath = pathname === "/" ? path.join(PUBLIC_DIR, "index.html") : path.join(PUBLIC_DIR, pathname.replace(/^\/+/, ""));
      if (!filePath.startsWith(PUBLIC_DIR)) return sendText(res, 403, "Forbidden");
      try {
        const file = await fs.readFile(filePath);
        res.writeHead(200, { "Content-Type": getContentType(filePath), "Cache-Control": "no-store, max-age=0" });
        res.end(file);
        return;
      } catch { return sendText(res, 404, "Not found"); }
    }

    return sendText(res, 405, "Method not allowed");
  } catch (error) {
    return sendJson(res, 500, { error: "Server error", details: error.message });
  }
});

server.listen(PORT, () => {
  console.log(`PodLink Bootstrap Console running on http://localhost:${PORT}`);
});
