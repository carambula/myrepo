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

### Content column
- **Max width**: 600px (inner column for primary actions and lists on home)
- **Horizontal inset to viewport**: Same as page grid — `spacing.page.marginLeft` / `marginRight` (16px / 12px mobile) on the home shell via `HomeLayout`
- **Token**: `HomeLayout` (preferred) or `ContentContainer` with default padding when not inside `AppLayout` `main`

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

### Inline metadata separators

When a subtitle, caption, or header row combines multiple metadata fragments (for example podcast name and duration, or year and rating):

- Separate segments with **exactly three ASCII spaces** (`"   "`).
- Use the design token `metadataSeparator` from `@min-apps/design-system/tokens` in code so all four min apps stay aligned.
- Do **not** use middle dots (·), bullet dots (•), pipes, slashes, or commas as decorative separators between those fragments.

The same rule applies to detail views and cards where metadata appears on one line (show stats, video counts, race location and date, and so on).

### Hover State
- **Background**: `var(--color-hover-primary)`
- **Shadow**: `0 2px 8px rgba(0, 0, 0, 0.1)`
- **Cursor**: Pointer
- **Transition**: 250ms ease-in-out

## Loading and empty (null) states

These rules apply to **all** min-app screens (lists, detail shells, settings, link previews, initial app load, and any “no data” view). They keep status UI consistent with list content, which is left-aligned in reading order.

### Layout and alignment

- **Always left-align** loading and empty states: `text-align: left` on the container; do not center the block in the viewport (`text-align: center`, `justify-content: center` on a full-width column, or large vertical “hero” empty layouts are not allowed).
- **Spinner and label** sit on one row: `display: flex`, `align-items: center`, `justify-content: flex-start`, `gap: 8px`, with the spinner first so motion stays at the **start** of the line (same edge as list titles).
- **Respect** `prefers-reduced-motion`: spinner animation is disabled in global styles when the user requests reduced motion; the track remains visible.

### Visual weight (keep it simple)

- **No large icons** in loading or empty states: no emoji-as-hero, no illustration tiles, and no oversized glyphs. Optional **small** inline UI (e.g. a text link or `Button` size `sm`) is allowed when it performs an action.
- **Spinner size**: **14px** diameter, **2px** border, using `.min-content-status__spinner` in `global.css` — do not use full-screen spinners or brand marks as loaders.
- **Typography**: secondary body line — **14px** (`0.875rem`), `var(--color-text-secondary)`, normal weight. One short line for loading; one or two lines maximum for empty copy.

### Implementation

- Import global styles so utilities apply: `import '@min-apps/design-system/src/styles/global.css'`.
- **React / JSX** (integration templates, deep linking): use the same class names as the design system:

```jsx
<div className="min-content-status min-content-status--loading" role="status" aria-live="polite">
  <span className="min-content-status__spinner" aria-hidden="true" />
  <span className="min-content-status__label">Loading…</span>
</div>

<div className="min-content-status min-content-status--empty">
  <p className="min-content-status__message">No items found</p>
</div>
```

**Main bootstrap loading** (initial `App` load in **every** min app, **web and native**): **WatchedIt (mov min)** is the reference. PodLink, YourTube, and Cyclismo must match it **exactly** — same structure and **`Loading…`** copy. **Web:** **[Main app loading](./main-app-loading.md)** (`MAIN_APP_LOADING_CLASSNAME` / `MainAppLoading` + `global.css`). **iOS / Android / React Native:** **[Main app loading — native](./main-app-loading-native.md)** (`@min-apps/design-system/react-native`, or generated `native/*`). Do **not** use a full-screen centered spinner shell on any platform.

- **Object-tree components** (same package): `LoadingState({ message: 'Loading…', main: true })` and `EmptyState({ message, main: true })` from `@min-apps/design-system/components`.

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
- **Canonical reference**: **WatchedIt (mov min)** — all four apps use this grid for every screen. Sticky search, filters, inputs, and fixed overlays must align to these insets, not custom padding. Full rules: **[Layout and margins (mov min)](./layout-margins-mov-min.md)**.
- **CSS** (when not using tokens in JS): `--min-page-margin-*` in `global.css`; utility classes `min-page-padding`, `min-page-padding-x`, `min-page-padding-y`.

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
- [ ] **Screen grid** matches mov min — [Layout and margins](./layout-margins-mov-min.md): no double horizontal padding inside `AppLayout` `main`; sticky search/filters/inputs align with primary content; fixed overlays use `spacing.page` / `--min-page-margin-*`

### Loading and empty (null) states
- [ ] Loading and empty blocks are **left-aligned** (no centered column or `text-align: center` for these states)
- [ ] Loading uses **flex-start** row: small spinner (14px) then label
- [ ] **Main / bootstrap** loading matches **WatchedIt (mov min)** — [Main app loading](./main-app-loading.md) (`MAIN_APP_LOADING_CLASSNAME` or equivalent; not a centered full-viewport flex wrapper)
- [ ] No **large** icons, hero emoji, or illustrations in loading/empty states
- [ ] Copy uses secondary text color and ~14px size

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
