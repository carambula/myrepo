# Min Apps Design System

A unified design system for the min apps suite: **WatchedIt** (mov min), **podlink** (pod min), **yourtube** (vid min), and **Cyclismo guide** (cyc min).

## Overview

This design system harmonizes the visual and interface language across all min apps, providing:

- **Design Tokens**: Centralized color, spacing, typography, and other design values
- **Theming System**: Interchangeable themes that work across all apps
- **Shared Components**: Common UI components with consistent styling
- **Layout Patterns**: Standardized margins, positioning, and spacing
- **Templates**: Pre-built page layouts and component compositions

## Installation

```bash
npm install @min-apps/design-system
```

## Usage

### Import Design Tokens

```javascript
import { tokens } from '@min-apps/design-system/tokens';
import { lightTheme, darkTheme } from '@min-apps/design-system/themes';
```

### Import Components

```javascript
import { Button, ListItem, AppHeader } from '@min-apps/design-system/components';
```

### Import Layout Components

```javascript
import { AppLayout, ContentContainer } from '@min-apps/design-system/layouts';
```

### Apply Global Styles

```javascript
import '@min-apps/design-system/styles.css';
```

## Design Principles

### Consistency
All apps share the same:
- Margins and padding values
- Top positioning for common elements
- SVG asset sizing and placement
- Button styles and positioning
- List element patterns and spacing

### Theming
Themes can be interchanged between apps. Each theme defines:
- Color palette
- Typography scale
- Spacing system
- Shadow and elevation values
- Border radius values

### Accessibility
All components follow WCAG 2.1 AA standards with:
- Proper color contrast
- Keyboard navigation
- Screen reader support
- Focus indicators

## Structure

```
src/
├── tokens/           # Design tokens (colors, spacing, typography, etc.)
├── themes/           # Theme configurations
├── components/       # Shared UI components
├── layouts/          # Layout components and templates
└── utils/            # Utility functions and helpers
```

## Documentation

See the `/docs` folder for detailed documentation on:
- Design tokens reference
- Component API documentation
- Theming guide
- Migration guide for existing apps
- Best practices

## License

MIT
