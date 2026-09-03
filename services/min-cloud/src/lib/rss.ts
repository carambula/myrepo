import * as cheerio from "cheerio";

export type ParsedEpisode = {
  id: string;
  guid: string;
  title: string;
  description: string;
  publishDate: string | null;
  durationSeconds: number | null;
  audioUrl: string | null;
  videoUrl: string | null;
  artworkUrl: string | null;
  episodeNumber: number | null;
  seasonNumber: number | null;
};

export type ParsedPodcastMeta = {
  title: string;
  author: string;
  description: string;
  artworkUrl: string | null;
  websiteUrl: string | null;
  language: string;
  isExplicit: boolean;
};

const decodeEntities = (value: string) =>
  value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .trim();

const parseDuration = (value: string | undefined) => {
  if (!value) {
    return null;
  }
  const trimmed = value.trim();
  if (/^\d+$/.test(trimmed)) {
    return Number(trimmed);
  }
  const parts = trimmed.split(":").map((part) => Number(part));
  if (parts.some((part) => Number.isNaN(part))) {
    return null;
  }
  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  }
  if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  }
  return null;
};

type CheerioSelection = cheerio.Cheerio<any>;

const firstText = (root: CheerioSelection, selectors: string[]) => {
  for (const selector of selectors) {
    const text = root.find(selector).first().text();
    if (text.trim()) {
      return decodeEntities(text);
    }
  }
  return "";
};

const firstAttr = (root: CheerioSelection, selector: string, attr: string) => {
  const value = root.find(selector).first().attr(attr);
  return value ? decodeEntities(value) : null;
};

export const parseRssDate = (value: string | null | undefined) => {
  if (!value) {
    return null;
  }
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) {
    return null;
  }
  return new Date(parsed).toISOString();
};

export const parseRssFeed = (xml: string): { meta: ParsedPodcastMeta; episodes: ParsedEpisode[] } => {
  const $ = cheerio.load(xml, { xmlMode: true });
  const channel = $("channel").first();
  const feed = $("feed").first();
  const root = channel.length ? channel : feed;

  const meta: ParsedPodcastMeta = {
    title: firstText(root, ["title"]) || "Untitled podcast",
    author: firstText(root, ["itunes\\:author", "author", "managingEditor"]) || "Unknown",
    description: firstText(root, ["description", "itunes\\:summary", "subtitle"]),
    artworkUrl:
      firstAttr(root, "itunes\\:image", "href") ||
      firstAttr(root, "image url", "href") ||
      root.find("image url").first().text().trim() ||
      null,
    websiteUrl: firstText(root, ["link"]) || null,
    language: firstText(root, ["language"]) || "en",
    isExplicit: /yes|true|explicit/i.test(firstText(root, ["itunes\\:explicit"]))
  };

  const items = $("item, entry").toArray();
  const episodes = items.map((item, index) => {
    const node = $(item);
    const title = firstText(node, ["title"]) || `Episode ${index + 1}`;
    const guid = firstText(node, ["guid", "id"]) || firstAttr(node, "enclosure", "url") || `${title}-${index}`;
    const enclosureUrl = firstAttr(node, "enclosure", "url");
    const enclosureType = firstAttr(node, "enclosure", "type") || "";
    const mediaUrl = firstAttr(node, "media\\:content", "url") || enclosureUrl;
    const isVideo = /video/i.test(enclosureType) || /\.(mp4|m4v|mov)(\?|$)/i.test(mediaUrl || "");
    return {
      id: guid,
      guid,
      title,
      description: firstText(node, ["description", "content\\:encoded", "summary", "itunes\\:summary"]),
      publishDate: parseRssDate(firstText(node, ["pubDate", "published", "updated"])),
      durationSeconds: parseDuration(firstText(node, ["itunes\\:duration"])),
      audioUrl: isVideo ? null : mediaUrl,
      videoUrl: isVideo ? mediaUrl : null,
      artworkUrl: firstAttr(node, "itunes\\:image", "href"),
      episodeNumber: Number(firstText(node, ["itunes\\:episode"])) || null,
      seasonNumber: Number(firstText(node, ["itunes\\:season"])) || null
    } satisfies ParsedEpisode;
  });

  return { meta, episodes };
};

export const newestEpisodesSince = (episodes: ParsedEpisode[], sinceIso: string | null) => {
  if (!sinceIso) {
    return episodes;
  }
  const since = Date.parse(sinceIso);
  if (Number.isNaN(since)) {
    return episodes;
  }
  return episodes.filter((episode) => {
    if (!episode.publishDate) {
      return false;
    }
    return Date.parse(episode.publishDate) > since;
  });
};
