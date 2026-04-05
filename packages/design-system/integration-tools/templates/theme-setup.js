/**
 * Theme Setup Template
 * 
 * Use this file to set up theming for your app.
 * Import this in your main app file.
 */

import { initTheme, applyTheme, themes } from '@min-apps/design-system';

/**
 * Initialize the theme system
 * Call this once when your app starts
 */
export function setupTheme() {
  initTheme();
}

/**
 * Optional: Create a custom theme for your app
 * 
 * Example for WatchedIt (purple theme):
 */
export const customTheme = {
  name: 'my-app',
  colors: {
    primary: {
      main: '#8B5CF6',    // Your brand color
      light: '#A78BFA',
      dark: '#7C3AED',
    },
    secondary: {
      main: '#EC4899',
      light: '#F472B6',
      dark: '#DB2777',
    }
  }
};

/**
 * Register and apply custom theme
 */
export function setupCustomTheme() {
  // Register your custom theme
  themes['my-app'] = customTheme;
  
  // Apply it
  applyTheme('my-app');
}

/**
 * Toggle between light and dark themes
 */
export function toggleTheme() {
  const currentTheme = localStorage.getItem('theme') || 'light';
  const newTheme = currentTheme === 'light' ? 'dark' : 'light';
  applyTheme(newTheme);
}

/**
 * Get current theme
 */
export function getCurrentTheme() {
  return localStorage.getItem('theme') || 'light';
}
