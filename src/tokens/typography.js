/**
 * Typography tokens for the min apps design system
 * Defines font families, sizes, weights, and line heights
 */

export const typography = {
  // Font families
  fonts: {
    primary: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
    secondary: 'Georgia, "Times New Roman", Times, serif',
    mono: 'Menlo, Monaco, Consolas, "Courier New", monospace',
  },
  
  // Font weights
  weights: {
    light: 300,
    normal: 400,
    medium: 500,
    semibold: 600,
    bold: 700,
    extrabold: 800,
  },
  
  // Font sizes
  sizes: {
    xs: '12px',     // 0.75rem
    sm: '14px',     // 0.875rem
    base: '16px',   // 1rem
    lg: '18px',     // 1.125rem
    xl: '20px',     // 1.25rem
    '2xl': '24px',  // 1.5rem
    '3xl': '30px',  // 1.875rem
    '4xl': '36px',  // 2.25rem
    '5xl': '48px',  // 3rem
    '6xl': '60px',  // 3.75rem
    '7xl': '72px',  // 4.5rem
  },
  
  // Line heights
  lineHeights: {
    none: 1,
    tight: 1.25,
    snug: 1.375,
    normal: 1.5,
    relaxed: 1.625,
    loose: 2,
  },
  
  // Letter spacing
  letterSpacing: {
    tighter: '-0.05em',
    tight: '-0.025em',
    normal: '0',
    wide: '0.025em',
    wider: '0.05em',
    widest: '0.1em',
  },
  
  // Text styles (semantic combinations)
  styles: {
    // Headings
    h1: {
      fontSize: '48px',
      fontWeight: 700,
      lineHeight: 1.2,
      letterSpacing: '-0.025em',
    },
    h2: {
      fontSize: '36px',
      fontWeight: 700,
      lineHeight: 1.25,
      letterSpacing: '-0.025em',
    },
    h3: {
      fontSize: '30px',
      fontWeight: 600,
      lineHeight: 1.3,
      letterSpacing: '-0.025em',
    },
    h4: {
      fontSize: '24px',
      fontWeight: 600,
      lineHeight: 1.35,
    },
    h5: {
      fontSize: '20px',
      fontWeight: 600,
      lineHeight: 1.4,
    },
    h6: {
      fontSize: '18px',
      fontWeight: 600,
      lineHeight: 1.4,
    },
    
    // Body text
    body: {
      fontSize: '16px',
      fontWeight: 400,
      lineHeight: 1.5,
    },
    bodyLarge: {
      fontSize: '18px',
      fontWeight: 400,
      lineHeight: 1.5,
    },
    bodySmall: {
      fontSize: '14px',
      fontWeight: 400,
      lineHeight: 1.5,
    },
    
    // UI text
    button: {
      fontSize: '16px',
      fontWeight: 600,
      lineHeight: 1,
      letterSpacing: '0.025em',
    },
    caption: {
      fontSize: '12px',
      fontWeight: 400,
      lineHeight: 1.4,
    },
    label: {
      fontSize: '14px',
      fontWeight: 500,
      lineHeight: 1.4,
    },
    overline: {
      fontSize: '12px',
      fontWeight: 600,
      lineHeight: 1,
      letterSpacing: '0.1em',
      textTransform: 'uppercase',
    },
  },
};

export default typography;
