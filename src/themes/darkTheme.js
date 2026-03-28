/**
 * Dark theme configuration
 */

import { colors } from '../tokens/colors.js';

export const darkTheme = {
  name: 'dark',
  
  colors: {
    // Background colors
    background: {
      primary: colors.gray[900],
      secondary: colors.gray[800],
      tertiary: colors.gray[700],
      elevated: colors.gray[800],
    },
    
    // Surface colors (for cards, modals, etc.)
    surface: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
      tertiary: colors.gray[600],
    },
    
    // Text colors
    text: {
      primary: colors.gray[50],
      secondary: colors.gray[300],
      tertiary: colors.gray[400],
      disabled: colors.gray[600],
      inverse: colors.gray[900],
    },
    
    // Border colors
    border: {
      primary: colors.gray[700],
      secondary: colors.gray[800],
      focus: colors.primary[400],
    },
    
    // Brand colors (adjusted for dark mode)
    primary: {
      main: colors.primary[400],
      light: colors.primary[300],
      dark: colors.primary[600],
      contrast: colors.gray[900],
    },
    
    secondary: {
      main: colors.secondary[400],
      light: colors.secondary[300],
      dark: colors.secondary[600],
      contrast: colors.gray[900],
    },
    
    accent: {
      main: colors.accent[400],
      light: colors.accent[300],
      dark: colors.accent[600],
      contrast: colors.gray[900],
    },
    
    // Semantic colors (adjusted for dark mode)
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
    
    // Interactive states
    hover: {
      primary: colors.gray[800],
      secondary: colors.gray[700],
    },
    
    active: {
      primary: colors.gray[700],
      secondary: colors.gray[600],
    },
    
    focus: {
      ring: colors.primary[400],
      background: colors.primary[900],
    },
  },
  
  // Shadow mode (darker shadows for dark theme)
  shadows: 'dark',
};

export default darkTheme;
