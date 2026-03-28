# Getting Started

## Installation

Install the design system in your min app project:

```bash
npm install @min-apps/design-system
```

## Basic Setup

### 1. Import Global Styles

Add this to your main application file (e.g., `index.js`, `App.js`):

```javascript
import '@min-apps/design-system/src/styles/global.css';
```

### 2. Initialize Theme

```javascript
import { initTheme } from '@min-apps/design-system';

// Initialize theme on app load
initTheme();
```

### 3. Use Components

```javascript
import { Button, ListItem, HomeLayout } from '@min-apps/design-system';

function App() {
  return (
    <HomeLayout
      logo="/path/to/logo.svg"
      title="My Min App"
      subtitle="A minimal, beautiful app"
    >
      <Button variant="primary">Get Started</Button>
      <ListItem
        title="Item 1"
        subtitle="Description"
        image="/path/to/image.jpg"
      />
    </HomeLayout>
  );
}
```

## Design Tokens

Access design tokens directly:

```javascript
import { spacing, colors, typography } from '@min-apps/design-system';

const customStyles = {
  padding: spacing[4],
  color: colors.primary[600],
  fontSize: typography.sizes.lg,
};
```

## Theming

### Using the Theme Provider

```javascript
import { useTheme } from '@min-apps/design-system';

function ThemeSwitcher() {
  const { theme, toggleTheme } = useTheme();
  
  return (
    <button onClick={toggleTheme}>
      Current theme: {theme}
    </button>
  );
}
```

### Manual Theme Switching

```javascript
import { applyTheme } from '@min-apps/design-system';

// Switch to dark theme
applyTheme('dark');

// Switch to light theme
applyTheme('light');
```

## CSS Variables

The design system uses CSS custom properties that you can reference in your CSS:

```css
.my-component {
  background-color: var(--color-background-primary);
  color: var(--color-text-primary);
  border: 1px solid var(--color-border-primary);
}
```

## Next Steps

- [Component Documentation](./components.md)
- [Design Tokens Reference](./tokens.md)
- [Theming Guide](./theming.md)
- [Migration Guide](./migration.md)
