/**
 * Effect tokens for the min apps design system.
 * Sheet backdrops are dim-only (no blur) — blur was expensive and rarely
 * read as frost on sheet chrome.
 */

export const effects = {
  backdropBlur: {
    none: '0',
    sm: '2px',
    md: '8px',
    lg: '16px',
    xl: '24px',
  },

  backdropOpacity: {
    light: 0.28,
    medium: 0.45,
    heavy: 0.62,
    dark: 0.7,
  },

  backdropDarkness: {
    small: 'rgba(0, 0, 0, 0.28)',
    medium: 'rgba(0, 0, 0, 0.45)',
    large: 'rgba(0, 0, 0, 0.62)',
    full: 'rgba(0, 0, 0, 0.7)',
  },
};

export default effects;
