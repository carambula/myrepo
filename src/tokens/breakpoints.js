/**
 * Breakpoint tokens for the min apps design system
 * Defines responsive breakpoints for different screen sizes
 */

export const breakpoints = {
  // Pixel values
  values: {
    xs: 320,
    sm: 640,
    md: 768,
    lg: 1024,
    xl: 1280,
    '2xl': 1536,
  },
  
  // Media query strings
  up: {
    xs: '@media (min-width: 320px)',
    sm: '@media (min-width: 640px)',
    md: '@media (min-width: 768px)',
    lg: '@media (min-width: 1024px)',
    xl: '@media (min-width: 1280px)',
    '2xl': '@media (min-width: 1536px)',
  },
  
  down: {
    xs: '@media (max-width: 319px)',
    sm: '@media (max-width: 639px)',
    md: '@media (max-width: 767px)',
    lg: '@media (max-width: 1023px)',
    xl: '@media (max-width: 1279px)',
    '2xl': '@media (max-width: 1535px)',
  },
  
  between: (min, max) => `@media (min-width: ${min}px) and (max-width: ${max}px)`,
};

export default breakpoints;
