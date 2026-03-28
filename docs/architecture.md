# Design System Architecture

## Overview

The min apps design system follows a hierarchical architecture with clear separation of concerns.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Min Apps Suite                               │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │WatchedIt │  │ podlink  │  │ yourtube │  │Cyclismo  │       │
│  │(mov min) │  │(pod min) │  │(vid min) │  │(cyc min) │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │             │              │             │              │
│       └─────────────┴──────────────┴─────────────┘              │
│                          │                                      │
│                          ▼                                      │
│              ┌───────────────────────┐                          │
│              │  Design System Core   │                          │
│              └───────────────────────┘                          │
└─────────────────────────────────────────────────────────────────┘

Design System Core Structure:

┌─────────────────────────────────────────────────────────────────┐
│                  @min-apps/design-system                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Layer 1: Foundation (Tokens)                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Colors        • Typography    • Breakpoints           │  │
│  │  • Spacing       • Shadows       • Transitions           │  │
│  │  • Borders       • Z-index                               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                        │
│                         ▼                                        │
│  Layer 2: Theming                                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Light Theme                                            │  │
│  │  • Dark Theme                                             │  │
│  │  • Theme Provider (CSS Variables)                        │  │
│  │  • Custom Themes (app-specific)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                        │
│                         ▼                                        │
│  Layer 3: Components                                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  UI Components          Layout Components                │  │
│  │  • Button               • AppLayout                       │  │
│  │  • ListItem             • HomeLayout                      │  │
│  │  • AppHeader            • ContentContainer               │  │
│  │  • Card                 • List                            │  │
│  │  • Input                • Grid                            │  │
│  │  • ThemeToggle          • Stack                           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │                                        │
│                         ▼                                        │
│  Layer 4: Global Styles                                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • CSS Reset                                              │  │
│  │  • Base Styles                                            │  │
│  │  • Utility Classes                                        │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Token Flow
```
Design Tokens → Themes → CSS Variables → Components → Apps
```

**Example:**
```javascript
// Token definition
spacing.logo.marginTop = '32px'

// Theme uses token
theme.spacing.logoTop = spacing.logo.marginTop

// CSS variable generated
--spacing-logo-top: 32px

// Component uses CSS variable
.logo { margin-top: var(--spacing-logo-top); }

// App uses component
<HomeLayout logo="/logo.svg" />
```

### 2. Theme Flow
```
System Preference → Theme Provider → CSS Variables → DOM
                         ↓
                  localStorage
```

**Example:**
```javascript
// 1. Detect system preference
const systemTheme = getSystemTheme(); // 'dark'

// 2. Check saved preference
const savedTheme = getSavedTheme(); // 'light' (if saved)

// 3. Apply theme
applyTheme(savedTheme || systemTheme);

// 4. Generate CSS variables
themeToCSSVariables(theme);

// 5. Inject into DOM
document.documentElement.style.setProperty('--color-bg', '#fff');

// 6. Save to localStorage
localStorage.setItem('min-apps-theme', 'light');
```

### 3. Component Composition Flow
```
Layout Component → UI Components → Tokens
```

**Example:**
```javascript
<HomeLayout>              // Layout component
  <Button>                // UI component
    padding: spacing[4]   // Token
  </Button>
</HomeLayout>
```

## Module Structure

### Tokens Module
```
src/tokens/
├── index.js         (main export)
├── colors.js        (color palette)
├── spacing.js       (spacing scale + semantic)
├── typography.js    (font system)
├── shadows.js       (elevation)
├── borders.js       (radii, widths)
├── breakpoints.js   (responsive)
├── transitions.js   (animations)
└── zIndex.js        (layering)
```

**Import pattern:**
```javascript
// Import all tokens
import { tokens } from '@min-apps/design-system';

// Import specific tokens
import { spacing, colors } from '@min-apps/design-system/tokens';

// Use tokens
const style = {
  padding: spacing[4],
  color: colors.primary[600],
};
```

### Themes Module
```
src/themes/
├── index.js           (main export)
├── lightTheme.js      (light theme config)
├── darkTheme.js       (dark theme config)
└── themeProvider.js   (theme utilities)
```

**Import pattern:**
```javascript
// Import theme utilities
import { initTheme, applyTheme, useTheme } from '@min-apps/design-system';

// Initialize
initTheme();

// Or manually apply
applyTheme('dark');

// React hook
const { theme, toggleTheme } = useTheme();
```

### Components Module
```
src/components/
├── index.js        (main export)
├── Button.js       (button component)
├── ListItem.js     (list item component)
├── AppHeader.js    (header component)
├── Card.js         (card component)
├── Input.js        (input component)
└── ThemeToggle.js  (theme toggle)
```

**Import pattern:**
```javascript
// Import specific components
import { Button, ListItem } from '@min-apps/design-system';

// Use components
<Button variant="primary">Click</Button>
<ListItem title="Item" subtitle="Description" />
```

### Layouts Module
```
src/layouts/
├── index.js           (main export)
├── AppLayout.js       (app wrapper)
├── HomeLayout.js      (home screen)
├── ContentContainer.js (max-width container)
├── List.js            (list container)
├── Grid.js            (grid layout)
└── Stack.js           (flex layout)
```

**Import pattern:**
```javascript
// Import layouts
import { HomeLayout, Grid } from '@min-apps/design-system';

// Use layouts
<HomeLayout logo="/logo.svg" title="App">
  <Grid columns={{ xs: 1, md: 2 }}>
    {items}
  </Grid>
</HomeLayout>
```

## Integration Patterns

### Pattern 1: Token-First Approach
Start with tokens, build up to components.

```javascript
// 1. Import tokens
import { spacing, colors } from '@min-apps/design-system';

// 2. Create custom styles
const customStyle = {
  padding: spacing[4],
  backgroundColor: colors.primary[600],
};

// 3. Use design system components
import { Button } from '@min-apps/design-system';
```

### Pattern 2: Component-First Approach
Use pre-built components, customize with tokens.

```javascript
// 1. Import components
import { Card, Button } from '@min-apps/design-system';

// 2. Use components
<Card padding="medium">
  <Button variant="primary">Click</Button>
</Card>

// 3. Customize with tokens if needed
import { spacing } from '@min-apps/design-system';
```

### Pattern 3: Layout-First Approach
Structure with layouts, fill with components.

```javascript
// 1. Import layout
import { HomeLayout } from '@min-apps/design-system';

// 2. Structure page
<HomeLayout logo="/logo.svg" title="App">
  {/* Content goes here */}
</HomeLayout>

// 3. Add components
import { Button, ListItem } from '@min-apps/design-system';
```

## Dependency Graph

```
App
 ├── global.css
 ├── initTheme()
 └── Components
      ├── Use CSS Variables (from theme)
      └── Use Tokens (directly)

CSS Variables (Runtime)
 └── Generated from Theme
      └── Based on Tokens

Tokens (Build Time)
 └── Foundation values
```

## Extension Points

### 1. Custom Tokens
Add app-specific tokens:

```javascript
import { spacing } from '@min-apps/design-system';

export const myAppSpacing = {
  ...spacing,
  custom: {
    playerHeight: '80px',
    thumbSize: '200px',
  },
};
```

### 2. Custom Themes
Create app-specific themes:

```javascript
import { themes } from '@min-apps/design-system';
import { myCustomTheme } from './myTheme';

// Register custom theme
themes.myapp = myCustomTheme;

// Use it
applyTheme('myapp');
```

### 3. Custom Components
Extend base components:

```javascript
import { Button } from '@min-apps/design-system';
import { spacing } from '@min-apps/design-system/tokens';

export function IconButton({ icon, ...props }) {
  return (
    <Button {...props}>
      <img src={icon} alt="" />
      {props.children}
    </Button>
  );
}
```

### 4. Custom Layouts
Compose layout components:

```javascript
import { AppLayout, ContentContainer } from '@min-apps/design-system';

export function DashboardLayout({ sidebar, children }) {
  return (
    <AppLayout>
      <ContentContainer>
        <div style={{ display: 'flex' }}>
          <aside>{sidebar}</aside>
          <main>{children}</main>
        </div>
      </ContentContainer>
    </AppLayout>
  );
}
```

## Performance Considerations

### 1. CSS Variables (Runtime)
- ✅ Fast theme switching
- ✅ No CSS regeneration
- ✅ Browser-native performance

### 2. Tree Shaking
Import only what you need:
```javascript
// Good - specific imports
import { Button } from '@min-apps/design-system';

// Less optimal - imports everything
import * as DS from '@min-apps/design-system';
```

### 3. Component Composition
Compose instead of duplicating:
```javascript
// Good - reuse components
<Card>
  <Button>Click</Button>
</Card>

// Bad - custom implementation
<div className="custom-card">
  <button className="custom-button">Click</button>
</div>
```

## Testing Strategy

### 1. Visual Regression Testing
- Compare screenshots before/after integration
- Verify spacing matches design system
- Check both themes

### 2. Component Testing
- Test each component in isolation
- Verify props work correctly
- Check accessibility

### 3. Theme Testing
- Test theme switching
- Verify CSS variables update
- Check localStorage persistence

### 4. Integration Testing
- Test full app flow
- Verify responsive behavior
- Check cross-browser compatibility

## Version Management

### Semantic Versioning
```
MAJOR.MINOR.PATCH

1.0.0 - Initial release
1.0.1 - Patch (bug fix)
1.1.0 - Minor (new feature)
2.0.0 - Major (breaking change)
```

### Breaking Changes
Consider breaking when:
- Removing tokens
- Changing token values significantly
- Removing component props
- Changing component behavior

### Non-Breaking Changes
Safe changes:
- Adding new tokens
- Adding new components
- Adding optional props
- Fixing bugs

## Migration Path

### Phase 1: Install (Week 1)
- Install design system
- Import global styles
- Initialize theming

### Phase 2: Tokens (Week 2)
- Replace spacing values
- Replace colors
- Update typography

### Phase 3: Components (Week 3-4)
- Replace buttons
- Replace list items
- Replace cards/containers

### Phase 4: Layouts (Week 5)
- Update page layouts
- Standardize positioning
- Verify spacing

### Phase 5: Testing (Week 6)
- Visual testing
- Accessibility testing
- Cross-browser testing

## Maintenance

### Regular Updates
- Review token usage
- Update documentation
- Fix bugs
- Add requested features

### Deprecation Process
1. Mark as deprecated in docs
2. Add console warning
3. Wait 1 major version
4. Remove in next major version

### Community Feedback
- GitHub issues for bugs
- Pull requests for features
- Documentation updates
- Example contributions

---

## Summary

The design system architecture is:
- **Layered** - Clear separation of concerns
- **Composable** - Build complex from simple
- **Extensible** - Easy to customize
- **Maintainable** - Well documented
- **Performant** - Optimized for production

This architecture ensures the design system remains flexible, scalable, and easy to use across all four min apps.
