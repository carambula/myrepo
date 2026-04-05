const http = require("http");
const https = require("https");
const { randomUUID } = require("crypto");
const path = require("path");
const fs = require("fs/promises");
const fsSync = require("fs");

const PROJECT_ROOT = path.resolve(__dirname, "..");
const BOOTSTRAP_PATH = path.join(PROJECT_ROOT, "YourTube", "bootstrap_data.json");
const THEME_PRESETS_PATH = path.join(PROJECT_ROOT, "YourTube", "theme_presets.json");
const DESIGN_SYSTEM_PATH = path.join(PROJECT_ROOT, "YourTube", "DesignSystem", "DesignSystem.swift");
const ITEM_MODEL_PATH = path.join(PROJECT_ROOT, "YourTube", "Item.swift");
const PUBLIC_DIR = path.join(__dirname, "public");

const PORT = process.env.PORT || 4190;
const YOUTUBE_API_KEY = process.env.YOUTUBE_API_KEY || "";

// ---- SSE Live Reload ----

const WATCHED_SOURCES = {
  designSystem: { path: DESIGN_SYSTEM_PATH, label: "DesignSystem.swift" },
  itemModel: { path: ITEM_MODEL_PATH, label: "Item.swift" },
  bootstrap: { path: BOOTSTRAP_PATH, label: "bootstrap_data.json" },
  themes: { path: THEME_PRESETS_PATH, label: "theme_presets.json" },
};

const sseClients = new Set();
const fileHashes = new Map();
const watchDebounce = new Map();

async function hashFile(filePath) {
  try {
    const stat = await fs.stat(filePath);
    return `${stat.mtimeMs}:${stat.size}`;
  } catch { return null; }
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
    transport.get(url, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        if (res.statusCode && res.statusCode >= 400) {
          return reject(new Error(`Request failed (${res.statusCode}): ${data.slice(0, 200)}`));
        }
        try { resolve(JSON.parse(data)); } catch (e) { reject(e); }
      });
    }).on("error", reject);
  });
}

// ---- Data Access ----

async function loadBootstrap() {
  try {
    const data = await fs.readFile(BOOTSTRAP_PATH, "utf8");
    return JSON.parse(data);
  } catch (error) {
    if (error && error.code === "ENOENT") {
      const initial = { generatedDate: new Date().toISOString(), categories: [], channels: [] };
      await saveBootstrap(initial);
      return initial;
    }
    throw error;
  }
}

async function saveBootstrap(bootstrapData) {
  const json = JSON.stringify(bootstrapData, null, 2);
  await fs.writeFile(BOOTSTRAP_PATH, `${json}\n`, "utf8");
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
  if (idx < 0) return "";
  const braceIdx = source.indexOf("{", idx);
  return extractBraceBlock(source, braceIdx);
}

function parseNumericTokens(body) {
  const tokens = {};
  const regex = /static (?:let|var) (\w+):\s*CGFloat\s*=\s*([0-9.]+)/g;
  let m; while ((m = regex.exec(body))) tokens[m[1]] = Number(m[2]);
  return tokens;
}

function parseStringCaseEnum(body) {
  const cases = [];
  const regex = /case (\w+)\s*(?:=\s*"([^"]*)")?/g;
  let m; while ((m = regex.exec(body))) cases.push({ id: m[1], rawValue: m[2] || m[1] });
  return cases;
}

async function loadDesignSystemTokens() {
  try {
    const source = await fs.readFile(DESIGN_SYSTEM_PATH, "utf8");
    const spacingBody = extractEnumBody(source, "Spacing");
    const cornerRadiusBody = extractEnumBody(source, "CornerRadius");
    const spacing = parseNumericTokens(spacingBody);
    const cornerRadius = parseNumericTokens(cornerRadiusBody);

    const presentationBody = extractEnumBody(source, "VideoDetailPresentationMode");
    const presentationCases = parseStringCaseEnum(presentationBody);

    return {
      generatedAt: new Date().toISOString(),
      sourceFile: "YourTube/DesignSystem/DesignSystem.swift",
      spacing,
      cornerRadius,
      videoDetailPresentationModes: presentationCases,
    };
  } catch {
    return { generatedAt: new Date().toISOString(), error: "Could not read DesignSystem.swift" };
  }
}

// ---- YouTube API ----

async function youtubeSearchChannels(query, maxResults = 10) {
  if (!YOUTUBE_API_KEY) {
    return { error: "YOUTUBE_API_KEY not set. Set it via environment variable.", results: [] };
  }
  const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&type=channel&maxResults=${maxResults}&q=${encodeURIComponent(query)}&key=${YOUTUBE_API_KEY}`;
  const data = await requestJson(url);
  return {
    results: (data.items || []).map((item) => ({
      channelID: item.snippet?.channelId || item.id?.channelId || "",
      title: item.snippet?.title || "",
      description: item.snippet?.description || "",
      thumbnailURL: item.snippet?.thumbnails?.default?.url || "",
    })),
  };
}

async function youtubeChannelDetails(channelID) {
  if (!YOUTUBE_API_KEY) return null;
  const url = `https://www.googleapis.com/youtube/v3/channels?part=snippet,contentDetails,statistics&id=${encodeURIComponent(channelID)}&key=${YOUTUBE_API_KEY}`;
  const data = await requestJson(url);
  const item = data.items?.[0];
  if (!item) return null;
  return {
    channelID: item.id,
    title: item.snippet?.title || "",
    description: item.snippet?.description || "",
    thumbnailURL: item.snippet?.thumbnails?.medium?.url || item.snippet?.thumbnails?.default?.url || "",
    subscriberCount: item.statistics?.subscriberCount || null,
    videoCount: item.statistics?.videoCount || null,
    uploadsPlaylistID: item.contentDetails?.relatedPlaylists?.uploads || "",
  };
}

async function youtubeRecentVideos(channelID, maxResults = 10) {
  if (!YOUTUBE_API_KEY) return [];
  const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&channelId=${encodeURIComponent(channelID)}&type=video&order=date&maxResults=${maxResults}&key=${YOUTUBE_API_KEY}`;
  const data = await requestJson(url);
  return (data.items || []).map((item) => ({
    videoID: item.id?.videoId || "",
    title: item.snippet?.title || "",
    description: item.snippet?.description || "",
    thumbnailURL: item.snippet?.thumbnails?.medium?.url || item.snippet?.thumbnails?.default?.url || "",
    publishedAt: item.snippet?.publishedAt || "",
  }));
}

// ---- Channel Normalization ----

function normalizeChannel(payload) {
  if (!payload || typeof payload !== "object") return null;
  const channelID = String(payload.channelID || "").trim();
  const title = String(payload.title || "").trim();
  if (!channelID || !title) return null;
  return {
    channelID,
    title,
    description: String(payload.description || "").trim().slice(0, 500),
    thumbnailURL: String(payload.thumbnailURL || "").trim(),
    category: String(payload.category || "").trim() || null,
    subscriberCount: payload.subscriberCount || null,
    videoCount: payload.videoCount || null,
    uploadsPlaylistID: String(payload.uploadsPlaylistID || "").trim() || null,
    addedAt: payload.addedAt || new Date().toISOString(),
  };
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
    // Bootstrap data
    if (pathname === "/api/bootstrap" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      return sendJson(res, 200, bootstrap);
    }

    // Data health
    if (pathname === "/api/health" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      const channels = bootstrap.channels || [];
      const categories = bootstrap.categories || [];
      const withThumbnail = channels.filter((c) => c.thumbnailURL).length;
      const withDescription = channels.filter((c) => c.description).length;
      const categorized = channels.filter((c) => c.category).length;
      return sendJson(res, 200, {
        totalChannels: channels.length,
        totalCategories: categories.length,
        channelsWithThumbnail: withThumbnail,
        channelsWithDescription: withDescription,
        categorizedChannels: categorized,
        uncategorizedChannels: channels.length - categorized,
        hasYouTubeApiKey: Boolean(YOUTUBE_API_KEY),
      });
    }

    // Add category
    if (pathname === "/api/categories" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const name = String(payload?.name || "").trim();
      if (!name) return sendJson(res, 400, { error: "Missing category name" });
      const bootstrap = await loadBootstrap();
      if (!bootstrap.categories) bootstrap.categories = [];
      if (bootstrap.categories.some((c) => c.name.toLowerCase() === name.toLowerCase())) {
        return sendJson(res, 409, { error: "Category already exists" });
      }
      bootstrap.categories.push({ name });
      bootstrap.categories.sort((a, b) => a.name.localeCompare(b.name));
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true });
    }

    // Delete category
    if (pathname.startsWith("/api/categories/") && req.method === "DELETE") {
      const name = decodeURIComponent(pathname.slice("/api/categories/".length));
      const bootstrap = await loadBootstrap();
      const before = (bootstrap.categories || []).length;
      bootstrap.categories = (bootstrap.categories || []).filter((c) => c.name !== name);
      if (bootstrap.categories.length === before) return sendJson(res, 404, { error: "Category not found" });
      for (const ch of bootstrap.channels || []) {
        if (ch.category === name) ch.category = null;
      }
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true });
    }

    // Add channel
    if (pathname === "/api/channels" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const normalized = normalizeChannel(payload);
      if (!normalized) return sendJson(res, 400, { error: "Missing channelID or title" });
      const bootstrap = await loadBootstrap();
      if (!bootstrap.channels) bootstrap.channels = [];
      if (bootstrap.channels.some((c) => c.channelID === normalized.channelID)) {
        return sendJson(res, 409, { error: "Channel already exists" });
      }
      bootstrap.channels.push(normalized);
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true, channel: normalized });
    }

    // Update channel
    if (pathname.startsWith("/api/channels/") && req.method === "PUT") {
      const channelID = decodeURIComponent(pathname.slice("/api/channels/".length));
      const payload = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      const index = (bootstrap.channels || []).findIndex((c) => c.channelID === channelID);
      if (index < 0) return sendJson(res, 404, { error: "Channel not found" });
      const updated = { ...bootstrap.channels[index], ...payload };
      bootstrap.channels[index] = updated;
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true, channel: updated });
    }

    // Delete channel
    if (pathname.startsWith("/api/channels/") && req.method === "DELETE") {
      const channelID = decodeURIComponent(pathname.slice("/api/channels/".length));
      const bootstrap = await loadBootstrap();
      const before = (bootstrap.channels || []).length;
      bootstrap.channels = (bootstrap.channels || []).filter((c) => c.channelID !== channelID);
      if (bootstrap.channels.length === before) return sendJson(res, 404, { error: "Channel not found" });
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true });
    }

    // YouTube search
    if (pathname === "/api/youtube/search" && req.method === "GET") {
      const query = parsedUrl.searchParams.get("q");
      if (!query) return sendJson(res, 400, { error: "Missing query" });
      const result = await youtubeSearchChannels(query);
      return sendJson(res, 200, result);
    }

    // YouTube channel details
    if (pathname === "/api/youtube/channel" && req.method === "GET") {
      const id = parsedUrl.searchParams.get("id");
      if (!id) return sendJson(res, 400, { error: "Missing id" });
      const details = await youtubeChannelDetails(id);
      if (!details) return sendJson(res, 404, { error: "Channel not found" });
      return sendJson(res, 200, details);
    }

    // YouTube recent videos for a channel
    if (pathname === "/api/youtube/videos" && req.method === "GET") {
      const channelId = parsedUrl.searchParams.get("channelId");
      if (!channelId) return sendJson(res, 400, { error: "Missing channelId" });
      const videos = await youtubeRecentVideos(channelId);
      return sendJson(res, 200, { videos });
    }

    // Enrich channels with YouTube API metadata
    if (pathname === "/api/channels/enrich" && req.method === "POST") {
      if (!YOUTUBE_API_KEY) return sendJson(res, 400, { error: "YOUTUBE_API_KEY not set" });
      const bootstrap = await loadBootstrap();
      let enriched = 0;
      let failed = 0;
      for (const channel of bootstrap.channels || []) {
        try {
          const details = await youtubeChannelDetails(channel.channelID);
          if (details) {
            if (details.title) channel.title = details.title;
            if (details.description) channel.description = details.description;
            if (details.thumbnailURL) channel.thumbnailURL = details.thumbnailURL;
            if (details.subscriberCount) channel.subscriberCount = details.subscriberCount;
            if (details.videoCount) channel.videoCount = details.videoCount;
            if (details.uploadsPlaylistID) channel.uploadsPlaylistID = details.uploadsPlaylistID;
            enriched++;
          }
        } catch { failed++; }
        await new Promise((r) => setTimeout(r, 200));
      }
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true, enriched, failed });
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
  console.log(`YourTube Bootstrap Console running on http://localhost:${PORT}`);
});
