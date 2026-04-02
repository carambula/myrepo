# WatchedIt Design System Integration Guide

**App**: WatchedIt (mov min)  
**Type**: Movie tracking app  
**Priority**: HIGH - This is the most mature app and should serve as the reference implementation

---

## Overview

WatchedIt is the most mature and hardened of the min apps. The integration should preserve its current functionality while normalizing its visual design to match the design system standards.

## App-Specific Considerations

### 1. Movie Cards & Posters

**Current State**: WatchedIt likely has custom movie card components with poster images.

**Migration Steps**:

- [ ] Standardize poster aspect ratio (2:3 for movie posters)
- [ ] Use `<Card>` component for movie cards
- [ ] Apply consistent spacing:
  ```javascript
  import { spacing } from '@min-apps/design-system/tokens';
  
  <Card elevation={1} hoverable>
    <img 
      src={posterUrl} 
      alt={title}
      style={{ 
        width: '100%',
        aspectRatio: '2/3',
        marginBottom: spacing.list.itemGap 
      }}
    />
    <div style={{ padding: spacing.list.itemPaddingY }}>
      <h3>{title}</h3>
      <p>{year}</p>
    </div>
  </Card>
  ```

### 2. Movie Lists

**Current State**: Custom list components for movies, watchlist, etc.

**Migration Steps**:

- [ ] Wrap lists in `<List>` component
- [ ] Use `<ListItem>` for each movie entry
- [ ] Apply standard list spacing:
  ```javascript
  import { List, ListItem } from '@min-apps/design-system/components';
  
  <List spacing="default">
    {movies.map(movie => (
      <ListItem
        key={movie.id}
        image={movie.posterUrl}
        title={movie.title}
        subtitle={`${movie.year} · ${movie.rating}`}
        onClick={() => navigateToMovie(movie.id)}
        action={<Button variant="ghost" size="sm">Add</Button>}
      />
    ))}
  </List>
  ```

### 3. Home Screen

**Current State**: Custom home layout with logo and navigation.

**Critical Requirements**:
- Logo must be positioned exactly **32px from top** (desktop)
- Logo must be centered horizontally
- Logo size: 120px (desktop), 80px (mobile)

**Migration**:

- [ ] Replace custom home layout with `<HomeLayout>`
- [ ] Verify logo positioning matches specification
  ```javascript
  import { HomeLayout } from '@min-apps/design-system/layouts';
  
  <HomeLayout
    logo="/watchedit-logo.svg"
    title="WatchedIt"
    subtitle="Track your movies"
  >
    <Button variant="primary" fullWidth onClick={handleGetStarted}>
      Browse Movies
    </Button>
    <Button variant="outline" fullWidth onClick={handleMyList}>
      My Watchlist
    </Button>
  </HomeLayout>
  ```

### 4. Movie Detail View

**Current State**: Custom detail page with movie information.

**Migration Steps**:

- [ ] Use `<AppLayout>` for overall page structure
- [ ] Use `<ContentContainer>` for max-width content
- [ ] Apply consistent spacing for metadata:
  ```javascript
  <AppLayout header={<AppHeader title={movie.title} />}>
    <ContentContainer>
      <Grid columns={2} gap={spacing[6]}>
        <div>
          <img src={movie.posterUrl} alt={movie.title} />
        </div>
        <div>
          <h1 style={{ marginBottom: spacing[4] }}>{movie.title}</h1>
          <p style={{ marginBottom: spacing[3] }}>{movie.year}</p>
          <p style={{ marginBottom: spacing[6] }}>{movie.synopsis}</p>
          <Button variant="primary">Add to Watchlist</Button>
        </div>
      </Grid>
    </ContentContainer>
  </AppLayout>
  ```

### 5. Player/Viewer Controls

**Current State**: Custom video player or trailer viewer controls.

**Migration Steps**:

- [ ] Use design system buttons for player controls
- [ ] Apply consistent spacing for control bar
- [ ] Use CSS variables for control colors
  ```javascript
  <div style={{ 
    display: 'flex',
    gap: spacing.button.gap,
    padding: spacing.button.paddingY,
    backgroundColor: 'var(--color-background-secondary)'
  }}>
    <Button variant="ghost" size="sm" onClick={handlePlay}>
      ▶ Play
    </Button>
    <Button variant="ghost" size="sm" onClick={handlePause}>
      ⏸ Pause
    </Button>
  </div>
  ```

### 6. Search Interface

**Current State**: Custom search component.

**Migration Steps**:

- [ ] Replace custom input with `<Input>` component
- [ ] Apply consistent spacing
- [ ] Use CSS variables for styling
  ```javascript
  import { Input } from '@min-apps/design-system/components';
  
  <Input
    type="search"
    placeholder="Search movies..."
    value={searchQuery}
    onChange={handleSearch}
    fullWidth
  />
  ```

### 7. Filters & Sorting

**Current State**: Custom filter/sort controls.

**Migration Steps**:

- [ ] Use design system buttons for filter options
- [ ] Apply consistent spacing between filter groups
- [ ] Use CSS variables for active state

## Color Replacements

WatchedIt likely uses purple/blue tones. Map these to design system:

```javascript
// Before
const colors = {
  primary: '#8B5CF6',    // Purple
  background: '#1F2937', // Dark gray
  text: '#F9FAFB',       // Light gray
};

// After
const styles = {
  primary: 'var(--color-primary-main)',
  background: 'var(--color-background-primary)',
  text: 'var(--color-text-primary)',
};
```

## Custom Theme (Optional)

Create a WatchedIt-specific theme while maintaining compatibility:

```javascript
// watchedit-theme.js
import { createTheme } from '@min-apps/design-system/themes';

export const watcheditTheme = createTheme({
  name: 'watchedit',
  colors: {
    primary: {
      main: '#8B5CF6',    // Purple
      light: '#A78BFA',
      dark: '#7C3AED',
    },
    // ... other colors inherit from default
  }
});

// In your app
import { themes, applyTheme } from '@min-apps/design-system';
import { watcheditTheme } from './watchedit-theme';

themes.watchedit = watcheditTheme;
applyTheme('watchedit');
```

## Testing Checklist

### Visual Consistency
- [ ] Logo position matches design spec (32px from top)
- [ ] Movie cards have consistent spacing
- [ ] List items have uniform height and spacing
- [ ] Buttons have consistent padding (24px × 12px)
- [ ] Page margins match design spec

### Functionality
- [ ] Movie search works
- [ ] Watchlist add/remove works
- [ ] Movie detail navigation works
- [ ] Theme switching works
- [ ] All player controls work

### Responsive
- [ ] Test on desktop (1920×1080, 1440×900)
- [ ] Test on tablet (768×1024)
- [ ] Test on mobile (375×667, 414×896)

### Themes
- [ ] Light theme displays correctly
- [ ] Dark theme displays correctly
- [ ] Custom purple theme works (if implemented)
- [ ] Theme persists on reload

## Common Issues & Solutions

### Issue: Poster images not displaying correctly
**Solution**: Ensure aspect ratio is set to 2:3 and use object-fit: cover

### Issue: List items have inconsistent heights
**Solution**: Use the `<ListItem>` component which enforces consistent spacing

### Issue: Colors don't update when switching themes
**Solution**: Ensure you're using CSS variables (`var(--color-*)`) not hard-coded colors

## Migration Priority

1. **High Priority** (Do First):
   - Home screen logo positioning
   - Theme setup and global styles
   - Movie list spacing
   - Button standardization

2. **Medium Priority**:
   - Movie detail pages
   - Search interface
   - Filter controls

3. **Low Priority** (Can Do Last):
   - Custom theme colors
   - Advanced animations
   - Edge case layouts

## Estimated Effort

- **Setup & Configuration**: 1-2 hours
- **Component Migration**: 4-6 hours
- **Spacing & Color Migration**: 3-4 hours
- **Testing & Refinement**: 2-3 hours
- **Total**: 10-15 hours

## Resources

- [Main Integration Checklist](../../docs/integration-checklist.md)
- [Design System Components](../../docs/components.md)
- [Theming Guide](../../docs/theming.md)
- [Visual Specification](../../docs/visual-specification.md)

## Success Criteria

WatchedIt integration is complete when:
- ✅ Logo positioned at exactly 32px from top
- ✅ All movie cards use consistent spacing
- ✅ List items have uniform spacing and height
- ✅ Theme switching works throughout
- ✅ Visual design matches other min apps
- ✅ No visual regressions from original app
- ✅ All existing functionality preserved
