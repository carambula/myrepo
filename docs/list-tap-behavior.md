# List Item Tap Behavior Guidelines

## Overview

This document defines the correct tap/click behavior for list items across all min apps. Following these patterns ensures a consistent and intuitive user experience.

---

## Core Principle: Separate Tap Areas

List items should have **separate tap areas** for different actions:

1. **Primary tap area** (art + title + row): Opens detail view or navigates
2. **Secondary tap area** (action button): Performs immediate action without navigation

### Example: Episode Lists

```
┌─────────────────────────────────────────────────┐
│  [Art]  Episode Title              [Play ▶]    │
│         Podcast Name · Duration                 │
└─────────────────────────────────────────────────┘
    ↑                                       ↑
    Primary tap area                   Secondary tap
    Opens episode player view          Plays episode
```

---

## Implementation Pattern

### Using EpisodeListItem Component

The `EpisodeListItem` component enforces the correct pattern automatically:

```javascript
import { EpisodeListItem } from '@min-apps/design-system/components';

<EpisodeListItem
  artwork={episode.artworkUrl}
  title={episode.title}
  subtitle={episode.podcastName}
  duration={episode.duration}
  isPlaying={episode.isPlaying}
  // Primary action: opens detail/player view
  onEpisodeClick={() => openEpisodePlayer(episode)}
  // Secondary action: plays episode
  onPlayClick={() => playEpisode(episode)}
/>
```

**Key Features:**
- Automatically handles `e.stopPropagation()` on the play button
- Consistent styling and spacing
- Proper accessibility labels
- Visual feedback on hover/active states

### Using ListItem Component

For custom implementations using the generic `ListItem`:

```javascript
import { ListItem, Button } from '@min-apps/design-system/components';

<ListItem
  image={item.imageUrl}
  title={item.title}
  subtitle={item.subtitle}
  // Primary action: row click
  onClick={() => openDetail(item)}
  action={
    <Button 
      variant="ghost"
      onClick={(e) => {
        // CRITICAL: Prevent row click from firing
        e.stopPropagation();
        performAction(item);
      }}
    >
      Action
    </Button>
  }
/>
```

**Critical Requirements:**
- ✅ **MUST** call `e.stopPropagation()` in action button handlers
- ✅ **MUST** provide separate `onClick` for row and action button
- ✅ **SHOULD** use clear visual distinction between tap areas

---

## Common Use Cases

### 1. Episode Lists (PodLink)

```javascript
// ✅ CORRECT
<EpisodeListItem
  onEpisodeClick={() => navigate(`/episode/${id}`)}  // Opens player
  onPlayClick={() => audioPlayer.play(id)}           // Plays immediately
/>

// ❌ WRONG - Entire row plays the episode
<div onClick={() => audioPlayer.play(id)}>
  <img src={art} />
  <h3>{title}</h3>
</div>
```

### 2. Downloaded Episodes

Downloaded episodes should follow the **same pattern** as regular episodes:
- Art/title → Opens episode player view
- Play button → Plays the episode

```javascript
<List>
  {downloadedEpisodes.map(episode => (
    <EpisodeListItem
      key={episode.id}
      artwork={episode.artworkUrl}
      title={episode.title}
      subtitle={episode.podcastName}
      duration={episode.duration}
      isPlaying={currentlyPlaying === episode.id}
      onEpisodeClick={() => openEpisodePlayer(episode.id)}
      onPlayClick={() => playDownloadedEpisode(episode.id)}
    />
  ))}
</List>
```

### 3. Video Lists (WatchedIt, Yourtube)

Same pattern applies:
- Art/title → Opens video detail/player
- Play button → Starts playback

### 4. Generic Lists with Actions

```javascript
<ListItem
  image={item.thumbnail}
  title={item.name}
  subtitle={item.description}
  onClick={() => viewDetails(item)}
  action={
    <Button 
      variant="ghost" 
      onClick={(e) => {
        e.stopPropagation();
        shareItem(item);
      }}
    >
      Share
    </Button>
  }
/>
```

---

## What NOT to Do

### ❌ Anti-Pattern 1: Entire Row Plays Content

```javascript
// WRONG: Tapping anywhere plays the episode
<div onClick={() => playEpisode(id)}>
  <img src={art} />
  <h3>{title}</h3>
  <button onClick={() => playEpisode(id)}>▶</button>
</div>
```

**Problem:** Users can't open the episode detail view without playing it.

### ❌ Anti-Pattern 2: Missing stopPropagation

```javascript
// WRONG: Play button triggers both play AND row click
<ListItem
  onClick={() => openDetail(item)}
  action={
    <Button onClick={() => play(item)}>  {/* Missing e.stopPropagation() */}
      Play
    </Button>
  }
/>
```

**Problem:** Clicking play opens detail view AND plays, causing unexpected navigation.

### ❌ Anti-Pattern 3: No Row Click Handler

```javascript
// WRONG: Can only play, can't open detail view
<div>
  <img src={art} />
  <h3>{title}</h3>
  <button onClick={() => playEpisode(id)}>▶</button>
</div>
```

**Problem:** No way to access episode details without playing.

---

## Accessibility

### Aria Labels

Always provide clear aria labels for action buttons:

```javascript
<button 
  onClick={(e) => { e.stopPropagation(); play(); }}
  aria-label={`Play ${episodeTitle}`}
>
  ▶
</button>
```

### Keyboard Navigation

- Tab navigation should reach both the row and the action button
- Enter/Space on row → Opens detail view
- Enter/Space on action button → Performs action

The `EpisodeListItem` component handles this automatically.

---

## Testing Checklist

When implementing episode lists (or any list with actions):

- [ ] Clicking art opens detail/player view
- [ ] Clicking title opens detail/player view  
- [ ] Clicking row (empty space) opens detail/player view
- [ ] Clicking play button plays the episode
- [ ] Clicking play button does NOT open detail/player view
- [ ] Play button has proper hover/active states
- [ ] Play button has aria-label
- [ ] Keyboard navigation works for both row and button
- [ ] Works on touch devices (proper tap targets)
- [ ] Works in all list views (home, downloads, search, etc.)

---

## Visual Specification

### Tap Target Sizes

- **Play button**: 40px × 40px minimum (for touch devices)
- **Row height**: 80px minimum (for episode lists with artwork)
- **Spacing between button and row edge**: 12px

### Visual Feedback

- **Row hover**: Light background change
- **Row active**: Darker background change
- **Button hover**: Scale up slightly (1.05x)
- **Button active**: Scale down slightly (0.95x)

The design system components handle these automatically.

---

## Migration Guide

If you have existing episode lists with incorrect tap behavior:

### Step 1: Identify the Problem

```javascript
// Before: Entire row plays
<div onClick={() => playEpisode(id)}>
  <img src={art} />
  <h3>{title}</h3>
</div>
```

### Step 2: Add Separate Handlers

```javascript
// After: Separate tap areas
<div onClick={() => openPlayer(id)}>
  <img src={art} />
  <h3>{title}</h3>
  <button 
    onClick={(e) => {
      e.stopPropagation();
      playEpisode(id);
    }}
  >
    ▶
  </button>
</div>
```

### Step 3: Use Design System Components

```javascript
// Best: Use EpisodeListItem
<EpisodeListItem
  artwork={art}
  title={title}
  subtitle={subtitle}
  duration={duration}
  onEpisodeClick={() => openPlayer(id)}
  onPlayClick={() => playEpisode(id)}
/>
```

---

## Related Components

- `EpisodeListItem` - Specialized component for episodes
- `ListItem` - Generic list item with action support
- `List` - Container for list items with spacing
- `Button` - Use in `action` prop for secondary actions

## Related Documentation

- [Components Documentation](./components.md)
- [PodLink Integration Guide](../integration-tools/app-specific/podlink-integration.md)
- [List View Template](../integration-tools/templates/list-view.jsx)
- [Episode List Template](../integration-tools/templates/episode-list-view.jsx)

---

## Questions?

If you're unsure about tap behavior for a specific use case, refer to this principle:

> **The primary tap area should navigate or show more detail.  
> The secondary tap area (button) should perform an immediate action.**

For episodes specifically:
- **Primary**: Open episode detail/player view
- **Secondary**: Play/pause the episode
