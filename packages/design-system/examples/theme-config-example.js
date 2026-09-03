/**
 * Example theme configurations for different min apps
 * These demonstrate how to create app-specific theme variations
 */

import { colors } from '../src/tokens/colors.js';

/**
 * WatchedIt (Movie App) Theme
 * Purple/blue color scheme for movies
 */
export const watchedItTheme = {
  name: 'watchedit',
  
  colors: {
    background: {
      primary: colors.gray[900],
      secondary: colors.gray[800],
      tertiary: colors.gray[700],
      elevated: colors.gray[800],
    },
    
    surface: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
      tertiary: colors.gray[600],
    },
    
    text: {
      primary: colors.gray[50],
      secondary: colors.gray[300],
      tertiary: colors.gray[400],
      disabled: colors.gray[600],
      inverse: colors.gray[900],
    },
    
    border: {
      primary: colors.gray[700],
      secondary: colors.gray[800],
      focus: '#9C27B0',
    },
    
    primary: {
      main: '#9C27B0',  // Purple for movies
      light: '#BA68C8',
      dark: '#7B1FA2',
      contrast: colors.white,
    },
    
    secondary: {
      main: '#2196F3',  // Blue accent
      light: '#64B5F6',
      dark: '#1976D2',
      contrast: colors.white,
    },
    
    accent: {
      main: '#FF9800',
      light: '#FFB74D',
      dark: '#F57C00',
      contrast: colors.white,
    },
    
    success: {
      main: colors.success[400],
      light: colors.success[900],
      dark: colors.success[600],
      contrast: colors.gray[900],
    },
    
    error: {
      main: colors.error[400],
      light: colors.error[900],
      dark: colors.error[600],
      contrast: colors.gray[900],
    },
    
    warning: {
      main: colors.warning[400],
      light: colors.warning[900],
      dark: colors.warning[600],
      contrast: colors.gray[900],
    },
    
    info: {
      main: colors.info[400],
      light: colors.info[900],
      dark: colors.info[600],
      contrast: colors.gray[900],
    },
    
    hover: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
    },
    
    active: {
      primary: colors.gray[700],
      secondary: colors.gray[600],
    },
    
    focus: {
      ring: '#9C27B0',
      background: '#4A148C',
    },
  },
  
  shadows: 'dark',
};

/**
 * podlink (Podcast App) Theme
 * Orange/warm color scheme for podcasts
 */
export const podlinkTheme = {
  name: 'podlink',
  
  colors: {
    background: {
      primary: colors.gray[900],
      secondary: colors.gray[800],
      tertiary: colors.gray[700],
      elevated: colors.gray[800],
    },
    
    surface: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
      tertiary: colors.gray[600],
    },
    
    text: {
      primary: colors.gray[50],
      secondary: colors.gray[300],
      tertiary: colors.gray[400],
      disabled: colors.gray[600],
      inverse: colors.gray[900],
    },
    
    border: {
      primary: colors.gray[700],
      secondary: colors.gray[800],
      focus: '#FF9800',
    },
    
    primary: {
      main: '#FF9800',  // Orange for podcasts
      light: '#FFB74D',
      dark: '#F57C00',
      contrast: colors.gray[900],
    },
    
    secondary: {
      main: '#FF5722',  // Deep orange accent
      light: '#FF7043',
      dark: '#E64A19',
      contrast: colors.white,
    },
    
    accent: {
      main: '#FFC107',
      light: '#FFD54F',
      dark: '#FFA000',
      contrast: colors.gray[900],
    },
    
    success: {
      main: colors.success[400],
      light: colors.success[900],
      dark: colors.success[600],
      contrast: colors.gray[900],
    },
    
    error: {
      main: colors.error[400],
      light: colors.error[900],
      dark: colors.error[600],
      contrast: colors.gray[900],
    },
    
    warning: {
      main: colors.warning[400],
      light: colors.warning[900],
      dark: colors.warning[600],
      contrast: colors.gray[900],
    },
    
    info: {
      main: colors.info[400],
      light: colors.info[900],
      dark: colors.info[600],
      contrast: colors.gray[900],
    },
    
    hover: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
    },
    
    active: {
      primary: colors.gray[700],
      secondary: colors.gray[600],
    },
    
    focus: {
      ring: '#FF9800',
      background: '#E65100',
    },
  },
  
  shadows: 'dark',
};

/**
 * yourtube (Video App) Theme
 * Red color scheme similar to YouTube
 */
export const yourtubeTheme = {
  name: 'yourtube',
  
  colors: {
    background: {
      primary: colors.gray[900],
      secondary: colors.gray[800],
      tertiary: colors.gray[700],
      elevated: colors.gray[800],
    },
    
    surface: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
      tertiary: colors.gray[600],
    },
    
    text: {
      primary: colors.gray[50],
      secondary: colors.gray[300],
      tertiary: colors.gray[400],
      disabled: colors.gray[600],
      inverse: colors.gray[900],
    },
    
    border: {
      primary: colors.gray[700],
      secondary: colors.gray[800],
      focus: '#F44336',
    },
    
    primary: {
      main: '#F44336',  // Red for videos
      light: '#EF5350',
      dark: '#D32F2F',
      contrast: colors.white,
    },
    
    secondary: {
      main: '#E91E63',  // Pink accent
      light: '#EC407A',
      dark: '#C2185B',
      contrast: colors.white,
    },
    
    accent: {
      main: '#FF5722',
      light: '#FF7043',
      dark: '#E64A19',
      contrast: colors.white,
    },
    
    success: {
      main: colors.success[400],
      light: colors.success[900],
      dark: colors.success[600],
      contrast: colors.gray[900],
    },
    
    error: {
      main: colors.error[400],
      light: colors.error[900],
      dark: colors.error[600],
      contrast: colors.gray[900],
    },
    
    warning: {
      main: colors.warning[400],
      light: colors.warning[900],
      dark: colors.warning[600],
      contrast: colors.gray[900],
    },
    
    info: {
      main: colors.info[400],
      light: colors.info[900],
      dark: colors.info[600],
      contrast: colors.gray[900],
    },
    
    hover: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
    },
    
    active: {
      primary: colors.gray[700],
      secondary: colors.gray[600],
    },
    
    focus: {
      ring: '#F44336',
      background: '#B71C1C',
    },
  },
  
  shadows: 'dark',
};

/**
 * Cyclismo Guide (Cycling App) Theme
 * Green/teal color scheme for cycling
 */
export const cyclismoTheme = {
  name: 'cyclismo',
  
  colors: {
    background: {
      primary: colors.gray[900],
      secondary: colors.gray[800],
      tertiary: colors.gray[700],
      elevated: colors.gray[800],
    },
    
    surface: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
      tertiary: colors.gray[600],
    },
    
    text: {
      primary: colors.gray[50],
      secondary: colors.gray[300],
      tertiary: colors.gray[400],
      disabled: colors.gray[600],
      inverse: colors.gray[900],
    },
    
    border: {
      primary: colors.gray[700],
      secondary: colors.gray[800],
      focus: '#4CAF50',
    },
    
    primary: {
      main: '#4CAF50',  // Green for cycling
      light: '#66BB6A',
      dark: '#388E3C',
      contrast: colors.white,
    },
    
    secondary: {
      main: '#009688',  // Teal accent
      light: '#26A69A',
      dark: '#00796B',
      contrast: colors.white,
    },
    
    accent: {
      main: '#8BC34A',
      light: '#9CCC65',
      dark: '#689F38',
      contrast: colors.gray[900],
    },
    
    success: {
      main: colors.success[400],
      light: colors.success[900],
      dark: colors.success[600],
      contrast: colors.gray[900],
    },
    
    error: {
      main: colors.error[400],
      light: colors.error[900],
      dark: colors.error[600],
      contrast: colors.gray[900],
    },
    
    warning: {
      main: colors.warning[400],
      light: colors.warning[900],
      dark: colors.warning[600],
      contrast: colors.gray[900],
    },
    
    info: {
      main: colors.info[400],
      light: colors.info[900],
      dark: colors.info[600],
      contrast: colors.gray[900],
    },
    
    hover: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
    },
    
    active: {
      primary: colors.gray[700],
      secondary: colors.gray[600],
    },
    
    focus: {
      ring: '#4CAF50',
      background: '#1B5E20',
    },
  },
  
  shadows: 'dark',
};

/**
 * Usage example:
 * 
 * import { themes, applyTheme } from '@min-apps/design-system';
 * import { watchedItTheme, podlinkTheme, yourtubeTheme, cyclismoTheme } from './theme-config-example';
 * 
 * // Register custom themes
 * themes.watchedit = watchedItTheme;
 * themes.podlink = podlinkTheme;
 * themes.yourtube = yourtubeTheme;
 * themes.cyclismo = cyclismoTheme;
 * 
 * // Apply app-specific theme
 * applyTheme('watchedit');
 */

export default {
  watchedItTheme,
  podlinkTheme,
  yourtubeTheme,
  cyclismoTheme,
};
