/**
 * Main export file for all design tokens
 */

export { colors } from './colors.js';
export { spacing } from './spacing.js';
export { typography } from './typography.js';
export { shadows } from './shadows.js';
export { borders } from './borders.js';
export { breakpoints } from './breakpoints.js';
export { transitions } from './transitions.js';
export { zIndex } from './zIndex.js';

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
};

export default tokens;
