/**
 * Main export file for all design tokens
 */

import { colors } from './colors.js';
import { spacing } from './spacing.js';
import { typography } from './typography.js';
import { shadows } from './shadows.js';
import { borders } from './borders.js';
import { breakpoints } from './breakpoints.js';
import { transitions } from './transitions.js';
import { zIndex } from './zIndex.js';
import { effects } from './effects.js';
import { metadataSeparator } from './metadata.js';
import {
  MIN_MAIN_CONTENT_TITLE,
  MIN_HOME_SCREEN_TITLE,
  MIN_HEADER_TITLE,
} from './minTitles.js';
import {
  MAIN_LOADING_MESSAGE,
  MAIN_LOADING_SPINNER_SIZE,
  MAIN_LOADING_ROW_GAP,
  MAIN_LOADING_LABEL_FONT_SIZE,
  MAIN_LOADING_PADDING_VERTICAL,
  MAIN_LOADING_LABEL_COLOR_LIGHT,
  MAIN_LOADING_SPINNER_COLOR_LIGHT,
} from './mainLoading.js';

export {
  colors,
  spacing,
  typography,
  shadows,
  borders,
  breakpoints,
  transitions,
  zIndex,
  effects,
  metadataSeparator,
  MIN_MAIN_CONTENT_TITLE,
  MIN_HOME_SCREEN_TITLE,
  MIN_HEADER_TITLE,
  MAIN_LOADING_MESSAGE,
  MAIN_LOADING_SPINNER_SIZE,
  MAIN_LOADING_ROW_GAP,
  MAIN_LOADING_LABEL_FONT_SIZE,
  MAIN_LOADING_PADDING_VERTICAL,
  MAIN_LOADING_LABEL_COLOR_LIGHT,
  MAIN_LOADING_SPINNER_COLOR_LIGHT,
};

// Aggregate export
export const tokens = {
  colors,
  spacing,
  typography,
  shadows,
  borders,
  breakpoints,
  transitions,
  zIndex,
  effects,
  metadataSeparator,
  minTitles: {
    mainContentTitle: MIN_MAIN_CONTENT_TITLE,
    homeScreenTitle: MIN_HOME_SCREEN_TITLE,
    headerTitle: MIN_HEADER_TITLE,
  },
  mainLoading: {
    message: MAIN_LOADING_MESSAGE,
    spinnerSize: MAIN_LOADING_SPINNER_SIZE,
    rowGap: MAIN_LOADING_ROW_GAP,
    labelFontSize: MAIN_LOADING_LABEL_FONT_SIZE,
    paddingVertical: MAIN_LOADING_PADDING_VERTICAL,
    labelColorLight: MAIN_LOADING_LABEL_COLOR_LIGHT,
    spinnerColorLight: MAIN_LOADING_SPINNER_COLOR_LIGHT,
  },
};

export default tokens;
