# Best Practices

Guidelines for using the min apps design system effectively.

## Spacing and Layout

### Use Semantic Spacing Tokens

Always use the semantic spacing tokens for consistency:

```javascript
import { spacing } from '@min-apps/design-system';

// Good - using semantic tokens
const styles = {
  marginTop: spacing.logo.marginTop,
  padding: spacing.list.itemPaddingY,
};

// Avoid - using arbitrary values
const styles = {
  marginTop: '35px',
  padding: '18px',
};
```

### Critical Spacing Values

These spacing values are crucial for visual consistency across all min apps:

#### Page Margins
```javascript
// Always use these for page-level margins
spacing.page.marginTop       // Top margin on all pages
spacing.page.marginLeft      // Left margin on all pages
spacing.page.marginRight     // Right margin on all pages
spacing.page.marginBottom    // Bottom margin on all pages
```

#### Logo Positioning
```javascript
// Always use these for home screen logos
spacing.logo.marginTop       // Distance from top of page
spacing.logo.marginBottom    // Space below logo
```

#### Button Spacing
```javascript
// Always use these for buttons
spacing.button.paddingX      // Horizontal padding
spacing.button.paddingY      // Vertical padding
spacing.button.gap           // Icon-to-text gap
spacing.button.marginBottom  // Space below buttons
```

#### List Item Spacing
```javascript
// Always use these for list items
spacing.list.itemPaddingY    // Vertical padding inside item
spacing.list.itemPaddingX    // Horizontal padding inside item
spacing.list.itemGap         // Gap between image and text
spacing.list.betweenItems    // Space between list items
```

### Layout Components

Use layout components instead of custom layouts:

```javascript
// Good - using layout components
import { HomeLayout, List } from '@min-apps/design-system';

<HomeLayout logo="/logo.svg" title="My App">
  <List>
    {items.map(item => <ListItem key={item.id} {...item} />)}
  </List>
</HomeLayout>

// Avoid - custom layout with hardcoded spacing
<div style={{ marginTop: '30px', padding: '15px' }}>
  <img src="/logo.svg" style={{ marginBottom: '20px' }} />
  <div>
    {items.map(item => <div key={item.id}>{item.title}</div>)}
  </div>
</div>
```

## Colors and Theming

### Always Use Theme Colors

Never hardcode colors - always use theme-aware color variables:

```css
/* Good */
.component {
  background-color: var(--color-background-primary);
  color: var(--color-text-primary);
  border-color: var(--color-border-primary);
}

/* Bad */
.component {
  background-color: #FFFFFF;
  color: #000000;
  border-color: #CCCCCC;
}
```

### Use Semantic Colors Correctly

```javascript
// Good - semantic color usage
<Button variant="primary">Save</Button>
<div className="error-message" style={{ color: 'var(--color-error-main)' }}>
  Error occurred
</div>

// Bad - misusing colors
<div className="error-message" style={{ color: 'var(--color-primary-main)' }}>
  Error occurred
</div>
```

### Test Both Themes

Always test your components in both light and dark themes:

```javascript
import { applyTheme } from '@min-apps/design-system';

// Test light theme
applyTheme('light');
// Verify component appearance

// Test dark theme
applyTheme('dark');
// Verify component appearance
```

## Typography

### Use Typography Styles

Use predefined typography styles instead of arbitrary font sizes:

```javascript
import { typography } from '@min-apps/design-system';

// Good - using typography styles
const headingStyle = {
  fontSize: typography.styles.h2.fontSize,
  fontWeight: typography.styles.h2.fontWeight,
  lineHeight: typography.styles.h2.lineHeight,
};

// Or use typography sizes
const textStyle = {
  fontSize: typography.sizes.lg,
  fontWeight: typography.weights.semibold,
};

// Avoid - arbitrary values
const headingStyle = {
  fontSize: '32px',
  fontWeight: 650,
  lineHeight: 1.3,
};
```

### Maintain Hierarchy

Use heading styles in order:

```javascript
// Good - proper hierarchy
<h1 style={typography.styles.h1}>Main Title</h1>
<h2 style={typography.styles.h2}>Section Title</h2>
<h3 style={typography.styles.h3}>Subsection</h3>
<p style={typography.styles.body}>Body text</p>

// Avoid - skipping levels or wrong hierarchy
<h1 style={typography.styles.h1}>Main Title</h1>
<h4 style={typography.styles.h4}>Section Title</h4>
```

## Components

### Prefer Design System Components

Use design system components instead of building custom ones:

```javascript
// Good - using design system components
import { Button, Card, ListItem } from '@min-apps/design-system';

<Card>
  <ListItem title="Item 1" subtitle="Description" />
  <Button variant="primary">Action</Button>
</Card>

// Avoid - custom components
<div className="custom-card">
  <div className="custom-list-item">
    <h3>Item 1</h3>
    <p>Description</p>
  </div>
  <button className="custom-button">Action</button>
</div>
```

### Component Composition

Compose components to build complex UIs:

```javascript
import { Stack, Card, Button, ListItem } from '@min-apps/design-system';

<Stack spacing="large">
  <Card>
    <h2>Section 1</h2>
    <ListItem title="Item 1" />
    <ListItem title="Item 2" />
  </Card>
  
  <Card>
    <h2>Section 2</h2>
    <Stack direction="horizontal" spacing="small">
      <Button variant="primary">Save</Button>
      <Button variant="outline">Cancel</Button>
    </Stack>
  </Card>
</Stack>
```

## Responsive Design

### Use Breakpoints

Use provided breakpoints for responsive behavior:

```javascript
import { breakpoints } from '@min-apps/design-system';

// In CSS
const styles = `
  .component {
    font-size: 14px;
  }
  
  ${breakpoints.up.md} {
    .component {
      font-size: 16px;
    }
  }
`;
```

### Mobile-First Approach

Design for mobile first, then enhance for larger screens:

```css
/* Mobile first */
.component {
  padding: 12px;
  font-size: 14px;
}

/* Tablet and up */
@media (min-width: 768px) {
  .component {
    padding: 16px;
    font-size: 16px;
  }
}

/* Desktop and up */
@media (min-width: 1024px) {
  .component {
    padding: 24px;
    font-size: 18px;
  }
}
```

### Use Responsive Components

Use Grid and Stack components for responsive layouts:

```javascript
import { Grid } from '@min-apps/design-system';

// Responsive grid: 1 column on mobile, 2 on tablet, 3 on desktop
<Grid columns={{ xs: 1, md: 2, lg: 3 }} gap="default">
  <Card>Item 1</Card>
  <Card>Item 2</Card>
  <Card>Item 3</Card>
</Grid>
```

## Accessibility

### Keyboard Navigation

Ensure all interactive elements are keyboard accessible:

```javascript
// Good - keyboard accessible
<Button onClick={handleClick}>
  Click Me
</Button>

// Also good - custom element with keyboard support
<div
  role="button"
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      handleClick();
    }
  }}
>
  Custom Button
</div>
```

### ARIA Labels

Provide appropriate ARIA labels:

```javascript
// Good - with aria-label
<button aria-label="Close dialog" onClick={handleClose}>
  <CloseIcon />
</button>

// Good - with visible text
<button onClick={handleSave}>
  Save Changes
</button>
```

### Color Contrast

Ensure sufficient color contrast:

```javascript
// Good - using theme colors with good contrast
<div style={{
  backgroundColor: 'var(--color-primary-main)',
  color: 'var(--color-primary-contrast)'
}}>
  High contrast text
</div>

// Check contrast ratios
// - Normal text: 4.5:1 minimum
// - Large text: 3:1 minimum
```

### Focus Indicators

Never remove focus indicators without providing alternatives:

```css
/* Bad */
button:focus {
  outline: none;
}

/* Good - custom focus style */
button:focus-visible {
  outline: 2px solid var(--color-border-focus);
  outline-offset: 2px;
}
```

## Performance

### Import Only What You Need

```javascript
// Good - specific imports
import { Button, Card } from '@min-apps/design-system';

// Less optimal - importing everything
import * as DS from '@min-apps/design-system';
```

### Avoid Inline Styles When Possible

```javascript
// Good - use CSS classes with theme variables
<div className="my-component">Content</div>

// CSS file:
.my-component {
  background-color: var(--color-background-primary);
  padding: 16px;
}

// Less optimal - inline styles
<div style={{
  backgroundColor: 'var(--color-background-primary)',
  padding: '16px'
}}>
  Content
</div>
```

## Code Organization

### Group Imports

```javascript
// Design system imports
import {
  Button,
  Card,
  ListItem,
  HomeLayout,
} from '@min-apps/design-system';

import {
  spacing,
  colors,
  typography,
} from '@min-apps/design-system/tokens';

// Local imports
import { MyCustomComponent } from './components/MyCustomComponent';
import { useMyHook } from './hooks/useMyHook';
```

### Component Structure

```javascript
import { useState } from 'react';
import { Button, Card, Stack } from '@min-apps/design-system';

export function MyComponent({ title, onSave }) {
  const [value, setValue] = useState('');
  
  const handleSave = () => {
    onSave(value);
  };
  
  return (
    <Card>
      <Stack spacing="default">
        <h2>{title}</h2>
        <input
          value={value}
          onChange={(e) => setValue(e.target.value)}
        />
        <Button variant="primary" onClick={handleSave}>
          Save
        </Button>
      </Stack>
    </Card>
  );
}
```

## Documentation

### Comment Complex Logic

```javascript
// Good - explaining non-obvious behavior
// Calculate responsive column count based on container width
// Ensures minimum 200px per column
const columnCount = Math.max(1, Math.floor(containerWidth / 200));

// Avoid - obvious comments
// Set count to 3
const count = 3;
```

### Prop Documentation

```javascript
/**
 * MovieCard component displays movie information
 * 
 * @param {string} title - Movie title
 * @param {string} poster - Poster image URL
 * @param {number} year - Release year
 * @param {function} onClick - Click handler
 */
export function MovieCard({ title, poster, year, onClick }) {
  // ...
}
```
