/**
 * Spacing tokens for the min apps design system
 * All spacing values are standardized to ensure consistent margins and padding
 */

export const spacing = {
  // Base spacing unit (4px)
  unit: 4,
  
  // Spacing scale
  0: '0',
  1: '4px',    // 0.25rem
  2: '8px',    // 0.5rem
  3: '12px',   // 0.75rem
  4: '16px',   // 1rem
  5: '20px',   // 1.25rem
  6: '24px',   // 1.5rem
  8: '32px',   // 2rem
  10: '40px',  // 2.5rem
  12: '48px',  // 3rem
  16: '64px',  // 4rem
  20: '80px',  // 5rem
  24: '96px',  // 6rem
  
  // Semantic spacing values
  page: {
    // Standard page margins for all apps
    marginTop: '24px',
    marginBottom: '24px',
    marginLeft: '16px',
    marginRight: '16px',
    marginTopMobile: '16px',
    marginBottomMobile: '16px',
    marginLeftMobile: '12px',
    marginRightMobile: '12px',
  },
  
  // SVG logo/asset positioning (top of home screen)
  logo: {
    marginTop: '32px',
    marginBottom: '24px',
    marginTopMobile: '24px',
    marginBottomMobile: '16px',
  },
  
  // Button spacing
  button: {
    paddingX: '24px',
    paddingY: '12px',
    gap: '8px',
    marginBottom: '16px',
  },
  
  // List item spacing
  list: {
    itemPaddingY: '16px',
    itemPaddingX: '16px',
    itemGap: '12px',
    betweenItems: '8px',
  },
  
  // Container spacing
  container: {
    paddingX: '16px',
    paddingY: '16px',
    maxWidth: '1200px',
  },
  
  // Section spacing
  section: {
    marginBottom: '48px',
    marginBottomMobile: '32px',
  },
  
  // Component spacing
  component: {
    gap: '16px',
    gapSmall: '8px',
    gapLarge: '24px',
  },
};

export default spacing;
