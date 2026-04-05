# PodLink Design System Integration Guide

**App**: PodLink (pod min)  
**Type**: Podcast app  
**Theme Color**: Orange/warm tones

---

## Overview

PodLink is a podcast app that allows users to follow, unlock, and listen to podcasts. The integration should normalize its visual design while preserving its unique podcast-focused features.

### Main app loading (bootstrap)

Use the **same** main bootstrap loader as **WatchedIt (mov min)**.

- [ ] **Native / React Native:** **[Main app loading — native](../../docs/main-app-loading-native.md)**.
- [ ] **Web:** **[Main app loading](../../docs/main-app-loading.md)**.

### Screen titles — match mov min (iOS)

Use the generated SwiftUI views from **`native/MinTitleTypography.swift`** so every title is the same size and position as WatchedIt:

- [ ] **Show detail title** (podcast hero): `MinMainContentTitleView(show.title)` — 48pt bold, leading, 16pt bottom. Parent applies `MinPageMargins` horizontal padding.
- [ ] **Home title**: `MinHomeScreenTitleView("PodLink")` — 36pt bold (30pt compact), centered.
- [ ] **Header title** (top bar in show/player view): `MinHeaderTitleView(show.title)` — 20pt semibold.
- [ ] Remove custom font sizes on podcast title `Text` views (e.g. `.font(.title)`, `.system(size: 28)`, `.largeTitle`).

## App-Specific Considerations

### 1. Podcast Episode Cards

**Current State**: Custom episode card components with artwork, title, description.

**Migration Steps**:

- [ ] Standardize podcast artwork (square, 1:1 aspect ratio)
- [ ] Use `<Card>` component for episode cards
- [ ] Apply consistent spacing:
  ```javascript
  import { Card } from '@min-apps/design-system/components';
  import { spacing } from '@min-apps/design-system/tokens';
  
  <Card elevation={1} hoverable>
    <div style={{ display: 'flex', gap: spacing.list.itemGap }}>
      <img 
        src={episode.artworkUrl} 
        alt={episode.title}
        style={{ 
          width: '80px',
          height: '80px',
          borderRadius: '8px'
        }}
      />
      <div style={{ flex: 1 }}>
        <h3 style={{ marginBottom: spacing[2] }}>{episode.title}</h3>
        <p style={{ marginBottom: spacing[1] }}>{episode.podcastName}</p>
        <span>{episode.duration}   {episode.publishDate}</span>
      </div>
    </div>
  </Card>
  ```

### 2. Episode Lists

**Current State**: Custom list components for episodes, shows, etc.

**IMPORTANT - Tap Behavior**: Episode lists must have separate tap areas:
- **Art and title**: Opens the episode detail/player view
- **Play button**: Plays/pauses the episode

**Migration Steps**:

- [ ] Wrap lists in `<List>` component
- [ ] Use `<ListItem>` for each episode entry
- [ ] Apply standard list spacing
- [ ] **CRITICAL**: Use `e.stopPropagation()` on the play button to prevent triggering the row click
  ```javascript
  import { List, ListItem, Button } from '@min-apps/design-system/components';
  import { metadataSeparator } from '@min-apps/design-system/tokens';

  <List spacing="comfortable">
    {episodes.map(episode => (
      <ListItem
        key={episode.id}
        image={episode.artworkUrl}
        title={episode.title}
        subtitle={`${episode.podcastName}${metadataSeparator}${episode.duration}`}
        onClick={() => openEpisodePlayer(episode.id)}
        action={
          <Button 
            variant="ghost" 
            size="sm"
            onClick={(e) => {
              e.stopPropagation();
              playEpisode(episode.id);
            }}
          >
            {episode.isPlaying ? '⏸' : '▶'}
          </Button>
        }
      />
    ))}
  </List>
  ```

**Example handlers**:
```javascript
const openEpisodePlayer = (episodeId) => {
  // Navigate to episode detail/player view
  navigate(`/episode/${episodeId}`);
};

const playEpisode = (episodeId) => {
  // Play the episode immediately
  audioPlayer.play(episodeId);
};
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
    logo="/podlink-logo.svg"
    title="PodLink"
    subtitle="Your podcast companion"
  >
    <Button variant="primary" fullWidth onClick={handleBrowse}>
      Browse Podcasts
    </Button>
    <Button variant="outline" fullWidth onClick={handleLibrary}>
      My Library
    </Button>
  </HomeLayout>
  ```

### 4. Audio Player

**Current State**: Custom audio player with playback controls.

**Migration Steps**:

- [ ] Use design system buttons for player controls
- [ ] Apply consistent spacing for control bar
- [ ] Use CSS variables for player colors
  ```javascript
  <div style={{ 
    padding: spacing[4],
    backgroundColor: 'var(--color-background-secondary)',
    borderTop: '1px solid var(--color-border-primary)'
  }}>
    {/* Episode info */}
    <div style={{ 
      display: 'flex', 
      gap: spacing.list.itemGap,
      marginBottom: spacing[3]
    }}>
      <img 
        src={currentEpisode.artworkUrl} 
        style={{ width: '48px', height: '48px', borderRadius: '4px' }}
      />
      <div>
        <h4>{currentEpisode.title}</h4>
        <p>{currentEpisode.podcastName}</p>
      </div>
    </div>
    
    {/* Playback controls */}
    <div style={{ 
      display: 'flex',
      justifyContent: 'center',
      gap: spacing.button.gap,
      marginBottom: spacing[2]
    }}>
      <Button variant="ghost" size="sm" onClick={handleSkipBack}>
        ⏮ 15s
      </Button>
      <Button variant="primary" onClick={handlePlayPause}>
        {isPlaying ? '⏸' : '▶'}
      </Button>
      <Button variant="ghost" size="sm" onClick={handleSkipForward}>
        15s ⏭
      </Button>
    </div>
    
    {/* Progress bar */}
    <input 
      type="range" 
      value={currentTime} 
      max={duration}
      onChange={handleSeek}
      style={{ width: '100%' }}
    />
  </div>
  ```

### 5. Show Detail View

**Current State**: Custom detail page with show information and episode list.

**Migration Steps**:

- [ ] Use `<AppLayout>` for overall page structure
- [ ] Use `<ContentContainer>` for max-width content
- [ ] Apply consistent spacing:
  ```javascript
  <AppLayout header={<AppHeader title={show.title} />}>
    <ContentContainer>
      <div style={{ 
        display: 'flex', 
        gap: spacing[6],
        marginBottom: spacing[6]
      }}>
        <img 
          src={show.artworkUrl} 
          alt={show.title}
          style={{ width: '200px', height: '200px', borderRadius: '8px' }}
        />
        <div>
          <h1 style={{ marginBottom: spacing[2] }}>{show.title}</h1>
          <p style={{ marginBottom: spacing[1] }}>{show.author}</p>
          <p style={{ 
            marginBottom: spacing[4],
            color: 'var(--color-text-secondary)'
          }}>
            {show.episodeCount} episodes   {show.category}
          </p>
          <Button variant="primary" onClick={handleSubscribe}>
            {isSubscribed ? '✓ Subscribed' : 'Subscribe'}
          </Button>
        </div>
      </div>
      
      <h2 style={{ marginBottom: spacing[4] }}>Episodes</h2>
      <List spacing="default">
        {/* Episode list */}
      </List>
    </ContentContainer>
  </AppLayout>
  ```

### 6. Search Interface

**Migration Steps**:

- [ ] Replace custom search input with `<Input>` component
- [ ] Apply consistent spacing
  ```javascript
  import { Input } from '@min-apps/design-system/components';
  
  <Input
    type="search"
    placeholder="Search podcasts and episodes..."
    value={searchQuery}
    onChange={handleSearch}
    fullWidth
  />
  ```

### 7. Media Links Feature

**Current State**: Unique feature showing links to media mentioned in episodes.

**Migration Steps**:

- [ ] Use `<ListItem>` for media link entries
- [ ] Apply consistent spacing between links
- [ ] Use design system icons/buttons
  ```javascript
  <div style={{ marginTop: spacing[6] }}>
    <h3 style={{ marginBottom: spacing[3] }}>Media Mentioned</h3>
    <List spacing="compact">
      {mediaLinks.map(link => (
        <ListItem
          key={link.id}
          image={link.thumbnailUrl}
          title={link.title}
          subtitle={link.type} // "YouTube", "Movie", "Book", etc.
          onClick={() => openLink(link.url)}
          action={
            <Button variant="ghost" size="sm">
              Open →
            </Button>
          }
        />
      ))}
    </List>
  </div>
  ```

## Color Replacements

PodLink uses orange/warm tones. Map these to design system:

```javascript
// Before
const colors = {
  primary: '#F97316',    // Orange
  background: '#FFFFFF',
  text: '#1F2937',
};

// After - Use CSS variables
const styles = {
  primary: 'var(--color-primary-main)',
  background: 'var(--color-background-primary)',
  text: 'var(--color-text-primary)',
};
```

## Custom Theme

Create a PodLink-specific orange theme:

```javascript
// podlink-theme.js
import { createTheme } from '@min-apps/design-system/themes';

export const podlinkTheme = createTheme({
  name: 'podlink',
  colors: {
    primary: {
      main: '#F97316',    // Orange
      light: '#FB923C',
      dark: '#EA580C',
    },
    secondary: {
      main: '#FBBF24',    // Amber
      light: '#FCD34D',
      dark: '#F59E0B',
    }
  }
});

// In your app
import { themes, applyTheme } from '@min-apps/design-system';
import { podlinkTheme } from './podlink-theme';

themes.podlink = podlinkTheme;
applyTheme('podlink');
```

## Testing Checklist

### Visual Consistency
- [ ] Logo position matches design spec (32px from top)
- [ ] Episode cards have consistent spacing
- [ ] List items have uniform height and spacing
- [ ] Player controls have consistent padding
- [ ] Page margins match design spec

### Functionality
- [ ] Podcast search works
- [ ] Episode playback works
- [ ] Subscribe/unsubscribe works
- [ ] Media links work
- [ ] Theme switching works

### Audio Player
- [ ] Play/pause works
- [ ] Skip forward/back works
- [ ] Progress bar updates
- [ ] Volume control works
- [ ] Background playback works

### Responsive
- [ ] Test on desktop (1920×1080, 1440×900)
- [ ] Test on tablet (768×1024)
- [ ] Test on mobile (375×667, 414×896)
- [ ] Player controls adapt to screen size

### Themes
- [ ] Light theme displays correctly
- [ ] Dark theme displays correctly
- [ ] Custom orange theme works
- [ ] Theme persists on reload

## Common Issues & Solutions

### Issue: Podcast artwork not displaying correctly
**Solution**: Ensure aspect ratio is 1:1 and use border-radius for rounded corners

### Issue: Player controls overlap with content
**Solution**: Use fixed positioning for player and add padding to content

### Issue: Episode list scrolling is janky
**Solution**: Use virtualization for long lists (react-window or similar)

## Migration Priority

1. **High Priority**:
   - Home screen logo positioning
   - Theme setup and global styles
   - Episode list spacing
   - Audio player controls

2. **Medium Priority**:
   - Show detail pages
   - Search interface
   - Media links feature

3. **Low Priority**:
   - Custom orange theme
   - Advanced player features
   - Animations

## Estimated Effort

- **Setup & Configuration**: 1-2 hours
- **Component Migration**: 5-7 hours
- **Audio Player Integration**: 3-4 hours
- **Spacing & Color Migration**: 3-4 hours
- **Testing & Refinement**: 2-3 hours
- **Total**: 14-20 hours

## Resources

- [Main Integration Checklist](../../docs/integration-checklist.md)
- [Design System Components](../../docs/components.md)
- [Theming Guide](../../docs/theming.md)
- [Visual Specification](../../docs/visual-specification.md)

## Success Criteria

PodLink integration is complete when:
- ✅ Logo positioned at exactly 32px from top
- ✅ All episode cards use consistent spacing
- ✅ List items have uniform spacing and height
- ✅ Audio player controls match design system
- ✅ Theme switching works throughout
- ✅ Visual design matches other min apps
- ✅ All podcast features work correctly
- ✅ Orange theme applied correctly
