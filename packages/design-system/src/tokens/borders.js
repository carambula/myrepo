/**
 * Border tokens for the min apps design system
 * Defines border widths, radii, and styles
 */

export const borders = {
  // Border widths
  widths: {
    none: '0',
    thin: '1px',
    medium: '2px',
    thick: '4px',
  },
  
  // Border radii
  radii: {
    none: '0',
    sm: '4px',
    md: '8px',
    lg: '12px',
    xl: '16px',
    '2xl': '24px',
    full: '9999px',
    
    // Primary art tile radius (movie posters, race images, video thumbnails, show art)
    // This is the ONLY radius that should be used for primary content artwork
    // across all min apps (WatchedIt, Cyclismo, Yourtube, Podlink)
    // DO NOT use larger radii (md, lg, xl, etc.) for primary art tiles
    artTile: '4px',
  },
  
  // Border styles
  styles: {
    solid: 'solid',
    dashed: 'dashed',
    dotted: 'dotted',
    none: 'none',
  },
};

export default borders;
