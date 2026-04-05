/**
 * Main export file for themes
 */

export { lightTheme } from './lightTheme.js';
export { darkTheme } from './darkTheme.js';
export {
  themes,
  applyTheme,
  getSavedTheme,
  getSystemTheme,
  initTheme,
  useTheme,
  themeToCSSVariables,
} from './themeProvider.js';

export default {
  lightTheme,
  darkTheme,
  themes,
  applyTheme,
  getSavedTheme,
  getSystemTheme,
  initTheme,
  useTheme,
};
