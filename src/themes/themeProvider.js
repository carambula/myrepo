/**
 * Theme provider utilities
 * Handles theme switching and CSS variable generation
 */

import { lightTheme } from './lightTheme.js';
import { darkTheme } from './darkTheme.js';

/**
 * Available themes
 */
export const themes = {
  light: lightTheme,
  dark: darkTheme,
};

/**
 * Converts a theme object to CSS custom properties
 */
export function themeToCSSVariables(theme) {
  const cssVars = {};
  
  function flattenObject(obj, prefix = '') {
    for (const [key, value] of Object.entries(obj)) {
      const varName = prefix ? `${prefix}-${key}` : key;
      
      if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
        flattenObject(value, varName);
      } else {
        cssVars[`--${varName}`] = value;
      }
    }
  }
  
  flattenObject(theme.colors, 'color');
  
  return cssVars;
}

/**
 * Applies theme to the document
 */
export function applyTheme(themeName = 'light') {
  const theme = themes[themeName] || themes.light;
  const cssVars = themeToCSSVariables(theme);
  
  const root = document.documentElement;
  
  // Apply CSS variables
  Object.entries(cssVars).forEach(([property, value]) => {
    root.style.setProperty(property, value);
  });
  
  // Set data attribute for theme-specific styles
  root.setAttribute('data-theme', theme.name);
  
  // Store theme preference
  if (typeof localStorage !== 'undefined') {
    localStorage.setItem('min-apps-theme', theme.name);
  }
  
  return theme;
}

/**
 * Gets the saved theme preference
 */
export function getSavedTheme() {
  if (typeof localStorage !== 'undefined') {
    return localStorage.getItem('min-apps-theme') || 'light';
  }
  return 'light';
}

/**
 * Detects system theme preference
 */
export function getSystemTheme() {
  if (typeof window !== 'undefined' && window.matchMedia) {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
  return 'light';
}

/**
 * Initialize theme on page load
 */
export function initTheme() {
  const savedTheme = getSavedTheme();
  const systemTheme = getSystemTheme();
  const theme = savedTheme || systemTheme;
  
  applyTheme(theme);
  
  // Listen for system theme changes
  if (typeof window !== 'undefined' && window.matchMedia) {
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!getSavedTheme()) {
        applyTheme(e.matches ? 'dark' : 'light');
      }
    });
  }
}

/**
 * React hook for theme management (optional, for React apps)
 */
export function useTheme() {
  const [currentTheme, setCurrentTheme] = React.useState(getSavedTheme());
  
  const toggleTheme = () => {
    const newTheme = currentTheme === 'light' ? 'dark' : 'light';
    applyTheme(newTheme);
    setCurrentTheme(newTheme);
  };
  
  const setTheme = (themeName) => {
    applyTheme(themeName);
    setCurrentTheme(themeName);
  };
  
  React.useEffect(() => {
    initTheme();
  }, []);
  
  return {
    theme: currentTheme,
    toggleTheme,
    setTheme,
  };
}

export default {
  themes,
  applyTheme,
  getSavedTheme,
  getSystemTheme,
  initTheme,
  useTheme,
};
