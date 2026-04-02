# YourTube Design System Integration Guide

**App**: yourtube (vid min)  
**Type**: Video app  
**Theme Color**: Red (YouTube-inspired)

---

## Overview

YourTube is a video app for browsing and watching videos. The integration should normalize its visual design to match the design system while preserving video-specific features.

## App-Specific Considerations

### 1. Video Cards & Thumbnails

**Current State**: Custom video card components with thumbnails.

**Migration Steps**:

- [ ] Standardize thumbnail aspect ratio (16:9 for video)
- [ ] Use `<Card>` component for video cards
- [ ] Apply consistent spacing:
  ```javascript
  import { Card } from '@min-apps/design-system/components';
  import { spacing } from '@min-apps/design-system/tokens';
  
  <Card elevation={1} hoverable>
    <div style={{ position: 'relative' }}>
      <img 
        src={video.thumbnailUrl} 
        alt={video.title}
        style={{ 
          width: '100%',
          aspectRatio: '16/9',
          objectFit: 'cover'
        }}
      />
      <span style={{
        position: 'absolute',
        bottom: '8px',
        right: '8px',
        padding: '2px 6px',
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        color: 'white',
        fontSize: '12px',
        borderRadius: '2px'
      }}>
        {video.duration}
      </span>
    </div>
    <div style={{ padding: spacing.list.itemPaddingY }}>
      <h3 style={{ marginBottom: spacing[2] }}>{video.title}</h3>
      <p style={{ color: 'var(--color-text-secondary)' }}>
        {video.channelName}
      </p>
      <p style={{ fontSize: '14px', color: 'var(--color-text-tertiary)' }}>
        {video.views} views · {video.publishedAt}
      </p>
    </div>
  </Card>
  ```

### 2. Video Lists & Grid

**Current State**: Custom grid layout for video thumbnails.

**Migration Steps**:

- [ ] Use `<Grid>` component for video grid layout
- [ ] Apply responsive columns
- [ ] Use consistent spacing:
  ```javascript
  import { Grid } from '@min-apps/design-system/layouts';
  import { spacing } from '@min-apps/design-system/tokens';
  
  <Grid 
    columns={{ xs: 1, sm: 2, md: 3, lg: 4 }}
    gap={spacing[4]}
  >
    {videos.map(video => (
      <VideoCard key={video.id} video={video} />
    ))}
  </Grid>
  ```

For list view:
  ```javascript
  import { List, ListItem } from '@min-apps/design-system/components';
  
  <List spacing="default">
    {videos.map(video => (
      <ListItem
        key={video.id}
        image={video.thumbnailUrl}
        title={video.title}
        subtitle={`${video.channelName} · ${video.views} views`}
        onClick={() => playVideo(video.id)}
        action={
          <Button variant="ghost" size="sm">
            Watch →
          </Button>
        }
      />
    ))}
  </List>
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
    logo="/yourtube-logo.svg"
    title="YourTube"
    subtitle="Watch your favorite videos"
  >
    <Button variant="primary" fullWidth onClick={handleBrowse}>
      Browse Videos
    </Button>
    <Button variant="outline" fullWidth onClick={handleSubscriptions}>
      My Subscriptions
    </Button>
  </HomeLayout>
  ```

### 4. Video Player

**Current State**: Custom video player with playback controls.

**Migration Steps**:

- [ ] Use design system buttons for player controls
- [ ] Apply consistent spacing for control bar
- [ ] Use CSS variables for player colors
  ```javascript
  <div style={{ 
    position: 'relative',
    backgroundColor: '#000',
    aspectRatio: '16/9'
  }}>
    {/* Video element */}
    <video 
      ref={videoRef}
      src={video.url}
      style={{ width: '100%', height: '100%' }}
    />
    
    {/* Control bar */}
    <div style={{ 
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      padding: spacing[3],
      background: 'linear-gradient(transparent, rgba(0,0,0,0.8))',
      display: 'flex',
      alignItems: 'center',
      gap: spacing.button.gap
    }}>
      <Button 
        variant="ghost" 
        size="sm"
        onClick={handlePlayPause}
        style={{ color: 'white' }}
      >
        {isPlaying ? '⏸' : '▶'}
      </Button>
      
      {/* Progress bar */}
      <input 
        type="range" 
        value={currentTime} 
        max={duration}
        onChange={handleSeek}
        style={{ flex: 1 }}
      />
      
      <span style={{ color: 'white', fontSize: '14px' }}>
        {formatTime(currentTime)} / {formatTime(duration)}
      </span>
      
      <Button 
        variant="ghost" 
        size="sm"
        onClick={handleFullscreen}
        style={{ color: 'white' }}
      >
        ⛶
      </Button>
    </div>
  </div>
  ```

### 5. Video Detail View

**Current State**: Custom detail page with video info and related videos.

**Migration Steps**:

- [ ] Use `<AppLayout>` for overall page structure
- [ ] Use `<ContentContainer>` for max-width content
- [ ] Apply consistent spacing:
  ```javascript
  <AppLayout>
    <ContentContainer>
      {/* Video player */}
      <div style={{ marginBottom: spacing[4] }}>
        <VideoPlayer video={video} />
      </div>
      
      {/* Video info */}
      <div style={{ marginBottom: spacing[6] }}>
        <h1 style={{ marginBottom: spacing[2] }}>{video.title}</h1>
        <div style={{ 
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: spacing[3]
        }}>
          <div>
            <p style={{ color: 'var(--color-text-secondary)' }}>
              {video.views} views · {video.publishedAt}
            </p>
          </div>
          <div style={{ display: 'flex', gap: spacing[2] }}>
            <Button variant="outline" size="sm">
              👍 {video.likes}
            </Button>
            <Button variant="outline" size="sm">
              Share
            </Button>
          </div>
        </div>
        
        {/* Channel info */}
        <div style={{ 
          display: 'flex',
          gap: spacing.list.itemGap,
          padding: spacing[4],
          backgroundColor: 'var(--color-background-secondary)',
          borderRadius: '8px'
        }}>
          <img 
            src={video.channel.avatarUrl}
            style={{ width: '48px', height: '48px', borderRadius: '50%' }}
          />
          <div style={{ flex: 1 }}>
            <h3>{video.channel.name}</h3>
            <p style={{ color: 'var(--color-text-secondary)' }}>
              {video.channel.subscribers} subscribers
            </p>
          </div>
          <Button variant="primary">
            {isSubscribed ? '✓ Subscribed' : 'Subscribe'}
          </Button>
        </div>
      </div>
      
      {/* Related videos */}
      <h2 style={{ marginBottom: spacing[4] }}>Related Videos</h2>
      <Grid columns={{ xs: 1, md: 2, lg: 3 }} gap={spacing[4]}>
        {/* Related video cards */}
      </Grid>
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
    placeholder="Search videos..."
    value={searchQuery}
    onChange={handleSearch}
    fullWidth
  />
  ```

### 7. Channel View

**Migration Steps**:

- [ ] Use design system components for channel page
- [ ] Apply consistent spacing
  ```javascript
  <AppLayout>
    <ContentContainer>
      {/* Channel header */}
      <div style={{ 
        padding: spacing[6],
        backgroundColor: 'var(--color-background-secondary)',
        marginBottom: spacing[6]
      }}>
        <div style={{ display: 'flex', gap: spacing[4] }}>
          <img 
            src={channel.avatarUrl}
            style={{ width: '88px', height: '88px', borderRadius: '50%' }}
          />
          <div>
            <h1 style={{ marginBottom: spacing[1] }}>{channel.name}</h1>
            <p style={{ 
              marginBottom: spacing[2],
              color: 'var(--color-text-secondary)'
            }}>
              {channel.subscribers} subscribers · {channel.videoCount} videos
            </p>
            <Button variant="primary">Subscribe</Button>
          </div>
        </div>
      </div>
      
      {/* Channel videos */}
      <h2 style={{ marginBottom: spacing[4] }}>Videos</h2>
      <Grid columns={{ xs: 1, sm: 2, md: 3, lg: 4 }} gap={spacing[4]}>
        {/* Video cards */}
      </Grid>
    </ContentContainer>
  </AppLayout>
  ```

## Color Replacements

YourTube uses red tones (YouTube-inspired). Map these to design system:

```javascript
// Before
const colors = {
  primary: '#FF0000',    // Red
  background: '#FFFFFF',
  text: '#0F0F0F',
};

// After - Use CSS variables
const styles = {
  primary: 'var(--color-primary-main)',
  background: 'var(--color-background-primary)',
  text: 'var(--color-text-primary)',
};
```

## Custom Theme

Create a YourTube-specific red theme:

```javascript
// yourtube-theme.js
import { createTheme } from '@min-apps/design-system/themes';

export const yourtubeTheme = createTheme({
  name: 'yourtube',
  colors: {
    primary: {
      main: '#FF0000',    // Red
      light: '#FF3333',
      dark: '#CC0000',
    }
  }
});

// In your app
import { themes, applyTheme } from '@min-apps/design-system';
import { yourtubeTheme } from './yourtube-theme';

themes.yourtube = yourtubeTheme;
applyTheme('yourtube');
```

## Testing Checklist

### Visual Consistency
- [ ] Logo position matches design spec (32px from top)
- [ ] Video cards have consistent spacing
- [ ] Thumbnails maintain 16:9 aspect ratio
- [ ] Player controls have consistent padding
- [ ] Page margins match design spec

### Functionality
- [ ] Video search works
- [ ] Video playback works
- [ ] Subscribe/unsubscribe works
- [ ] Related videos load correctly
- [ ] Theme switching works

### Video Player
- [ ] Play/pause works
- [ ] Seek/scrubbing works
- [ ] Volume control works
- [ ] Fullscreen works
- [ ] Quality selection works (if applicable)

### Responsive
- [ ] Test on desktop (1920×1080, 1440×900)
- [ ] Test on tablet (768×1024)
- [ ] Test on mobile (375×667, 414×896)
- [ ] Player adapts to screen size
- [ ] Grid layout responsive

### Themes
- [ ] Light theme displays correctly
- [ ] Dark theme displays correctly
- [ ] Custom red theme works
- [ ] Theme persists on reload

## Common Issues & Solutions

### Issue: Video thumbnails have inconsistent sizes
**Solution**: Always use 16:9 aspect ratio and object-fit: cover

### Issue: Player controls don't show on hover
**Solution**: Use CSS :hover state with opacity/visibility transitions

### Issue: Grid layout breaks on mobile
**Solution**: Use responsive columns prop in Grid component

## Migration Priority

1. **High Priority**:
   - Home screen logo positioning
   - Theme setup and global styles
   - Video card/thumbnail standardization
   - Video player controls

2. **Medium Priority**:
   - Video detail pages
   - Channel pages
   - Search interface

3. **Low Priority**:
   - Custom red theme
   - Advanced player features
   - Animations

## Estimated Effort

- **Setup & Configuration**: 1-2 hours
- **Component Migration**: 5-7 hours
- **Video Player Integration**: 4-5 hours
- **Spacing & Color Migration**: 3-4 hours
- **Testing & Refinement**: 2-3 hours
- **Total**: 15-21 hours

## Resources

- [Main Integration Checklist](../../docs/integration-checklist.md)
- [Design System Components](../../docs/components.md)
- [Theming Guide](../../docs/theming.md)
- [Visual Specification](../../docs/visual-specification.md)

## Success Criteria

YourTube integration is complete when:
- ✅ Logo positioned at exactly 32px from top
- ✅ All video cards use 16:9 thumbnails
- ✅ List/grid items have uniform spacing
- ✅ Video player controls match design system
- ✅ Theme switching works throughout
- ✅ Visual design matches other min apps
- ✅ All video features work correctly
- ✅ Red theme applied correctly
