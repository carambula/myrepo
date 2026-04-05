import * as cheerio from "cheerio";
import type { RaceInput, TeamInput, AthleteInput } from "../normalize.js";
import { fetchHtml, buildFetchOptions } from "./fetcher.js";

const baseUrl = "https://www.procyclingstats.com";

const normalizeUrl = (href: string) => {
  if (href.startsWith("http")) {
    return href;
  }
  return `${baseUrl}/${href.replace(/^\//, "")}`;
};

const parseYear = (html: string) => {
  const match = html.match(/calendar\s+(\d{4})/i) || html.match(/UCI Cycling calendar\s+(\d{4})/i);
  if (match?.[1]) {
    return Number(match[1]);
  }
  return new Date().getUTCFullYear();
};

const toIsoDate = (year: number, value: string) => {
  const match = value.match(/(\d{1,2})\.(\d{1,2})/);
  if (!match) {
    return null;
  }
  const day = match[1].padStart(2, "0");
  const month = match[2].padStart(2, "0");
  return `${year}-${month}-${day}`;
};

const parseDateRange = (year: number, value: string) => {
  const parts = value.split("-").map((part) => part.trim());
  if (parts.length === 1) {
    const single = toIsoDate(year, parts[0]);
    return single ? { start: single, end: single } : null;
  }
  const start = toIsoDate(year, parts[0]);
  const end = toIsoDate(year, parts[1]);
  if (!start || !end) {
    return null;
  }
  return { start, end };
};

const detectGender = (url: string, name: string, classification: string) => {
  if (url.includes("women=1")) {
    if (/women|femmes|dames|ladies/i.test(name) || /WWT/i.test(classification)) {
      return "Women";
    }
    return null;
  }
  if (/women|femmes|dames|ladies/i.test(name)) {
    return "Women";
  }
  if (/WWT/i.test(classification)) {
    return "Women";
  }
  return null;
};

const parseCalendarHtml = (html: string, sourceUrl: string) => {
  const year = parseYear(html);
  const $ = cheerio.load(html);
  const races: RaceInput[] = [];

  $("table tr").each((_, row) => {
    const cells = $(row).find("td");
    if (cells.length < 3) {
      return;
    }
    const dateRange = $(cells[0]).text().trim();
    const raceCell = $(cells[2]);
    const name = raceCell.text().trim();
    const classification = $(cells[cells.length - 1]).text().trim();

    if (!name || !dateRange) {
      return;
    }

    const parsed = parseDateRange(year, dateRange);
    if (!parsed) {
      return;
    }

    const raceType = parsed.start === parsed.end ? "One-day" : "Stage race";
    const link = raceCell.find("a").attr("href");
    const officialWebsite = link ? normalizeUrl(link) : null;
    const genderDivision = detectGender(sourceUrl, name, classification);
    if (sourceUrl.includes("women=1") && !genderDivision) {
      return;
    }

    races.push({
      name,
      series: "PCS",
      classification: classification || null,
      discipline: "Road",
      raceType,
      startDate: parsed.start,
      endDate: parsed.end,
      locationCountry: null,
      locationCity: null,
      organizer: null,
      officialWebsite,
      genderDivision
    });
  });

  return races;
};

export const fetchPcsCalendar = async (urls: string[]): Promise<RaceInput[]> => {
  const options = buildFetchOptions();
  const races: RaceInput[] = [];
  for (const url of urls) {
    const html = await fetchHtml(url, options);
    races.push(...parseCalendarHtml(html, url));
  }
  return races;
};

const extractTeamLinks = (html: string) => {
  const $ = cheerio.load(html);
  const links = new Set<string>();
  $('a[href*="/team/"]').each((_, link) => {
    const href = $(link).attr("href");
    if (!href) return;
    links.add(normalizeUrl(href));
  });
  return Array.from(links);
};

const parseTeamInfo = ($: cheerio.CheerioAPI, discipline: string): TeamInput => {
  const title = $("h1").first().text().trim() || $("title").text().trim();
  const name = title.split("|")[0]?.replace(/\(\w+\)\s*$/, "").trim() || "Unknown";
  let uciCode: string | null = null;
  let region: string | null = null;
  let website: string | null = null;
  let logoUrl: string | null = null;

  $("table tr").each((_, row) => {
    const cells = $(row).find("td, th");
    if (cells.length < 2) return;
    const label = $(cells[0]).text().trim().toLowerCase();
    const value = $(cells[1]).text().trim();
    if (!value) return;
    if (label.includes("abbreviation")) uciCode = value;
    if (label.includes("license country")) region = value;
  });

  const websiteLink = $('a[href^="http"]').filter((_, link) => {
    const href = $(link).attr("href") ?? "";
    return href.includes("team") && !href.includes("procyclingstats");
  });
  if (websiteLink.length) {
    website = websiteLink.first().attr("href") ?? null;
  }

  const jersey = $('img[src*="shirts"]').first().attr("src");
  if (jersey) {
    logoUrl = normalizeUrl(jersey);
  }

  return {
    name,
    uciCode,
    discipline,
    region,
    website,
    socialHandles: null,
    logoUrl
  };
};

const parseRiders = ($: cheerio.CheerioAPI, teamName: string, discipline: string): AthleteInput[] => {
  const riders = new Map<string, AthleteInput>();
  $('a[href*="/rider/"]').each((_, link) => {
    const name = $(link).text().trim();
    if (!name || name.length < 3) return;
    if (!/^[A-ZÀ-ÿ' .-]+$/i.test(name)) return;
    if (!riders.has(name)) {
      riders.set(name, {
        fullName: name,
        teamName,
        nationality: null,
        discipline,
        dob: null,
        socialHandles: null
      });
    }
  });
  return Array.from(riders.values());
};

export const fetchPcsRosters = async (
  listUrls: string[]
): Promise<{ teams: TeamInput[]; athletes: AthleteInput[] }> => {
  const options = buildFetchOptions();
  const teamLinks = new Set<string>();
  for (const listUrl of listUrls) {
    const html = await fetchHtml(listUrl, options);
    extractTeamLinks(html).forEach((link) => teamLinks.add(link));
  }

  const teams: TeamInput[] = [];
  const athletes: AthleteInput[] = [];
  for (const teamUrl of teamLinks) {
    const html = await fetchHtml(teamUrl, options);
    const $ = cheerio.load(html);
    const team = parseTeamInfo($, "Road");
    teams.push(team);
    parseRiders($, team.name, "Road").forEach((rider) => athletes.push(rider));
  }

  return { teams, athletes };
};
