const http = require("http");
const https = require("https");
const { randomUUID } = require("crypto");
const { execFile } = require("child_process");
const path = require("path");
const fs = require("fs/promises");
const fsSync = require("fs");

const PROJECT_ROOT = path.resolve(__dirname, "..");
const BOOTSTRAP_PATH = path.join(PROJECT_ROOT, "WatchedIt", "bootstrap_data.json");
const THEME_PRESETS_PATH = path.join(PROJECT_ROOT, "WatchedIt", "theme_presets.json");
const DESIGN_SYSTEM_PATH = path.join(PROJECT_ROOT, "WatchedIt", "DesignSystem.swift");
const MOVIE_LIST_VIEW_PATH = path.join(PROJECT_ROOT, "WatchedIt", "MovieListView.swift");
const DETAIL_LAYOUT_PATH = path.join(PROJECT_ROOT, "WatchedIt", "MovieDetailLayoutStyles.swift");
const PUBLIC_DIR = path.join(__dirname, "public");
const TMDB_API_KEY =
  process.env.TMDB_API_KEY || "4f6ab1dde752aedd41093bab21f383c7";
const OMDB_API_KEY = process.env.OMDB_API_KEY || "c418f9f5";

const {
  fetchWikidataPhysicalMediaIndex,
  seedCriterionFromSources,
  seedCurated4K,
  filterIndexToCatalog,
  applyIndexToMovies,
  overlayFromMovies,
  overlayFromIndex,
  physicalMediaStats,
} = require("./physicalMedia");
const PHYSICAL_MEDIA_PATH = path.join(PROJECT_ROOT, "WatchedIt", "physical_media.json");

const PORT = process.env.PORT || 4187;
const PODCAST_LOOKBACK_DAYS = Math.max(
  1,
  Number.parseInt(process.env.PODCAST_LOOKBACK_DAYS || "60", 10) || 60
);
const PODCAST_INGEST_CONTRACT = Object.freeze({
  version: "podcast-ingest-v1",
  feedOrdering: "newest-first",
  fallbackLookbackDays: PODCAST_LOOKBACK_DAYS,
  cutoffRules: Object.freeze({
    withLatestKnownEpisodeDate: "only-episodes-strictly-newer",
    withoutLatestKnownEpisodeDate: "lookback-window-only",
  }),
  candidateFields: Object.freeze([
    "title",
    "sourceTitle",
    "episodeDate",
    "podcastEpisodeDescription",
  ]),
  sourceStatsFields: Object.freeze([
    "sourceIdentifier",
    "sourceName",
    "latestKnownEpisodeDate",
    "latestKnownSourceTitle",
    "scannedCount",
    "stoppedEarly",
    "stopReason",
    "skippedByNoise",
    "candidateCount",
  ]),
});

// ---- Live File Watcher + SSE ----

const WATCHED_SOURCES = {
  designSystem: { path: DESIGN_SYSTEM_PATH, label: "DesignSystem.swift" },
  settings: { path: MOVIE_LIST_VIEW_PATH, label: "MovieListView.swift" },
  detailLayout: { path: DETAIL_LAYOUT_PATH, label: "MovieDetailLayoutStyles.swift" },
  themes: { path: THEME_PRESETS_PATH, label: "theme_presets.json" },
};

const sseClients = new Set();
const fileHashes = new Map();

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

const watchDebounce = new Map();

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
            broadcastSSE("file-change", {
              source: key,
              file: src.label,
              timestamp: Date.now(),
            });
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

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

function sendText(res, status, text) {
  res.writeHead(status, { "Content-Type": "text/plain" });
  res.end(text);
}

async function readRequestBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  const body = Buffer.concat(chunks).toString("utf8");
  if (!body) {
    return null;
  }
  return JSON.parse(body);
}

async function loadBootstrap() {
  const data = await fs.readFile(BOOTSTRAP_PATH, "utf8");
  return JSON.parse(data);
}

async function loadThemePresets() {
  try {
    const data = await fs.readFile(THEME_PRESETS_PATH, "utf8");
    const parsed = JSON.parse(data);
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed;
  } catch (error) {
    if (error && error.code === "ENOENT") {
      return [];
    }
    throw error;
  }
}

async function saveThemePresets(themePresets) {
  const tempPath = `${THEME_PRESETS_PATH}.tmp`;
  const json = JSON.stringify(themePresets, null, 2);
  await fs.writeFile(tempPath, `${json}\n`, "utf8");
  await fs.rename(tempPath, THEME_PRESETS_PATH);
}

async function saveBootstrap(bootstrapData) {
  const tempPath = `${BOOTSTRAP_PATH}.tmp`;
  const json = JSON.stringify(bootstrapData, null, 2);
  await fs.writeFile(tempPath, `${json}\n`, "utf8");
  await fs.rename(tempPath, BOOTSTRAP_PATH);
}

function extractBraceBlock(source, openBraceIndex) {
  if (openBraceIndex < 0 || openBraceIndex >= source.length) {
    return "";
  }
  let depth = 0;
  for (let index = openBraceIndex; index < source.length; index += 1) {
    const char = source[index];
    if (char === "{") {
      depth += 1;
    } else if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(openBraceIndex + 1, index);
      }
    }
  }
  return "";
}

function extractEnumBody(source, enumName) {
  const enumIndex = source.indexOf(`enum ${enumName}`);
  if (enumIndex < 0) {
    return "";
  }
  const braceIndex = source.indexOf("{", enumIndex);
  return extractBraceBlock(source, braceIndex);
}

function parseNumericTokens(enumBody) {
  const tokens = {};
  const regex = /static let (\w+):\s*CGFloat\s*=\s*([0-9.]+)/g;
  let match = regex.exec(enumBody);
  while (match) {
    tokens[match[1]] = Number(match[2]);
    match = regex.exec(enumBody);
  }
  return tokens;
}

function parseTypographyTokens(enumBody) {
  const tokens = {};
  const systemRegex =
    /static let (\w+)\s*=\s*Font\.system\(size:\s*([0-9.]+),\s*weight:\s*\.([a-zA-Z]+).*?\)/g;
  let systemMatch = systemRegex.exec(enumBody);
  while (systemMatch) {
    tokens[systemMatch[1]] = {
      size: Number(systemMatch[2]),
      weight: systemMatch[3],
      source: "Font.system",
    };
    systemMatch = systemRegex.exec(enumBody);
  }

  const sizeRegex = /static var (\w+):\s*Font\s*\{([\s\S]*?)\}/g;
  let sizeMatch = sizeRegex.exec(enumBody);
  while (sizeMatch) {
    const name = sizeMatch[1];
    const body = sizeMatch[2];
    const sizeNum = body.match(/size:\s*([0-9.]+)/);
    const weightStr = body.match(/weight:\s*(?:Font\.Weight\.|\.)(\w+)/);
    if (sizeNum && !tokens[name]) {
      tokens[name] = {
        size: Number(sizeNum[1]),
        weight: weightStr ? weightStr[1] : null,
        source: "theme-style",
      };
    }
    sizeMatch = sizeRegex.exec(enumBody);
  }

  if (!tokens.overline) {
    const overlineRegex =
      /static let overline\s*=\s*Font\.system\(size:\s*([0-9.]+),\s*weight:\s*\.([a-zA-Z]+).*?\)/;
    const overlineMatch = enumBody.match(overlineRegex);
    if (overlineMatch) {
      tokens.overline = {
        size: Number(overlineMatch[1]),
        weight: overlineMatch[2],
        source: "Font.system",
      };
    }
  }

  return tokens;
}

function parseIconTokens(enumBody) {
  const tokens = {};
  const regex = /static let (\w+)\s*=\s*"([^"]+)"/g;
  let match = regex.exec(enumBody);
  while (match) {
    tokens[match[1]] = match[2];
    match = regex.exec(enumBody);
  }
  return tokens;
}

function parseColorTokenNames(enumBody) {
  const names = [];
  const regex = /static (?:let|var) (\w+)/g;
  let match = regex.exec(enumBody);
  while (match) {
    names.push(match[1]);
    match = regex.exec(enumBody);
  }
  return Array.from(new Set(names));
}

function parseAnimationTokens(enumBody) {
  const tokens = {};
  const easeRegex = /static let (\w+)\s*=\s*\w*\.?Animation\.easeInOut\(duration:\s*([0-9.]+)\)/g;
  let m = easeRegex.exec(enumBody);
  while (m) {
    tokens[m[1]] = { duration: Number(m[2]), easing: "ease-in-out" };
    m = easeRegex.exec(enumBody);
  }
  const springRegex = /static let (\w+)\s*=\s*\w*\.?Animation\.spring\(response:\s*([0-9.]+),\s*dampingFraction:\s*([0-9.]+)\)/g;
  let s = springRegex.exec(enumBody);
  while (s) {
    tokens[s[1]] = { duration: Number(s[2]), damping: Number(s[3]), easing: "spring" };
    s = springRegex.exec(enumBody);
  }
  return tokens;
}

function parseShadowTokens(enumBody) {
  const tokens = {};
  const regex = /static let (\w+)\s*=\s*\(color:\s*\w+\.Color\.black\.opacity\(([0-9.]+)\),\s*radius:\s*CGFloat\(([0-9.]+)\),\s*x:\s*CGFloat\(([0-9.]+)\),\s*y:\s*CGFloat\(([0-9.]+)\)\)/g;
  let m = regex.exec(enumBody);
  while (m) {
    tokens[m[1]] = { opacity: Number(m[2]), radius: Number(m[3]), x: Number(m[4]), y: Number(m[5]) };
    m = regex.exec(enumBody);
  }
  return tokens;
}

function parseOpacityTokens(enumBody) {
  const tokens = {};
  const regex = /static let (\w+):\s*Double\s*=\s*([0-9.]+)/g;
  let m = regex.exec(enumBody);
  while (m) {
    tokens[m[1]] = Number(m[2]);
    m = regex.exec(enumBody);
  }
  return tokens;
}

function parseGlassControlTokens(source) {
  const tokens = {};
  const enumIndex = source.indexOf("enum GlassControl");
  if (enumIndex < 0) return tokens;
  const braceIndex = source.indexOf("{", enumIndex);
  const body = extractBraceBlock(source, braceIndex);
  const regex = /static let (\w+):\s*CGFloat\s*=\s*([0-9.]+)/g;
  let m = regex.exec(body);
  while (m) {
    tokens[m[1]] = Number(m[2]);
    m = regex.exec(body);
  }
  return tokens;
}

function swiftWeightToCss(weight) {
  const map = { ultraLight: 100, thin: 200, light: 300, regular: 400, medium: 500, semibold: 600, bold: 700, heavy: 800, black: 900 };
  return map[weight] || 400;
}

function toPx(value) {
  if (typeof value !== "number" || Number.isNaN(value)) return null;
  return `${value}px`;
}

function buildDesignSystemTokenPayload(source) {
  const colorBody = extractEnumBody(source, "Color");
  const typographyBody = extractEnumBody(source, "Typography");
  const spacingBody = extractEnumBody(source, "Spacing");
  const cornerRadiusBody = extractEnumBody(source, "CornerRadius");
  const iconBody = extractEnumBody(source, "Icon");
  const animationBody = extractEnumBody(source, "Animation");
  const shadowBody = extractEnumBody(source, "Shadow");
  const iconSizeBody = extractEnumBody(source, "IconSize");
  const opacityBody = extractEnumBody(source, "Opacity");

  const spacing = parseNumericTokens(spacingBody);
  const cornerRadius = parseNumericTokens(cornerRadiusBody);
  const typography = parseTypographyTokens(typographyBody);
  const icons = parseIconTokens(iconBody);
  const colorTokenNames = parseColorTokenNames(colorBody);
  const animations = parseAnimationTokens(animationBody);
  const shadows = parseShadowTokens(shadowBody);
  const iconSize = parseNumericTokens(iconSizeBody);
  const opacity = parseOpacityTokens(opacityBody);
  const glass = parseGlassControlTokens(source);

  const cssVars = {};

  // Legacy admin aliases (kept for backward compat)
  const adminSpaceMap = { xs: "2xs", sm: "xs", md: "sm", lg: "md", xl: "lg", xxl: "xl", xxxl: "2xl" };
  for (const [swift, admin] of Object.entries(adminSpaceMap)) {
    if (spacing[swift] != null) cssVars[`--space-${admin}`] = toPx(spacing[swift]);
  }

  // Canonical spacing: --ds-space-{swiftName}
  for (const [name, val] of Object.entries(spacing)) {
    cssVars[`--ds-space-${name}`] = toPx(val);
  }

  // Canonical corner radius: --ds-radius-{swiftName}
  for (const [name, val] of Object.entries(cornerRadius)) {
    cssVars[`--ds-radius-${name}`] = toPx(val);
  }
  // Legacy radius aliases
  for (const name of ["sm", "md", "lg", "xl", "round"]) {
    if (cornerRadius[name] != null) cssVars[`--radius-${name}`] = toPx(cornerRadius[name]);
  }

  // Canonical typography: --ds-type-{tokenName}-size and -weight
  for (const [name, info] of Object.entries(typography)) {
    if (info.size) cssVars[`--ds-type-${name}-size`] = toPx(info.size);
    cssVars[`--ds-type-${name}-weight`] = String(swiftWeightToCss(info.weight));
  }

  // Canonical shadows: --ds-shadow-{name}
  for (const [name, s] of Object.entries(shadows)) {
    cssVars[`--ds-shadow-${name}`] = `${s.x}px ${s.y}px ${s.radius}px rgba(0,0,0,${s.opacity})`;
  }

  // Canonical icon sizes: --ds-icon-{name}
  for (const [name, val] of Object.entries(iconSize)) {
    cssVars[`--ds-icon-${name}`] = toPx(val);
  }

  // Canonical opacity: --ds-opacity-{name}
  for (const [name, val] of Object.entries(opacity)) {
    cssVars[`--ds-opacity-${name}`] = String(val);
  }

  // Canonical animations: --ds-anim-{name}
  for (const [name, a] of Object.entries(animations)) {
    if (a.easing === "spring") {
      cssVars[`--ds-anim-${name}`] = `${a.duration}s`;
      cssVars[`--ds-anim-${name}-damping`] = String(a.damping);
    } else {
      cssVars[`--ds-anim-${name}`] = `${a.duration}s`;
      cssVars[`--ds-anim-${name}-easing`] = a.easing;
    }
  }

  // Glass control constants: --ds-glass-{name}
  for (const [name, val] of Object.entries(glass)) {
    const cssName = name.replace(/([A-Z])/g, "-$1").toLowerCase();
    cssVars[`--ds-glass-${cssName}`] = toPx(val);
  }

  Object.keys(cssVars).forEach((key) => {
    if (cssVars[key] == null || cssVars[key] === "") delete cssVars[key];
  });

  return {
    generatedAt: new Date().toISOString(),
    sourceFile: "WatchedIt/DesignSystem.swift",
    spacing,
    cornerRadius,
    typography,
    icons,
    colorTokenNames,
    animations,
    shadows,
    iconSize,
    opacity,
    glass,
    cssVars,
  };
}

async function loadDesignSystemTokens() {
  const source = await fs.readFile(DESIGN_SYSTEM_PATH, "utf8");
  return buildDesignSystemTokenPayload(source);
}

// ---- Settings Enum Parsing ----

function extractComputedPropertyBody(enumBody, propertyName) {
  const propRegex = new RegExp(
    `var\\s+${propertyName}\\s*:\\s*\\w+\\s*\\{`
  );
  const match = propRegex.exec(enumBody);
  if (!match) return "";
  const braceStart = enumBody.indexOf("{", match.index + match[0].length - 1);
  return extractBraceBlock(enumBody, braceStart);
}

function parseSwitchCaseStrings(block) {
  const result = {};
  const regex = /case\s*\.(\w+)\s*:\s*\n\s*return\s*"([^"]+)"/g;
  let m = regex.exec(block);
  while (m) {
    result[m[1]] = m[2];
    m = regex.exec(block);
  }
  return result;
}

function parseSwitchCaseNumbers(block) {
  const result = {};
  const regex = /case\s*\.(\w+)\s*:\s*\n\s*return\s+([0-9.]+)/g;
  let m = regex.exec(block);
  while (m) {
    result[m[1]] = Number(m[2]);
    m = regex.exec(block);
  }
  return result;
}

function parseStringCaseEnum(source, enumName) {
  const body = extractEnumBody(source, enumName);
  if (!body) return null;

  const cases = [];
  const caseRegex = /case\s+(\w+)\s*=\s*"([^"]+)"/g;
  let m = caseRegex.exec(body);
  while (m) {
    cases.push({ id: m[1], rawValue: m[2] });
    m = caseRegex.exec(body);
  }

  const descBody = extractComputedPropertyBody(body, "description");
  const descriptions = parseSwitchCaseStrings(descBody);
  cases.forEach((c) => {
    if (descriptions[c.id]) c.description = descriptions[c.id];
  });

  const storageKeyMatch = body.match(
    /static var storageKey[^{]*\{[^}]*return\s*"([^"]+)"/
  );

  return {
    name: enumName,
    storageKey: storageKeyMatch ? storageKeyMatch[1] : null,
    cases,
  };
}

function parsePosterSizePreference(source) {
  const result = parseStringCaseEnum(source, "PosterSizePreference");
  if (!result) return null;

  const body = extractEnumBody(source, "PosterSizePreference");
  const scaleBody = extractComputedPropertyBody(body, "scale");
  const scales = parseSwitchCaseNumbers(scaleBody);
  result.cases.forEach((c) => {
    if (scales[c.id] != null) c.scale = scales[c.id];
  });

  const baseWMatch = source.match(
    /baseInspirationPosterWidth:\s*CGFloat\s*=\s*([0-9.]+)/
  );
  const baseHMatch = source.match(
    /baseInspirationPosterHeight:\s*CGFloat\s*=\s*([0-9.]+)/
  );
  result.baseWidth = baseWMatch ? Number(baseWMatch[1]) : 100;
  result.baseHeight = baseHMatch ? Number(baseHMatch[1]) : 150;

  return result;
}

function parseCustomToolbarIconSpacing(source) {
  const result = parseStringCaseEnum(source, "CustomToolbarIconSpacing");
  if (!result) return null;

  const body = extractEnumBody(source, "CustomToolbarIconSpacing");
  const pointsBody = extractComputedPropertyBody(body, "points");
  const points = parseSwitchCaseNumbers(pointsBody);
  result.cases.forEach((c) => {
    if (points[c.id] != null) c.points = points[c.id];
  });

  return result;
}

async function loadAppSettings() {
  let movieListSource = "";
  let detailLayoutSource = "";
  try {
    movieListSource = await fs.readFile(MOVIE_LIST_VIEW_PATH, "utf8");
  } catch (_) {}
  try {
    detailLayoutSource = await fs.readFile(DETAIL_LAYOUT_PATH, "utf8");
  } catch (_) {}

  return {
    generatedAt: new Date().toISOString(),
    sourceFiles: [
      "WatchedIt/MovieListView.swift",
      "WatchedIt/MovieDetailLayoutStyles.swift",
    ],
    posterSizePreference: parsePosterSizePreference(movieListSource),
    mainListToolbarStyle: parseStringCaseEnum(
      movieListSource,
      "MainListToolbarStyle"
    ),
    mainToolbarLayoutStyle: parseStringCaseEnum(
      movieListSource,
      "MainToolbarLayoutStyle"
    ),
    customToolbarIconSpacing: parseCustomToolbarIconSpacing(movieListSource),
    searchBarAppearance: parseStringCaseEnum(
      movieListSource,
      "SearchBarAppearance"
    ),
    movieDetailLayoutStyle: parseStringCaseEnum(
      detailLayoutSource,
      "MovieDetailLayoutStyle"
    ),
    movieDetailActionBarPosition: parseStringCaseEnum(
      detailLayoutSource,
      "MovieDetailActionBarPosition"
    ),
    movieDetailActionBarLayout: parseStringCaseEnum(
      detailLayoutSource,
      "MovieDetailActionBarLayout"
    ),
    movieDetailLayoutParameters: parseLayoutParameterDefaults(detailLayoutSource),
  };
}

function parseLayoutParameterDefaults(source) {
  const match = source.match(
    /struct\s+MovieDetailLayoutParameters\s*\{([\s\S]*?)(?:\n\s*static\s|func\s+encode)/
  );
  if (!match) return {};
  const body = match[1];
  const result = {};
  const propRe = /var\s+(\w+):\s*\w+\s*=\s*([^\n]+)/g;
  let m;
  while ((m = propRe.exec(body)) !== null) {
    const name = m[1];
    const raw = m[2].trim();
    if (raw === "true" || raw === "false") {
      result[name] = raw === "true";
    } else if (raw.startsWith(".")) {
      result[name] = raw.slice(1);
    } else {
      const num = parseFloat(raw);
      if (!isNaN(num)) result[name] = num;
    }
  }
  return result;
}

function withMovieIndexes(bootstrapData) {
  const movies = bootstrapData.movies.map((movie, index) => ({
    __index: index,
    ...movie,
  }));
  return { ...bootstrapData, movies };
}

function normalizeSourceType(value) {
  return value === "podcast" ? "podcast" : "url";
}

function normalizeSourcePayload(payload, existing = null) {
  if (!payload || typeof payload !== "object") {
    return null;
  }
  const identifier = String(payload.identifier || "")
    .trim()
    .toLowerCase();
  const name = String(payload.name || "").trim();
  const url = String(payload.url || "").trim();
  if (!identifier || !name || !url) {
    return null;
  }
  return {
    identifier,
    name,
    type: normalizeSourceType(payload.type),
    url,
    isRankedList: Boolean(payload.isRankedList),
    movieCount: Number(existing?.movieCount || 0),
  };
}

function syncSourceMovieCounts(bootstrapData) {
  const countByIdentifier = new Map();
  for (const movie of bootstrapData.movies || []) {
    if (!movie.sourceIdentifier) {
      continue;
    }
    countByIdentifier.set(
      movie.sourceIdentifier,
      (countByIdentifier.get(movie.sourceIdentifier) || 0) + 1
    );
  }
  for (const source of bootstrapData.dataSources || []) {
    source.movieCount = countByIdentifier.get(source.identifier) || 0;
  }
}

function clampColorChannel(value, fallback = 0) {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return fallback;
  }
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
  const clampedRatio = Math.max(0, Math.min(1, Number(ratio) || 0));
  return {
    red: clampColorChannel(baseColor.red * (1 - clampedRatio) + targetColor.red * clampedRatio),
    green: clampColorChannel(baseColor.green * (1 - clampedRatio) + targetColor.green * clampedRatio),
    blue: clampColorChannel(baseColor.blue * (1 - clampedRatio) + targetColor.blue * clampedRatio),
    alpha: clampColorChannel(baseColor.alpha, 1),
  };
}

function normalizeThemePresetPayload(payload, existing = null) {
  if (!payload || typeof payload !== "object") {
    return null;
  }
  const nowIso = new Date().toISOString();
  const name = String(payload.name || "")
    .trim()
    .slice(0, 80);
  if (!name) {
    return null;
  }
  const builtInThemeName = payload.builtInThemeName
    ? String(payload.builtInThemeName).trim().slice(0, 80)
    : null;
  const headlineFontStyle = payload.headlineFontStyle
    ? String(payload.headlineFontStyle).trim().slice(0, 64)
    : "system-default";
  const bodyFontStyle = payload.bodyFontStyle
    ? String(payload.bodyFontStyle).trim().slice(0, 64)
    : "system-default";
  const darkModeHeadlineColor = normalizeThemeColor(
    payload.darkModeHeadlineColor || payload.headlineColor
  );
  const lightModeHeadlineColor = normalizeThemeColor(
    payload.lightModeHeadlineColor || payload.headlineColor
  );
  const darkModeBackground = normalizeThemeColor(payload.darkModeBackground);
  const lightModeBackground = normalizeThemeColor(payload.lightModeBackground);
  const darkModeBackgroundTint = mixThemeColors(
    darkModeBackground,
    { red: 1, green: 1, blue: 1, alpha: 1 },
    0.03
  );
  const lightModeBackgroundTint = mixThemeColors(
    lightModeBackground,
    { red: 0, green: 0, blue: 0, alpha: 1 },
    0.03
  );
  return {
    id: existing?.id || payload.id || randomUUID(),
    name,
    builtInThemeName: builtInThemeName || null,
    headlineFontStyle,
    bodyFontStyle,
    accent: normalizeThemeColor(payload.accent),
    secondaryAccent: normalizeThemeColor(payload.secondaryAccent),
    // Keep legacy key for older tooling while storing mode-specific values.
    headlineColor: darkModeHeadlineColor,
    darkModeHeadlineColor,
    lightModeHeadlineColor,
    // Keep legacy key while providing mode-specific tints.
    backgroundTint: darkModeBackgroundTint,
    darkModeBackgroundTint,
    lightModeBackgroundTint,
    darkModeBackground,
    lightModeBackground,
    supportsLightMode: Boolean(payload.supportsLightMode),
    createdAt: existing?.createdAt || nowIso,
    lastUpdated: nowIso,
  };
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
            return reject(
              new Error(`Request failed (${res.statusCode}): ${data.slice(0, 200)}`)
            );
          }
          try {
            resolve(JSON.parse(data));
          } catch (error) {
            reject(error);
          }
        });
      })
      .on("error", reject);
  });
}

function parseRssItems(xml) {
  const items = [];
  const itemRegex = /<item[\s\S]*?<\/item>/gi;
  const titleRegex = /<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>|<title>([\s\S]*?)<\/title>/i;
  const guidRegex = /<guid[^>]*>([\s\S]*?)<\/guid>/i;
  const pubDateRegex = /<pubDate>([\s\S]*?)<\/pubDate>/i;
  const descRegex = /<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>|<description>([\s\S]*?)<\/description>/i;

  const matches = xml.match(itemRegex) || [];
  for (const match of matches) {
    const titleMatch = match.match(titleRegex);
    const guidMatch = match.match(guidRegex);
    const dateMatch = match.match(pubDateRegex);
    const descMatch = match.match(descRegex);
    const rawTitle = (titleMatch?.[1] || titleMatch?.[2] || "").trim();
    if (!rawTitle) {
      continue;
    }
    items.push({
      title: rawTitle,
      guid: (guidMatch?.[1] || "").trim(),
      pubDate: (dateMatch?.[1] || "").trim(),
      description: (descMatch?.[1] || descMatch?.[2] || "").trim(),
    });
  }
  return items;
}

function parseRssDate(value) {
  if (!value) {
    return null;
  }
  const parsed = Date.parse(value);
  return Number.isNaN(parsed) ? null : new Date(parsed);
}

function normalizeEpisodeTitle(title) {
  return (title || "").trim().toLowerCase();
}

function shouldSkipPodcastNoise(sourceIdentifier, rawTitle, cleanedTitle) {
  const normalizedRaw = normalizeEpisodeTitle(rawTitle);
  const normalizedCleaned = normalizeEpisodeTitle(cleanedTitle);
  if (!normalizedCleaned) {
    return true;
  }

  // Big Picture has many non-movie episodes (mailbags, drafts, news).
  // Keep this conservative to avoid skipping obvious movie episodes.
  if (sourceIdentifier === "big-picture") {
    const bigPictureNoisePattern =
      /\b(mailbag|draft|auction|box office|top\s*\d+|rankings|hall of fame|interview|preview|q&a|questions|state of|awards? race|oscars?|emmys?|tv corner|trailer talk|news round(up)?|hot take|power rankings)\b/i;
    if (bigPictureNoisePattern.test(normalizedRaw)) {
      return true;
    }
  }

  return false;
}

function isRecentPodcastItem(pubDate, now = new Date()) {
  const publishedAt = parseRssDate(pubDate);
  if (!publishedAt) {
    return true;
  }
  const cutoff = new Date(
    now.getTime() -
      PODCAST_INGEST_CONTRACT.fallbackLookbackDays * 24 * 60 * 60 * 1000
  );
  return publishedAt >= cutoff;
}

function buildPodcastSourceState(bootstrapData, sourceIdentifiers = null) {
  const allowed = sourceIdentifiers ? new Set(sourceIdentifiers) : null;
  const podcastSourceIds = new Set(
    (bootstrapData.dataSources || [])
      .filter((source) => source.type === "podcast" && source.url)
      .map((source) => source.identifier)
      .filter((id) => !allowed || allowed.has(id))
  );

  const stateBySource = new Map();
  for (const sourceId of podcastSourceIds) {
    stateBySource.set(sourceId, {
      sourceIdentifier: sourceId,
      existingSourceTitles: new Set(),
      latestEpisodeDate: null,
      latestKnownSourceTitle: null,
      latestKnownSourceTitleNormalized: "",
    });
  }

  for (const movie of bootstrapData.movies || []) {
    const sourceId = movie.sourceIdentifier;
    if (!sourceId || !stateBySource.has(sourceId)) {
      continue;
    }
    const state = stateBySource.get(sourceId);
    const normalizedTitle = normalizeEpisodeTitle(movie.sourceTitle || movie.title || "");
    state.existingSourceTitles.add(normalizedTitle);
    if (!state.latestKnownSourceTitleNormalized && normalizedTitle) {
      state.latestKnownSourceTitle = movie.sourceTitle || movie.title || null;
      state.latestKnownSourceTitleNormalized = normalizedTitle;
    }

    const episodeDate = parseRssDate(movie.episodeDate);
    if (episodeDate && (!state.latestEpisodeDate || episodeDate > state.latestEpisodeDate)) {
      state.latestEpisodeDate = episodeDate;
    }
  }

  return stateBySource;
}

function collectNewPodcastItemsFromFeed(rssItems, sourceState, now = new Date()) {
  const latestEpisodeDate = sourceState?.latestEpisodeDate || null;
  const latestKnownSourceTitle = sourceState?.latestKnownSourceTitle || null;
  const latestKnownSourceTitleNormalized =
    sourceState?.latestKnownSourceTitleNormalized || "";
  const sourceIdentifier = sourceState?.sourceIdentifier || null;
  const existingSourceTitles = sourceState?.existingSourceTitles || new Set();
  const candidates = [];
  let scannedCount = 0;
  let stoppedEarly = false;
  let stopReason = null;
  let skippedByNoise = 0;

  // RSS feeds are expected newest -> oldest. Once we reach a dated episode at/before
  // the watermark we can stop scanning.
  for (const item of rssItems) {
    scannedCount += 1;
    const normalizedSourceTitle = normalizeEpisodeTitle(item.title);
    if (!normalizedSourceTitle) {
      continue;
    }
    if (
      latestKnownSourceTitleNormalized &&
      normalizedSourceTitle === latestKnownSourceTitleNormalized
    ) {
      stoppedEarly = true;
      stopReason = "latest-known-title";
      break;
    }
    if (existingSourceTitles.has(normalizedSourceTitle)) {
      continue;
    }

    const pubDate = parseRssDate(item.pubDate);
    if (latestEpisodeDate) {
      if (!pubDate) {
        continue;
      }
      if (pubDate <= latestEpisodeDate) {
        stoppedEarly = true;
        stopReason = "latest-known-date";
        break;
      }
    } else if (!isRecentPodcastItem(item.pubDate, now)) {
      continue;
    }

    const cleanedTitle = cleanPodcastTitle(item.title);
    if (!cleanedTitle) {
      continue;
    }
    if (shouldSkipPodcastNoise(sourceIdentifier, item.title, cleanedTitle)) {
      skippedByNoise += 1;
      continue;
    }

    candidates.push({
      title: cleanedTitle,
      sourceTitle: item.title,
      episodeDate: item.pubDate || null,
      podcastEpisodeDescription: item.description || null,
    });
  }

  return {
    candidates,
    stats: {
      latestEpisodeDate: latestEpisodeDate ? latestEpisodeDate.toISOString() : null,
      latestKnownSourceTitle,
      scannedCount,
      stoppedEarly,
      stopReason,
      skippedByNoise,
    },
  };
}

function buildPodcastSourceStat(source, stats, candidateCount) {
  return {
    sourceIdentifier: source.identifier,
    sourceName: source.name,
    latestKnownEpisodeDate: stats.latestEpisodeDate,
    latestKnownSourceTitle: stats.latestKnownSourceTitle,
    scannedCount: stats.scannedCount,
    stoppedEarly: stats.stoppedEarly,
    stopReason: stats.stopReason,
    skippedByNoise: stats.skippedByNoise,
    candidateCount,
  };
}

function toPodcastPreviewItem(candidate, source) {
  return {
    title: candidate.title,
    sourceTitle: candidate.sourceTitle,
    sourceIdentifier: source.identifier,
    sourceName: source.name,
    rank: null,
    episodeDate: candidate.episodeDate || null,
    podcastEpisodeDescription: candidate.podcastEpisodeDescription || null,
  };
}

function toBootstrapPodcastMovie(candidate, sourceIdentifier) {
  return {
    title: candidate.title,
    sourceIdentifier,
    rank: null,
    sourceTitle: candidate.sourceTitle,
    tmdbId: null,
    year: null,
    posterPath: null,
    backdropPath: null,
    overview: null,
    mpaaRating: null,
    genres: [],
    streamingServices: [],
    credits: null,
    trailer: null,
    podcastEpisodeDescription: candidate.podcastEpisodeDescription || null,
    episodeDate: candidate.episodeDate || null,
  };
}

function cleanPodcastTitle(title) {
  // Keep parity with WatchedIt/PodcastEpisodeIntakeService.swift (iOS + tvOS shared).
  let cleaned = title;
  cleaned = cleaned.replace(/^["'“”‘’]+|["'“”‘’]+$/g, "");
  cleaned = cleaned.replace(/\s+/g, " ").trim();

  const withIndex = cleaned.toLowerCase().indexOf(" with ");
  if (withIndex > 0) {
    cleaned = cleaned.slice(0, withIndex).trim();
  }

  const dashIndex = cleaned.indexOf(" - ");
  if (dashIndex > 0) {
    cleaned = cleaned.slice(0, dashIndex).trim();
  }

  cleaned = cleaned.replace(/^episode\s+\d+:\s*/i, "").trim();
  cleaned = cleaned.replace(/^\d+[\.\):\-]\s+/, "").trim();
  cleaned = cleaned.replace(/[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$/g, "").trim();
  cleaned = cleaned.replace(/^["'“”‘’]+|["'“”‘’]+$/g, "").trim();
  return cleaned;
}

function extractMpaaRating(releaseDates) {
  const usEntry = releaseDates?.results?.find((entry) => entry.iso_3166_1 === "US");
  if (!usEntry) {
    return null;
  }
  const certification = usEntry.release_dates?.find((date) => date.certification);
  return certification?.certification || null;
}

function pickTrailer(videos) {
  const youtube = videos?.results?.filter((video) => video.site === "YouTube") || [];
  const official = youtube.find((video) => video.type === "Trailer" && video.official);
  const fallback =
    youtube.find((video) => video.type === "Trailer") || youtube[0] || null;
  const selected = official || fallback;
  if (!selected) {
    return null;
  }
  return {
    id: selected.id,
    name: selected.name,
    youtubeKey: selected.key,
    isOfficial: Boolean(selected.official),
  };
}

function mapStreamingProviders(result, region) {
  const regionData = result?.results?.[region];
  if (!regionData) {
    return [];
  }

  const providerBuckets = [
    ...(regionData.flatrate || []),
    ...(regionData.rent || []),
    ...(regionData.buy || []),
  ];

  const providerMap = new Map();
  for (const provider of providerBuckets) {
    if (!provider || provider.provider_id == null) {
      continue;
    }
    if (!providerMap.has(provider.provider_id)) {
      providerMap.set(provider.provider_id, {
        providerId: provider.provider_id,
        providerName: provider.provider_name,
        logoPath: provider.logo_path || null,
        displayPriority: provider.display_priority ?? 999,
      });
    }
  }

  return Array.from(providerMap.values()).sort(
    (a, b) => a.displayPriority - b.displayPriority
  );
}

function providersEqual(left, right) {
  if (left.length !== right.length) {
    return false;
  }
  for (let index = 0; index < left.length; index += 1) {
    if (left[index].providerId !== right[index].providerId) {
      return false;
    }
  }
  return true;
}

async function fetchStreamingServices(tmdbId, region) {
  const url = new URL(`https://api.themoviedb.org/3/movie/${tmdbId}/watch/providers`);
  url.searchParams.set("api_key", TMDB_API_KEY);
  const data = await requestJson(url.toString());
  return mapStreamingProviders(data, region);
}

async function fetchHtml(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => resolve(data));
      })
      .on("error", reject);
  });
}

function scrapeRottenTomatoesGuide(html) {
  const matches = html.match(/<a[^>]*href="[^"]*rottentomatoes\.com\/m\/[^"]*"[^>]*>([^<]+)<\/a>/gi) || [];
  const titles = [];
  const seen = new Set();
  for (const match of matches) {
    const textMatch = match.match(/>([^<]+)</);
    if (!textMatch) continue;
    let title = textMatch[1].replace(/&#039;/g, "'").replace(/&amp;/g, "&").trim();
    if (!title || title.length > 200) continue;
    const normalized = title.toLowerCase();
    if (seen.has(normalized)) continue;
    seen.add(normalized);
    titles.push({ title, rank: titles.length + 1 });
  }
  return titles;
}

function scrapeImdbList(html) {
  const matches = html.match(/<a[^>]*href="\/title\/tt\d+\/"[^>]*>([^<]+)<\/a>/gi) || [];
  const titles = [];
  const seen = new Set();
  for (const match of matches) {
    const textMatch = match.match(/>([^<]+)</);
    if (!textMatch) continue;
    let title = textMatch[1].replace(/&#x27;/g, "'").replace(/&amp;/g, "&").trim();
    title = title.replace(/\(\d{4}\)\s*$/, "").trim();
    if (!title || title.length > 200) continue;
    const normalized = title.toLowerCase();
    if (seen.has(normalized)) continue;
    seen.add(normalized);
    titles.push({ title, rank: titles.length + 1 });
  }
  return titles;
}

async function previewListItems(url) {
  const html = await fetchHtml(url);
  if (url.includes("rottentomatoes.com/guide/")) {
    return scrapeRottenTomatoesGuide(html);
  }
  if (url.includes("imdb.com/list/") || url.includes("imdb.com/chart/")) {
    return scrapeImdbList(html);
  }
  return [];
}

function markDuplicates(items, bootstrapData, sourceIdentifier) {
  const existingSourceTitles = new Set(
    bootstrapData.movies
      .filter((movie) => movie.sourceIdentifier === sourceIdentifier)
      .map((movie) => movie.sourceTitle || movie.title)
  );
  return items.map((item) => ({
    ...item,
    isDuplicate: existingSourceTitles.has(item.sourceTitle || item.title),
  }));
}

async function enrichItems(items) {
  const enriched = [];
  for (const item of items) {
    try {
      const { query, year } = buildTmdbSearchInput(item.title);
      const searchUrl = new URL("https://api.themoviedb.org/3/search/movie");
      searchUrl.searchParams.set("api_key", TMDB_API_KEY);
      searchUrl.searchParams.set("query", query);
      if (year) {
        searchUrl.searchParams.set("year", String(year));
      }
      const search = await requestJson(searchUrl.toString());
      const first = search.results?.[0];
      if (!first) {
        enriched.push(item);
        continue;
      }
      const detailsUrl = new URL(`https://api.themoviedb.org/3/movie/${first.id}`);
      detailsUrl.searchParams.set("api_key", TMDB_API_KEY);
      detailsUrl.searchParams.set("append_to_response", "credits,videos,release_dates");
      const details = await requestJson(detailsUrl.toString());
      const merged = applyTmdbData(item, details);
      const status = determineItemStatus(merged);
      enriched.push({ ...merged, tmdbId: details.id, status });
    } catch {
      enriched.push({ ...item, status: "missing" });
    }
  }
  return enriched;
}

function buildTmdbSearchInput(rawTitle) {
  // Keep parity with PodcastEpisodeIntakeService.buildTMDBSearchInput(rawTitle:).
  let query = (rawTitle || "").trim();
  let year = null;

  const yearMatch = query.match(/[\(\[]\s*((?:19|20)\d{2})\s*[\)\]]\s*$/);
  if (yearMatch) {
    year = Number.parseInt(yearMatch[1], 10) || null;
  }

  query = query.replace(/[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$/g, "").trim();
  query = query.replace(/\s+/g, " ").trim();

  return {
    query: query || (rawTitle || "").trim(),
    year,
  };
}

function determineItemStatus(item) {
  if (!item.tmdbId) {
    return "missing";
  }
  const hasCore =
    item.year &&
    item.posterPath &&
    item.overview &&
    item.genres &&
    item.genres.length > 0;
  return hasCore ? "enriched" : "light";
}

function buildDedupeGroups(bootstrapData) {
  const groups = new Map();
  bootstrapData.movies.forEach((movie, index) => {
    const sourceTitle = movie.sourceTitle || movie.title || "";
    const key = `${movie.sourceIdentifier}|${sourceTitle.toLowerCase()}`;
    if (!groups.has(key)) {
      groups.set(key, {
        key,
        sourceIdentifier: movie.sourceIdentifier,
        sourceName:
          bootstrapData.dataSources.find((source) => source.identifier === movie.sourceIdentifier)
            ?.name || movie.sourceIdentifier,
        title: sourceTitle,
        items: [],
      });
    }
    groups.get(key).items.push({
      index,
      title: movie.title,
      year: movie.year || null,
      tmdbId: movie.tmdbId || null,
    });
  });

  return Array.from(groups.values())
    .filter((group) => group.items.length > 1)
    .map((group) => ({
      ...group,
      items: group.items.sort((a, b) => (a.tmdbId || 0) - (b.tmdbId || 0)),
    }));
}

async function handleBootstrapRefreshPodcast(sourceIdentifier) {
  const bootstrapData = await loadBootstrap();
  const source = bootstrapData.dataSources.find(
    (item) => item.identifier === sourceIdentifier
  );
  if (!source || source.type !== "podcast" || !source.url) {
    throw new Error("Invalid podcast source");
  }

  const rssXml = await new Promise((resolve, reject) => {
    https
      .get(source.url, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => resolve(data));
      })
      .on("error", reject);
  });

  const items = parseRssItems(rssXml);
  const podcastStateBySource = buildPodcastSourceState(bootstrapData, [sourceIdentifier]);
  const sourceState = podcastStateBySource.get(sourceIdentifier);
  const { candidates, stats } = collectNewPodcastItemsFromFeed(items, sourceState);

  const newMovies = [];
  for (const item of candidates) {
    const newEntry = toBootstrapPodcastMovie(item, sourceIdentifier);
    newMovies.push(newEntry);
  }

  if (newMovies.length) {
    bootstrapData.movies = [...newMovies, ...bootstrapData.movies];
    bootstrapData.generatedDate = new Date().toISOString();
    await saveBootstrap(bootstrapData);
  }

  return {
    contract: PODCAST_INGEST_CONTRACT,
    addedCount: newMovies.length,
    addedMovies: newMovies,
    sourceStats: {
      latestKnownEpisodeDate: stats.latestEpisodeDate,
      latestKnownSourceTitle: stats.latestKnownSourceTitle,
      scannedCount: stats.scannedCount,
      stoppedEarly: stats.stoppedEarly,
      stopReason: stats.stopReason,
      skippedByNoise: stats.skippedByNoise,
    },
  };
}

function applyTmdbData(movie, tmdbDetails) {
  const releaseYear = tmdbDetails.release_date
    ? Number(tmdbDetails.release_date.slice(0, 4))
    : null;
  const cast =
    tmdbDetails.credits?.cast?.slice(0, 10).map((member) => ({
      id: member.id,
      name: member.name,
      character: member.character || null,
      profilePath: member.profile_path || null,
    })) || [];
  const director = tmdbDetails.credits?.crew?.find(
    (member) => member.job === "Director"
  );

  return {
    ...movie,
    tmdbId: tmdbDetails.id,
    title: tmdbDetails.title || movie.title,
    year: releaseYear || movie.year,
    overview: tmdbDetails.overview || movie.overview,
    posterPath: tmdbDetails.poster_path || movie.posterPath,
    backdropPath: tmdbDetails.backdrop_path || movie.backdropPath,
    genres: tmdbDetails.genres?.map((genre) => genre.name) || movie.genres || [],
    mpaaRating: extractMpaaRating(tmdbDetails.release_dates) || movie.mpaaRating,
    credits:
      director || cast.length
        ? {
            director: director?.name || null,
            cast,
          }
        : movie.credits || null,
    trailer: pickTrailer(tmdbDetails.videos) || movie.trailer || null,
  };
}

function parseOscarAwards(awardsText) {
  if (!awardsText) return null;
  let totalWins = 0;
  let totalNominations = 0;
  const winsMatch = awardsText.match(/Won (\d+) Oscars?/);
  if (winsMatch) totalWins = parseInt(winsMatch[1], 10);
  const nomsMatch = awardsText.match(/Nominated for (\d+) Oscars?/);
  if (nomsMatch) totalNominations = parseInt(nomsMatch[1], 10);
  if (totalWins === 0 && totalNominations === 0) return null;
  return { wins: [], nominations: [], totalWins, totalNominations, rawAwardsText: awardsText };
}

async function fetchImdbIdFromTmdb(tmdbId) {
  const url = `https://api.themoviedb.org/3/movie/${tmdbId}/external_ids?api_key=${TMDB_API_KEY}`;
  const data = await requestJson(url);
  return data.imdb_id || null;
}

function requestOmdb(url) {
  const transport = url.startsWith("http://") ? http : https;
  return new Promise((resolve, reject) => {
    transport
      .get(url, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            resolve(parsed);
          } catch (error) {
            reject(error);
          }
        });
      })
      .on("error", reject);
  });
}

async function fetchOmdbAwards(imdbId, apiKey) {
  const key = apiKey || OMDB_API_KEY;
  const url = `http://www.omdbapi.com/?apikey=${key}&i=${imdbId}`;
  const data = await requestOmdb(url);
  if (data.Error === "Invalid API key!") throw new Error("Invalid OMDB API key");
  if (data.Response !== "True") return null;
  return data.Awards || null;
}

async function fetchOmdbAwardsByTitle(title, year, apiKey) {
  const key = apiKey || OMDB_API_KEY;
  let url = `http://www.omdbapi.com/?apikey=${key}&t=${encodeURIComponent(title)}`;
  if (year) url += `&y=${year}`;
  const data = await requestOmdb(url);
  if (data.Error === "Invalid API key!") throw new Error("Invalid OMDB API key");
  if (data.Response !== "True") return null;
  return data.Awards || null;
}

// ---- Wikidata SPARQL for detailed Oscar data ----

const OSCAR_CATEGORY_MAP = {
  "academy award for best picture": "Best Picture",
  "academy award for best director": "Best Director",
  "academy award for best actor": "Best Actor",
  "academy award for best actress": "Best Actress",
  "academy award for best actor in a leading role": "Best Actor",
  "academy award for best actress in a leading role": "Best Actress",
  "academy award for best supporting actor": "Best Supporting Actor",
  "academy award for best supporting actress": "Best Supporting Actress",
  "academy award for best actor in a supporting role": "Best Supporting Actor",
  "academy award for best actress in a supporting role": "Best Supporting Actress",
  "academy award for best original screenplay": "Best Original Screenplay",
  "academy award for best adapted screenplay": "Best Adapted Screenplay",
  "academy award for best writing, original screenplay": "Best Original Screenplay",
  "academy award for best writing, adapted screenplay": "Best Adapted Screenplay",
  "academy award for best cinematography": "Best Cinematography",
  "academy award for best film editing": "Best Film Editing",
  "academy award for best visual effects": "Best Visual Effects",
  "academy award for best original score": "Best Original Score",
  "academy award for best original song": "Best Original Song",
  "academy award for best sound editing": "Best Sound Editing",
  "academy award for best sound mixing": "Best Sound Mixing",
  "academy award for best sound": "Best Sound Editing",
  "academy award for best production design": "Best Production Design",
  "academy award for best art direction": "Best Production Design",
  "academy award for best costume design": "Best Costume Design",
  "academy award for best makeup and hairstyling": "Best Makeup and Hairstyling",
  "academy award for best makeup": "Best Makeup and Hairstyling",
  "academy award for best animated feature film": "Best Animated Feature",
  "academy award for best animated feature": "Best Animated Feature",
  "academy award for best international feature film": "Best International Feature Film",
  "academy award for best foreign language film": "Best International Feature Film",
  "academy award for best documentary feature film": "Best Documentary Feature",
  "academy award for best documentary feature": "Best Documentary Feature",
  "academy award for best documentary – feature": "Best Documentary Feature",
  "academy award for best live action short film": "Other",
  "academy award for best animated short film": "Other",
  "academy award for best documentary short film": "Other",
};

function mapWikidataCategory(label) {
  return OSCAR_CATEGORY_MAP[label.toLowerCase()] || "Other";
}

function buildWikidataSparql(imdbId) {
  return `
SELECT ?awardLabel ?type ?recipientLabel WHERE {
  ?film wdt:P345 "${imdbId}" .
  {
    ?film p:P166 ?stmt .
    ?stmt ps:P166 ?award .
    OPTIONAL { ?stmt pq:P1346 ?recipient . }
    BIND("won" AS ?type)
  } UNION {
    ?film p:P1411 ?stmt .
    ?stmt ps:P1411 ?award .
    OPTIONAL { ?stmt pq:P1346 ?recipient . }
    BIND("nominated" AS ?type)
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
}
ORDER BY ?type ?awardLabel`.trim();
}

async function fetchWikidataOscars(imdbId) {
  const query = buildWikidataSparql(imdbId);
  const url = `https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(query)}`;
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { "User-Agent": "WatchedIt/1.0 (movie tracker app)" } }, (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(data);
            const bindings = parsed?.results?.bindings || [];
            const wins = [];
            const nominations = [];
            const winCategories = new Set();
            const nomCategories = new Set();

            for (const b of bindings) {
              const label = b.awardLabel?.value || "";
              if (!label.toLowerCase().startsWith("academy award")) continue;
              const category = mapWikidataCategory(label);
              const recipient = b.recipientLabel?.value || null;
              const type = b.type?.value;
              const id = `${category}-${(recipient || "").toLowerCase().replace(/\s+/g, "-")}`.substring(0, 80);

              if (type === "won") {
                winCategories.add(category);
                wins.push({ id, category, year: null, recipient });
              } else {
                nomCategories.add(category);
                nominations.push({ id, category, year: null, nominee: recipient });
              }
            }

            if (wins.length === 0 && nominations.length === 0) {
              return resolve(null);
            }
            resolve({
              wins,
              nominations,
              totalWins: winCategories.size,
              totalNominations: nomCategories.size,
            });
          } catch (error) {
            reject(error);
          }
        });
      })
      .on("error", reject);
  });
}

function mergeWikidataIntoOscar(existing, wikidata) {
  if (!wikidata) return existing;
  return {
    wins: wikidata.wins,
    nominations: wikidata.nominations,
    totalWins: wikidata.totalWins,
    totalNominations: wikidata.totalNominations,
    rawAwardsText: existing?.rawAwardsText || null,
  };
}

function getContentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html";
  if (filePath.endsWith(".js")) return "text/javascript";
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".svg")) return "image/svg+xml";
  if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) return "image/jpeg";
  if (filePath.endsWith(".png")) return "image/png";
  if (filePath.endsWith(".webp")) return "image/webp";
  return "application/octet-stream";
}

function fetchImageBuffer(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith("https") ? https : http;
    const req = mod.get(url, { headers: { "User-Agent": "WatchedIt-Bootstrap/1.0" } }, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetchImageBuffer(res.headers.location).then(resolve, reject);
      }
      if (res.statusCode !== 200) {
        res.resume();
        return reject(new Error(`HTTP ${res.statusCode}`));
      }
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    });
    req.on("error", reject);
    req.setTimeout(8000, () => { req.destroy(); reject(new Error("Timeout")); });
  });
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  const pathname = parsedUrl.pathname.replace(/\/+$/, "") || "/";

  try {
    if (pathname.startsWith("/api/bootstrap") && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      return sendJson(res, 200, withMovieIndexes(bootstrap));
    }

    if (pathname === "/api/sources" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      const normalized = normalizeSourcePayload(payload);
      if (!normalized) {
        return sendJson(res, 400, { error: "Invalid source payload" });
      }
      const duplicate = bootstrap.dataSources.some(
        (source) => source.identifier === normalized.identifier
      );
      if (duplicate) {
        return sendJson(res, 409, { error: "Source identifier already exists" });
      }
      bootstrap.dataSources.push(normalized);
      bootstrap.dataSources.sort((a, b) => a.name.localeCompare(b.name));
      syncSourceMovieCounts(bootstrap);
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true, source: normalized });
    }

    if (pathname.startsWith("/api/sources/") && req.method === "PUT") {
      const existingIdentifier = decodeURIComponent(pathname.split("/").pop() || "");
      const payload = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      const index = bootstrap.dataSources.findIndex(
        (source) => source.identifier === existingIdentifier
      );
      if (index < 0) {
        return sendJson(res, 404, { error: "Source not found" });
      }
      const existing = bootstrap.dataSources[index];
      const normalized = normalizeSourcePayload(payload, existing);
      if (!normalized) {
        return sendJson(res, 400, { error: "Invalid source payload" });
      }
      const duplicate = bootstrap.dataSources.some(
        (source, sourceIndex) =>
          sourceIndex !== index && source.identifier === normalized.identifier
      );
      if (duplicate) {
        return sendJson(res, 409, { error: "Source identifier already exists" });
      }
      bootstrap.dataSources[index] = normalized;
      if (normalized.identifier !== existingIdentifier) {
        for (const movie of bootstrap.movies || []) {
          if (movie.sourceIdentifier === existingIdentifier) {
            movie.sourceIdentifier = normalized.identifier;
          }
        }
      }
      bootstrap.dataSources.sort((a, b) => a.name.localeCompare(b.name));
      syncSourceMovieCounts(bootstrap);
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true, source: normalized });
    }

    if (pathname === "/api/themes" && req.method === "GET") {
      const themes = await loadThemePresets();
      return sendJson(res, 200, { themes });
    }

    if (pathname === "/api/live/changes" && req.method === "GET") {
      res.writeHead(200, {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
        "X-Accel-Buffering": "no",
      });
      res.write(`event: connected\ndata: ${JSON.stringify({
        watching: Object.entries(WATCHED_SOURCES).map(([k, v]) => ({ key: k, file: v.label })),
        timestamp: Date.now(),
      })}\n\n`);
      sseClients.add(res);
      req.on("close", () => sseClients.delete(res));
      const keepAlive = setInterval(() => {
        try { res.write(": keepalive\n\n"); } catch { clearInterval(keepAlive); sseClients.delete(res); }
      }, 30000);
      req.on("close", () => clearInterval(keepAlive));
      return;
    }

    if (pathname === "/api/design-system/tokens" && req.method === "GET") {
      const tokens = await loadDesignSystemTokens();
      return sendJson(res, 200, tokens);
    }

    if (pathname === "/api/design-system/settings" && req.method === "GET") {
      const settings = await loadAppSettings();
      return sendJson(res, 200, settings);
    }

    if (pathname === "/api/themes" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const themes = await loadThemePresets();
      const normalized = normalizeThemePresetPayload(payload);
      if (!normalized) {
        return sendJson(res, 400, { error: "Invalid theme payload" });
      }
      const duplicateName = themes.some(
        (theme) => theme.name.toLowerCase() === normalized.name.toLowerCase()
      );
      if (duplicateName) {
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
      const index = themes.findIndex((theme) => String(theme.id) === themeId);
      if (index < 0) {
        return sendJson(res, 404, { error: "Theme not found" });
      }
      const normalized = normalizeThemePresetPayload(payload, themes[index]);
      if (!normalized) {
        return sendJson(res, 400, { error: "Invalid theme payload" });
      }
      const duplicateName = themes.some(
        (theme, themeIndex) =>
          themeIndex !== index &&
          String(theme.name || "").toLowerCase() === normalized.name.toLowerCase()
      );
      if (duplicateName) {
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
      const filtered = themes.filter((theme) => String(theme.id) !== themeId);
      if (filtered.length === themes.length) {
        return sendJson(res, 404, { error: "Theme not found" });
      }
      await saveThemePresets(filtered);
      return sendJson(res, 200, { success: true });
    }

    if (pathname.startsWith("/api/movies/") && req.method === "PUT") {
      const index = Number(pathname.split("/").pop());
      const payload = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      if (!Number.isInteger(index) || index < 0 || index >= bootstrap.movies.length) {
        return sendJson(res, 400, { error: "Invalid index" });
      }
      if (!payload || !payload.sourceIdentifier || !payload.title) {
        return sendJson(res, 400, { error: "Missing required fields" });
      }
      const updatedMovie = { ...payload };
      delete updatedMovie.__index;
      bootstrap.movies[index] = updatedMovie;
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true });
    }

    if (pathname === "/api/movies" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      if (!payload || !payload.sourceIdentifier || !payload.title) {
        return sendJson(res, 400, { error: "Missing required fields" });
      }
      const newMovie = { ...payload };
      delete newMovie.__index;
      bootstrap.movies.unshift(newMovie);
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true });
    }

    if (pathname.startsWith("/api/movies/") && req.method === "DELETE") {
      const index = Number(pathname.split("/").pop());
      const bootstrap = await loadBootstrap();
      if (!Number.isInteger(index) || index < 0 || index >= bootstrap.movies.length) {
        return sendJson(res, 400, { error: "Invalid index" });
      }
      bootstrap.movies.splice(index, 1);
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true });
    }

    if (pathname.startsWith("/api/movies/") && pathname.endsWith("/streaming/refresh") && req.method === "POST") {
      const segments = pathname.split("/").filter(Boolean);
      const index = Number(segments[2]);
      const payload = await readRequestBody(req);
      const region = payload?.region || "US";
      const bootstrap = await loadBootstrap();
      if (!Number.isInteger(index) || index < 0 || index >= bootstrap.movies.length) {
        return sendJson(res, 400, { error: "Invalid index" });
      }
      const movie = bootstrap.movies[index];
      if (!movie.tmdbId) {
        return sendJson(res, 400, { error: "Movie has no TMDB ID" });
      }

      let streamingServices;
      try {
        streamingServices = await fetchStreamingServices(movie.tmdbId, region);
      } catch (error) {
        return sendJson(res, 502, {
          error: "Streaming lookup failed",
          details: error.message,
          tmdbId: movie.tmdbId,
          title: movie.title,
        });
      }
      const existing = movie.streamingServices || [];
      if (!providersEqual(existing, streamingServices)) {
        movie.streamingServices = streamingServices;
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);
      }

      return sendJson(res, 200, {
        success: true,
        count: streamingServices.length,
        streamingServices,
      });
    }

    if (pathname === "/api/streaming/refresh-all" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const region = payload?.region || "US";
      const delayMs = Number(payload?.delayMs ?? 150);
      const bootstrap = await loadBootstrap();

      let updatedCount = 0;
      let skippedCount = 0;
      let unchangedCount = 0;
      let failedCount = 0;
      const reportItems = [];

      for (const movie of bootstrap.movies) {
        if (!movie.tmdbId) {
          skippedCount += 1;
          continue;
        }
        let streamingServices;
        try {
          streamingServices = await fetchStreamingServices(movie.tmdbId, region);
        } catch (error) {
          failedCount += 1;
          reportItems.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "failed",
            error: error.message,
          });
          if (delayMs > 0) {
            await new Promise((resolve) => setTimeout(resolve, delayMs));
          }
          continue;
        }
        const existing = movie.streamingServices || [];
        if (!providersEqual(existing, streamingServices)) {
          movie.streamingServices = streamingServices;
          updatedCount += 1;
          reportItems.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "updated",
          });
        } else {
          unchangedCount += 1;
          reportItems.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "unchanged",
          });
        }
        if (delayMs > 0) {
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
      }

      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);

      return sendJson(res, 200, {
        success: true,
        updatedCount,
        skippedCount,
        failedCount,
        report: {
          totalCount: bootstrap.movies.length - skippedCount,
          updatedCount,
          unchangedCount,
          skippedCount,
          failedCount,
          items: reportItems,
        },
      });
    }

    if (pathname === "/api/data/health" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];
      const sources = bootstrap.dataSources || [];

      const missing = (movie, field) => movie[field] == null || movie[field] === "";
      const missingGenres = (movie) => !movie.genres || movie.genres.length === 0;
      const missingStreaming = (movie) =>
        !movie.streamingServices || movie.streamingServices.length === 0;

      let duplicateSourceTitles = 0;
      const seenSourceTitles = new Set();
      for (const movie of movies) {
        const key = `${movie.sourceIdentifier}|${movie.sourceTitle || movie.title}`;
        if (seenSourceTitles.has(key)) {
          duplicateSourceTitles += 1;
        } else {
          seenSourceTitles.add(key);
        }
      }

      return sendJson(res, 200, {
        totalMovies: movies.length,
        totalSources: sources.length,
        missingTmdbId: movies.filter((movie) => missing(movie, "tmdbId")).length,
        missingYear: movies.filter((movie) => missing(movie, "year")).length,
        missingPoster: movies.filter((movie) => missing(movie, "posterPath")).length,
        missingOverview: movies.filter((movie) => missing(movie, "overview")).length,
        missingGenres: movies.filter(missingGenres).length,
        missingStreaming: movies.filter(missingStreaming).length,
        missingCredits: movies.filter((movie) => movie.credits == null).length,
        missingTrailer: movies.filter((movie) => movie.trailer == null).length,
        duplicateSourceTitles,
      });
    }

    if (pathname === "/api/feeds/refresh-all" && req.method === "POST") {
      const bootstrap = await loadBootstrap();
      let addedCount = 0;
      let skippedCount = 0;
      for (const source of bootstrap.dataSources.filter((s) => s.type === "podcast" && s.url)) {
        const result = await handleBootstrapRefreshPodcast(source.identifier);
        addedCount += result.addedCount;
        skippedCount += result.addedMovies.length === 0 ? 0 : 0;
      }
      return sendJson(res, 200, { success: true, addedCount, skippedCount });
    }

    if (pathname === "/api/feeds/preview" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const identifiers = payload?.identifiers || [];
      const bootstrap = await loadBootstrap();
      const sources = bootstrap.dataSources.filter(
        (s) =>
          s.type === "podcast" &&
          s.url &&
          (identifiers.length === 0 || identifiers.includes(s.identifier))
      );
      const items = [];

      for (const source of sources) {
        const rssXml = await fetchHtml(source.url);
        const rssItems = parseRssItems(rssXml);
        const existingSourceTitles = new Set(
          bootstrap.movies
            .filter((movie) => movie.sourceIdentifier === source.identifier)
            .map((movie) => movie.sourceTitle || movie.title)
        );

        for (const item of rssItems) {
          if (!isRecentPodcastItem(item.pubDate)) {
            continue;
          }
          if (existingSourceTitles.has(item.title)) {
            continue;
          }
          const cleanedTitle = cleanPodcastTitle(item.title);
          if (!cleanedTitle) {
            continue;
          }
          items.push({
            title: cleanedTitle,
            sourceTitle: item.title,
            sourceIdentifier: source.identifier,
            sourceName: source.name,
            rank: null,
            episodeDate: item.pubDate || null,
            podcastEpisodeDescription: item.description || null,
          });
        }
      }

      const enrichedItems = await enrichItems(items);
      const deduped = enrichedItems.map((item) => ({
        ...item,
        isDuplicate: false,
        status: item.status || determineItemStatus(item),
      }));

      return sendJson(res, 200, { items: deduped });
    }

    if (pathname === "/api/feeds/commit" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const items = payload?.items || [];
      if (!Array.isArray(items)) {
        return sendJson(res, 400, { error: "Missing items" });
      }

      const bootstrap = await loadBootstrap();
      const sourceMap = new Map(
        bootstrap.dataSources.map((source) => [source.identifier, source])
      );

      const newMovies = [];
      const reportItems = [];
      let missingCount = 0;
      let lightCount = 0;
      for (const item of items) {
        if (!item.sourceIdentifier) {
          continue;
        }
        const source = sourceMap.get(item.sourceIdentifier);
        if (!source) {
          continue;
        }
        newMovies.push({
          title: item.title,
          sourceIdentifier: item.sourceIdentifier,
          rank: null,
          sourceTitle: item.sourceTitle || item.title,
          tmdbId: item.tmdbId ?? null,
          year: item.year ?? null,
          posterPath: item.posterPath ?? null,
          backdropPath: item.backdropPath ?? null,
          overview: item.overview ?? null,
          mpaaRating: item.mpaaRating ?? null,
          genres: item.genres ?? [],
          streamingServices: item.streamingServices ?? [],
          credits: item.credits ?? null,
          trailer: item.trailer ?? null,
          podcastEpisodeDescription: item.podcastEpisodeDescription ?? null,
          episodeDate: item.episodeDate ?? null,
        });
        reportItems.push({
          sourceName: source.name,
          title: item.title,
          status: item.status || determineItemStatus(item),
          tmdbId: item.tmdbId ?? null,
        });
        if (item.status === "missing") {
          missingCount += 1;
        } else if (item.status === "light") {
          lightCount += 1;
        }
        source.movieCount = (source.movieCount || 0) + 1;
      }

      bootstrap.movies = [...newMovies, ...bootstrap.movies];
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);

      return sendJson(res, 200, {
        success: true,
        addedCount: newMovies.length,
        report: {
          addedCount: newMovies.length,
          skippedCount: 0,
          missingCount,
          lightCount,
          sourceCount: new Set(reportItems.map((item) => item.sourceName)).size,
          items: reportItems,
        },
      });
    }

    if (pathname === "/api/podcasts/latest/preview" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const identifiers = payload?.identifiers || [];
      const bootstrap = await loadBootstrap();
      const sources = bootstrap.dataSources.filter(
        (s) =>
          s.type === "podcast" &&
          s.url &&
          (identifiers.length === 0 || identifiers.includes(s.identifier))
      );
      const sourceIds = sources.map((source) => source.identifier);
      const podcastStateBySource = buildPodcastSourceState(bootstrap, sourceIds);
      const items = [];
      const sourceStats = [];

      for (const source of sources) {
        const rssXml = await fetchHtml(source.url);
        const rssItems = parseRssItems(rssXml);
        const sourceState = podcastStateBySource.get(source.identifier);
        const { candidates, stats } = collectNewPodcastItemsFromFeed(
          rssItems,
          sourceState
        );
        sourceStats.push(buildPodcastSourceStat(source, stats, candidates.length));

        for (const item of candidates) {
          items.push(toPodcastPreviewItem(item, source));
        }
      }

      const enrichedItems = await enrichItems(items);
      const deduped = enrichedItems.map((item) => ({
        ...item,
        isDuplicate: false,
        status: item.status || determineItemStatus(item),
      }));

      return sendJson(res, 200, {
        contract: PODCAST_INGEST_CONTRACT,
        items: deduped,
        sourceStats,
      });
    }

    if (pathname === "/api/podcasts/latest/commit" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const items = payload?.items || [];
      if (!Array.isArray(items)) {
        return sendJson(res, 400, { error: "Missing items" });
      }

      const bootstrap = await loadBootstrap();
      const sourceMap = new Map(
        bootstrap.dataSources.map((source) => [source.identifier, source])
      );

      const newMovies = [];
      const reportItems = [];
      let missingCount = 0;
      let lightCount = 0;

      for (const item of items) {
        if (!item.sourceIdentifier) {
          continue;
        }
        const source = sourceMap.get(item.sourceIdentifier);
        if (!source) {
          continue;
        }
        newMovies.push({
          title: item.title,
          sourceIdentifier: item.sourceIdentifier,
          rank: null,
          sourceTitle: item.sourceTitle || item.title,
          tmdbId: item.tmdbId ?? null,
          year: item.year ?? null,
          posterPath: item.posterPath ?? null,
          backdropPath: item.backdropPath ?? null,
          overview: item.overview ?? null,
          mpaaRating: item.mpaaRating ?? null,
          genres: item.genres ?? [],
          streamingServices: item.streamingServices ?? [],
          credits: item.credits ?? null,
          trailer: item.trailer ?? null,
          podcastEpisodeDescription: item.podcastEpisodeDescription ?? null,
          episodeDate: item.episodeDate ?? null,
        });
        reportItems.push({
          sourceName: source.name,
          title: item.title,
          status: item.status || determineItemStatus(item),
          tmdbId: item.tmdbId ?? null,
        });
        if (item.status === "missing") {
          missingCount += 1;
        } else if (item.status === "light") {
          lightCount += 1;
        }
        source.movieCount = (source.movieCount || 0) + 1;
      }

      bootstrap.movies = [...newMovies, ...bootstrap.movies];
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);

      return sendJson(res, 200, {
        success: true,
        addedCount: newMovies.length,
        report: {
          addedCount: newMovies.length,
          skippedCount: 0,
          missingCount,
          lightCount,
          sourceCount: new Set(reportItems.map((item) => item.sourceName)).size,
          items: reportItems,
        },
      });
    }

    if (pathname === "/api/dedupe/preview" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      const groups = buildDedupeGroups(bootstrap);
      return sendJson(res, 200, { groups });
    }

    if (pathname === "/api/dedupe/commit" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const selections = payload?.selections || [];
      const bootstrap = await loadBootstrap();

      const keepMap = new Map(selections.map((selection) => [selection.key, selection.keepIndex]));
      const deleteIndexes = new Set();
      const groups = buildDedupeGroups(bootstrap);

      for (const group of groups) {
        const keepIndex = keepMap.get(group.key);
        for (const item of group.items) {
          if (keepIndex == null || item.index !== keepIndex) {
            deleteIndexes.add(item.index);
          }
        }
      }

      if (deleteIndexes.size === 0) {
        return sendJson(res, 200, { success: true, deletedCount: 0 });
      }

      bootstrap.movies = bootstrap.movies.filter((_, index) => !deleteIndexes.has(index));
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);

      return sendJson(res, 200, { success: true, deletedCount: deleteIndexes.size });
    }

    if (pathname === "/api/ingest/preview" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const { sourceType, identifier, name, url, isRankedList } = payload || {};
      if (!sourceType || !identifier || !name || !url) {
        return sendJson(res, 400, { error: "Missing source data" });
      }
      const bootstrap = await loadBootstrap();
      let items = [];
      if (sourceType === "podcast") {
        const rssXml = await fetchHtml(url);
        const rssItems = parseRssItems(rssXml);
        items = rssItems.map((item) => ({
          title: cleanPodcastTitle(item.title),
          sourceTitle: item.title,
          rank: null,
          sourceIdentifier: identifier,
          episodeDate: item.pubDate || null,
          podcastEpisodeDescription: item.description || null,
        }));
      } else {
        const listItems = await previewListItems(url);
        items = listItems.map((item) => ({
          title: item.title,
          sourceTitle: item.title,
          rank: isRankedList ? item.rank : null,
          sourceIdentifier: identifier,
        }));
      }
      const enrichedItems = await enrichItems(items);
      const deduped = markDuplicates(enrichedItems, bootstrap, identifier).map(
        (item) => ({
          ...item,
          status: item.status || determineItemStatus(item),
        })
      );
      return sendJson(res, 200, { items: deduped });
    }

    if (pathname === "/api/ingest/enrich" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const items = payload?.items || [];
      const enriched = await enrichItems(items);
      return sendJson(res, 200, { items: enriched });
    }

    if (pathname === "/api/ingest/commit" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const { sourceType, identifier, name, url, isRankedList, items } = payload || {};
      if (!identifier || !name || !url || !Array.isArray(items)) {
        return sendJson(res, 400, { error: "Missing commit data" });
      }
      const bootstrap = await loadBootstrap();
      let source = bootstrap.dataSources.find((entry) => entry.identifier === identifier);
      if (!source) {
        source = {
          identifier,
          name,
          type: sourceType === "podcast" ? "podcast" : "url",
          url,
          isRankedList: Boolean(isRankedList),
          movieCount: 0,
        };
        bootstrap.dataSources.push(source);
      }

      const newMovies = items.map((item) => ({
        title: item.title,
        sourceIdentifier: identifier,
        rank: item.rank ?? null,
        sourceTitle: item.sourceTitle || item.title,
        tmdbId: item.tmdbId ?? null,
        year: item.year ?? null,
        posterPath: item.posterPath ?? null,
        backdropPath: item.backdropPath ?? null,
        overview: item.overview ?? null,
        mpaaRating: item.mpaaRating ?? null,
        genres: item.genres ?? [],
        streamingServices: item.streamingServices ?? [],
        credits: item.credits ?? null,
        trailer: item.trailer ?? null,
        podcastEpisodeDescription: item.podcastEpisodeDescription ?? null,
        episodeDate: item.episodeDate ?? null,
      }));

      bootstrap.movies = [...newMovies, ...bootstrap.movies];
      source.movieCount = (source.movieCount || 0) + newMovies.length;
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);

      return sendJson(res, 200, { success: true, addedCount: newMovies.length });
    }

    if (pathname === "/api/bootstrap/regenerate" && req.method === "POST") {
      execFile(
        "swift",
        ["generate_bootstrap_database.swift"],
        { cwd: PROJECT_ROOT },
        (error, stdout, stderr) => {
          if (error) {
            return sendJson(res, 500, {
              error: "Bootstrap generation failed",
              details: stderr || stdout || error.message,
            });
          }
          return sendJson(res, 200, { success: true, output: stdout.trim() });
        }
      );
      return;
    }

    if (pathname === "/api/podcasts/refresh" && req.method === "POST") {
      const payload = await readRequestBody(req);
      if (!payload?.sourceIdentifier) {
        return sendJson(res, 400, { error: "Missing sourceIdentifier" });
      }
      const result = await handleBootstrapRefreshPodcast(payload.sourceIdentifier);
      return sendJson(res, 200, result);
    }

    if (pathname === "/api/tmdb/search" && req.method === "GET") {
      const query = parsedUrl.searchParams.get("query");
      const year = parsedUrl.searchParams.get("year");
      if (!query) {
        return sendJson(res, 400, { error: "Missing query" });
      }
      const searchUrl = new URL("https://api.themoviedb.org/3/search/movie");
      searchUrl.searchParams.set("api_key", TMDB_API_KEY);
      searchUrl.searchParams.set("query", query);
      if (year) {
        searchUrl.searchParams.set("year", year);
      }
      const data = await requestJson(searchUrl.toString());
      return sendJson(res, 200, data);
    }

    if (pathname.startsWith("/api/tmdb/details/") && req.method === "GET") {
      const id = pathname.split("/").pop();
      const detailsUrl = new URL(`https://api.themoviedb.org/3/movie/${id}`);
      detailsUrl.searchParams.set("api_key", TMDB_API_KEY);
      detailsUrl.searchParams.set(
        "append_to_response",
        "credits,videos,release_dates"
      );
      const details = await requestJson(detailsUrl.toString());
      return sendJson(res, 200, details);
    }

    if (pathname.startsWith("/api/tmdb/apply/") && req.method === "POST") {
      const index = Number(pathname.split("/").pop());
      const payload = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      if (!Number.isInteger(index) || index < 0 || index >= bootstrap.movies.length) {
        return sendJson(res, 400, { error: "Invalid index" });
      }
      if (!payload?.tmdbId) {
        return sendJson(res, 400, { error: "Missing tmdbId" });
      }
      const detailsUrl = new URL(`https://api.themoviedb.org/3/movie/${payload.tmdbId}`);
      detailsUrl.searchParams.set("api_key", TMDB_API_KEY);
      detailsUrl.searchParams.set(
        "append_to_response",
        "credits,videos,release_dates"
      );
      const details = await requestJson(detailsUrl.toString());
      bootstrap.movies[index] = applyTmdbData(bootstrap.movies[index], details);
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, { success: true, movie: bootstrap.movies[index] });
    }

    if (pathname === "/api/oscar-awards/stats" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];
      const withTmdb = movies.filter((m) => m.tmdbId);
      const withAwards = movies.filter((m) => m.oscarAwards);
      const withWins = movies.filter((m) => m.oscarAwards?.totalWins > 0);
      const withNoms = movies.filter((m) => m.oscarAwards?.totalNominations > 0);
      const eligible = withTmdb.filter((m) => !m.oscarAwards);
      const withDetail = movies.filter(
        (m) => m.oscarAwards && ((m.oscarAwards.wins?.length || 0) > 0 || (m.oscarAwards.nominations?.length || 0) > 0)
      );
      const eligibleWikidata = movies.filter(
        (m) => m.oscarAwards && (m.oscarAwards.wins?.length || 0) === 0 && (m.oscarAwards.nominations?.length || 0) === 0
      );
      return sendJson(res, 200, {
        totalMovies: movies.length,
        moviesWithTmdb: withTmdb.length,
        moviesWithAwards: withAwards.length,
        moviesWithWins: withWins.length,
        moviesWithNominations: withNoms.length,
        eligibleForEnrichment: eligible.length,
        withCategoryDetail: withDetail.length,
        eligibleForWikidata: eligibleWikidata.length,
      });
    }

    if (pathname === "/api/oscar-awards/enrich" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const mode = payload?.mode || "missing";
      const delayMs = Number(payload?.delayMs ?? 150);
      const dryRun = Boolean(payload?.dryRun);
      const omdbKey = payload?.omdbApiKey || OMDB_API_KEY;
      const batchSize = Math.min(Number(payload?.batchSize) || 100, 500);
      const offset = Math.max(Number(payload?.offset) || 0, 0);
      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];

      const candidates = movies.filter((movie) => {
        if (!movie.tmdbId) return false;
        if (mode === "missing") return !movie.oscarAwards;
        if (mode === "all") return true;
        return !movie.oscarAwards;
      });

      const seen = new Set();
      const deduped = [];
      for (const movie of candidates) {
        if (seen.has(movie.tmdbId)) continue;
        seen.add(movie.tmdbId);
        deduped.push(movie);
      }

      const totalEligible = deduped.length;
      const batch = deduped.slice(offset, offset + batchSize);

      let enrichedCount = 0;
      let skippedCount = 0;
      let failedCount = 0;
      let noAwardsCount = 0;
      const reportItems = [];
      let abortedDueToKey = false;

      for (const movie of batch) {
        if (abortedDueToKey) break;
        let awardsText = null;
        let method = null;

        try {
          const imdbId = await fetchImdbIdFromTmdb(movie.tmdbId);
          if (imdbId) {
            awardsText = await fetchOmdbAwards(imdbId, omdbKey);
            method = "imdb";
          }
          if (!awardsText && movie.title && movie.year) {
            awardsText = await fetchOmdbAwardsByTitle(movie.title, movie.year, omdbKey);
            method = "title";
          }
        } catch (error) {
          if (error.message === "Invalid OMDB API key") {
            abortedDueToKey = true;
            failedCount += 1;
            reportItems.push({
              title: movie.title,
              tmdbId: movie.tmdbId,
              status: "failed",
              error: "Invalid OMDB API key — get a free key at https://www.omdbapi.com/apikey.aspx",
            });
            break;
          }
          failedCount += 1;
          reportItems.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "failed",
            error: error.message,
          });
          if (delayMs > 0) await new Promise((r) => setTimeout(r, delayMs));
          continue;
        }

        const parsed = parseOscarAwards(awardsText);
        if (parsed) {
          if (!dryRun) {
            for (const m of movies) {
              if (m.tmdbId === movie.tmdbId) {
                m.oscarAwards = parsed;
              }
            }
          }
          enrichedCount += 1;
          reportItems.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "enriched",
            wins: parsed.totalWins,
            nominations: parsed.totalNominations,
            method,
          });
        } else {
          noAwardsCount += 1;
          reportItems.push({
            title: movie.title,
            tmdbId: movie.tmdbId,
            status: "no-oscars",
            rawAwards: awardsText || null,
          });
        }

        if (delayMs > 0) await new Promise((r) => setTimeout(r, delayMs));
      }

      if (!dryRun && enrichedCount > 0) {
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);
      }

      const nextOffset = offset + batch.length;

      return sendJson(res, 200, {
        success: true,
        dryRun,
        abortedDueToKey,
        totalEligible,
        batchSize,
        offset,
        processedInBatch: batch.length,
        nextOffset: nextOffset < totalEligible ? nextOffset : null,
        enrichedCount,
        skippedCount,
        failedCount,
        noAwardsCount,
        report: reportItems,
      });
    }

    if (pathname === "/api/oscar-awards/wikidata-enrich" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const mode = payload?.mode || "missing";
      const delayMs = Math.max(Number(payload?.delayMs ?? 300), 0);
      const batchSize = Math.min(Number(payload?.batchSize) || 50, 200);
      const offset = Math.max(Number(payload?.offset) || 0, 0);
      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];

      const candidates = movies.filter((movie) => {
        if (!movie.tmdbId) return false;
        if (mode === "all") return true;
        const a = movie.oscarAwards;
        if (!a) return false;
        return (!a.wins || a.wins.length === 0) && (!a.nominations || a.nominations.length === 0);
      });

      const seen = new Set();
      const deduped = [];
      for (const movie of candidates) {
        if (seen.has(movie.tmdbId)) continue;
        seen.add(movie.tmdbId);
        deduped.push(movie);
      }

      const totalEligible = deduped.length;
      const batch = deduped.slice(offset, offset + batchSize);
      let enrichedCount = 0;
      let failedCount = 0;
      let noDataCount = 0;
      const reportItems = [];

      for (const movie of batch) {
        try {
          let imdbId = movie.imdbId || null;
          if (!imdbId) {
            imdbId = await fetchImdbIdFromTmdb(movie.tmdbId);
            if (imdbId) {
              for (const m of movies) {
                if (m.tmdbId === movie.tmdbId) m.imdbId = imdbId;
              }
            }
          }
          if (!imdbId) {
            noDataCount += 1;
            reportItems.push({ title: movie.title, tmdbId: movie.tmdbId, status: "no-imdb" });
            if (delayMs > 0) await new Promise((r) => setTimeout(r, delayMs));
            continue;
          }

          const wikidata = await fetchWikidataOscars(imdbId);
          if (wikidata) {
            const merged = mergeWikidataIntoOscar(movie.oscarAwards, wikidata);
            for (const m of movies) {
              if (m.tmdbId === movie.tmdbId) m.oscarAwards = merged;
            }
            enrichedCount += 1;
            reportItems.push({
              title: movie.title,
              tmdbId: movie.tmdbId,
              status: "enriched",
              wins: wikidata.wins.length,
              nominations: wikidata.nominations.length,
              categories: [...new Set([...wikidata.wins.map((w) => w.category), ...wikidata.nominations.map((n) => n.category)])],
            });
          } else {
            noDataCount += 1;
            reportItems.push({ title: movie.title, tmdbId: movie.tmdbId, status: "no-wikidata" });
          }
        } catch (error) {
          failedCount += 1;
          reportItems.push({ title: movie.title, tmdbId: movie.tmdbId, status: "failed", error: error.message });
        }
        if (delayMs > 0) await new Promise((r) => setTimeout(r, delayMs));
      }

      if (enrichedCount > 0) {
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);
      }

      const processedInBatch = batch.length;
      const nextOffset = offset + processedInBatch < totalEligible ? offset + processedInBatch : null;
      return sendJson(res, 200, {
        success: true,
        totalEligible,
        batchSize,
        offset,
        processedInBatch,
        nextOffset,
        enrichedCount,
        noDataCount,
        failedCount,
        report: reportItems,
      });
    }

    if (pathname === "/api/oscar-awards/wikidata-single" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const tmdbId = Number(payload?.tmdbId);
      if (!tmdbId) return sendJson(res, 400, { error: "tmdbId is required" });

      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];
      const target = movies.find((m) => m.tmdbId === tmdbId);
      if (!target) return sendJson(res, 404, { error: "Movie not found" });

      try {
        let imdbId = target.imdbId || null;
        if (!imdbId) {
          imdbId = await fetchImdbIdFromTmdb(tmdbId);
          if (imdbId) {
            for (const m of movies) {
              if (m.tmdbId === tmdbId) m.imdbId = imdbId;
            }
          }
        }
        if (!imdbId) {
          return sendJson(res, 200, { success: false, reason: "no-imdb", title: target.title });
        }

        const wikidata = await fetchWikidataOscars(imdbId);
        if (!wikidata) {
          return sendJson(res, 200, { success: true, reason: "no-wikidata-oscars", title: target.title });
        }

        const merged = mergeWikidataIntoOscar(target.oscarAwards, wikidata);
        for (const m of movies) {
          if (m.tmdbId === tmdbId) m.oscarAwards = merged;
        }
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);

        return sendJson(res, 200, {
          success: true,
          title: target.title,
          oscarAwards: merged,
        });
      } catch (error) {
        return sendJson(res, 500, { success: false, error: error.message, title: target.title });
      }
    }

    if (pathname === "/api/physical-media/stats" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      return sendJson(res, 200, physicalMediaStats(bootstrap.movies || []));
    }

    if (pathname === "/api/physical-media/enrich" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const overwriteManual = Boolean(payload?.overwriteManual);
      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];
      const index = await fetchWikidataPhysicalMediaIndex();
      seedCriterionFromSources(movies, index);
      seedCurated4K(index);
      const catalogIndex = filterIndexToCatalog(index, movies);
      const updatedCount = applyIndexToMovies(movies, catalogIndex, { overwriteManual });
      if (updatedCount > 0) {
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);
      }
      const overlay = overlayFromIndex(catalogIndex);
      await fs.writeFile(PHYSICAL_MEDIA_PATH, JSON.stringify(overlay, null, 2) + "\n");
      return sendJson(res, 200, {
        success: true,
        updatedCount,
        overlayCount: Object.keys(overlay.byTmdbId).length,
        stats: physicalMediaStats(movies),
      });
    }

    if (pathname === "/api/physical-media/update" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const tmdbId = Number(payload?.tmdbId);
      if (!tmdbId) return sendJson(res, 400, { error: "tmdbId is required" });
      const bootstrap = await loadBootstrap();
      const movies = bootstrap.movies || [];
      const targets = movies.filter((movie) => movie.tmdbId === tmdbId);
      if (!targets.length) return sendJson(res, 404, { error: "Movie not found" });

      const next = {
        editions: Array.isArray(payload?.editions) ? payload.editions : (targets[0].physicalMedia?.editions || []),
        hasCriterion: Boolean(payload?.hasCriterion),
        has4K: Boolean(payload?.has4K),
        hasBluRay: Boolean(payload?.hasBluRay),
        manualOverride: payload?.manualOverride !== false,
      };
      for (const movie of targets) {
        movie.physicalMedia = next;
      }
      bootstrap.generatedDate = new Date().toISOString();
      await saveBootstrap(bootstrap);

      const overlay = overlayFromMovies(movies);
      await fs.writeFile(PHYSICAL_MEDIA_PATH, JSON.stringify(overlay, null, 2) + "\n");
      return sendJson(res, 200, { success: true, physicalMedia: next });
    }

    if (pathname === "/api/physical-media/clear" && req.method === "POST") {
      const bootstrap = await loadBootstrap();
      let clearedCount = 0;
      for (const movie of bootstrap.movies || []) {
        if (movie.physicalMedia) {
          delete movie.physicalMedia;
          clearedCount += 1;
        }
      }
      if (clearedCount > 0) {
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);
      }
      await fs.writeFile(PHYSICAL_MEDIA_PATH, JSON.stringify({ byTmdbId: {} }, null, 2) + "\n");
      return sendJson(res, 200, { success: true, clearedCount });
    }

    if (pathname === "/api/oscar-awards/clear" && req.method === "POST") {
      const bootstrap = await loadBootstrap();
      let clearedCount = 0;
      for (const movie of bootstrap.movies || []) {
        if (movie.oscarAwards) {
          delete movie.oscarAwards;
          clearedCount += 1;
        }
      }
      if (clearedCount > 0) {
        bootstrap.generatedDate = new Date().toISOString();
        await saveBootstrap(bootstrap);
      }
      return sendJson(res, 200, { success: true, clearedCount });
    }

    if (pathname === "/api/image-proxy" && req.method === "GET") {
      const imageUrl = parsedUrl.searchParams.get("url");
      if (!imageUrl) return sendText(res, 400, "Missing url param");
      const allowed = /^https:\/\/(image\.tmdb\.org|is\d*-ssl\.mzstatic\.com)\//;
      if (!allowed.test(imageUrl)) return sendText(res, 403, "Domain not allowed");
      const cacheDir = path.join(__dirname, ".image-cache");
      const hash = require("crypto").createHash("sha256").update(imageUrl).digest("hex");
      const ext = path.extname(new URL(imageUrl).pathname) || ".jpg";
      const cachePath = path.join(cacheDir, `${hash}${ext}`);
      try { await fs.mkdir(cacheDir, { recursive: true }); } catch {}
      try {
        const cached = await fs.readFile(cachePath);
        res.writeHead(200, { "Content-Type": getContentType(cachePath), "Cache-Control": "public, max-age=86400" });
        return res.end(cached);
      } catch {}
      try {
        const buf = await fetchImageBuffer(imageUrl);
        await fs.writeFile(cachePath, buf);
        res.writeHead(200, { "Content-Type": getContentType(cachePath), "Cache-Control": "public, max-age=86400" });
        return res.end(buf);
      } catch (err) {
        return sendText(res, 502, `Failed to fetch image: ${err.message}`);
      }
    }

    if (req.method === "GET") {
      const filePath =
        pathname === "/"
          ? path.join(PUBLIC_DIR, "index.html")
          : path.join(PUBLIC_DIR, pathname.replace(/^\/+/, ""));
      if (!filePath.startsWith(PUBLIC_DIR)) {
        return sendText(res, 403, "Forbidden");
      }
      try {
        const file = await fs.readFile(filePath);
        res.writeHead(200, {
          "Content-Type": getContentType(filePath),
          "Cache-Control": "no-store, max-age=0",
        });
        res.end(file);
        return;
      } catch {
        return sendText(res, 404, "Not found");
      }
    }

    return sendText(res, 405, "Method not allowed");
  } catch (error) {
    return sendJson(res, 500, {
      error: "Server error",
      details: error.message,
    });
  }
});

server.listen(PORT, () => {
  console.log(`Bootstrap web editor running on http://localhost:${PORT}`);
});

