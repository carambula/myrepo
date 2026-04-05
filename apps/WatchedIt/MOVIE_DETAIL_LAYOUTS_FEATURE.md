# Movie Details Layout Options

## Summary

Added a comprehensive layout system for movie details with 5 distinct styles and customizable parameters for each. Users can choose how poster and backdrop images are displayed and fine-tune sizes, spacing, and visual effects.

## The Problem

The movie details view had a single fixed layout that showed either a backdrop or poster at the top. Different users have different preferences for how they want to see movie artwork, and the one-size-fits-all approach didn't accommodate various viewing preferences.

## The Solution

### 5 Unique Layout Styles

#### 1. Classic (Default)
- **Description**: Full-width backdrop or poster at top (current default)
- **Best For**: Users who want maximum artwork visibility
- **Customizable Parameters**:
  - Backdrop Height (150-400px)
  - Poster Height (250-500px)

#### 2. Compact
- **Description**: Poster on left with blurred backdrop background
- **Best For**: Users who want artwork without losing vertical space
- **Customizable Parameters**:
  - Poster Width (80-180px)
  - Poster Height (120-270px)
  - Blur Radius (5-40px) - amount of blur on backdrop

#### 3. Split
- **Description**: Poster and backdrop side-by-side
- **Best For**: Users who want to see both poster and backdrop simultaneously
- **Customizable Parameters**:
  - Poster Width (100-200px)
  - Backdrop Opacity (0.3-1.0)
  - Title Overlap (0-80px) - how far title overlaps images

#### 4. Poster Focus
- **Description**: Large centered poster, no backdrop, minimal design
- **Best For**: Users who prefer clean, poster-focused layouts
- **Customizable Parameters**:
  - Poster Width (150-300px)
  - Poster Height (225-450px)
  - Shadow Radius (5-40px) - size of drop shadow

#### 5. Cinematic
- **Description**: Full backdrop with floating poster card overlay
- **Best For**: Users who want a dramatic, immersive presentation
- **Customizable Parameters**:
  - Backdrop Height (250-450px)
  - Poster Scale (0.5-1.2x) - size of floating poster
  - Overlay Opacity (0.1-0.7) - darkness of gradient on backdrop

## Technical Implementation

### Files Created

**`WatchedIt/MovieDetailLayoutStyles.swift`**
- `MovieDetailLayoutStyle` enum with 5 styles
- `MovieDetailLayoutParameters` struct with all customizable values
- Layout component views:
  - `MovieDetailHeaderLayout` - main switcher
  - `ClassicHeaderLayout`
  - `CompactHeaderLayout`
  - `SplitHeaderLayout`
  - `PosterFocusHeaderLayout`
  - `CinematicHeaderLayout`

**`WatchedIt/Views/MovieDetailLayoutSettingsView.swift`**
- Settings UI with style selector
- Preview button to test layouts
- Parameter sliders for each style
- Real-time parameter updates with AppStorage

### Files Modified

**`WatchedIt/MovieDetailView.swift`**
- Added layout style and parameters AppStorage
- Replaced hardcoded header with `MovieDetailHeaderLayout`
- Maintains all existing functionality (action bar, content sections)

**`WatchedIt/MovieListView.swift`**
- Added "Movie Details Layout" link to Account menu
- Updated Appearance section description

## User Experience

### Accessing Layout Settings

1. Open any movie
2. Tap Account (top-right)
3. Scroll to Appearance section
4. Tap "Movie Details Layout"
5. Choose from 5 layout styles
6. Adjust parameters with sliders
7. Tap "Preview Layout" to test

### Layout Behavior

- **Preserved Elements**: All layouts maintain the same action bar (play, rewatched, listened, save, menu) and all content below
- **Responsive**: Layouts adapt to parameter changes in real-time
- **Persistent**: Settings saved to AppStorage and persist across app launches
- **Theme-Aware**: All layouts respect the current theme colors

### Parameter Sliders

Each layout has 3 customizable parameters with:
- Clear labels and descriptions
- Real-time value display
- Sensible min/max ranges
- Smooth slider interaction
- Background cards matching app design

## Visual Comparison

```
CLASSIC
┌─────────────────────────────┐
│    [Backdrop/Poster]        │  ← Full width, customizable height
│                              │
├─────────────────────────────┤
│  Title & Info                │
│  [Action Buttons]            │
│  Rest of content...          │
└─────────────────────────────┘

COMPACT
┌─────────────────────────────┐
│ ┌──┐                         │  ← Poster on left, blurred backdrop bg
│ │  │  Space for title/info   │
│ │  │                         │
│ └──┘                         │
├─────────────────────────────┤
│  [Action Buttons]            │
│  Rest of content...          │
└─────────────────────────────┘

SPLIT
┌─────────────────────────────┐
│ ┌──┐ │ [Backdrop]            │  ← Poster left, backdrop right
│ │  │ │                       │
│ │  │ │                       │
│ └──┘ │                       │
├─────────────────────────────┤
│  Title overlaps images ↑     │
│  [Action Buttons]            │
│  Rest of content...          │
└─────────────────────────────┘

POSTER FOCUS
┌─────────────────────────────┐
│                              │
│        ┌────────┐            │  ← Large centered poster
│        │        │            │     with shadow, no backdrop
│        │        │            │
│        │        │            │
│        └────────┘            │
├─────────────────────────────┤
│  Title & Info                │
│  [Action Buttons]            │
│  Rest of content...          │
└─────────────────────────────┘

CINEMATIC
┌─────────────────────────────┐
│    [Full Backdrop]           │  ← Large backdrop with
│                              │     gradient overlay
│           ┌──┐               │
│           │  │ ← Floating    │  ← Small poster card
│           └──┘    poster     │     overlaps bottom
├─────────────────────────────┤
│  Title & Info                │
│  [Action Buttons]            │
│  Rest of content...          │
└─────────────────────────────┘
```

## Storage & Performance

### AppStorage Keys
- `"movieDetailLayoutStyle"` - Selected layout style (String)
- `MovieDetailLayoutParameters.storageKey` - All parameter values (Data)

### Performance Considerations
- Layouts use efficient SwiftUI views
- Images loaded with `CachedAsyncImage` (no duplicate fetching)
- Parameter changes are lightweight (no heavy computation)
- Preview uses sample movie data (no network calls)

## Testing

To test the feature:

1. **Try each layout**:
   - Navigate to Account → Appearance → Movie Details Layout
   - Select each of the 5 styles
   - Tap Preview to see the layout

2. **Adjust parameters**:
   - Move sliders for each parameter
   - Observe real-time value updates
   - Tap Preview to see changes

3. **Verify persistence**:
   - Change layout and parameters
   - Close app completely
   - Reopen and check movie details
   - Settings should be preserved

4. **Test with different movies**:
   - Movies with backdrop and poster
   - Movies with only poster
   - Movies with only backdrop
   - Verify graceful handling of missing images

## Git Status

- **Branch**: `cursor/default-poster-image-quality-796b`
- **Commit**: Add movie details layout options with 5 styles and customizable parameters
- **Files created**: 3
- **Files modified**: 3
- **Lines changed**: +1539 insertions, -48 deletions
