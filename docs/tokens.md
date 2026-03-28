# Design Tokens Reference

Complete reference for all design tokens in the min apps design system.

## Colors

### Base Colors
```javascript
import { colors } from '@min-apps/design-system';

colors.white    // #FFFFFF
colors.black    // #000000
```

### Gray Scale
```javascript
colors.gray[50]   // #FAFAFA
colors.gray[100]  // #F5F5F5
colors.gray[200]  // #EEEEEE
colors.gray[300]  // #E0E0E0
colors.gray[400]  // #BDBDBD
colors.gray[500]  // #9E9E9E
colors.gray[600]  // #757575
colors.gray[700]  // #616161
colors.gray[800]  // #424242
colors.gray[900]  // #212121
```

### Primary Colors
```javascript
colors.primary[500]  // Main primary color
colors.primary[600]  // Darker variant (used in light theme)
colors.primary[400]  // Lighter variant (used in dark theme)
```

### Semantic Colors
```javascript
colors.success[600]  // Success states
colors.error[600]    // Error states
colors.warning[600]  // Warning states
colors.info[600]     // Info states
```

### Theme-aware Color Variables (CSS)
```css
var(--color-background-primary)   /* Main background */
var(--color-background-secondary) /* Secondary background */
var(--color-surface-primary)      /* Card/surface background */
var(--color-text-primary)         /* Main text color */
var(--color-text-secondary)       /* Secondary text */
var(--color-border-primary)       /* Border color */
var(--color-primary-main)         /* Primary brand color */
var(--color-error-main)           /* Error color */
/* ... and many more */
```

## Spacing

### Standard Spacing Scale
```javascript
import { spacing } from '@min-apps/design-system';

spacing[0]   // 0
spacing[1]   // 4px
spacing[2]   // 8px
spacing[3]   // 12px
spacing[4]   // 16px
spacing[5]   // 20px
spacing[6]   // 24px
spacing[8]   // 32px
spacing[10]  // 40px
spacing[12]  // 48px
spacing[16]  // 64px
spacing[20]  // 80px
spacing[24]  // 96px
```

### Semantic Spacing

#### Page Margins (Critical for consistency!)
```javascript
// Desktop
spacing.page.marginTop        // 24px - Top margin on all pages
spacing.page.marginBottom     // 24px - Bottom margin on all pages
spacing.page.marginLeft       // 16px - Left margin on all pages
spacing.page.marginRight      // 16px - Right margin on all pages

// Mobile
spacing.page.marginTopMobile    // 16px
spacing.page.marginBottomMobile // 16px
spacing.page.marginLeftMobile   // 12px
spacing.page.marginRightMobile  // 12px
```

#### Logo/SVG Asset Positioning
```javascript
// Desktop
spacing.logo.marginTop      // 32px - Top position for home screen logo
spacing.logo.marginBottom   // 24px - Space below logo

// Mobile
spacing.logo.marginTopMobile    // 24px
spacing.logo.marginBottomMobile // 16px
```

#### Button Spacing
```javascript
spacing.button.paddingX     // 24px - Horizontal button padding
spacing.button.paddingY     // 12px - Vertical button padding
spacing.button.gap          // 8px - Gap between button icon and text
spacing.button.marginBottom // 16px - Space below buttons
```

#### List Item Spacing
```javascript
spacing.list.itemPaddingY  // 16px - Vertical padding inside list item
spacing.list.itemPaddingX  // 16px - Horizontal padding inside list item
spacing.list.itemGap       // 12px - Gap between list item elements
spacing.list.betweenItems  // 8px - Space between list items
```

## Typography

### Font Families
```javascript
import { typography } from '@min-apps/design-system';

typography.fonts.primary    // System font stack
typography.fonts.secondary  // Serif font stack
typography.fonts.mono       // Monospace font stack
```

### Font Sizes
```javascript
typography.sizes.xs     // 12px
typography.sizes.sm     // 14px
typography.sizes.base   // 16px (default)
typography.sizes.lg     // 18px
typography.sizes.xl     // 20px
typography.sizes['2xl'] // 24px
typography.sizes['3xl'] // 30px
typography.sizes['4xl'] // 36px
typography.sizes['5xl'] // 48px
typography.sizes['6xl'] // 60px
typography.sizes['7xl'] // 72px
```

### Font Weights
```javascript
typography.weights.light     // 300
typography.weights.normal    // 400
typography.weights.medium    // 500
typography.weights.semibold  // 600
typography.weights.bold      // 700
typography.weights.extrabold // 800
```

### Text Styles (Semantic combinations)
```javascript
// Headings
typography.styles.h1  // { fontSize: 48px, fontWeight: 700, ... }
typography.styles.h2  // { fontSize: 36px, fontWeight: 700, ... }
typography.styles.h3  // { fontSize: 30px, fontWeight: 600, ... }
typography.styles.h4  // { fontSize: 24px, fontWeight: 600, ... }
typography.styles.h5  // { fontSize: 20px, fontWeight: 600, ... }
typography.styles.h6  // { fontSize: 18px, fontWeight: 600, ... }

// Body
typography.styles.body       // { fontSize: 16px, fontWeight: 400, ... }
typography.styles.bodyLarge  // { fontSize: 18px, fontWeight: 400, ... }
typography.styles.bodySmall  // { fontSize: 14px, fontWeight: 400, ... }

// UI
typography.styles.button   // { fontSize: 16px, fontWeight: 600, ... }
typography.styles.caption  // { fontSize: 12px, fontWeight: 400, ... }
typography.styles.label    // { fontSize: 14px, fontWeight: 500, ... }
```

## Shadows

```javascript
import { shadows } from '@min-apps/design-system';

shadows.none        // No shadow
shadows.xs          // Subtle shadow
shadows.sm          // Small shadow
shadows.md          // Medium shadow (default)
shadows.lg          // Large shadow
shadows.xl          // Extra large shadow
shadows['2xl']      // Double extra large shadow

// Semantic shadows
shadows.card        // For cards
shadows.cardHover   // Card hover state
shadows.button      // For buttons
shadows.buttonHover // Button hover state
shadows.modal       // For modals
shadows.dropdown    // For dropdowns
```

## Borders

### Border Radii
```javascript
import { borders } from '@min-apps/design-system';

borders.radii.none    // 0
borders.radii.sm      // 4px
borders.radii.md      // 8px (default for buttons, cards)
borders.radii.lg      // 12px
borders.radii.xl      // 16px
borders.radii['2xl']  // 24px
borders.radii.full    // 9999px (for circles)
```

### Border Widths
```javascript
borders.widths.none   // 0
borders.widths.thin   // 1px
borders.widths.medium // 2px
borders.widths.thick  // 4px
```

## Breakpoints

```javascript
import { breakpoints } from '@min-apps/design-system';

// Pixel values
breakpoints.values.xs    // 320px
breakpoints.values.sm    // 640px
breakpoints.values.md    // 768px
breakpoints.values.lg    // 1024px
breakpoints.values.xl    // 1280px
breakpoints.values['2xl'] // 1536px

// Media queries
breakpoints.up.sm    // '@media (min-width: 640px)'
breakpoints.down.md  // '@media (max-width: 767px)'
```

## Transitions

```javascript
import { transitions } from '@min-apps/design-system';

// Durations
transitions.durations.instant  // 0ms
transitions.durations.fast     // 150ms
transitions.durations.normal   // 250ms
transitions.durations.slow     // 350ms
transitions.durations.slower   // 500ms

// Common transitions
transitions.all        // All properties
transitions.color      // Color only
transitions.background // Background color only
transitions.transform  // Transform only
transitions.opacity    // Opacity only
transitions.shadow     // Box shadow only
```

## Z-Index

```javascript
import { zIndex } from '@min-apps/design-system';

zIndex.base          // 0
zIndex.dropdown      // 1000
zIndex.sticky        // 1100
zIndex.fixed         // 1200
zIndex.modalBackdrop // 1300
zIndex.modal         // 1400
zIndex.popover       // 1500
zIndex.tooltip       // 1600
zIndex.toast         // 1700
```

## Usage Examples

### Using tokens in JavaScript
```javascript
import { spacing, colors, typography } from '@min-apps/design-system';

const styles = {
  padding: spacing[4],
  marginTop: spacing.logo.marginTop,
  color: colors.primary[600],
  fontSize: typography.sizes.lg,
  fontWeight: typography.weights.semibold,
};
```

### Using CSS variables in CSS
```css
.my-component {
  padding: 16px; /* Or use spacing tokens */
  background-color: var(--color-background-primary);
  color: var(--color-text-primary);
  border: 1px solid var(--color-border-primary);
}

.my-component:hover {
  background-color: var(--color-hover-primary);
}
```
