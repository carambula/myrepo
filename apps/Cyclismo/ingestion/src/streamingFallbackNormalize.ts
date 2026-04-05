/**
 * Normalizes race titles so PCS/UCI variants match streaming fallback rules:
 * hyphens vs spaces (e.g. Milano-Sanremo), accents (Dauphiné), and year suffixes.
 */
export const normalizeRaceTitleForStreamingFallback = (s: string): string =>
  s
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[''''\u2018\u2019]/g, "'")
    .replace(/[-–—]+/g, " ")
    .replace(/\d{4}/g, "")
    .replace(/\s+/g, " ")
    .trim();
