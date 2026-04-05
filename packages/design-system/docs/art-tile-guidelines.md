# Primary Art Tile Guidelines

## Overview

All primary art tiles across the min apps suite must use a standardized border radius for visual consistency. This guideline applies to:

- **WatchedIt (mov min)**: Movie posters, TV show posters
- **Cyclismo guide (cyc min)**: Race images, rider photos, team logos
- **Yourtube (vid min)**: Video thumbnails
- **Podlink (pod min)**: Podcast show art, episode artwork

## The Standard: `borders.radii.artTile`

All primary content artwork **MUST** use the `borders.radii.artTile` token, which is set to `4px`.

```javascript
import { borders } from '@min-apps/design-system/tokens';

// ✅ CORRECT - Use artTile for all primary art
const artworkStyle = {
  borderRadius: borders.radii.artTile,
};
```

## What Qualifies as a "Primary Art Tile"?

Primary art tiles are the main visual representation of content items:

- **Movie/TV Posters**: Any image representing a movie or TV show in WatchedIt
- **Race Images**: Photos representing cycling races in Cyclismo guide
- **Rider/Team Photos**: Profile images for riders and teams in Cyclismo guide
- **Video Thumbnails**: YouTube video thumbnail images in Yourtube
- **Podcast Artwork**: Show art and episode artwork in Podlink

## Prohibited Practices

### ❌ DO NOT use larger radii for primary art tiles

```javascript
// ❌ WRONG - Do not use md, lg, xl, or other radii
borderRadius: borders.radii.md,   // 8px - TOO LARGE
borderRadius: borders.radii.lg,   // 12px - TOO LARGE
borderRadius: '8px',              // Hardcoded - TOO LARGE
```

### ❌ DO NOT hardcode radius values

```javascript
// ❌ WRONG - Always use the design token
borderRadius: '4px',  // Even if correct value, use the token
```

### ✅ ALWAYS use the artTile token

```javascript
// ✅ CORRECT
borderRadius: borders.radii.artTile,
```

## Implementation Examples

### Component Usage

For shared components like `ListItem` and `EpisodeListItem`, the `artTile` radius is already applied:

```javascript
import { ListItem } from '@min-apps/design-system/components';

// The component already uses borders.radii.artTile internally
<ListItem
  image="/movie-poster.jpg"
  title="The Movie Title"
/>
```

### Custom Implementation

When implementing custom art tile displays:

```javascript
import { borders } from '@min-apps/design-system/tokens';

function MoviePoster({ src, alt }) {
  return (
    <img
      src={src}
      alt={alt}
      style={{
        width: '200px',
        height: '300px',
        borderRadius: borders.radii.artTile,
        objectFit: 'cover',
      }}
    />
  );
}
```

### CSS/Styled Components

```css
.movie-poster {
  border-radius: var(--border-radius-art-tile); /* 4px */
  object-fit: cover;
}
```

## Exceptions

### When NOT to use artTile

The `artTile` radius is specifically for **primary content artwork**. Other UI elements should use appropriate radii:

- **Cards/Containers**: Use `borders.radii.md` (8px) or `borders.radii.lg` (12px)
- **Buttons**: Use `borders.radii.md` (8px)
- **Inputs**: Use `borders.radii.md` (8px)
- **Avatars**: Use `borders.radii.full` (circular)
- **Feature Icons**: May use `borders.radii.lg` (12px) or `borders.radii.full`

```javascript
// ✅ CORRECT - Non-art elements can use other radii
<Card borderRadius={borders.radii.lg}>        // Card uses lg
  <img 
    src="/poster.jpg" 
    style={{ borderRadius: borders.radii.artTile }}  // Art uses artTile
  />
</Card>
```

## Rationale

The smaller `4px` radius:

1. **Maintains content fidelity**: Preserves more of the original artwork
2. **Modern aesthetic**: Provides a subtle rounded corner without over-stylizing
3. **Visual consistency**: Creates a unified look across all min apps
4. **Distinguishes content**: Differentiates primary art from UI chrome and containers

## Migration Guide

If you have existing code using larger radii for art tiles, update it:

```javascript
// Before
borderRadius: borders.radii.md,  // 8px

// After
borderRadius: borders.radii.artTile,  // 4px
```

## Questions?

If you're unsure whether an element qualifies as a "primary art tile," ask:

1. Is this the main visual representation of the content item?
2. Is it a movie poster, race image, video thumbnail, or podcast artwork?

If yes to both → use `borders.radii.artTile`

If no → use the appropriate radius for the UI element type
