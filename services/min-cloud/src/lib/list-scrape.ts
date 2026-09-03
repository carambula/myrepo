export type ScrapedTitle = {
  title: string;
  rank: number;
};

const decode = (value: string) =>
  value
    .replace(/&amp;/g, "&")
    .replace(/&#039;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&quot;/g, '"')
    .trim();

export const scrapeRottenTomatoesGuide = (html: string): ScrapedTitle[] => {
  const matches = html.match(/<a[^>]*href="[^"]*rottentomatoes\.com\/m\/[^"]*"[^>]*>([^<]+)<\/a>/gi) || [];
  const titles: ScrapedTitle[] = [];
  const seen = new Set<string>();
  for (const match of matches) {
    const textMatch = match.match(/>([^<]+)</);
    if (!textMatch) {
      continue;
    }
    const title = decode(textMatch[1]);
    if (!title || title.length > 200) {
      continue;
    }
    const key = title.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    titles.push({ title, rank: titles.length + 1 });
  }
  return titles;
};

export const scrapeImdbList = (html: string): ScrapedTitle[] => {
  const matches = html.match(/<a[^>]*href="\/title\/tt\d+\/"[^>]*>([^<]+)<\/a>/gi) || [];
  const titles: ScrapedTitle[] = [];
  const seen = new Set<string>();
  for (const match of matches) {
    const textMatch = match.match(/>([^<]+)</);
    if (!textMatch) {
      continue;
    }
    const title = decode(textMatch[1]).replace(/\(\d{4}\)\s*$/, "").trim();
    if (!title || title.length > 200) {
      continue;
    }
    const key = title.toLowerCase();
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    titles.push({ title, rank: titles.length + 1 });
  }
  return titles;
};

const scrapeGenericLinks = (html: string): ScrapedTitle[] => {
  const matches = html.match(/<a[^>]*>([^<]{2,120})<\/a>/gi) || [];
  const titles: ScrapedTitle[] = [];
  const seen = new Set<string>();
  const skip = /^(home|sign in|log in|menu|search|watchlist|imdb|rotten tomatoes|privacy|terms|help)$/i;
  for (const match of matches) {
    const text = decode(match.replace(/<[^>]+>/g, ""));
    const key = text.toLowerCase();
    if (!text || seen.has(key) || skip.test(text)) {
      continue;
    }
    seen.add(key);
    titles.push({ title: text, rank: titles.length + 1 });
    if (titles.length >= 80) {
      break;
    }
  }
  return titles;
};

export const scrapeListItems = (url: string, html: string): ScrapedTitle[] => {
  if (url.includes("rottentomatoes.com/guide/")) {
    const titles = scrapeRottenTomatoesGuide(html);
    if (titles.length) {
      return titles;
    }
  }
  if (url.includes("imdb.com/list/") || url.includes("imdb.com/chart/")) {
    const titles = scrapeImdbList(html);
    if (titles.length) {
      return titles;
    }
  }
  return scrapeGenericLinks(html);
};
