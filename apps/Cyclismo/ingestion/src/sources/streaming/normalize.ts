/**
 * Parse region text from FloBikes/Max/Peacock into normalized codes.
 * "USA, US Territories, and Canada" -> ["US", "CA"]
 * "Canada Only" -> ["CA"]
 * "Global" -> ["GLOBAL"]
 */
export const parseRegionCodes = (text: string): string[] => {
  const t = text.toLowerCase();
  if (t.includes("global")) return ["GLOBAL"];
  const codes: string[] = [];
  if (/usa|united states|u\.?s\.?|us territories/i.test(t)) codes.push("US");
  if (/canada|ca\b/i.test(t)) codes.push("CA");
  if (t.includes("uk") || t.includes("united kingdom")) codes.push("GB");
  if (codes.length === 0 && t.trim()) return ["GLOBAL"];
  return codes;
};

/** Convert month name (Mar, March) + day to ISO date string for given year */
export const parseMonthDayToIso = (
  year: number,
  monthStr: string,
  dayStr: string
): string | null => {
  const months: Record<string, number> = {
    jan: 1, january: 1, feb: 2, february: 2, mar: 3, march: 3,
    apr: 4, april: 4, may: 5, jun: 6, june: 6, jul: 7, july: 7,
    aug: 8, august: 8, sep: 9, sept: 9, september: 9, oct: 10, october: 10,
    nov: 11, november: 11, dec: 12, december: 12
  };
  const m = months[monthStr.toLowerCase()];
  if (!m) return null;
  const d = parseInt(dayStr, 10);
  if (isNaN(d) || d < 1 || d > 31) return null;
  return `${year}-${String(m).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
};

/** Parse "March 24-30" or "Apr 5" into start/end dates */
export const parseDateRange = (year: number, range: string): { start: string; end: string } | null => {
  const trimmed = range.trim();
  // "Apr 5" or "April 5"
  const singleMatch = trimmed.match(/^([a-z]+)\s+(\d{1,2})$/i);
  if (singleMatch) {
    const start = parseMonthDayToIso(year, singleMatch[1], singleMatch[2]);
    if (start) return { start, end: start };
    return null;
  }
  // "March 24-30" or "Mar 24-30"
  const rangeMatch = trimmed.match(/^([a-z]+)\s+(\d{1,2})\s*[-–]\s*(\d{1,2})$/i);
  if (rangeMatch) {
    const start = parseMonthDayToIso(year, rangeMatch[1], rangeMatch[2]);
    const end = parseMonthDayToIso(year, rangeMatch[1], rangeMatch[3]);
    if (start && end) return { start, end };
  }
  return null;
};
