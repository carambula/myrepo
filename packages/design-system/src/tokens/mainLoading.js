/**
 * Canonical main bootstrap loading — same values for web (CSS), React Native, and generated native code.
 * WatchedIt (mov min) is the reference. Regenerate native/ via `npm run build:native`.
 */

/** Exact copy string (Unicode ellipsis …, not three periods). */
export const MAIN_LOADING_MESSAGE = 'Loading…';

/** Spinner visual diameter (pt / dp / CSS px). */
export const MAIN_LOADING_SPINNER_SIZE = 14;

/** Space between spinner and label. */
export const MAIN_LOADING_ROW_GAP = 8;

/** Secondary label line (matches caption / 0.875rem). */
export const MAIN_LOADING_LABEL_FONT_SIZE = 14;

/** Vertical padding for the loading row (matches .min-content-status). */
export const MAIN_LOADING_PADDING_VERTICAL = 16;

/** Light-theme defaults for RN when app has no theme bridge yet. */
export const MAIN_LOADING_LABEL_COLOR_LIGHT = '#616161';
export const MAIN_LOADING_SPINNER_COLOR_LIGHT = '#757575';
