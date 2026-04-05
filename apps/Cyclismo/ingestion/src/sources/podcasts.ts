type PodcastSourceSeed = {
  slug: string;
  name: string;
  searchTerm: string;
  feedUrl?: string;
  websiteUrl?: string;
};

export type PodcastSourceResolved = {
  slug: string;
  name: string;
  feedUrl: string;
  websiteUrl: string | null;
};

export type PodcastEpisodeScraped = {
  guid: string | null;
  title: string;
  rawTitle: string;
  description: string | null;
  episodeUrl: string | null;
  publishedAt: string | null;
};

export type RaceForPodcastMatch = {
  raceId: string;
  name: string;
  startDate: string;
};

export type StageForPodcastMatch = {
  stageId: string;
  raceId: string;
  raceName: string;
  raceStartDate: string;
  stageNumber: number | null;
  name: string;
  date: string | null;
  isRestDay: boolean;
  stageType: string | null;
};

export type PodcastEpisodeMatch = {
  source: PodcastSourceResolved;
  episode: PodcastEpisodeScraped;
  raceId: string;
  raceName: string;
  matchedBy: string;
  stageId?: string;
  stageName?: string;
  stageMatchedBy?: string;
};

const PODCAST_SOURCE_SEEDS: PodcastSourceSeed[] = [
  {
    slug: "how-the-race-was-won",
    name: "How the Race was Won Podcast",
    searchTerm: "How the Race Was Won Podcast cycling",
    feedUrl: process.env.HOW_THE_RACE_WAS_WON_FEED_URL,
    websiteUrl: "https://escapecollective.com"
  },
  {
    slug: "lanterne-rouge",
    name: "The Lanterne Rouge Cycling Podcast",
    searchTerm: "Lanterne Rouge Cycling Podcast",
    feedUrl: process.env.LANTERNE_ROUGE_FEED_URL,
    websiteUrl: "https://lanternerouge.com"
  },
  {
    slug: "wheel-talk",
    name: "Wheel Talk",
    searchTerm: "Wheel Talk Escape Collective cycling podcast",
    feedUrl: process.env.WHEEL_TALK_FEED_URL ?? "https://publicfeeds.net/f/16098/wheel-talk",
    websiteUrl: "https://escapecollective.com/wheeltalk/"
  },
  {
    slug: "lanterne-rouge-youtube",
    name: "Lanterne Rouge (YouTube)",
    searchTerm: "Lanterne Rouge YouTube Cycling",
    feedUrl:
      process.env.LANTERNE_ROUGE_YOUTUBE_FEED_URL ??
      "https://www.youtube.com/feeds/videos.xml?channel_id=UC77UtoyivVHkpApL0wGfH5w",
    websiteUrl: "https://www.youtube.com/@LanterneRougeCycling"
  }
];

const nowUtc = () => new Date();

const subMonthsUtc = (base: Date, months: number) => {
  const next = new Date(base.getTime());
  next.setUTCMonth(next.getUTCMonth() - months);
  return next;
};

const extractYears = (value: string): number[] => {
  const years = value.match(/\b(19|20)\d{2}\b/g) ?? [];
  return years.map((year) => Number(year));
};

const raceYearFromStartDate = (startDate: string): number | null => {
  const parsed = Date.parse(startDate);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).getUTCFullYear();
};

const isEpisodeWithinRaceWindow = (episodePublishedAt: string | null, raceStartDate: string): boolean => {
  if (!episodePublishedAt) return false;
  const publishedMs = Date.parse(episodePublishedAt);
  const raceStartMs = Date.parse(raceStartDate);
  if (Number.isNaN(publishedMs) || Number.isNaN(raceStartMs)) return false;
  const dayDelta = Math.round((publishedMs - raceStartMs) / (1000 * 60 * 60 * 24));
  // Keep links close to the race window to avoid cross-season stage mislinks.
  return dayDelta >= -45 && dayDelta <= 45;
};

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
  "race"
]);

const RACE_ALIAS_RULES: Array<{ pattern: RegExp; aliases: string[] }> = [
  { pattern: /\btour de france femmes?\b/i, aliases: ["tour de france femmes", "tdf femmes", "tdff"] },
  { pattern: /\btour de france\b/i, aliases: ["tour de france", "tdf", "le tour"] },
  { pattern: /\bgiro d'?italia\b/i, aliases: ["giro d italia", "giro"] },
  { pattern: /\bvuelta a espa[ñn]a\b/i, aliases: ["vuelta a espana", "vuelta"] },
  { pattern: /\bparis[- ]?roubaix\b/i, aliases: ["paris roubaix", "roubaix", "hell of the north"] },
  { pattern: /\btour of flanders\b|\bronde van vlaanderen\b/i, aliases: ["tour of flanders", "ronde van vlaanderen", "flanders", "ronde"] },
  { pattern: /\bliege[- ]?bastogne[- ]?liege\b/i, aliases: ["liege bastogne liege", "lbl"] },
  {
    pattern: /\b(milano|milan)[- ]?san ?remo\b/i,
    aliases: ["milano sanremo", "milan san remo", "san remo", "milan sanremo"]
  },
  {
    pattern: /\b(milano|milan)[- ]?san ?remo\b.*\b(donne|women|womens)\b/i,
    aliases: ["milano sanremo", "milan san remo", "san remo", "milan sanremo", "sanremo donne"]
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
      "catalonia"
    ]
  },
  { pattern: /\bitzulia\b|\bbasque country\b/i, aliases: ["itzulia", "basque country"] }
];

const normalizeTitle = (value: string) =>
  value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\b(uci|mens|women|womens|race|cycling|podcast|preview|review)\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const compactText = (value: string) => value.replace(/\s+/g, "");

const tokenize = (value: string): string[] =>
  value
    .split(" ")
    .map((token) => token.trim())
    .filter((token) => token.length >= 3 && !TOKEN_STOPWORDS.has(token));

const tokenOverlapScore = (left: string, right: string): number => {
  const leftTokens = new Set(tokenize(left));
  const rightTokens = new Set(tokenize(right));
  if (leftTokens.size === 0 || rightTokens.size === 0) return 0;
  let common = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) common += 1;
  }
  return (common / Math.max(leftTokens.size, rightTokens.size)) * 10;
};

const stripHtml = (value: string): string =>
  value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/gi, "$1")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, " ")
    .trim();

const decodeXmlText = (value: string) =>
  value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/gi, "$1")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .trim();

const parseRssDate = (value: string | null): string | null => {
  if (!value) return null;
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).toISOString();
};

const extractTag = (xml: string, tag: string): string | null => {
  const direct = xml.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i"));
  if (direct?.[1]) return decodeXmlText(direct[1]);
  return null;
};

const extractLink = (itemXml: string): string | null => {
  const atomAlternate = itemXml.match(/<link[^>]*rel="alternate"[^>]*href="([^"]+)"[^>]*\/?>/i)?.[1];
  if (atomAlternate) return atomAlternate.trim();
  const atom = itemXml.match(/<link[^>]*href="([^"]+)"[^>]*\/?>/i)?.[1];
  if (atom) return atom.trim();
  const link = extractTag(itemXml, "link");
  return link?.trim() ?? null;
};

const parseRssItems = (xml: string): PodcastEpisodeScraped[] => {
  const parseBlock = (
    blockXml: string,
    publicationTagFallbacks: string[] = ["pubDate"]
  ): PodcastEpisodeScraped | null => {
      const rawTitle = extractTag(blockXml, "title") ?? "";
      const title = stripHtml(rawTitle);
      if (!title) return null;
      const guid =
        extractTag(blockXml, "guid") ??
        extractTag(blockXml, "id") ??
        extractTag(blockXml, "yt:videoId");
      const description =
        extractTag(blockXml, "description") ??
        extractTag(blockXml, "media:description") ??
        extractTag(blockXml, "summary") ??
        extractTag(blockXml, "content");
      const pubDateRaw =
        publicationTagFallbacks
          .map((tag) => extractTag(blockXml, tag))
          .find((value): value is string => Boolean(value)) ?? null;
      let episodeUrl = extractLink(blockXml);
      if (!episodeUrl) {
        const youtubeVideoId = extractTag(blockXml, "yt:videoId");
        if (youtubeVideoId) {
          episodeUrl = `https://www.youtube.com/watch?v=${youtubeVideoId}`;
        }
      }
      return {
        guid: guid || null,
        title,
        rawTitle,
        description: description ? stripHtml(description) : null,
        episodeUrl: episodeUrl || null,
        publishedAt: parseRssDate(pubDateRaw)
      } satisfies PodcastEpisodeScraped;
  };

  const rssItems = (xml.match(/<item[\s\S]*?<\/item>/gi) ?? [])
    .map((itemXml) => parseBlock(itemXml, ["pubDate"]))
    .filter((item): item is PodcastEpisodeScraped => item != null);
  const atomEntries = (xml.match(/<entry[\s\S]*?<\/entry>/gi) ?? [])
    .map((entryXml) => parseBlock(entryXml, ["published", "updated"]))
    .filter((item): item is PodcastEpisodeScraped => item != null);
  return [...rssItems, ...atomEntries];
};

const resolveFeedUrl = async (seed: PodcastSourceSeed): Promise<string> => {
  if (seed.feedUrl && seed.feedUrl.trim()) {
    return seed.feedUrl.trim();
  }

  const url = new URL("https://itunes.apple.com/search");
  url.searchParams.set("entity", "podcast");
  url.searchParams.set("limit", "8");
  url.searchParams.set("term", seed.searchTerm);
  const response = await fetch(url, {
    headers: {
      "User-Agent": "CyclismoPodcastIngestion/1.0"
    }
  });
  if (!response.ok) {
    throw new Error(`iTunes search failed (${response.status}) for ${seed.name}`);
  }
  const body = (await response.json()) as { results?: Array<{ feedUrl?: string; collectionName?: string }> };
  const feedUrl = body.results?.find((result) => (result.feedUrl ?? "").length > 0)?.feedUrl;
  if (!feedUrl) {
    throw new Error(`No feed URL found for ${seed.name}`);
  }
  return feedUrl;
};

const buildRaceMatchKeys = (raceName: string): string[] => {
  const normalized = normalizeTitle(raceName);
  if (!normalized) return [];
  const keys = new Set<string>([normalized]);
  keys.add(
    normalized
      .replace(/\b(the|la|le|de|du|des|of)\b/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );
  keys.add(
    normalized
      .replace(/\b(gp|grand prix)\b/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );

  const sansCiclista = normalized
    .replace(/\bciclista\b/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (sansCiclista !== normalized && sansCiclista.length >= 5) {
    keys.add(sansCiclista);
  }

  for (const rule of RACE_ALIAS_RULES) {
    if (rule.pattern.test(raceName)) {
      for (const alias of rule.aliases) {
        const normalizedAlias = normalizeTitle(alias);
        if (normalizedAlias) keys.add(normalizedAlias);
      }
    }
  }

  return Array.from(keys).filter((key) => key.length >= 5);
};

const matchEpisodeToRaces = (
  episode: PodcastEpisodeScraped,
  candidateRaces: RaceForPodcastMatch[]
): Array<{ race: RaceForPodcastMatch; matchedBy: string; score: number }> => {
  const episodeTitleNorm = normalizeTitle(`${episode.title} ${episode.rawTitle}`);
  if (!episodeTitleNorm) return [];
  const descSlice = (episode.description ?? "").slice(0, 2500);
  const episodeSearchNorm = normalizeTitle(`${episode.title} ${episode.rawTitle} ${descSlice}`);
  const episodeSearchCompact = compactText(episodeSearchNorm);
  const titleYears = new Set(extractYears(`${episode.title} ${episode.rawTitle}`));
  const enforceYearMatch = titleYears.size > 0;

  const candidates: Array<{ race: RaceForPodcastMatch; matchedBy: string; score: number }> = [];
  for (const race of candidateRaces) {
    if (!isEpisodeWithinRaceWindow(episode.publishedAt, race.startDate)) {
      continue;
    }
    const raceYear = raceYearFromStartDate(race.startDate);
    if (!raceYear) {
      continue;
    }
    if (enforceYearMatch) {
      const yearOk =
        titleYears.has(raceYear) || titleYears.has(raceYear - 1);
      if (!yearOk) {
        continue;
      }
    }
    const keys = buildRaceMatchKeys(race.name);
    const raceNameNorm = normalizeTitle(race.name);
    let winnerForRace: { race: RaceForPodcastMatch; matchedBy: string; score: number } | null = null;
    for (const key of keys) {
      if (key.length < 5) continue;
      const keyCompact = compactText(key);
      const directContains = episodeSearchNorm.includes(key);
      const compactContains = episodeSearchCompact.includes(keyCompact);
      const overlap = tokenOverlapScore(episodeTitleNorm, key);
      const raceOverlap = tokenOverlapScore(episodeTitleNorm, raceNameNorm);
      const score =
        (directContains ? 14 : 0) +
        (compactContains ? 10 : 0) +
        overlap +
        raceOverlap +
        Math.min(8, key.length / 5);
      if (!directContains && !compactContains && overlap < 6) continue;
      if (score < 16) continue;
      if (!winnerForRace || score > winnerForRace.score) {
        winnerForRace = { race, matchedBy: key, score };
      }
    }
    if (winnerForRace) {
      candidates.push(winnerForRace);
    }
  }

  if (candidates.length === 0) return [];
  candidates.sort((a, b) => b.score - a.score);
  const bestScore = candidates[0]?.score ?? 0;
  const threshold = Math.max(16, bestScore - 4);
  return candidates.filter((candidate) => candidate.score >= threshold).slice(0, 3);
};

const extractStageNumber = (value: string): number | null => {
  const match = value.match(/\b(?:stage|stg|etape)\s*(\d{1,2})\b/i);
  if (!match?.[1]) return null;
  const parsed = Number(match[1]);
  return Number.isFinite(parsed) ? parsed : null;
};

const escapeRegex = (value: string) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const extractRaceScopedStageNumber = (normalizedTitle: string, raceName: string): number | null => {
  const keys = buildRaceMatchKeys(raceName).sort((a, b) => b.length - a.length);
  for (const key of keys) {
    if (!key) continue;
    const escapedKey = escapeRegex(key);
    const patterns = [
      new RegExp(`${escapedKey}\\s*(?:stage|stg|etape)\\s*(\\d{1,2})`, "i"),
      new RegExp(`(?:stage|stg|etape)\\s*(\\d{1,2})\\s*(?:of|for)?\\s*${escapedKey}`, "i")
    ];
    for (const pattern of patterns) {
      const match = normalizedTitle.match(pattern);
      if (!match?.[1]) continue;
      const parsed = Number(match[1]);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }
  return null;
};

const isRestDayMentioned = (value: string) => /\b(rest\s*day|jour\s+de\s+repos)\b/i.test(value);

const matchEpisodeToStage = (
  episode: PodcastEpisodeScraped,
  raceId: string,
  stages: StageForPodcastMatch[]
): { stage: StageForPodcastMatch; matchedBy: string } | null => {
  const stageCandidates = stages.filter((stage) => stage.raceId === raceId);
  if (!stageCandidates.length) {
    return null;
  }
  const normalizedTitle = normalizeTitle(`${episode.title} ${episode.rawTitle}`);
  const raceNameForStages = stageCandidates[0]?.raceName ?? "";
  const stageNumber =
    extractRaceScopedStageNumber(normalizedTitle, raceNameForStages) ??
    extractStageNumber(normalizedTitle);
  if (stageNumber != null) {
    const exact = stageCandidates.find((stage) => stage.stageNumber === stageNumber);
    if (exact) {
      return { stage: exact, matchedBy: `stage_number:${stageNumber}` };
    }
  }
  if (isRestDayMentioned(normalizedTitle)) {
    const restDay = stageCandidates.find((stage) => stage.isRestDay);
    if (restDay) {
      return { stage: restDay, matchedBy: "rest_day" };
    }
  }

  let winner: { stage: StageForPodcastMatch; score: number; matchedBy: string } | null = null;
  for (const stage of stageCandidates) {
    const stageNameNorm = normalizeTitle(stage.name);
    if (!stageNameNorm) continue;
    const overlap = tokenOverlapScore(normalizedTitle, stageNameNorm);
    const contains = normalizedTitle.includes(stageNameNorm);
    const score =
      (contains ? 8 : 0) +
      overlap +
      (stage.stageType && normalizedTitle.includes(normalizeTitle(stage.stageType)) ? 4 : 0);
    if (!contains && overlap < 6) continue;
    if (score < 12) continue;
    if (!winner || score > winner.score) {
      winner = { stage, score, matchedBy: `stage_name:${stageNameNorm}` };
    }
  }
  return winner ? { stage: winner.stage, matchedBy: winner.matchedBy } : null;
};

export const getConfiguredPodcastSources = async (): Promise<PodcastSourceResolved[]> => {
  const resolved = await Promise.all(
    PODCAST_SOURCE_SEEDS.map(async (seed) => {
      const feedUrl = await resolveFeedUrl(seed);
      return {
        slug: seed.slug,
        name: seed.name,
        feedUrl,
        websiteUrl: seed.websiteUrl ?? null
      } satisfies PodcastSourceResolved;
    })
  );
  return resolved;
};

export const scrapePodcastEpisodes = async (
  source: PodcastSourceResolved
): Promise<PodcastEpisodeScraped[]> => {
  const response = await fetch(source.feedUrl, {
    headers: {
      "User-Agent": "CyclismoPodcastIngestion/1.0"
    }
  });
  if (!response.ok) {
    throw new Error(`Podcast fetch failed (${response.status}) for ${source.name}`);
  }
  const xml = await response.text();
  return parseRssItems(xml);
};

export const matchPodcastEpisodesToRaces = (
  source: PodcastSourceResolved,
  episodes: PodcastEpisodeScraped[],
  races: RaceForPodcastMatch[],
  stages: StageForPodcastMatch[] = [],
  lookbackMonths = 4
): PodcastEpisodeMatch[] => {
  const now = nowUtc();
  const raceCutoff = subMonthsUtc(now, lookbackMonths);
  const episodeCutoff = subMonthsUtc(now, 12);
  const candidateRaces = races.filter((race) => {
    const start = Date.parse(race.startDate);
    return !Number.isNaN(start) && start >= raceCutoff.getTime();
  });

  const matches: PodcastEpisodeMatch[] = [];
  for (const episode of episodes) {
    const publishedAtMs = episode.publishedAt ? Date.parse(episode.publishedAt) : NaN;
    if (Number.isNaN(publishedAtMs) || publishedAtMs < episodeCutoff.getTime()) {
      continue;
    }
    const raceMatches = matchEpisodeToRaces(episode, candidateRaces);
    if (!raceMatches.length) continue;
    for (const match of raceMatches) {
      const stageMatch = matchEpisodeToStage(episode, match.race.raceId, stages);
      matches.push({
        source,
        episode,
        raceId: match.race.raceId,
        raceName: match.race.name,
        matchedBy: match.matchedBy,
        stageId: stageMatch?.stage.stageId,
        stageName: stageMatch?.stage.name,
        stageMatchedBy: stageMatch?.matchedBy
      });
    }
  }
  return matches;
};
