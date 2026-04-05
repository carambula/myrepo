# Episode List Tap Behavior - Quick Reference

## The Problem

Previously in PodLink (and potentially other min apps), the entire episode list item would play the episode when tapped anywhere. This created a poor user experience where users couldn't view episode details without starting playback.

## The Solution

Implemented separate tap areas:
- **Art + Title + Row**: Opens episode detail/player view
- **Play Button**: Plays/pauses the episode immediately

## What Changed

### 1. New Component: `EpisodeListItem`

Use this component for all episode lists:

```javascript
import { EpisodeListItem } from '@min-apps/design-system/components';

<EpisodeListItem
  artwork={episode.artwork}
  title={episode.title}
  subtitle={episode.podcastName}
  duration={episode.duration}
  isPlaying={episode.isPlaying}
  onEpisodeClick={() => openEpisodePlayer(episode.id)}
  onPlayClick={() => playEpisode(episode.id)}
/>
```

### 2. Documentation

- **`docs/list-tap-behavior.md`** - Complete guidelines
- **`integration-tools/templates/episode-list-view.jsx`** - Working example

### 3. Updated Integration Guides

All app integration guides now include correct tap behavior:
- PodLink (podcasts)
- YourTube (videos)
- WatchedIt (movies)

## Where This Applies

✅ **Downloaded episodes list**  
✅ **Search results**  
✅ **Podcast episode lists**  
✅ **Home screen episode lists**  
✅ **Queue/Up Next lists**  
✅ **Any future episode list implementations**

Also applies to:
- Video lists (YourTube)
- Movie lists (WatchedIt)
- Any media list with a play/action button

## Migration Checklist

If you're updating existing code:

- [ ] Replace row `onClick` that plays content with handler that opens detail view
- [ ] Add separate play button with its own handler
- [ ] Add `e.stopPropagation()` to play button handler
- [ ] Or better: Use the `EpisodeListItem` component (handles stopPropagation automatically)

## Key Technical Detail

The play button **MUST** call `e.stopPropagation()` to prevent the row click from firing:

```javascript
// CORRECT ✅
<Button onClick={(e) => {
  e.stopPropagation();  // Prevents row click
  playEpisode(id);
}}>
  Play
</Button>

// WRONG ❌
<Button onClick={() => playEpisode(id)}>
  Play
</Button>
```

The `EpisodeListItem` component handles this automatically.

## Questions?

See `docs/list-tap-behavior.md` for the complete guide.
