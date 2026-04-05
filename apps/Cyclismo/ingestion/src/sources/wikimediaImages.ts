/**
 * Fetches cycling-related race images from Wikimedia Commons.
 * Uses search API to find images by race name; results are cached.
 */

import fs from "node:fs/promises";
import path from "node:path";

const COMMONS_API = "https://commons.wikimedia.org/w/api.php";
const CACHE_PATH = ".cache/wikimedia-images.json";
const REQUEST_DELAY_MS = 300;

type Cache = Record<string, string>;

const loadCache = async (): Promise<Cache> => {
  try {
    const data = await fs.readFile(CACHE_PATH, "utf8");
    const parsed = JSON.parse(data);
    return typeof parsed === "object" && parsed !== null ? parsed : {};
  } catch {
    return {};
  }
};

const saveCache = async (cache: Cache) => {
  await fs.mkdir(path.dirname(CACHE_PATH), { recursive: true });
  await fs.writeFile(CACHE_PATH, JSON.stringify(cache, null, 0), "utf8");
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const searchCommons = async (query: string): Promise<string | null> => {
  const searchUrl = new URL(COMMONS_API);
  searchUrl.searchParams.set("action", "query");
  searchUrl.searchParams.set("list", "search");
  searchUrl.searchParams.set("srsearch", `${query} cycling`);
  searchUrl.searchParams.set("srnamespace", "6");
  searchUrl.searchParams.set("srlimit", "3");
  searchUrl.searchParams.set("format", "json");

  const res = await fetch(searchUrl.toString(), {
    headers: { "User-Agent": "CyclismoBootstrap/1.0 (+https://github.com/)" }
  });
  if (!res.ok) return null;

  const data = (await res.json()) as { query?: { search?: Array<{ title: string }> } };
  const first = data?.query?.search?.[0]?.title;
  if (!first || !first.startsWith("File:")) return null;
  return first;
};

const getImageUrl = async (fileTitle: string, width = 800): Promise<string | null> => {
  const url = new URL(COMMONS_API);
  url.searchParams.set("action", "query");
  url.searchParams.set("titles", fileTitle);
  url.searchParams.set("prop", "imageinfo");
  url.searchParams.set("iiprop", "url");
  url.searchParams.set("iiurlwidth", String(width));
  url.searchParams.set("format", "json");

  const res = await fetch(url.toString(), {
    headers: { "User-Agent": "CyclismoBootstrap/1.0 (+https://github.com/)" }
  });
  if (!res.ok) return null;

  const data = (await res.json()) as {
    query?: { pages?: Record<string, { imageinfo?: Array<{ url: string }> }> };
  };
  const pages = data?.query?.pages;
  if (!pages) return null;
  const page = Object.values(pages)[0];
  const info = page?.imageinfo?.[0];
  return info?.url ?? null;
};

const normalizeRaceNameForSearch = (name: string): string => {
  return name
    .replace(/\s*(20\d{2})\s*$/i, "")
    .replace(/\s*\(.*\)\s*$/, "")
    .trim();
};

/**
 * Fetches a cycling race image URL from Wikimedia Commons.
 * Returns null if no suitable image is found.
 */
export const fetchWikimediaImageForRace = async (
  raceName: string,
  cache: Cache
): Promise<string | null> => {
  const searchKey = normalizeRaceNameForSearch(raceName);
  const cached = cache[searchKey];
  if (cached) return cached;

  const fileTitle = await searchCommons(searchKey);
  await sleep(REQUEST_DELAY_MS);
  if (!fileTitle) return null;

  const imageUrl = await getImageUrl(fileTitle);
  await sleep(REQUEST_DELAY_MS);
  if (imageUrl) cache[searchKey] = imageUrl;
  return imageUrl;
};

/**
 * Enriches races with Wikimedia Commons images where available.
 * Modifies races in place; loads/saves cache.
 */
export const enrichRacesWithWikimediaImages = async (
  races: Array<{ name?: string | null; imageUrl?: string | null }>
): Promise<void> => {
  const cache = await loadCache();
  let changed = false;

  for (const race of races) {
    if (race.imageUrl) continue;
    const name = race.name ?? "";
    if (!name.trim()) continue;

    const url = await fetchWikimediaImageForRace(name, cache);
    if (url) {
      (race as { imageUrl?: string }).imageUrl = url;
      changed = true;
    }
  }

  if (changed) await saveCache(cache);
};
