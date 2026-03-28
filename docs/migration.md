# Migration Guide

This guide helps you migrate your existing min app to use the unified design system.

## Migration Strategy

### Phase 1: Setup (Do First)

1. **Install the design system**
   ```bash
   npm install @min-apps/design-system
   ```

2. **Import global styles**
   Add to your main file:
   ```javascript
   import '@min-apps/design-system/src/styles/global.css';
   ```

3. **Initialize theming**
   ```javascript
   import { initTheme } from '@min-apps/design-system';
   initTheme();
   ```

### Phase 2: Replace Hard-coded Values

#### Before (app-specific values)
```javascript
const styles = {
  marginTop: '20px',
  color: '#1976D2',
  fontSize: '16px',
  padding: '12px 24px',
};
```

#### After (design tokens)
```javascript
import { spacing, colors, typography } from '@min-apps/design-system';

const styles = {
  marginTop: spacing[5],
  color: colors.primary[600],
  fontSize: typography.sizes.base,
  padding: `${spacing[3]} ${spacing[6]}`,
};
```

### Phase 3: Replace Custom Components

#### Buttons

**Before:**
```javascript
<button className="primary-btn" onClick={handleClick}>
  Click Me
</button>
```

**After:**
```javascript
import { Button } from '@min-apps/design-system';

<Button variant="primary" onClick={handleClick}>
  Click Me
</Button>
```

#### List Items

**Before:**
```javascript
<div className="list-item">
  <img src={image} alt={title} />
  <div>
    <h3>{title}</h3>
    <p>{subtitle}</p>
  </div>
</div>
```

**After:**
```javascript
import { ListItem } from '@min-apps/design-system';

<ListItem
  image={image}
  title={title}
  subtitle={subtitle}
  onClick={handleClick}
/>
```

#### Headers

**Before:**
```javascript
<header className="app-header">
  <img src={logo} alt="Logo" className="logo" />
  <h1>{title}</h1>
</header>
```

**After:**
```javascript
import { AppHeader } from '@min-apps/design-system';

<AppHeader
  logo={logo}
  title={title}
  actions={<ThemeToggle />}
/>
```

### Phase 4: Standardize Layouts

#### Home Page Layout

**Before:**
```javascript
<div className="home">
  <div className="logo-section">
    <img src={logo} />
    <h1>{title}</h1>
  </div>
  <div className="content">
    {children}
  </div>
</div>
```

**After:**
```javascript
import { HomeLayout } from '@min-apps/design-system';

<HomeLayout
  logo={logo}
  title={title}
  subtitle={subtitle}
>
  {children}
</HomeLayout>
```

#### App Layout

**Before:**
```javascript
<div className="app">
  <header>...</header>
  <main className="content">
    {children}
  </main>
  <footer>...</footer>
</div>
```

**After:**
```javascript
import { AppLayout } from '@min-apps/design-system';

<AppLayout
  header={<AppHeader {...headerProps} />}
  footer={<Footer />}
>
  {children}
</AppLayout>
```

### Phase 5: Update CSS/Styles

Replace custom CSS with design system utilities:

**Before:**
```css
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 16px;
}

.card {
  background: #fff;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  padding: 16px;
}
```

**After:**
```javascript
import { ContentContainer, Card } from '@min-apps/design-system';

<ContentContainer maxWidth="default">
  <Card padding="medium" elevation="medium">
    {content}
  </Card>
</ContentContainer>
```

## App-Specific Considerations

### WatchedIt (mov min)
- Replace movie list items with `ListItem` component
- Use `HomeLayout` for the main screen
- Apply standardized spacing for movie cards
- Update logo positioning to use `spacing.logo` tokens

### podlink (pod min)
- Replace podcast list items with `ListItem` component
- Standardize episode card spacing
- Use consistent button styles for play/pause controls
- Apply uniform margins for player controls

### yourtube (vid min)
- Replace video list items with `ListItem` component
- Standardize video thumbnail sizing
- Use consistent spacing for video metadata
- Apply uniform positioning for video controls

### Cyclismo guide (cyc min)
- Replace route/guide list items with `ListItem` component
- Standardize map container sizing and positioning
- Use consistent spacing for route details
- Apply uniform margins for navigation elements

## Testing Checklist

After migration, verify:

- [ ] All margins and spacing are consistent across pages
- [ ] Logo/SVG assets are positioned identically on home screens
- [ ] Buttons have the same size, padding, and spacing
- [ ] List items have uniform height, padding, and gaps
- [ ] Theme switching works correctly
- [ ] All colors update when theme changes
- [ ] Typography is consistent across all text elements
- [ ] Responsive behavior works on mobile devices
- [ ] Accessibility (keyboard navigation, screen readers)

## Troubleshooting

### Colors not updating with theme
Make sure you're using CSS variables:
```css
/* Wrong */
color: #1976D2;

/* Correct */
color: var(--color-primary-main);
```

### Layout inconsistencies
Verify you're using the design system spacing tokens:
```javascript
import { spacing } from '@min-apps/design-system';

// Use spacing tokens everywhere
marginTop: spacing.logo.marginTop
```

### Component styling conflicts
The design system uses `min-` prefixed class names to avoid conflicts. If you see styling issues, check for CSS specificity conflicts.

## Need Help?

Refer to the following documentation:
- [Component API Documentation](./components.md)
- [Design Tokens Reference](./tokens.md)
- [Theming Guide](./theming.md)
