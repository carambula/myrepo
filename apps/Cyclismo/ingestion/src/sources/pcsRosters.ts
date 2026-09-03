import * as cheerio from "cheerio";
import type { AthleteInput, TeamInput } from "../normalize.js";

const baseUrl = "https://www.procyclingstats.com";

const normalizeUrl = (href: string) => {
  if (href.startsWith("http")) {
    return href;
  }
  return `${baseUrl}/${href.replace(/^\//, "")}`;
};

const fetchHtml = async (url: string) => {
  const response = await fetch(url, {
    headers: {
      accept: "text/html",
      "user-agent": "CyclismoBootstrap/1.0 (+https://github.com/)",
      "accept-language": "en-US,en;q=0.9"
    }
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch ${url}`);
  }
  return response.text();
};

const guessDiscipline = (url: string) => {
  if (url.includes("/teams/women")) {
    return "Road";
  }
  if (url.includes("/teams/continental") || url.includes("/teams/worldtour")) {
    return "Road";
  }
  return "Road";
};

const parseTeamName = ($: cheerio.CheerioAPI) => {
  const h1 = $("h1").first().text().trim();
  if (h1) {
    return h1.replace(/\(\w+\)\s*$/, "").trim();
  }
  const title = $("title").text().trim();
  if (title) {
    return title.split("|")[0]?.replace(/\(\w+\)\s*$/, "").trim() ?? "Unknown";
  }
  return "Unknown";
};

const parseTeamInfo = ($: cheerio.CheerioAPI, discipline: string): TeamInput => {
  const name = parseTeamName($);
  const infoRows = $("table").find("tr");
  let uciCode: string | null = null;
  let region: string | null = null;
  let website: string | null = null;
  let logoUrl: string | null = null;

  infoRows.each((_, row) => {
    const cells = $(row).find("td, th");
    if (cells.length < 2) {
      return;
    }
    const label = $(cells[0]).text().trim().toLowerCase();
    const value = $(cells[1]).text().trim();
    if (!value) {
      return;
    }
    if (label.includes("abbreviation")) {
      uciCode = value;
    }
    if (label.includes("license country")) {
      region = value;
    }
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
    if (!name || name.length < 3) {
      return;
    }
    if (!/^[A-ZÀ-ÿ' .-]+$/i.test(name)) {
      return;
    }
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

const extractTeamLinks = ($: cheerio.CheerioAPI) => {
  const links = new Set<string>();
  $('a[href*="/team/"]').each((_, link) => {
    const href = $(link).attr("href");
    if (!href) {
      return;
    }
    if (!href.includes("/team/")) {
      return;
    }
    links.add(normalizeUrl(href));
  });
  return Array.from(links);
};

const parseListUrls = (raw: string | undefined) => {
  if (!raw) {
    return [];
  }
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
};

export const fetchPcsTeamRosters = async (
  listUrls: string | undefined
): Promise<{ teams: TeamInput[]; athletes: AthleteInput[] }> => {
  const urls = parseListUrls(listUrls);
  if (!urls.length) {
    return { teams: [], athletes: [] };
  }

  const teamLinks = new Set<string>();
  for (const listUrl of urls) {
    const html = await fetchHtml(listUrl);
    const $ = cheerio.load(html);
    extractTeamLinks($).forEach((link) => teamLinks.add(link));
  }

  const teams: TeamInput[] = [];
  const athletes: AthleteInput[] = [];

  for (const teamUrl of teamLinks) {
    const html = await fetchHtml(teamUrl);
    const $ = cheerio.load(html);
    const discipline = guessDiscipline(teamUrl);
    const team = parseTeamInfo($, discipline);
    teams.push(team);
    parseRiders($, team.name, discipline).forEach((rider) => athletes.push(rider));
  }

  return { teams, athletes };
};
