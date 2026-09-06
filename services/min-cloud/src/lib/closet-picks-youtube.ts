import { absoluteCriterionUrl, guestNameFromEpisodeTitle } from "./closet-picks-scrape.js";

export const CLOSET_PICKS_YOUTUBE_PLAYLIST_ID = "PL7D89754A5DAD1E8E";
export const CLOSET_PICKS_YOUTUBE_PLAYLIST_URL = `https://www.youtube.com/playlist?list=${CLOSET_PICKS_YOUTUBE_PLAYLIST_ID}`;
export const CLOSET_PICKS_YOUTUBE_FEED_URL = `https://www.youtube.com/feeds/videos.xml?playlist_id=${CLOSET_PICKS_YOUTUBE_PLAYLIST_ID}`;

export type ClosetPicksYouTubeVideo = {
  videoId: string;
  title: string;
  watchUrl: string;
  published: string | null;
  description: string;
  collectionUrl: string | null;
  guestKey: string;
};

export type ClosetPicksYouTubeMatchTarget = {
  sourceTitle?: string | null;
  sourceUrl?: string | null;
  episodeTitle?: string | null;
  episodeUrl?: string | null;
  guestName?: string | null;
};

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;
const COLLECTION_URL =
  /https?:\/\/(?:www\.)?criterion\.com\/(?:shop\/collection\/\d+-[^\s"'<>]+?closet-picks|closet-picks\/[^\s"'<>]+)/i;

const FETCH_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  "Accept-Language": "en-US,en;q=0.9"
};

export const closetPicksYouTubeWatchUrl = (videoId: string) => `https://www.youtube.com/watch?v=${videoId}`;

export const closetPicksYouTubeVideoId = (raw: string | null | undefined) => {
  const value = String(raw || "").trim();
  if (!value) {
    return "";
  }
  if (YOUTUBE_ID.test(value)) {
    return value;
  }
  try {
    const url = new URL(value);
    const host = url.hostname.replace(/^www\./, "");
    if (host === "youtu.be") {
      const id = url.pathname.split("/").filter(Boolean)[0] || "";
      return YOUTUBE_ID.test(id) ? id : "";
    }
    if (host === "youtube.com" || host === "m.youtube.com" || host === "music.youtube.com") {
      const queryId = url.searchParams.get("v") || "";
      if (YOUTUBE_ID.test(queryId)) {
        return queryId;
      }
      const parts = url.pathname.split("/").filter(Boolean);
      const nested = parts[0] && ["embed", "shorts", "live", "v", "watch"].includes(parts[0]) ? parts[1] : parts[0];
      return nested && YOUTUBE_ID.test(nested) ? nested : "";
    }
  } catch {
    return "";
  }
  return "";
};

export const closetPicksYouTubeGuestKey = (title: string) => {
  const cleaned = guestNameFromEpisodeTitle(title.replace(/criterion\s+mobile\s+/gi, " ")).replace(/&/g, " and ");
  return cleaned
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
};

export const closetPicksCollectionKey = (url: string | null | undefined) => {
  const raw = String(url || "").trim();
  if (!raw) {
    return "";
  }
  try {
    return new URL(absoluteCriterionUrl(raw)).pathname.replace(/\/$/, "").toLowerCase();
  } catch {
    return "";
  }
};

export const closetPicksCollectionUrlFromText = (text: string) => {
  const match = String(text || "").match(COLLECTION_URL);
  return match ? absoluteCriterionUrl(match[0].replace(/[.,;)]+$/, "")) : null;
};

const walk = (value: unknown, visit: (node: Record<string, unknown>) => void) => {
  if (!value || typeof value !== "object") {
    return;
  }
  if (Array.isArray(value)) {
    for (const item of value) {
      walk(item, visit);
    }
    return;
  }
  const node = value as Record<string, unknown>;
  visit(node);
  for (const child of Object.values(node)) {
    walk(child, visit);
  }
};

const titleFromLockup = (lockup: Record<string, unknown>) => {
  const metadata = lockup.metadata as Record<string, unknown> | undefined;
  const view = metadata?.lockupMetadataViewModel as Record<string, unknown> | undefined;
  const title = view?.title as Record<string, unknown> | undefined;
  return typeof title?.content === "string" ? title.content : "";
};

export const parseClosetPicksYouTubeLockups = (payload: unknown): ClosetPicksYouTubeVideo[] => {
  const videos: ClosetPicksYouTubeVideo[] = [];
  const seen = new Set<string>();
  walk(payload, (node) => {
    const lockup = (node.lockupViewModel as Record<string, unknown> | undefined) ?? node;
    if (lockup.contentType !== "LOCKUP_CONTENT_TYPE_VIDEO") {
      return;
    }
    const videoId = closetPicksYouTubeVideoId(typeof lockup.contentId === "string" ? lockup.contentId : "");
    if (!videoId || seen.has(videoId)) {
      return;
    }
    const title = titleFromLockup(lockup);
    seen.add(videoId);
    videos.push({
      videoId,
      title,
      watchUrl: closetPicksYouTubeWatchUrl(videoId),
      published: null,
      description: "",
      collectionUrl: null,
      guestKey: closetPicksYouTubeGuestKey(title)
    });
  });
  return videos;
};

export const parseClosetPicksYouTubeContinuationToken = (payload: unknown) => {
  const tokens: string[] = [];
  walk(payload, (node) => {
    const command = node.continuationCommand;
    if (!command || typeof command !== "object") {
      return;
    }
    const token = (command as { token?: unknown }).token;
    if (typeof token === "string" && token.length > 100) {
      tokens.push(token);
    }
  });
  return tokens[0] ?? "";
};

export const parseClosetPicksYouTubePage = (html: string) => {
  const cfgMatch = html.match(/ytcfg\.set\((\{.*?\})\);/s);
  let innertubeKey = "";
  let context: Record<string, unknown> = {
    client: { clientName: "WEB", clientVersion: "2.20260904.01.00", hl: "en", gl: "US" }
  };
  if (cfgMatch) {
    try {
      const cfg = JSON.parse(cfgMatch[1]) as Record<string, unknown>;
      innertubeKey = typeof cfg.INNERTUBE_API_KEY === "string" ? cfg.INNERTUBE_API_KEY : "";
      if (cfg.INNERTUBE_CONTEXT && typeof cfg.INNERTUBE_CONTEXT === "object") {
        context = cfg.INNERTUBE_CONTEXT as Record<string, unknown>;
      }
    } catch {
      // keep defaults
    }
  }
  const dataMatch = html.match(/ytInitialData\s*=\s*(\{.+?\});\s*<\/script>/s);
  const payload = dataMatch ? JSON.parse(dataMatch[1]) : {};
  return {
    videos: parseClosetPicksYouTubeLockups(payload),
    continuation: parseClosetPicksYouTubeContinuationToken(payload),
    innertubeKey,
    context
  };
};

export const parseClosetPicksYouTubeFeed = (xml: string): ClosetPicksYouTubeVideo[] => {
  const entries = xml.split(/<entry\b/i).slice(1);
  return entries
    .map((entry) => {
      const videoId = closetPicksYouTubeVideoId(entry.match(/<yt:videoId>([^<]+)<\/yt:videoId>/i)?.[1]);
      const title = (entry.match(/<title>([^<]+)<\/title>/i)?.[1] || "").trim();
      const description =
        entry.match(/<media:description>([\s\S]*?)<\/media:description>/i)?.[1]?.replace(/<!\[CDATA\[|\]\]>/g, "") ||
        "";
      const published = entry.match(/<published>([^<]+)<\/published>/i)?.[1] || null;
      if (!videoId) {
        return null;
      }
      return {
        videoId,
        title,
        watchUrl: closetPicksYouTubeWatchUrl(videoId),
        published,
        description,
        collectionUrl: closetPicksCollectionUrlFromText(description),
        guestKey: closetPicksYouTubeGuestKey(title)
      } satisfies ClosetPicksYouTubeVideo;
    })
    .filter((video): video is ClosetPicksYouTubeVideo => Boolean(video));
};

const mergeYouTubeVideos = (groups: ClosetPicksYouTubeVideo[][]) => {
  const byId = new Map<string, ClosetPicksYouTubeVideo>();
  for (const group of groups) {
    for (const video of group) {
      const existing = byId.get(video.videoId);
      if (!existing) {
        byId.set(video.videoId, video);
        continue;
      }
      byId.set(video.videoId, {
        ...existing,
        title: existing.title || video.title,
        published: existing.published || video.published,
        description: existing.description || video.description,
        collectionUrl: existing.collectionUrl || video.collectionUrl,
        guestKey: existing.guestKey || video.guestKey
      });
    }
  }
  return [...byId.values()];
};

const fetchText = async (url: string, init: RequestInit = {}) => {
  const response = await fetch(url, {
    ...init,
    headers: { ...FETCH_HEADERS, ...(init.headers || {}) },
    signal: AbortSignal.timeout(20000)
  });
  if (!response.ok) {
    throw new Error(`GET ${url} failed ${response.status}`);
  }
  return response.text();
};

const browseYouTubeContinuation = async (
  token: string,
  innertubeKey: string,
  context: Record<string, unknown>
) => {
  const url = innertubeKey
    ? `https://www.youtube.com/youtubei/v1/browse?prettyPrint=false&key=${encodeURIComponent(innertubeKey)}`
    : "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false";
  const response = await fetch(url, {
    method: "POST",
    headers: { ...FETCH_HEADERS, "Content-Type": "application/json" },
    body: JSON.stringify({ context, continuation: token }),
    signal: AbortSignal.timeout(20000)
  });
  if (!response.ok) {
    throw new Error(`YouTube browse failed ${response.status}`);
  }
  return response.json();
};

export const fetchClosetPicksYouTubeVideos = async (): Promise<ClosetPicksYouTubeVideo[]> => {
  const groups: ClosetPicksYouTubeVideo[][] = [];
  try {
    groups.push(parseClosetPicksYouTubeFeed(await fetchText(CLOSET_PICKS_YOUTUBE_FEED_URL)));
  } catch {
    // RSS is supplemental
  }

  const page = parseClosetPicksYouTubePage(await fetchText(CLOSET_PICKS_YOUTUBE_PLAYLIST_URL));
  groups.push(page.videos);
  let continuation = page.continuation;
  const seenTokens = new Set<string>();
  for (let index = 0; continuation && index < 20 && !seenTokens.has(continuation); index += 1) {
    seenTokens.add(continuation);
    const payload = await browseYouTubeContinuation(continuation, page.innertubeKey, page.context);
    groups.push(parseClosetPicksYouTubeLockups(payload));
    continuation = parseClosetPicksYouTubeContinuationToken(payload);
  }

  const videos = mergeYouTubeVideos(groups);
  if (!videos.length) {
    throw new Error("Closet Picks YouTube playlist returned no videos");
  }
  return videos;
};

const tokenSet = (key: string) => new Set(key.split(" ").filter(Boolean));

const tokensCover = (left: Set<string>, right: Set<string>) =>
  right.size > 0 && [...right].every((token) => left.has(token));

export const matchClosetPicksYouTubeVideo = (
  target: ClosetPicksYouTubeMatchTarget,
  videos: ClosetPicksYouTubeVideo[]
) => {
  const collection = closetPicksCollectionKey(target.sourceUrl || target.episodeUrl);
  if (collection) {
    const byCollection = videos.find((video) => closetPicksCollectionKey(video.collectionUrl) === collection);
    if (byCollection) {
      return byCollection;
    }
  }

  const guest = closetPicksYouTubeGuestKey(
    target.sourceTitle || target.episodeTitle || target.guestName || ""
  );
  if (!guest) {
    return null;
  }
  const exact = videos.find((video) => video.guestKey === guest);
  if (exact) {
    return exact;
  }

  const guestTokens = tokenSet(guest);
  const covered = videos.filter((video) => {
    const videoTokens = tokenSet(video.guestKey);
    return tokensCover(videoTokens, guestTokens) || tokensCover(guestTokens, videoTokens);
  });
  return covered.length === 1 ? covered[0] : null;
};

export const attachClosetPicksYouTube = <T extends ClosetPicksYouTubeMatchTarget>(
  rows: T[],
  videos: ClosetPicksYouTubeVideo[]
) =>
  rows.map((row) => {
    const video = matchClosetPicksYouTubeVideo(row, videos);
    if (!video) {
      return row;
    }
    return {
      ...row,
      youtubeUrl: video.watchUrl,
      episodeDate: (row as { episodeDate?: string | null }).episodeDate ?? video.published
    };
  });
