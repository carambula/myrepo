# Theming Guide

Complete guide to theming in the min apps design system.

## Overview

The design system uses a theme-based color system with CSS custom properties (CSS variables). All apps can share the same themes, making them interchangeable.

## Available Themes

### Light Theme
The default theme with light backgrounds and dark text.

### Dark Theme
Dark backgrounds with light text for reduced eye strain in low-light environments.

## Using Themes

### Automatic Theme Initialization

The simplest way to enable theming is to initialize it on app load:

```javascript
import { initTheme } from '@min-apps/design-system';

// In your main app file
initTheme();
```

This will:
1. Check for saved theme preference
2. Fall back to system preference
3. Apply the appropriate theme
4. Listen for system theme changes

### Manual Theme Control

#### Apply a specific theme

```javascript
import { applyTheme } from '@min-apps/design-system';

// Switch to dark theme
applyTheme('dark');

// Switch to light theme
applyTheme('light');
```

#### Get saved theme preference

```javascript
import { getSavedTheme } from '@min-apps/design-system';

const savedTheme = getSavedTheme();
console.log(savedTheme); // 'light' or 'dark'
```

#### Detect system theme preference

```javascript
import { getSystemTheme } from '@min-apps/design-system';

const systemTheme = getSystemTheme();
console.log(systemTheme); // 'light' or 'dark'
```

### React Hook (for React apps)

```javascript
import { useTheme } from '@min-apps/design-system';

function ThemeSwitcher() {
  const { theme, toggleTheme, setTheme } = useTheme();
  
  return (
    <div>
      <p>Current theme: {theme}</p>
      <button onClick={toggleTheme}>
        Toggle Theme
      </button>
      <button onClick={() => setTheme('light')}>
        Light
      </button>
      <button onClick={() => setTheme('dark')}>
        Dark
      </button>
    </div>
  );
}
```

### Using the ThemeToggle Component

```javascript
import { ThemeToggle, useTheme } from '@min-apps/design-system';

function App() {
  const { theme, toggleTheme } = useTheme();
  
  return (
    <header>
      <h1>My App</h1>
      <ThemeToggle currentTheme={theme} onToggle={toggleTheme} />
    </header>
  );
}
```

## Creating Custom Themes

You can create custom themes by following the theme structure:

```javascript
// customTheme.js
import { colors } from '@min-apps/design-system';

export const customTheme = {
  name: 'custom',
  
  colors: {
    background: {
      primary: '#F0F4F8',
      secondary: '#E2E8F0',
      tertiary: '#CBD5E0',
      elevated: '#FFFFFF',
    },
    
    surface: {
      primary: '#FFFFFF',
      secondary: '#F7FAFC',
      tertiary: '#EDF2F7',
    },
    
    text: {
      primary: '#1A202C',
      secondary: '#4A5568',
      tertiary: '#718096',
      disabled: '#A0AEC0',
      inverse: '#FFFFFF',
    },
    
    border: {
      primary: '#CBD5E0',
      secondary: '#E2E8F0',
      focus: '#3182CE',
    },
    
    primary: {
      main: '#3182CE',
      light: '#63B3ED',
      dark: '#2C5282',
      contrast: '#FFFFFF',
    },
    
    // ... continue with other color categories
  },
  
  shadows: 'normal',
};
```

### Register and use custom theme

```javascript
import { themes, applyTheme } from '@min-apps/design-system';
import { customTheme } from './customTheme';

// Register the custom theme
themes.custom = customTheme;

// Apply it
applyTheme('custom');
```

## Theme Structure

Each theme must include:

### 1. Background Colors
- `background.primary` - Main app background
- `background.secondary` - Secondary background areas
- `background.tertiary` - Tertiary background
- `background.elevated` - Elevated surfaces (modals, dialogs)

### 2. Surface Colors
- `surface.primary` - Primary surface (cards, panels)
- `surface.secondary` - Secondary surfaces
- `surface.tertiary` - Tertiary surfaces

### 3. Text Colors
- `text.primary` - Main text
- `text.secondary` - Secondary text
- `text.tertiary` - Tertiary text
- `text.disabled` - Disabled text
- `text.inverse` - Inverse text (for colored backgrounds)

### 4. Border Colors
- `border.primary` - Primary borders
- `border.secondary` - Secondary borders
- `border.focus` - Focus ring color

### 5. Brand Colors
Each with `main`, `light`, `dark`, and `contrast` variants:
- `primary` - Primary brand color
- `secondary` - Secondary brand color
- `accent` - Accent color

### 6. Semantic Colors
Each with `main`, `light`, `dark`, and `contrast` variants:
- `success` - Success states
- `error` - Error states
- `warning` - Warning states
- `info` - Info states

### 7. Interactive State Colors
- `hover.primary` - Primary hover state
- `hover.secondary` - Secondary hover state
- `active.primary` - Primary active/pressed state
- `active.secondary` - Secondary active state
- `focus.ring` - Focus ring color
- `focus.background` - Focus background color

## Using Theme Colors

### In CSS

All theme colors are available as CSS custom properties:

```css
.my-component {
  background-color: var(--color-background-primary);
  color: var(--color-text-primary);
  border: 1px solid var(--color-border-primary);
}

.my-component:hover {
  background-color: var(--color-hover-primary);
}

.my-button {
  background-color: var(--color-primary-main);
  color: var(--color-primary-contrast);
}

.my-button:hover {
  background-color: var(--color-primary-dark);
}
```

### In JavaScript

Access theme colors through the theme object:

```javascript
import { themes } from '@min-apps/design-system';

const currentTheme = themes.light;
const primaryColor = currentTheme.colors.primary.main;
```

## Theme Persistence

The design system automatically saves theme preference to `localStorage`:

```javascript
// Saved as 'min-apps-theme'
localStorage.getItem('min-apps-theme'); // 'light' or 'dark'
```

To clear saved preference:

```javascript
localStorage.removeItem('min-apps-theme');
```

## System Theme Detection

The design system respects the user's system preference:

```javascript
// Automatically detected
window.matchMedia('(prefers-color-scheme: dark)').matches;
```

The theme will automatically switch when the system preference changes, unless the user has manually selected a theme.

## Best Practices

### 1. Always use theme colors

```css
/* Bad */
.component {
  background-color: #FFFFFF;
  color: #000000;
}

/* Good */
.component {
  background-color: var(--color-background-primary);
  color: var(--color-text-primary);
}
```

### 2. Test both themes

Always test your components in both light and dark themes to ensure good contrast and readability.

### 3. Use semantic colors

Use semantic colors for their intended purpose:

```javascript
// Good - using semantic colors
<Button variant="primary">Save</Button>
<div style={{ color: 'var(--color-error-main)' }}>Error message</div>

// Avoid - using brand colors for semantic states
<div style={{ color: 'var(--color-primary-main)' }}>Error message</div>
```

### 4. Provide theme toggle

Always provide an easy way for users to switch themes:

```javascript
import { ThemeToggle, useTheme } from '@min-apps/design-system';

function Header() {
  const { theme, toggleTheme } = useTheme();
  
  return (
    <header>
      <h1>App Name</h1>
      <ThemeToggle currentTheme={theme} onToggle={toggleTheme} />
    </header>
  );
}
```

## Theme-Specific Styles

If you need to apply styles only in a specific theme, use the `data-theme` attribute:

```css
/* Styles for light theme only */
[data-theme="light"] .special-component {
  background-image: url('/bg-light.jpg');
}

/* Styles for dark theme only */
[data-theme="dark"] .special-component {
  background-image: url('/bg-dark.jpg');
}
```

## Sharing Themes Across Apps

Since all min apps use the same design system, themes are automatically interchangeable:

1. WatchedIt, podlink, yourtube, and Cyclismo guide all use the same theme structure
2. Custom themes created for one app work in all apps
3. Theme preferences can be synchronized across apps (if using shared storage)

```javascript
// All apps can use the same themes
import { lightTheme, darkTheme } from '@min-apps/design-system';

// Apply light theme in any app
applyTheme('light');
```
