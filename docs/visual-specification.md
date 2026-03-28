# Visual Specification

This document defines the exact visual specifications that all min apps must follow.

## Home Screen Layout

### Logo/SVG Asset
- **Position**: Centered horizontally
- **Top margin**: 32px (desktop), 24px (mobile)
- **Bottom margin**: 24px (desktop), 16px (mobile)
- **Size**: 120px × 120px (desktop), 80px × 80px (mobile)
- **Token**: `spacing.logo.*`

### Title
- **Font size**: 36px (desktop), 30px (mobile)
- **Font weight**: 700
- **Color**: `var(--color-text-primary)`
- **Bottom margin**: 8px
- **Token**: `typography.styles.h2`

### Subtitle
- **Font size**: 18px
- **Font weight**: 400
- **Color**: `var(--color-text-secondary)`
- **Bottom margin**: 24px
- **Token**: `typography.styles.bodyLarge`

### Content Container
- **Max width**: 600px
- **Horizontal padding**: 16px (desktop), 12px (mobile)
- **Token**: Use `ContentContainer` component

## Button Specifications

### Primary Button
- **Padding**: 12px (vertical) × 24px (horizontal)
- **Font size**: 16px
- **Font weight**: 600
- **Border radius**: 8px
- **Background**: `var(--color-primary-main)`
- **Text color**: `var(--color-primary-contrast)`
- **Shadow**: `0 2px 4px rgba(0, 0, 0, 0.1)`
- **Bottom margin**: 16px
- **Tokens**: `spacing.button.*`, `typography.styles.button`

### Button Hover State
- **Background**: `var(--color-primary-dark)`
- **Shadow**: `0 4px 8px rgba(0, 0, 0, 0.15)`
- **Transform**: `translateY(-1px)`
- **Transition**: 250ms ease-in-out

### Button Active State
- **Transform**: `translateY(0)`
- **Shadow**: `0 2px 4px rgba(0, 0, 0, 0.1)`

## List Item Specifications

### Container
- **Display**: Flex row
- **Align items**: Center
- **Padding**: 16px (vertical and horizontal)
- **Gap**: 12px (between image and content)
- **Background**: `var(--color-surface-primary)`
- **Border radius**: 8px
- **Bottom margin**: 8px (between items)
- **Tokens**: `spacing.list.*`

### Image
- **Size**: 48px × 48px
- **Border radius**: 8px
- **Object fit**: Cover
- **Flex shrink**: 0

### Title
- **Font size**: 16px
- **Font weight**: 600
- **Color**: `var(--color-text-primary)`
- **Bottom margin**: 4px
- **Text overflow**: Ellipsis
- **Token**: `typography.styles.body`

### Subtitle
- **Font size**: 14px
- **Font weight**: 400
- **Color**: `var(--color-text-secondary)`
- **Text overflow**: Ellipsis
- **Token**: `typography.styles.bodySmall`

### Hover State
- **Background**: `var(--color-hover-primary)`
- **Shadow**: `0 2px 8px rgba(0, 0, 0, 0.1)`
- **Cursor**: Pointer
- **Transition**: 250ms ease-in-out

## Page Layout Specifications

### Page Margins
- **Desktop**:
  - Top: 24px
  - Right: 16px
  - Bottom: 24px
  - Left: 16px
- **Mobile** (< 768px):
  - Top: 16px
  - Right: 12px
  - Bottom: 16px
  - Left: 12px
- **Token**: `spacing.page.*`

### Content Width
- **Default max width**: 1200px
- **Small max width**: 640px
- **Large max width**: 1400px
- **Centered**: Horizontally with auto margins
- **Token**: Use `ContentContainer` component

## Card Specifications

### Default Card
- **Padding**: 16px
- **Background**: `var(--color-surface-primary)`
- **Border radius**: 12px
- **Shadow**: `0 2px 8px rgba(0, 0, 0, 0.1)`
- **Token**: `borders.radii.lg`, `shadows.card`

### Card Hover (if hoverable)
- **Shadow**: `0 8px 16px rgba(0, 0, 0, 0.15)`
- **Transform**: `translateY(-2px)`
- **Transition**: 250ms ease-in-out

## Typography Scale

### Headings
```
H1: 48px, weight 700, line-height 1.2
H2: 36px, weight 700, line-height 1.25
H3: 30px, weight 600, line-height 1.3
H4: 24px, weight 600, line-height 1.35
H5: 20px, weight 600, line-height 1.4
H6: 18px, weight 600, line-height 1.4
```

### Body Text
```
Large: 18px, weight 400, line-height 1.5
Default: 16px, weight 400, line-height 1.5
Small: 14px, weight 400, line-height 1.5
```

### UI Text
```
Button: 16px, weight 600, line-height 1, letter-spacing 0.025em
Label: 14px, weight 500, line-height 1.4
Caption: 12px, weight 400, line-height 1.4
```

### Font Family
```
Primary: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif
```

## Color Specifications

### Light Theme
```css
Background Primary: #FFFFFF
Background Secondary: #FAFAFA
Text Primary: #212121
Text Secondary: #616161
Text Tertiary: #757575
Border Primary: #E0E0E0
Primary Main: #1E88E5
Primary Dark: #1976D2
Primary Contrast: #FFFFFF
Hover Primary: #F5F5F5
Active Primary: #EEEEEE
```

### Dark Theme
```css
Background Primary: #212121
Background Secondary: #424242
Text Primary: #FAFAFA
Text Secondary: #E0E0E0
Text Tertiary: #BDBDBD
Border Primary: #616161
Primary Main: #42A5F5
Primary Dark: #64B5F6
Primary Contrast: #212121
Hover Primary: #424242
Active Primary: #616161
```

## Spacing Scale

```
0:  0px
1:  4px
2:  8px
3:  12px
4:  16px
5:  20px
6:  24px
8:  32px
10: 40px
12: 48px
16: 64px
20: 80px
24: 96px
```

## Shadow Scale

```
XS: 0 1px 2px 0 rgba(0, 0, 0, 0.05)
SM: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06)
MD: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)
LG: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)
XL: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)

Card: 0 2px 8px rgba(0, 0, 0, 0.1)
Card Hover: 0 8px 16px rgba(0, 0, 0, 0.15)
Button: 0 2px 4px rgba(0, 0, 0, 0.1)
Button Hover: 0 4px 8px rgba(0, 0, 0, 0.15)
```

## Border Radii

```
SM: 4px
MD: 8px (default for buttons, inputs)
LG: 12px (default for cards)
XL: 16px
2XL: 24px
Full: 9999px (circles)
```

## Breakpoints

```
XS: 320px   (small phones)
SM: 640px   (large phones)
MD: 768px   (tablets)
LG: 1024px  (desktops)
XL: 1280px  (large desktops)
2XL: 1536px (extra large)
```

## Transitions

### Durations
```
Fast: 150ms
Normal: 250ms (default)
Slow: 350ms
Slower: 500ms
```

### Easing
```
Default: cubic-bezier(0.4, 0, 0.2, 1)
Ease In: cubic-bezier(0.4, 0, 1, 1)
Ease Out: cubic-bezier(0, 0, 0.2, 1)
```

## Z-Index Layers

```
Base: 0
Dropdown: 1000
Sticky: 1100
Fixed: 1200
Modal Backdrop: 1300
Modal: 1400
Popover: 1500
Tooltip: 1600
Toast: 1700
```

## Measurement Checklist

Use this to verify exact measurements across all apps:

### Home Screen
- [ ] Logo top margin: 32px (desktop), 24px (mobile)
- [ ] Logo size: 120px × 120px (desktop), 80px × 80px (mobile)
- [ ] Logo bottom margin: 24px (desktop), 16px (mobile)
- [ ] Title font size: 36px (desktop), 30px (mobile)
- [ ] Content max width: 600px

### Buttons
- [ ] Padding: 12px × 24px
- [ ] Font size: 16px
- [ ] Font weight: 600
- [ ] Border radius: 8px
- [ ] Bottom margin: 16px

### List Items
- [ ] Container padding: 16px
- [ ] Image-text gap: 12px
- [ ] Image size: 48px × 48px
- [ ] Between items gap: 8px
- [ ] Title font size: 16px
- [ ] Subtitle font size: 14px

### Page Layout
- [ ] Page margin top: 24px (desktop), 16px (mobile)
- [ ] Page margin left/right: 16px (desktop), 12px (mobile)

## Visual Comparison

When integrating, compare your app with the example app:
1. Open `examples/basic-app.html` in a browser
2. Open your app side-by-side
3. Measure and compare:
   - Logo position from top
   - Button heights and spacing
   - List item heights and gaps
   - Page margins
   - Typography sizes

Use browser dev tools to measure exact pixel values.

---

## Design Tools

### For Designers
If creating mockups in Figma, Sketch, or Adobe XD:
- Import the spacing scale as library
- Set up color variables matching the theme
- Use the typography scale
- Create components matching the specification

### For Developers
Use the design system tokens directly:
```javascript
import { spacing, typography, colors } from '@min-apps/design-system';
```

Never hard-code values. Always use tokens.
