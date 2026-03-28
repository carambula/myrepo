/**
 * Light theme configuration
 */

import { colors } from '../tokens/colors.js';

export const lightTheme = {
  name: 'light',
  
  colors: {
    // Background colors
    background: {
      primary: colors.white,
      secondary: colors.gray[50],
      tertiary: colors.gray[100],
      elevated: colors.white,
    },
    
    // Surface colors (for cards, modals, etc.)
    surface: {
      primary: colors.white,
      secondary: colors.gray[50],
      tertiary: colors.gray[100],
    },
    
    // Text colors
    text: {
      primary: colors.gray[900],
      secondary: colors.gray[700],
      tertiary: colors.gray[600],
      disabled: colors.gray[400],
      inverse: colors.white,
    },
    
    // Border colors
    border: {
      primary: colors.gray[300],
      secondary: colors.gray[200],
      focus: colors.primary[500],
    },
    
    // Brand colors
    primary: {
      main: colors.primary[600],
      light: colors.primary[400],
      dark: colors.primary[800],
      contrast: colors.white,
    },
    
    secondary: {
      main: colors.secondary[600],
      light: colors.secondary[400],
      dark: colors.secondary[800],
      contrast: colors.white,
    },
    
    accent: {
      main: colors.accent[600],
      light: colors.accent[400],
      dark: colors.accent[800],
      contrast: colors.white,
    },
    
    // Semantic colors
    success: {
      main: colors.success[600],
      light: colors.success[100],
      dark: colors.success[800],
      contrast: colors.white,
    },
    
    error: {
      main: colors.error[600],
      light: colors.error[100],
      dark: colors.error[800],
      contrast: colors.white,
    },
    
    warning: {
      main: colors.warning[600],
      light: colors.warning[100],
      dark: colors.warning[800],
      contrast: colors.gray[900],
    },
    
    info: {
      main: colors.info[600],
      light: colors.info[100],
      dark: colors.info[800],
      contrast: colors.white,
    },
    
    // Interactive states
    hover: {
      primary: colors.gray[100],
      secondary: colors.gray[50],
    },
    
    active: {
      primary: colors.gray[200],
      secondary: colors.gray[100],
    },
    
    focus: {
      ring: colors.primary[500],
      background: colors.primary[50],
    },
  },
  
  // Shadow mode
  shadows: 'normal',
};

export default lightTheme;
