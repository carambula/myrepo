/**
 * Canonical screen title metrics for native + RN — derived from typography + spacing.
 * WatchedIt (mov min) is the reference. Regenerate Swift/Kotlin/XML via `npm run build:native`.
 */

import { typography } from './typography.js';
import { spacing } from './spacing.js';

function round2(n) {
  return Math.round(n * 100) / 100;
}

function parsePx(v) {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  const m = /^([\d.]+)px$/i.exec(String(v).trim());
  return m ? parseFloat(m[1]) : 0;
}

/** e.g. "-0.025em" → offset in px at given font size */
function letterSpacingToPx(letterSpacing, fontSizePx) {
  if (letterSpacing == null || letterSpacing === '0' || letterSpacing === 0) return 0;
  const em = /^(-?[\d.]+)em$/i.exec(String(letterSpacing).trim());
  if (em) return parseFloat(em[1]) * fontSizePx;
  return 0;
}

function textStyleMetrics(style) {
  const fontSize = parsePx(style.fontSize);
  const lineHeight =
    typeof style.lineHeight === 'number' ? fontSize * style.lineHeight : parsePx(style.lineHeight);
  return {
    fontSize,
    fontWeight: style.fontWeight,
    lineHeight: round2(lineHeight),
    letterSpacing: round2(letterSpacingToPx(style.letterSpacing, fontSize)),
  };
}

const main = textStyleMetrics(typography.styles.mainContentTitle);
const h2 = textStyleMetrics(typography.styles.h2);
const h3 = textStyleMetrics(typography.styles.h3);
const h5 = textStyleMetrics(typography.styles.h5);

/** Primary title in the main content column (detail / hero) — same as `typography.styles.mainContentTitle` */
export const MIN_MAIN_CONTENT_TITLE = {
  ...main,
  marginBottom: parsePx(spacing[4]),
};

/**
 * Home screen app name (centered block) — regular width uses h2 scale; compact uses h3 size with h2 weight (700).
 */
export const MIN_HOME_SCREEN_TITLE = {
  fontSizeRegular: h2.fontSize,
  fontSizeCompact: h3.fontSize,
  fontWeight: typography.styles.h2.fontWeight,
  lineHeightRegular: h2.lineHeight,
  lineHeightCompact: h3.lineHeight,
  letterSpacingRegular: h2.letterSpacing,
  letterSpacingCompact: h3.letterSpacing,
  marginBottom: parsePx(spacing[2]),
};

/** Inline / navigation header title — same as AppHeader `typography.styles.h5` */
export const MIN_HEADER_TITLE = {
  ...h5,
};
