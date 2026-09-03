import { fetchJson } from "./http.js";
import { podcastIdFromItunes } from "./passwords.js";

type ItunesPodcast = {
  trackId: number;
  trackName: string;
  artistName?: string;
  feedUrl?: string;
  artworkUrl600?: string;
  artworkUrl100?: string;
  genres?: string[];
  collectionExplicitness?: string;
  trackViewUrl?: string;
};

export const searchItunesPodcasts = async (term: string) => {
  const url = new URL("https://itunes.apple.com/search");
  url.searchParams.set("media", "podcast");
  url.searchParams.set("term", term);
  url.searchParams.set("limit", "20");
  const data = await fetchJson<{ results: ItunesPodcast[] }>(url.toString());
  return (data.results ?? []).map(mapItunesPodcast);
};

export const lookupItunesPodcast = async (itunesId: string) => {
  const url = new URL("https://itunes.apple.com/lookup");
  url.searchParams.set("id", itunesId);
  const data = await fetchJson<{ results: ItunesPodcast[] }>(url.toString());
  const match = data.results?.[0];
  return match ? mapItunesPodcast(match) : null;
};

export const mapItunesPodcast = (item: ItunesPodcast) => ({
  id: podcastIdFromItunes(String(item.trackId)),
  itunesId: String(item.trackId),
  title: item.trackName,
  author: item.artistName ?? "",
  feedUrl: item.feedUrl ?? "",
  artworkUrl: item.artworkUrl100 ?? item.artworkUrl600 ?? null,
  artworkUrl600: item.artworkUrl600 ?? item.artworkUrl100 ?? null,
  categories: item.genres ?? [],
  websiteUrl: item.trackViewUrl ?? null,
  isExplicit: item.collectionExplicitness === "explicit"
});
