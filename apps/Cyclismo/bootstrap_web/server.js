const http = require("http");
const https = require("https");
const crypto = require("crypto");
const { randomUUID } = require("crypto");
const { execFile } = require("child_process");
const path = require("path");
const fs = require("fs/promises");

const PROJECT_ROOT = path.resolve(__dirname, "..");
const BOOTSTRAP_PATH = path.join(PROJECT_ROOT, "Cyclismo", "bootstrap_database.json");
const THEME_PRESETS_PATH = path.join(PROJECT_ROOT, "Cyclismo", "theme_presets.json");
const PUBLIC_DIR = path.join(__dirname, "public");

const PORT = process.env.PORT || 4188;
const AUTO_GENERATE = process.env.AUTO_GENERATE_BOOTSTRAP !== "false";
const API_BASE_URL = process.env.CYCLISMO_API_BASE_URL || "http://localhost:4000";

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
    if (error && error.code === "ENOENT") {
      return [];
    }
    throw error;
  }
}

async function saveThemePresets(themePresets) {
  const json = JSON.stringify(themePresets, null, 2);
  await fs.writeFile(THEME_PRESETS_PATH, `${json}\n`, "utf8");
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
    headlineColor: darkModeHeadlineColor,
    darkModeHeadlineColor,
    lightModeHeadlineColor,
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

function getArtworkUrl(race) {
  const url =
    race?.imageUrl ??
    race?.image_url ??
    race?.artworkVariants?.landscapeUrl ??
    race?.artwork_variants?.landscape_url ??
    race?.artworkVariants?.portraitUrl ??
    race?.artwork_variants?.portrait_url ??
    race?.artworkVariants?.squareUrl ??
    race?.artwork_variants?.square_url;
  if (url && String(url).trim()) return url.trim();
  const loc = [race?.locationCity, race?.locationCountry].filter(Boolean).join("|");
  const seedStr = loc ? loc : `${race?.name || ""}|${race?.startDate || ""}|${race?.discipline || ""}`;
  const seed = crypto.createHash("md5").update(seedStr).digest("hex").slice(0, 12);
  return `https://picsum.photos/seed/${seed}/800/400`;
}

function withIndexes(bootstrapData) {
  const races = (bootstrapData.races || []).map((race, index) => ({
    __index: index,
    ...race,
    effectiveImageUrl: getArtworkUrl(race),
  }));
  const teams = (bootstrapData.teams || []).map((team, index) => ({
    __index: index,
    ...team,
  }));
  const athletes = (bootstrapData.athletes || []).map((athlete, index) => ({
    __index: index,
    ...athlete,
  }));
  return { ...bootstrapData, races, teams, athletes };
}

const PODCAST_SOURCES = [
  {
    slug: "how-the-race-was-won",
    name: "How the Race was Won Podcast",
    searchTerm: "How the Race Was Won Podcast cycling",
    feedUrl: process.env.HOW_THE_RACE_WAS_WON_FEED_URL || null,
    websiteUrl: "https://escapecollective.com",
  },
  {
    slug: "lanterne-rouge",
    name: "The Lanterne Rouge Cycling Podcast",
    searchTerm: "Lanterne Rouge Cycling Podcast",
    feedUrl: process.env.LANTERNE_ROUGE_FEED_URL || null,
    websiteUrl: "https://lanternerouge.com",
  },
];

const TOKEN_STOPWORDS = new Set([
  "the",
  "a",
  "an",
  "of",
  "de",
  "du",
  "des",
  "la",
  "le",
  "et",
  "in",
  "to",
  "for",
  "with",
  "on",
  "at",
  "from",
  "stage",
  "stages",
  "women",
  "womens",
  "men",
  "mens",
  "tour",
  "race",
]);

const RACE_ALIAS_RULES = [
  { pattern: /\btour de france femmes?\b/i, aliases: ["tour de france femmes", "tdf femmes", "tdff"] },
  { pattern: /\btour de france\b/i, aliases: ["tour de france", "tdf", "le tour"] },
  { pattern: /\bgiro d'?italia\b/i, aliases: ["giro d italia", "giro"] },
  { pattern: /\bvuelta a espa[ñn]a\b/i, aliases: ["vuelta a espana", "vuelta"] },
  { pattern: /\bparis[- ]?roubaix\b/i, aliases: ["paris roubaix", "roubaix", "hell of the north"] },
  { pattern: /\btour of flanders\b|\bronde van vlaanderen\b/i, aliases: ["tour of flanders", "ronde van vlaanderen", "flanders", "ronde"] },
  { pattern: /\bliege[- ]?bastogne[- ]?liege\b/i, aliases: ["liege bastogne liege", "lbl"] },
  {
    pattern: /\b(milano|milan)[- ]?san ?remo\b/i,
    aliases: ["milano sanremo", "milan san remo", "san remo", "milan sanremo"],
  },
  {
    pattern: /\b(milano|milan)[- ]?san ?remo\b.*\b(donne|women|womens)\b/i,
    aliases: ["milano sanremo", "milan san remo", "san remo", "milan sanremo", "sanremo donne"],
  },
  { pattern: /\bstrade bianche\b/i, aliases: ["strade bianche", "strade"] },
  { pattern: /\bparis[- ]?nice\b/i, aliases: ["paris nice"] },
  { pattern: /\b(criterium du )?dauphin[eé]\b/i, aliases: ["criterium du dauphine", "dauphine"] },
  { pattern: /\btirreno[- ]?adriatico\b/i, aliases: ["tirreno adriatico", "tirreno"] },
  { pattern: /\btour de suisse\b/i, aliases: ["tour de suisse", "suisse"] },
  { pattern: /\btour de romandie\b/i, aliases: ["tour de romandie", "romandie"] },
  { pattern: /\buae tour\b/i, aliases: ["uae tour"] },
  { pattern: /\btour down under\b/i, aliases: ["tour down under", "tdu"] },
  { pattern: /\bamstel gold race\b/i, aliases: ["amstel gold race", "amstel"] },
  { pattern: /\bgent[- ]?wevelgem\b/i, aliases: ["gent wevelgem", "gw"] },
  { pattern: /\be3\b/i, aliases: ["e3 saxo classic", "e3"] },
  { pattern: /\bdwars door vlaanderen\b/i, aliases: ["dwars door vlaanderen", "dwars"] },
  { pattern: /\bomloop het nieuwsblad\b/i, aliases: ["omloop het nieuwsblad", "omloop"] },
  { pattern: /\bil lombardia\b|\btour of lombardy\b/i, aliases: ["il lombardia", "tour of lombardy", "lombardia", "lombardy"] },
  {
    pattern:
      /\bvolta (ciclista )?a catalunya\b|\bvolta\s+catalunya\b|\bciclista a catalunya\b/i,
    aliases: [
      "volta ciclista a catalunya",
      "volta a catalunya",
      "volta catalunya",
      "catalunya",
      "tour of catalonia",
      "catalonia",
    ],
  },
  { pattern: /\bitzulia\b|\bbasque country\b/i, aliases: ["itzulia", "basque country"] },
];

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (res) => {
        if (res.statusCode && res.statusCode >= 400) {
          reject(new Error(`Request failed (${res.statusCode})`));
          return;
        }
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => resolve(data));
      })
      .on("error", reject);
  });
}

async function fetchJson(url) {
  const text = await fetchText(url);
  return JSON.parse(text);
}

function fetchTextAny(url) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const client = parsed.protocol === "https:" ? https : http;
    client
      .get(parsed, (res) => {
        if (res.statusCode && res.statusCode >= 400) {
          reject(new Error(`Request failed (${res.statusCode})`));
          return;
        }
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => resolve(data));
      })
      .on("error", reject);
  });
}

function requestJson(url, method = "GET", payload = null) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const client = parsed.protocol === "https:" ? https : http;
    const body = payload ? JSON.stringify(payload) : null;
    const req = client.request(
      {
        protocol: parsed.protocol,
        hostname: parsed.hostname,
        port: parsed.port,
        path: `${parsed.pathname}${parsed.search}`,
        method,
        headers: {
          "Content-Type": "application/json",
          ...(body ? { "Content-Length": Buffer.byteLength(body) } : {}),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          if ((res.statusCode || 500) >= 400) {
            reject(new Error(data || `Request failed (${res.statusCode})`));
            return;
          }
          try {
            resolve(data ? JSON.parse(data) : {});
          } catch (error) {
            reject(error);
          }
        });
      }
    );
    req.on("error", reject);
    if (body) req.write(body);
    req.end();
  });
}

function normalizeResultKey(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

async function resolveApiRaceForBootstrapRace(race) {
  const raceId = race.raceId || race.race_id;
  if (raceId) {
    try {
      await requestJson(`${API_BASE_URL}/races/${encodeURIComponent(raceId)}`);
      return raceId;
    } catch {
      // Fall through to name/date matching.
    }
  }
  const search = await requestJson(
    `${API_BASE_URL}/search?q=${encodeURIComponent(race.name || "")}`
  );
  const candidates = Array.isArray(search?.races) ? search.races : [];
  const targetDate = race.startDate || race.start_date || "";
  const targetName = normalizeResultKey(race.name || "");
  const matched = candidates.find((candidate) => {
    const sameDate = (candidate.startDate || candidate.start_date || "") === targetDate;
    const sameName = normalizeResultKey(candidate.name || "") === targetName;
    return sameDate && sameName;
  });
  return matched?.raceId || matched?.race_id || null;
}

function normalizeRaceResultForBootstrap(result, localRaceId) {
  return {
    raceResultId: result.raceResultId || result.race_result_id || randomUUID(),
    raceId: localRaceId,
    resultType: result.resultType || result.result_type || "general_classification",
    rank: Number(result.rank || 1),
    athleteName: result.athleteName || result.athlete_name || "Unknown",
    teamName: result.teamName || result.team_name || null,
    nationality: result.nationality || null,
    resultText: result.resultText || result.result_text || null,
    source: result.source || "unknown",
    sourceUrl: result.sourceUrl || result.source_url || null,
    metadata: result.metadata || null,
    syncedAt: result.syncedAt || result.synced_at || new Date().toISOString(),
    createdAt: result.createdAt || result.created_at || new Date().toISOString(),
    updatedAt: result.updatedAt || result.updated_at || new Date().toISOString(),
  };
}

function normalizeStageResultForBootstrap(result, localStageId) {
  return {
    stageResultId: result.stageResultId || result.stage_result_id || randomUUID(),
    stageId: localStageId,
    resultType: result.resultType || result.result_type || "stage",
    rank: Number(result.rank || 1),
    athleteName: result.athleteName || result.athlete_name || "Unknown",
    teamName: result.teamName || result.team_name || null,
    nationality: result.nationality || null,
    resultText: result.resultText || result.result_text || null,
    source: result.source || "unknown",
    sourceUrl: result.sourceUrl || result.source_url || null,
    metadata: result.metadata || null,
    syncedAt: result.syncedAt || result.synced_at || new Date().toISOString(),
    createdAt: result.createdAt || result.created_at || new Date().toISOString(),
    updatedAt: result.updatedAt || result.updated_at || new Date().toISOString(),
  };
}

function matchLocalStageToApiStage(localStage, apiStages) {
  const localId = localStage.stageId || localStage.stage_id;
  const byId = apiStages.find(
    (apiStage) => (apiStage.stageId || apiStage.stage_id) === localId
  );
  if (byId) return byId;
  const localNumber = localStage.stageNumber ?? localStage.stage_number ?? null;
  const localDate = localStage.date || "";
  const byNumberDate = apiStages.find((apiStage) => {
    const apiNumber = apiStage.stageNumber ?? apiStage.stage_number ?? null;
    const apiDate = apiStage.date || "";
    return localNumber != null && apiNumber === localNumber && localDate && apiDate === localDate;
  });
  if (byNumberDate) return byNumberDate;
  const localName = normalizeResultKey(localStage.name || "");
  return apiStages.find((apiStage) => {
    const apiName = normalizeResultKey(apiStage.name || "");
    const apiDate = apiStage.date || "";
    return localName && apiName === localName && (!localDate || localDate === apiDate);
  });
}

function decodeXmlText(value) {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/gi, "$1")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .trim();
}

function stripHtml(value) {
  return decodeXmlText(value || "")
    .replace(/<[^>]+>/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function parseRssItems(xml) {
  const items = [];
  const itemBlocks = xml.match(/<item[\s\S]*?<\/item>/gi) || [];
  for (const item of itemBlocks) {
    const title = decodeXmlText((item.match(/<title[^>]*>([\s\S]*?)<\/title>/i) || [])[1] || "");
    if (!title) continue;
    const guid = decodeXmlText((item.match(/<guid[^>]*>([\s\S]*?)<\/guid>/i) || [])[1] || "") || null;
    const pubDateRaw = decodeXmlText((item.match(/<pubDate[^>]*>([\s\S]*?)<\/pubDate>/i) || [])[1] || "");
    const descriptionRaw = decodeXmlText(
      (item.match(/<description[^>]*>([\s\S]*?)<\/description>/i) || [])[1] || ""
    );
    const link =
      (item.match(/<link[^>]*href="([^"]+)"[^>]*\/?>/i) || [])[1] ||
      decodeXmlText((item.match(/<link[^>]*>([\s\S]*?)<\/link>/i) || [])[1] || "") ||
      null;
    const parsedDate = Date.parse(pubDateRaw);
    items.push({
      guid,
      title: stripHtml(title),
      rawTitle: title,
      description: descriptionRaw ? stripHtml(descriptionRaw) : null,
      episodeUrl: link || null,
      publishedAt: Number.isNaN(parsedDate) ? null : new Date(parsedDate).toISOString(),
    });
  }
  return items;
}

function normalizeForMatch(value) {
  return (value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\b(uci|mens|women|womens|race|cycling|podcast|preview|review)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function compactText(value) {
  return (value || "").replace(/\s+/g, "");
}

function tokenize(value) {
  return (value || "")
    .split(" ")
    .map((token) => token.trim())
    .filter((token) => token.length >= 3 && !TOKEN_STOPWORDS.has(token));
}

function tokenOverlapScore(left, right) {
  const leftTokens = new Set(tokenize(left));
  const rightTokens = new Set(tokenize(right));
  if (leftTokens.size === 0 || rightTokens.size === 0) return 0;
  let common = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) common += 1;
  }
  return (common / Math.max(leftTokens.size, rightTokens.size)) * 10;
}

function raceMatchKeys(raceName) {
  const normalized = normalizeForMatch(raceName);
  if (!normalized) return [];
  const keys = new Set([normalized]);
  keys.add(normalized.replace(/\b(the|la|le|de|du|des|of)\b/g, " ").replace(/\s+/g, " ").trim());
  keys.add(normalized.replace(/\b(gp|grand prix)\b/g, " ").replace(/\s+/g, " ").trim());
  const sansCiclista = normalized
    .replace(/\bciclista\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (sansCiclista !== normalized && sansCiclista.length >= 5) {
    keys.add(sansCiclista);
  }
  for (const rule of RACE_ALIAS_RULES) {
    if (rule.pattern.test(raceName || "")) {
      for (const alias of rule.aliases) {
        const normalizedAlias = normalizeForMatch(alias);
        if (normalizedAlias) keys.add(normalizedAlias);
      }
    }
  }
  return Array.from(keys).filter((key) => key.length >= 5);
}

function resolveEpisodeMatch(episode, races) {
  const titlePortionNorm = normalizeForMatch(`${episode.title || ""} ${episode.rawTitle || ""}`);
  const descSlice = String(episode.description || "").slice(0, 2500);
  const searchNorm = normalizeForMatch(`${episode.title || ""} ${episode.rawTitle || ""} ${descSlice}`);
  if (!titlePortionNorm && !searchNorm) return null;
  const searchCompact = compactText(searchNorm);
  const titleYears = new Set(extractYears(`${episode.title || ""} ${episode.rawTitle || ""}`));
  const enforceYearMatch = titleYears.size > 0;
  let winner = null;
  for (const race of races) {
    const raceYear = raceYearFromStartDate(race.startDate || race.start_date);
    if (!raceYear) continue;
    if (enforceYearMatch) {
      const yearOk = titleYears.has(raceYear) || titleYears.has(raceYear - 1);
      if (!yearOk) continue;
    }
    const keys = raceMatchKeys(race.name || "");
    const raceNorm = normalizeForMatch(race.name || "");
    for (const key of keys) {
      const keyCompact = compactText(key);
      const directContains = searchNorm.includes(key);
      const compactContains = searchCompact.includes(keyCompact);
      const overlap = tokenOverlapScore(titlePortionNorm, key);
      const raceOverlap = tokenOverlapScore(titlePortionNorm, raceNorm);
      const score =
        (directContains ? 14 : 0) +
        (compactContains ? 10 : 0) +
        overlap +
        raceOverlap +
        Math.min(8, key.length / 5);
      if (!directContains && !compactContains && overlap < 6) continue;
      if (score < 16) continue;
      if (!winner || score > winner.score) {
        winner = { race, matchedBy: key, score };
      }
    }
  }
  if (!winner) return null;
  return { race: winner.race, matchedBy: winner.matchedBy };
}

function cutoffIsoDate(monthsBack) {
  const d = new Date();
  d.setUTCMonth(d.getUTCMonth() - monthsBack);
  return d.toISOString().slice(0, 10);
}

function extractYears(value) {
  const years = String(value || "").match(/\b(19|20)\d{2}\b/g) || [];
  return years.map((year) => Number(year));
}

function raceYearFromStartDate(startDate) {
  const parsed = Date.parse(startDate || "");
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).getUTCFullYear();
}

async function resolvePodcastSources() {
  const resolved = [];
  for (const source of PODCAST_SOURCES) {
    let feedUrl = source.feedUrl;
    if (!feedUrl) {
      const searchUrl =
        "https://itunes.apple.com/search?entity=podcast&limit=8&term=" +
        encodeURIComponent(source.searchTerm);
      const result = await fetchJson(searchUrl);
      feedUrl = result?.results?.find((entry) => entry.feedUrl)?.feedUrl || null;
    }
    if (!feedUrl) {
      throw new Error(`Unable to resolve feed URL for ${source.name}`);
    }
    resolved.push({
      sourceId: `pod-${source.slug}`,
      slug: source.slug,
      name: source.name,
      feedUrl,
      websiteUrl: source.websiteUrl || null,
    });
  }
  return resolved;
}

function ensurePodcastCollections(bootstrap) {
  if (!Array.isArray(bootstrap.podcastSources)) bootstrap.podcastSources = [];
  if (!Array.isArray(bootstrap.podcastEpisodes)) bootstrap.podcastEpisodes = [];
  if (!Array.isArray(bootstrap.racePodcastEpisodes)) bootstrap.racePodcastEpisodes = [];
}

async function buildPodcastPreview(bootstrap, identifiers) {
  const selected = Array.isArray(identifiers) && identifiers.length ? new Set(identifiers) : null;
  const sources = await resolvePodcastSources();
  const cutoff = cutoffIsoDate(4);
  const episodeCutoff = new Date();
  episodeCutoff.setUTCMonth(episodeCutoff.getUTCMonth() - 12);
  const candidateRaces = (bootstrap.races || []).filter((race) => (race.startDate || "") >= cutoff);
  const existingEpisodeKey = new Set(
    (bootstrap.podcastEpisodes || []).map((episode) => {
      const sourceId = episode.sourceId || episode.source_id || "";
      return `${sourceId}::${episode.guid || ""}::${episode.episodeUrl || episode.episode_url || ""}`;
    })
  );

  const items = [];
  for (const source of sources) {
    if (selected && !selected.has(source.slug) && !selected.has(source.sourceId)) continue;
    const xml = await fetchText(source.feedUrl);
    const episodes = parseRssItems(xml);
    for (const episode of episodes) {
      const publishedAtMs = Date.parse(episode.publishedAt || "");
      if (Number.isNaN(publishedAtMs) || publishedAtMs < episodeCutoff.getTime()) continue;
      const key = `${source.sourceId}::${episode.guid || ""}::${episode.episodeUrl || ""}`;
      if (existingEpisodeKey.has(key)) continue;
      const resolved = resolveEpisodeMatch(episode, candidateRaces);
      if (!resolved) continue;
      items.push({
        sourceId: source.sourceId,
        sourceSlug: source.slug,
        sourceName: source.name,
        sourceFeedUrl: source.feedUrl,
        sourceWebsiteUrl: source.websiteUrl,
        guid: episode.guid,
        title: episode.title,
        rawTitle: episode.rawTitle,
        description: episode.description,
        episodeUrl: episode.episodeUrl,
        publishedAt: episode.publishedAt,
        raceId: resolved.race.raceId || resolved.race.race_id,
        raceName: resolved.race.name,
        matchedBy: resolved.matchedBy,
      });
    }
  }
  return items;
}

function getContentType(filePath) {
  if (filePath.endsWith(".html")) return "text/html";
  if (filePath.endsWith(".js")) return "text/javascript";
  if (filePath.endsWith(".css")) return "text/css";
  if (filePath.endsWith(".svg")) return "image/svg+xml";
  return "application/octet-stream";
}

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host}`);
  const pathname = parsedUrl.pathname.replace(/\/+$/, "") || "/";

  try {
    if (pathname === "/api/bootstrap" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      return sendJson(res, 200, withIndexes(bootstrap));
    }

    if (pathname === "/api/health" && req.method === "GET") {
      const bootstrap = await loadBootstrap();
      return sendJson(res, 200, {
        races: bootstrap.races?.length || 0,
        stages: bootstrap.stages?.length || bootstrap.raceStages?.length || bootstrap.race_stages?.length || 0,
        teams: bootstrap.teams?.length || 0,
        athletes: bootstrap.athletes?.length || 0,
        participants: bootstrap.participants?.length || 0,
        streamers: bootstrap.streamers?.length || 0,
        raceStreams: bootstrap.raceStreams?.length || 0,
        podcastSources: bootstrap.podcastSources?.length || 0,
        podcastEpisodes: bootstrap.podcastEpisodes?.length || 0,
        racePodcastEpisodes: bootstrap.racePodcastEpisodes?.length || 0,
        stagePodcastEpisodes:
          bootstrap.stagePodcastEpisodes?.length ||
          bootstrap.stage_podcast_episodes?.length ||
          0,
        raceResults: bootstrap.raceResults?.length || bootstrap.race_results?.length || 0,
        stageResults: bootstrap.stageResults?.length || bootstrap.stage_results?.length || 0,
      });
    }

    if (pathname === "/api/results/refresh-race" && req.method === "POST") {
      const body = await readRequestBody(req);
      const raceId = body?.raceId || body?.race_id;
      if (!raceId) {
        return sendJson(res, 400, { error: "raceId is required" });
      }
      const bootstrap = await loadBootstrap();
      const races = bootstrap.races || [];
      const race = races.find((entry) => (entry.raceId || entry.race_id) === raceId);
      if (!race) {
        return sendJson(res, 404, { error: "Race not found in bootstrap JSON" });
      }
      const apiRaceId = await resolveApiRaceForBootstrapRace(race);
      if (!apiRaceId) {
        return sendJson(res, 404, { error: "Race not found in backend API" });
      }
      const apiRaceResults = await requestJson(
        `${API_BASE_URL}/races/${encodeURIComponent(apiRaceId)}/results`
      );
      const apiStages = await requestJson(
        `${API_BASE_URL}/races/${encodeURIComponent(apiRaceId)}/stages`
      );
      const localStages = (bootstrap.stages || bootstrap.raceStages || bootstrap.race_stages || []).filter(
        (stage) => (stage.raceId || stage.race_id) === raceId
      );

      if (!Array.isArray(bootstrap.raceResults)) bootstrap.raceResults = [];
      if (!Array.isArray(bootstrap.stageResults)) bootstrap.stageResults = [];
      bootstrap.raceResults = bootstrap.raceResults.filter((result) => result.raceId !== raceId);
      for (const result of Array.isArray(apiRaceResults) ? apiRaceResults : []) {
        bootstrap.raceResults.push(normalizeRaceResultForBootstrap(result, raceId));
      }

      let stageResultsAdded = 0;
      const apiStagesArray = Array.isArray(apiStages) ? apiStages : [];
      for (const localStage of localStages) {
        const localStageId = localStage.stageId || localStage.stage_id;
        if (!localStageId) continue;
        const apiStage = matchLocalStageToApiStage(localStage, apiStagesArray);
        if (!apiStage) continue;
        const apiStageId = apiStage.stageId || apiStage.stage_id;
        if (!apiStageId) continue;
        const apiStageResults = await requestJson(
          `${API_BASE_URL}/stages/${encodeURIComponent(apiStageId)}/results`
        );
        bootstrap.stageResults = bootstrap.stageResults.filter(
          (result) => result.stageId !== localStageId
        );
        for (const result of Array.isArray(apiStageResults) ? apiStageResults : []) {
          bootstrap.stageResults.push(normalizeStageResultForBootstrap(result, localStageId));
          stageResultsAdded += 1;
        }
      }

      await saveBootstrap(bootstrap);
      return sendJson(res, 200, {
        success: true,
        report: {
          raceResultsAdded: Array.isArray(apiRaceResults) ? apiRaceResults.length : 0,
          stageResultsAdded,
        },
      });
    }

    if (pathname === "/api/bootstrap/regenerate" && req.method === "POST") {
      execFile(
        "npm",
        ["run", "generate-bootstrap"],
        { cwd: path.join(PROJECT_ROOT, "ingestion") },
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

    if (pathname.startsWith("/api/races/") && pathname.endsWith("/image") && req.method === "PATCH") {
      const raceId = pathname.slice("/api/races/".length, -"/image".length);
      const body = await readRequestBody(req);
      const imageUrl = body?.imageUrl ?? body?.image_url;
      if (imageUrl != null && typeof imageUrl !== "string") {
        return sendJson(res, 400, { error: "imageUrl must be string or null" });
      }
      const trimmed = imageUrl != null ? String(imageUrl).trim() : "";
      if (trimmed && !/^https?:\/\//i.test(trimmed) && !/^\//.test(trimmed)) {
        return sendJson(res, 400, { error: "imageUrl must be http(s) URL or root-relative path" });
      }
      const bootstrap = await loadBootstrap();
      const race = (bootstrap.races || []).find(
        (r) => (r.raceId ?? r.race_id) === raceId
      );
      if (!race) {
        return sendJson(res, 404, { error: "Race not found" });
      }
      race.imageUrl = trimmed || null;
      if (race.race_id !== undefined) race.image_url = race.imageUrl;
      await fs.writeFile(BOOTSTRAP_PATH, JSON.stringify(bootstrap, null, 2), "utf8");
      return sendJson(res, 200, { success: true, race });
    }

    if (pathname === "/api/podcasts/sources" && req.method === "GET") {
      const sources = await resolvePodcastSources();
      return sendJson(res, 200, { sources });
    }

    if (pathname === "/api/podcasts/preview" && req.method === "POST") {
      const body = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      const items = await buildPodcastPreview(bootstrap, body?.identifiers || []);
      return sendJson(res, 200, { items });
    }

    if (pathname === "/api/podcasts/commit" && req.method === "POST") {
      const body = await readRequestBody(req);
      const items = Array.isArray(body?.items) ? body.items : [];
      if (items.length === 0) {
        return sendJson(res, 400, { error: "Missing items" });
      }
      const bootstrap = await loadBootstrap();
      ensurePodcastCollections(bootstrap);

      const sourceIds = new Set(bootstrap.podcastSources.map((source) => source.sourceId || source.source_id));
      const episodeKey = new Set(
        bootstrap.podcastEpisodes.map((episode) => {
          const sourceId = episode.sourceId || episode.source_id || "";
          return `${sourceId}::${episode.guid || ""}::${episode.episodeUrl || episode.episode_url || ""}`;
        })
      );
      const raceEpisodePair = new Set(
        bootstrap.racePodcastEpisodes.map((link) => `${link.raceId || link.race_id}::${link.episodeId || link.episode_id}`)
      );

      let addedSources = 0;
      let addedEpisodes = 0;
      let addedLinks = 0;

      for (const item of items) {
        if (!item.sourceId || !item.raceId || !item.title) continue;

        if (!sourceIds.has(item.sourceId)) {
          bootstrap.podcastSources.push({
            sourceId: item.sourceId,
            slug: item.sourceSlug,
            name: item.sourceName,
            feedUrl: item.sourceFeedUrl,
            websiteUrl: item.sourceWebsiteUrl || null,
          });
          sourceIds.add(item.sourceId);
          addedSources += 1;
        }

        const key = `${item.sourceId}::${item.guid || ""}::${item.episodeUrl || ""}`;
        let episodeId = item.episodeId;
        if (!episodeId) {
          episodeId = `ep-${crypto.createHash("sha1").update(key).digest("hex").slice(0, 16)}`;
        }
        if (!episodeKey.has(key)) {
          bootstrap.podcastEpisodes.push({
            episodeId,
            sourceId: item.sourceId,
            guid: item.guid || null,
            title: item.title,
            rawTitle: item.rawTitle || item.title,
            description: item.description || null,
            episodeUrl: item.episodeUrl || null,
            publishedAt: item.publishedAt || null,
          });
          episodeKey.add(key);
          addedEpisodes += 1;
        }

        const pairKey = `${item.raceId}::${episodeId}`;
        if (!raceEpisodePair.has(pairKey)) {
          bootstrap.racePodcastEpisodes.push({
            raceId: item.raceId,
            episodeId,
            matchedBy: item.matchedBy || null,
          });
          raceEpisodePair.add(pairKey);
          addedLinks += 1;
        }
      }

      await saveBootstrap(bootstrap);
      return sendJson(res, 200, {
        success: true,
        report: { addedSources, addedEpisodes, addedLinks, totalItems: items.length },
      });
    }

    if (pathname === "/api/podcasts/refresh" && req.method === "POST") {
      const body = await readRequestBody(req);
      const bootstrap = await loadBootstrap();
      const items = await buildPodcastPreview(bootstrap, body?.identifiers || []);
      if (items.length === 0) {
        return sendJson(res, 200, {
          success: true,
          report: { addedSources: 0, addedEpisodes: 0, addedLinks: 0, totalItems: 0 },
        });
      }
      ensurePodcastCollections(bootstrap);
      const sourceIds = new Set(bootstrap.podcastSources.map((source) => source.sourceId || source.source_id));
      const episodeKey = new Set(
        bootstrap.podcastEpisodes.map((episode) => {
          const sourceId = episode.sourceId || episode.source_id || "";
          return `${sourceId}::${episode.guid || ""}::${episode.episodeUrl || episode.episode_url || ""}`;
        })
      );
      const raceEpisodePair = new Set(
        bootstrap.racePodcastEpisodes.map((link) => `${link.raceId || link.race_id}::${link.episodeId || link.episode_id}`)
      );
      let addedSources = 0;
      let addedEpisodes = 0;
      let addedLinks = 0;
      for (const item of items) {
        if (!item.sourceId || !item.raceId || !item.title) continue;
        if (!sourceIds.has(item.sourceId)) {
          bootstrap.podcastSources.push({
            sourceId: item.sourceId,
            slug: item.sourceSlug,
            name: item.sourceName,
            feedUrl: item.sourceFeedUrl,
            websiteUrl: item.sourceWebsiteUrl || null,
          });
          sourceIds.add(item.sourceId);
          addedSources += 1;
        }
        const key = `${item.sourceId}::${item.guid || ""}::${item.episodeUrl || ""}`;
        let episodeId = item.episodeId;
        if (!episodeId) {
          episodeId = `ep-${crypto.createHash("sha1").update(key).digest("hex").slice(0, 16)}`;
        }
        if (!episodeKey.has(key)) {
          bootstrap.podcastEpisodes.push({
            episodeId,
            sourceId: item.sourceId,
            guid: item.guid || null,
            title: item.title,
            rawTitle: item.rawTitle || item.title,
            description: item.description || null,
            episodeUrl: item.episodeUrl || null,
            publishedAt: item.publishedAt || null,
          });
          episodeKey.add(key);
          addedEpisodes += 1;
        }
        const pairKey = `${item.raceId}::${episodeId}`;
        if (!raceEpisodePair.has(pairKey)) {
          bootstrap.racePodcastEpisodes.push({
            raceId: item.raceId,
            episodeId,
            matchedBy: item.matchedBy || null,
          });
          raceEpisodePair.add(pairKey);
          addedLinks += 1;
        }
      }
      await saveBootstrap(bootstrap);
      return sendJson(res, 200, {
        success: true,
        report: { addedSources, addedEpisodes, addedLinks, totalItems: items.length },
      });
    }

    if (pathname === "/api/themes" && req.method === "GET") {
      const themes = await loadThemePresets();
      return sendJson(res, 200, { themes });
    }

    if (pathname === "/api/themes" && req.method === "POST") {
      const payload = await readRequestBody(req);
      const themes = await loadThemePresets();
      const normalized = normalizeThemePresetPayload(payload);
      if (!normalized) {
        return sendJson(res, 400, { error: "Invalid theme payload" });
      }
      const duplicateName = themes.some(
        (theme) => String(theme.name || "").toLowerCase() === normalized.name.toLowerCase()
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

    if (req.method === "GET") {
      const filePath =
        pathname === "/" || pathname === "/index"
          ? path.join(PUBLIC_DIR, "index.html")
          : pathname === "/themes"
            ? path.join(PUBLIC_DIR, "themes.html")
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

const runGenerate = () =>
  new Promise((resolve) => {
    execFile(
      "npm",
      ["run", "generate-bootstrap"],
      { cwd: path.join(PROJECT_ROOT, "ingestion") },
      (error, stdout, stderr) => {
        if (error) {
          console.error("Bootstrap generation failed:", stderr || stdout || error.message);
        }
        resolve(true);
      }
    );
  });

server.listen(PORT, async () => {
  if (AUTO_GENERATE) {
    await runGenerate();
  }
  console.log(`Cyclismo bootstrap console running on http://localhost:${PORT}`);
});
