# Integration Checklist

Use this checklist when integrating the design system into each min app.

## Pre-Integration

- [ ] Review the [Getting Started Guide](./getting-started.md)
- [ ] Review the [Migration Guide](./migration.md)
- [ ] Review the [Design Tokens Reference](./tokens.md)
- [ ] Back up your current app (create a git branch)

## Installation

- [ ] Install the design system package
  ```bash
  npm install @min-apps/design-system
  ```

## Phase 1: Setup

- [ ] Import global styles in your main file
  ```javascript
  import '@min-apps/design-system/src/styles/global.css';
  ```

- [ ] Initialize theming
  ```javascript
  import { initTheme } from '@min-apps/design-system';
  initTheme();
  ```

- [ ] Verify theme switching works
  ```javascript
  import { applyTheme } from '@min-apps/design-system';
  applyTheme('dark'); // Test dark theme
  applyTheme('light'); // Test light theme
  ```

## Phase 2: Replace Hard-coded Spacing

### Page Margins
- [ ] Replace custom page margins with `spacing.page.*`
  - [ ] Top margins: `spacing.page.marginTop` (24px desktop, 16px mobile)
  - [ ] Left margins: `spacing.page.marginLeft` (16px desktop, 12px mobile)
  - [ ] Right margins: `spacing.page.marginRight`
  - [ ] Bottom margins: `spacing.page.marginBottom`

### Logo Positioning (Critical!)
- [ ] Update home screen logo positioning with `spacing.logo.*`
  - [ ] Logo top margin: `spacing.logo.marginTop` (32px desktop, 24px mobile)
  - [ ] Logo bottom margin: `spacing.logo.marginBottom` (24px desktop, 16px mobile)
  - [ ] Verify logo is centered horizontally
  - [ ] Verify logo size is consistent (120px desktop, 80px mobile)

### Button Spacing
- [ ] Update button padding with `spacing.button.*`
  - [ ] Horizontal padding: `spacing.button.paddingX` (24px)
  - [ ] Vertical padding: `spacing.button.paddingY` (12px)
  - [ ] Icon-text gap: `spacing.button.gap` (8px)
  - [ ] Bottom margin: `spacing.button.marginBottom` (16px)

### List Item Spacing
- [ ] Update list item spacing with `spacing.list.*`
  - [ ] Vertical padding: `spacing.list.itemPaddingY` (16px)
  - [ ] Horizontal padding: `spacing.list.itemPaddingX` (16px)
  - [ ] Image-text gap: `spacing.list.itemGap` (12px)
  - [ ] Space between items: `spacing.list.betweenItems` (8px)

## Phase 3: Replace Colors

- [ ] Replace all hard-coded colors with CSS variables
  - [ ] Background colors: `var(--color-background-primary)`
  - [ ] Text colors: `var(--color-text-primary)`
  - [ ] Border colors: `var(--color-border-primary)`
  - [ ] Primary colors: `var(--color-primary-main)`

- [ ] Test all screens in both light and dark themes
  - [ ] Verify color contrast is sufficient
  - [ ] Check hover states
  - [ ] Check active/pressed states
  - [ ] Check disabled states

## Phase 4: Replace Components

### Buttons
- [ ] Replace custom buttons with `<Button>` component
  - [ ] Primary buttons: `variant="primary"`
  - [ ] Secondary buttons: `variant="secondary"`
  - [ ] Outline buttons: `variant="outline"`
  - [ ] Text/ghost buttons: `variant="ghost"`

### List Items
- [ ] Replace custom list items with `<ListItem>` component
  - [ ] Add `title` prop
  - [ ] Add `subtitle` prop
  - [ ] Add `image` prop (if applicable)
  - [ ] Add `onClick` handler
  - [ ] Add `action` prop for buttons/icons

### Headers
- [ ] Replace custom headers with `<AppHeader>` component
  - [ ] Add `logo` prop
  - [ ] Add `title` prop
  - [ ] Add `actions` prop (e.g., ThemeToggle)

### Cards
- [ ] Replace custom card/container components with `<Card>`
  - [ ] Set appropriate `padding` prop
  - [ ] Set appropriate `elevation` prop
  - [ ] Add `hoverable` if needed

### Inputs
- [ ] Replace custom inputs with `<Input>` component
  - [ ] Add `label` prop
  - [ ] Add `helperText` for errors
  - [ ] Add `error` boolean prop
  - [ ] Add `fullWidth` if needed

## Phase 5: Update Layouts

### Home Screen
- [ ] Replace custom home layout with `<HomeLayout>`
  - [ ] Move logo to `logo` prop
  - [ ] Move title to `title` prop
  - [ ] Move subtitle to `subtitle` prop
  - [ ] Verify logo positioning matches design system

### App Layout
- [ ] Replace custom app layout with `<AppLayout>`
  - [ ] Move header to `header` prop
  - [ ] Move footer to `footer` prop
  - [ ] Move main content to children

### Lists
- [ ] Wrap list items in `<List>` component
  - [ ] Set spacing: `compact`, `default`, or `comfortable`

### Grids
- [ ] Replace custom grids with `<Grid>` component
  - [ ] Set responsive columns
  - [ ] Set gap spacing

## Phase 6: Typography

- [ ] Replace custom font sizes with typography tokens
  - [ ] Headings: `typography.styles.h1` through `typography.styles.h6`
  - [ ] Body text: `typography.styles.body`
  - [ ] Buttons: `typography.styles.button`
  - [ ] Captions: `typography.styles.caption`

- [ ] Update font weights
  - [ ] Use `typography.weights.*`

## Phase 7: Testing

### Visual Testing
- [ ] Test on desktop (1920x1080, 1440x900, 1280x800)
- [ ] Test on tablet (768x1024)
- [ ] Test on mobile (375x667, 414x896)
- [ ] Compare spacing with other min apps
- [ ] Verify logo position matches other apps
- [ ] Verify button positions match other apps
- [ ] Verify list item spacing matches other apps

### Theme Testing
- [ ] Test entire app in light theme
- [ ] Test entire app in dark theme
- [ ] Test theme toggle functionality
- [ ] Verify theme persists on page reload
- [ ] Test all interactive states (hover, active, focus, disabled)

### Accessibility Testing
- [ ] Test keyboard navigation
  - [ ] Tab through all interactive elements
  - [ ] Verify focus indicators are visible
  - [ ] Test Enter/Space on buttons
- [ ] Test with screen reader
  - [ ] Verify all images have alt text
  - [ ] Verify buttons have labels
  - [ ] Verify form inputs have labels
- [ ] Verify color contrast
  - [ ] Check with browser dev tools
  - [ ] Use contrast checker tool

### Cross-browser Testing
- [ ] Chrome/Edge
- [ ] Firefox
- [ ] Safari
- [ ] Mobile Safari
- [ ] Mobile Chrome

## Phase 8: Cleanup

- [ ] Remove old custom component files
- [ ] Remove old CSS files with hard-coded values
- [ ] Remove unused dependencies
- [ ] Update documentation
- [ ] Update README

## Phase 9: App-Specific Theme (Optional)

If you want a custom theme for your app:

- [ ] Create theme configuration (see `examples/theme-config-example.js`)
- [ ] Register custom theme
  ```javascript
  import { themes } from '@min-apps/design-system';
  import { myAppTheme } from './myAppTheme';
  themes.myapp = myAppTheme;
  ```
- [ ] Apply custom theme
  ```javascript
  applyTheme('myapp');
  ```

## Final Verification

- [ ] All pages use design system spacing
- [ ] All pages use design system colors
- [ ] All pages use design system components
- [ ] Logo positioned identically to other apps
- [ ] Buttons styled identically to other apps
- [ ] List items styled identically to other apps
- [ ] Theme switching works throughout app
- [ ] No console errors
- [ ] No visual regressions
- [ ] Accessibility checks pass

## Post-Integration

- [ ] Create pull request with changes
- [ ] Request code review
- [ ] Document any app-specific customizations
- [ ] Share learnings with team

---

## App-Specific Notes

### WatchedIt (mov min)
- [ ] Replace movie card components with design system
- [ ] Update poster image sizing
- [ ] Standardize movie list spacing
- [ ] Update player controls positioning

### podlink (pod min)
- [ ] Replace podcast episode components
- [ ] Standardize episode card spacing
- [ ] Update player controls styling
- [ ] Normalize episode list items

### yourtube (vid min)
- [ ] Replace video card components
- [ ] Standardize thumbnail sizing
- [ ] Update video metadata spacing
- [ ] Normalize video list items

### Cyclismo guide (cyc min)
- [ ] Replace route/guide components
- [ ] Standardize map container sizing
- [ ] Update route detail spacing
- [ ] Normalize guide list items

---

## Need Help?

If you encounter issues during integration:

1. Check the [Migration Guide](./migration.md)
2. Review [Best Practices](./best-practices.md)
3. Look at the [example app](../examples/basic-app.html)
4. Check the [Component Documentation](./components.md)
5. Verify you're using the latest version of the design system

## Success Criteria

Integration is complete when:
✅ All spacing matches design system tokens  
✅ All colors use CSS variables  
✅ All components use design system components  
✅ Themes work correctly in light and dark modes  
✅ App looks identical to other min apps in terms of spacing and positioning  
✅ No visual regressions  
✅ Accessibility standards met  
