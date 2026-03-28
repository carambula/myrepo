# Quick Reference Card

## Installation

```bash
npm install @min-apps/design-system
```

## Setup

```javascript
import '@min-apps/design-system/src/styles/global.css';
import { initTheme } from '@min-apps/design-system';

initTheme();
```

## Critical Spacing Values

### Logo Position (Home Screen)
```javascript
spacing.logo.marginTop        // 32px (desktop)
spacing.logo.marginBottom     // 24px (desktop)
spacing.logo.marginTopMobile  // 24px (mobile)
```

### Page Margins
```javascript
spacing.page.marginTop        // 24px (desktop)
spacing.page.marginLeft       // 16px (desktop)
spacing.page.marginTopMobile  // 16px (mobile)
```

### Button Spacing
```javascript
spacing.button.paddingY       // 12px
spacing.button.paddingX       // 24px
spacing.button.gap            // 8px
```

### List Item Spacing
```javascript
spacing.list.itemPaddingY     // 16px
spacing.list.itemPaddingX     // 16px
spacing.list.itemGap          // 12px
spacing.list.betweenItems     // 8px
```

## Common Imports

```javascript
// Tokens
import { spacing, colors, typography } from '@min-apps/design-system';

// Theming
import { initTheme, applyTheme, useTheme } from '@min-apps/design-system';

// Components
import { 
  Button, 
  ListItem, 
  Card, 
  Input, 
  AppHeader,
  ThemeToggle 
} from '@min-apps/design-system';

// Layouts
import { 
  AppLayout, 
  HomeLayout, 
  ContentContainer,
  List,
  Grid,
  Stack 
} from '@min-apps/design-system';
```

## Component Examples

### Button
```javascript
<Button variant="primary">Primary</Button>
<Button variant="secondary">Secondary</Button>
<Button variant="outline">Outline</Button>
<Button variant="ghost">Ghost</Button>
```

### List Item
```javascript
<ListItem
  image="/thumb.jpg"
  title="Title"
  subtitle="Description"
  onClick={handleClick}
/>
```

### Home Layout
```javascript
<HomeLayout
  logo="/logo.svg"
  title="My App"
  subtitle="A minimal app"
>
  {children}
</HomeLayout>
```

### Card
```javascript
<Card padding="medium" elevation="medium">
  {content}
</Card>
```

### Grid
```javascript
<Grid columns={{ xs: 1, md: 2, lg: 3 }} gap="default">
  {items}
</Grid>
```

## CSS Variables

```css
/* Background */
var(--color-background-primary)
var(--color-background-secondary)

/* Text */
var(--color-text-primary)
var(--color-text-secondary)

/* Borders */
var(--color-border-primary)

/* Brand */
var(--color-primary-main)
var(--color-primary-dark)

/* Interactive */
var(--color-hover-primary)
var(--color-active-primary)
```

## Theme Switching

```javascript
// Manual
applyTheme('dark');
applyTheme('light');

// React Hook
const { theme, toggleTheme, setTheme } = useTheme();

toggleTheme();              // Toggle between light/dark
setTheme('dark');          // Set specific theme
```

## Responsive Breakpoints

```javascript
breakpoints.values.xs   // 320px
breakpoints.values.sm   // 640px
breakpoints.values.md   // 768px
breakpoints.values.lg   // 1024px
```

## Typography

```javascript
// Sizes
typography.sizes.xs       // 12px
typography.sizes.sm       // 14px
typography.sizes.base     // 16px
typography.sizes.lg       // 18px

// Weights
typography.weights.normal    // 400
typography.weights.semibold  // 600
typography.weights.bold      // 700

// Styles
typography.styles.h1
typography.styles.h2
typography.styles.body
typography.styles.button
```

## Common Patterns

### Replace Hard-coded Spacing
```javascript
// Before
marginTop: '30px'

// After
marginTop: spacing.logo.marginTop
```

### Replace Hard-coded Colors
```css
/* Before */
background-color: #FFFFFF;

/* After */
background-color: var(--color-background-primary);
```

### Replace Custom Components
```javascript
// Before
<button className="my-button">Click</button>

// After
<Button variant="primary">Click</Button>
```

## Documentation Links

- **[Getting Started](./docs/getting-started.md)** - Setup guide
- **[Migration Guide](./docs/migration.md)** - Migration steps
- **[Integration Checklist](./docs/integration-checklist.md)** - Step-by-step
- **[Visual Spec](./docs/visual-specification.md)** - Exact measurements
- **[Tokens](./docs/tokens.md)** - Token reference
- **[Components](./docs/components.md)** - Component API
- **[Theming](./docs/theming.md)** - Theme guide
- **[Best Practices](./docs/best-practices.md)** - Guidelines
- **[Architecture](./docs/architecture.md)** - System design

## Troubleshooting

### Colors not changing with theme?
Use CSS variables, not hard-coded colors:
```css
color: var(--color-text-primary);  /* ✓ */
color: #000000;                    /* ✗ */
```

### Spacing inconsistent?
Use semantic spacing tokens:
```javascript
marginTop: spacing.logo.marginTop  /* ✓ */
marginTop: '35px'                  /* ✗ */
```

### Components not found?
Check your import path:
```javascript
import { Button } from '@min-apps/design-system';  /* ✓ */
```

## Need Help?

1. Check the [documentation](./docs/)
2. Look at the [examples](./examples/)
3. Review the [integration checklist](./docs/integration-checklist.md)
4. Open an issue on GitHub

---

## Quick Start Checklist

- [ ] Install: `npm install @min-apps/design-system`
- [ ] Import global styles
- [ ] Initialize theme: `initTheme()`
- [ ] Replace spacing with tokens
- [ ] Replace colors with CSS variables
- [ ] Replace components
- [ ] Test light/dark themes
- [ ] Verify responsive behavior

**Time estimate**: 1-2 weeks per app

---

Print this card and keep it handy during integration!
