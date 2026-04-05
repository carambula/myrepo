/**
 * React Native entry — for any React Native screens in the apps.
 * The four min apps are **native** (Swift + Kotlin). This file only exists
 * for edge-case RN screens. The actual layout enforcement is in generated
 * Swift / Kotlin components under `native/` — see `native/MinAppLayout.swift`
 * and `native/MinAppLayout.kt`.
 */

export { MainAppLoading } from './components/MainAppLoading.native.js';
export { MainContentTitle } from './components/MainContentTitle.native.js';
export { spacing } from './tokens/spacing.js';
export { usePageMargins } from './hooks/usePageMargins.native.js';
export {
  MIN_MAIN_CONTENT_TITLE,
  MIN_HOME_SCREEN_TITLE,
  MIN_HEADER_TITLE,
} from './tokens/minTitles.js';
export {
  MAIN_LOADING_MESSAGE,
  MAIN_LOADING_SPINNER_SIZE,
  MAIN_LOADING_ROW_GAP,
  MAIN_LOADING_LABEL_FONT_SIZE,
  MAIN_LOADING_PADDING_VERTICAL,
  MAIN_LOADING_LABEL_COLOR_LIGHT,
  MAIN_LOADING_SPINNER_COLOR_LIGHT,
} from './tokens/mainLoading.js';
