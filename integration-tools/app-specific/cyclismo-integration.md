# Cyclismo Guide Design System Integration Guide

**App**: Cyclismo Guide (cyc min)  
**Type**: Cycling race guide app  
**Theme Color**: Green/teal (cycling-inspired)

---

## Overview

Cyclismo Guide is a cycling race guide app that provides information about cycling races, routes, riders, and teams. The integration should normalize its visual design while preserving cycling-specific features.

## App-Specific Considerations

### 1. Race/Route Cards

**Current State**: Custom race card components with route maps and details.

**Migration Steps**:

- [ ] Use `<Card>` component for race cards
- [ ] Standardize map thumbnails (16:9 or 4:3 aspect ratio)
- [ ] Apply consistent spacing:
  ```javascript
  import { Card } from '@min-apps/design-system/components';
  import { spacing } from '@min-apps/design-system/tokens';
  
  <Card elevation={1} hoverable>
    <div style={{ position: 'relative' }}>
      <img 
        src={race.mapThumbnailUrl} 
        alt={race.name}
        style={{ 
          width: '100%',
          aspectRatio: '16/9',
          objectFit: 'cover'
        }}
      />
      <div style={{
        position: 'absolute',
        top: '8px',
        left: '8px',
        padding: '4px 8px',
        backgroundColor: 'var(--color-primary-main)',
        color: 'white',
        fontSize: '12px',
        fontWeight: 'bold',
        borderRadius: '4px'
      }}>
        {race.category}
      </div>
    </div>
    <div style={{ padding: spacing.list.itemPaddingY }}>
      <h3 style={{ marginBottom: spacing[1] }}>{race.name}</h3>
      <p style={{ 
        marginBottom: spacing[2],
        color: 'var(--color-text-secondary)' 
      }}>
        {race.location} · {race.date}
      </p>
      <div style={{ 
        display: 'flex', 
        gap: spacing[3],
        fontSize: '14px',
        color: 'var(--color-text-tertiary)'
      }}>
        <span>📏 {race.distance} km</span>
        <span>📈 {race.elevation} m</span>
        <span>⏱️ {race.duration}</span>
      </div>
    </div>
  </Card>
  ```

### 2. Race Lists & Calendar

**Current State**: Custom list and calendar components for races.

**Migration Steps**:

- [ ] Use `<List>` component for race lists
- [ ] Use `<ListItem>` for each race entry
  ```javascript
  import { List, ListItem } from '@min-apps/design-system/components';
  
  <List spacing="default">
    {races.map(race => (
      <ListItem
        key={race.id}
        image={race.mapThumbnailUrl}
        title={race.name}
        subtitle={`${race.location} · ${race.date} · ${race.distance} km`}
        onClick={() => viewRace(race.id)}
        action={
          <Button variant="ghost" size="sm">
            View →
          </Button>
        }
      />
    ))}
  </List>
  ```

For calendar view:
  ```javascript
  <div style={{ padding: spacing[4] }}>
    <h2 style={{ marginBottom: spacing[4] }}>Race Calendar</h2>
    {months.map(month => (
      <div key={month} style={{ marginBottom: spacing[6] }}>
        <h3 style={{ marginBottom: spacing[3] }}>{month}</h3>
        <List spacing="compact">
          {getRacesForMonth(month).map(race => (
            <ListItem
              key={race.id}
              title={race.name}
              subtitle={`${race.date} · ${race.location}`}
              onClick={() => viewRace(race.id)}
            />
          ))}
        </List>
      </div>
    ))}
  </div>
  ```

### 3. Home Screen

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
    logo="/cyclismo-logo.svg"
    title="Cyclismo Guide"
    subtitle="Your cycling race companion"
  >
    <Button variant="primary" fullWidth onClick={handleBrowseRaces}>
      Browse Races
    </Button>
    <Button variant="outline" fullWidth onClick={handleCalendar}>
      Race Calendar
    </Button>
  </HomeLayout>
  ```

### 4. Route/Map View

**Current State**: Custom map interface showing race routes.

**Migration Steps**:

- [ ] Use design system for map container styling
- [ ] Apply consistent spacing around map
- [ ] Use CSS variables for map controls
  ```javascript
  <div style={{ 
    height: '400px',
    marginBottom: spacing[4],
    border: '1px solid var(--color-border-primary)',
    borderRadius: '8px',
    overflow: 'hidden'
  }}>
    {/* Map component */}
    <MapComponent route={race.route} />
    
    {/* Map controls */}
    <div style={{
      position: 'absolute',
      top: spacing[2],
      right: spacing[2],
      display: 'flex',
      flexDirection: 'column',
      gap: spacing[1]
    }}>
      <Button variant="secondary" size="sm" onClick={handleZoomIn}>
        +
      </Button>
      <Button variant="secondary" size="sm" onClick={handleZoomOut}>
        −
      </Button>
    </div>
  </div>
  ```

### 5. Race Detail View

**Current State**: Custom detail page with race information, route, and results.

**Migration Steps**:

- [ ] Use `<AppLayout>` for overall page structure
- [ ] Use `<ContentContainer>` for max-width content
- [ ] Apply consistent spacing:
  ```javascript
  <AppLayout header={<AppHeader title={race.name} />}>
    <ContentContainer>
      {/* Race header */}
      <div style={{ marginBottom: spacing[6] }}>
        <h1 style={{ marginBottom: spacing[2] }}>{race.name}</h1>
        <div style={{ 
          display: 'flex',
          gap: spacing[4],
          marginBottom: spacing[3],
          color: 'var(--color-text-secondary)'
        }}>
          <span>📍 {race.location}</span>
          <span>📅 {race.date}</span>
          <span>🏆 {race.category}</span>
        </div>
      </div>
      
      {/* Race stats */}
      <Grid columns={{ xs: 2, md: 4 }} gap={spacing[4]} style={{ marginBottom: spacing[6] }}>
        <Card padding="md">
          <h4 style={{ marginBottom: spacing[1] }}>Distance</h4>
          <p style={{ fontSize: '24px', fontWeight: 'bold' }}>
            {race.distance} km
          </p>
        </Card>
        <Card padding="md">
          <h4 style={{ marginBottom: spacing[1] }}>Elevation</h4>
          <p style={{ fontSize: '24px', fontWeight: 'bold' }}>
            {race.elevation} m
          </p>
        </Card>
        <Card padding="md">
          <h4 style={{ marginBottom: spacing[1] }}>Avg. Speed</h4>
          <p style={{ fontSize: '24px', fontWeight: 'bold' }}>
            {race.avgSpeed} km/h
          </p>
        </Card>
        <Card padding="md">
          <h4 style={{ marginBottom: spacing[1] }}>Difficulty</h4>
          <p style={{ fontSize: '24px', fontWeight: 'bold' }}>
            {race.difficulty}
          </p>
        </Card>
      </Grid>
      
      {/* Route map */}
      <h2 style={{ marginBottom: spacing[3] }}>Route</h2>
      <RouteMap race={race} />
      
      {/* Race description */}
      <div style={{ marginTop: spacing[6], marginBottom: spacing[6] }}>
        <h2 style={{ marginBottom: spacing[3] }}>About</h2>
        <p style={{ lineHeight: 1.6 }}>{race.description}</p>
      </div>
      
      {/* Results or startlist */}
      <h2 style={{ marginBottom: spacing[3] }}>
        {race.hasResults ? 'Results' : 'Start List'}
      </h2>
      <List spacing="compact">
        {/* Rider list */}
      </List>
    </ContentContainer>
  </AppLayout>
  ```

### 6. Rider/Team Profiles

**Migration Steps**:

- [ ] Use design system components for profile pages
- [ ] Apply consistent spacing
  ```javascript
  <AppLayout>
    <ContentContainer>
      {/* Rider header */}
      <div style={{ 
        display: 'flex',
        gap: spacing[4],
        marginBottom: spacing[6]
      }}>
        <img 
          src={rider.photoUrl}
          style={{ 
            width: '120px', 
            height: '120px', 
            borderRadius: '8px',
            objectFit: 'cover'
          }}
        />
        <div>
          <h1 style={{ marginBottom: spacing[1] }}>{rider.name}</h1>
          <p style={{ 
            marginBottom: spacing[2],
            color: 'var(--color-text-secondary)'
          }}>
            {rider.team} · {rider.nationality}
          </p>
          <div style={{ display: 'flex', gap: spacing[2] }}>
            <Button variant="primary">Follow</Button>
            <Button variant="outline">Share</Button>
          </div>
        </div>
      </div>
      
      {/* Rider stats */}
      <Grid columns={{ xs: 2, md: 4 }} gap={spacing[4]} style={{ marginBottom: spacing[6] }}>
        <Card padding="md">
          <h4 style={{ marginBottom: spacing[1] }}>Wins</h4>
          <p style={{ fontSize: '24px', fontWeight: 'bold' }}>
            {rider.wins}
          </p>
        </Card>
        {/* More stats */}
      </Grid>
      
      {/* Recent results */}
      <h2 style={{ marginBottom: spacing[3] }}>Recent Results</h2>
      <List spacing="default">
        {/* Results list */}
      </List>
    </ContentContainer>
  </AppLayout>
  ```

### 7. Search Interface

**Migration Steps**:

- [ ] Replace custom search input with `<Input>` component
- [ ] Apply consistent spacing
  ```javascript
  import { Input } from '@min-apps/design-system/components';
  
  <Input
    type="search"
    placeholder="Search races, riders, teams..."
    value={searchQuery}
    onChange={handleSearch}
    fullWidth
  />
  ```

## Color Replacements

Cyclismo uses green/teal tones. Map these to design system:

```javascript
// Before
const colors = {
  primary: '#10B981',    // Green
  secondary: '#14B8A6',  // Teal
  background: '#FFFFFF',
  text: '#1F2937',
};

// After - Use CSS variables
const styles = {
  primary: 'var(--color-primary-main)',
  secondary: 'var(--color-secondary-main)',
  background: 'var(--color-background-primary)',
  text: 'var(--color-text-primary)',
};
```

## Custom Theme

Create a Cyclismo-specific green theme:

```javascript
// cyclismo-theme.js
import { createTheme } from '@min-apps/design-system/themes';

export const cyclismoTheme = createTheme({
  name: 'cyclismo',
  colors: {
    primary: {
      main: '#10B981',    // Green
      light: '#34D399',
      dark: '#059669',
    },
    secondary: {
      main: '#14B8A6',    // Teal
      light: '#2DD4BF',
      dark: '#0D9488',
    }
  }
});

// In your app
import { themes, applyTheme } from '@min-apps/design-system';
import { cyclismoTheme } from './cyclismo-theme';

themes.cyclismo = cyclismoTheme;
applyTheme('cyclismo');
```

## Testing Checklist

### Visual Consistency
- [ ] Logo position matches design spec (32px from top)
- [ ] Race cards have consistent spacing
- [ ] Map containers have consistent sizing
- [ ] Page margins match design spec
- [ ] Stats cards have uniform spacing

### Functionality
- [ ] Race search works
- [ ] Calendar view works
- [ ] Map rendering works
- [ ] Rider profiles load correctly
- [ ] Theme switching works

### Map Features
- [ ] Route displays correctly
- [ ] Zoom controls work
- [ ] Map markers work
- [ ] Route elevation profile displays
- [ ] Touch gestures work (mobile)

### Responsive
- [ ] Test on desktop (1920×1080, 1440×900)
- [ ] Test on tablet (768×1024)
- [ ] Test on mobile (375×667, 414×896)
- [ ] Map adapts to screen size
- [ ] Stats grid responsive

### Themes
- [ ] Light theme displays correctly
- [ ] Dark theme displays correctly
- [ ] Custom green theme works
- [ ] Theme persists on reload

## Common Issues & Solutions

### Issue: Map container not sizing correctly
**Solution**: Use explicit height and overflow: hidden

### Issue: Route data not loading
**Solution**: Ensure map component has proper error handling

### Issue: Stats cards have inconsistent heights
**Solution**: Use Grid component with equal-height cards

## Migration Priority

1. **High Priority**:
   - Home screen logo positioning
   - Theme setup and global styles
   - Race card/list standardization
   - Map container styling

2. **Medium Priority**:
   - Race detail pages
   - Rider/team profiles
   - Calendar view
   - Search interface

3. **Low Priority**:
   - Custom green theme
   - Advanced map features
   - Animations

## Estimated Effort

- **Setup & Configuration**: 1-2 hours
- **Component Migration**: 5-7 hours
- **Map Integration**: 3-4 hours
- **Spacing & Color Migration**: 3-4 hours
- **Testing & Refinement**: 2-3 hours
- **Total**: 14-20 hours

## Resources

- [Main Integration Checklist](../../docs/integration-checklist.md)
- [Design System Components](../../docs/components.md)
- [Theming Guide](../../docs/theming.md)
- [Visual Specification](../../docs/visual-specification.md)

## Success Criteria

Cyclismo integration is complete when:
- ✅ Logo positioned at exactly 32px from top
- ✅ All race cards use consistent spacing
- ✅ List items have uniform spacing and height
- ✅ Map containers properly styled
- ✅ Theme switching works throughout
- ✅ Visual design matches other min apps
- ✅ All cycling features work correctly
- ✅ Green theme applied correctly
