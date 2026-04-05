# Poster Size and Image Quality Improvements

## Summary

Updated WatchedIt to use the largest poster size (+60%) as the default and fetch optimally-sized images from TMDB to ensure crisp, high-quality poster display.

## Changes Made

### 1. Default Poster Size Changed

**Before**: `+10%` (110px × 165px posters)  
**After**: `+60%` (160px × 240px posters)

This provides a much more visual, artwork-focused browsing experience by default.

### 2. Optimal Image Fetching

Added intelligent image size selection based on poster size preference:

| Poster Size | Scale | Display Size | TMDB Image Size | Image Width | Retina Quality |
|-------------|-------|--------------|-----------------|-------------|----------------|
| +10% | 1.10x | 110px × 165px | `w185` | 185px | ✅ 1.7x density |
| +20% | 1.20x | 120px × 180px | `w342` | 342px | ✅ 2.9x density |
| +40% | 1.40x | 140px × 210px | `w342` | 342px | ✅ 2.4x density |
| +60% | 1.60x | 160px × 240px | `w500` | 500px | ✅ 3.1x density |

**Why This Matters:**
- iPhone screens are 2x or 3x retina displays
- For crisp images on 3x displays, we need ~3x the display size in pixels
- Previous: All sizes used `w185` (185px) → pixelated at +60% size
- Now: Larger poster sizes fetch higher-resolution images → crisp and sharp

### 3. Files Modified

#### `WatchedIt/MovieListView.swift`
- Added `optimalImageSize` computed property to `PosterSizePreference` enum
- Changed default from `plus10` to `plus60` (3 locations)
- Updated `inspirationPoster()` to use optimal image size
- Updated `prefetchUpcomingImages()` to prefetch optimal sizes

#### `WatchedIt/Views/CollectionsHomeView.swift`
- Changed default from `plus10` to `plus60`
- Updated `posterView` to use optimal image size

### 4. Image Fetching Strategy

**Main Grid Posters** (affected by poster size preference):
- Now fetch w185/w342/w500 based on preference
- Ensures sharp rendering on retina displays

**Small Thumbnails** (fixed 50px × 75px):
- MovieRowView (search results, compact rows)
- SearchResultRow
- Still use w185 (optimal for small sizes)

**Streaming Service Logos**:
- Still use w185 (small logos don't need higher res)

## Technical Details

### Image Size Selection Logic

```swift
var optimalImageSize: MovieDataService.ImageSize {
    switch self {
    case .plus10:
        return .thumbnail  // w185 - sufficient for 110px posters
    case .plus20:
        return .small      // w342 - better quality for 120px posters
    case .plus40:
        return .small      // w342 - good for 140px posters
    case .plus60:
        return .medium     // w500 - crisp for 160px posters
    }
}
```

### TMDB Image Sizes Available

| Size | Width | Use Case |
|------|-------|----------|
| `w185` | 185px | Small thumbnails, list items |
| `w342` | 342px | Medium posters, detail views |
| `w500` | 500px | Large posters, featured content |
| `w780` | 780px | Extra large detail views |
| `w1280` | 1280px | Backdrops |
| `original` | Full res | Downloads, high-quality exports |

## User Impact

### What Users Will Notice

1. **Larger default posters**: Much more visual browsing experience
2. **Crisp image quality**: No pixelation on large posters
3. **Maintained performance**: Smaller poster sizes still use smaller images
4. **Existing preferences preserved**: Users who already set a preference keep it

### Bandwidth Considerations

- **+60% posters**: ~3x larger image files vs. w185
  - w185 ≈ 15-30 KB per poster
  - w500 ≈ 40-80 KB per poster
- Image caching minimizes repeated downloads
- Prefetching still loads only next 10 images
- Most users on WiFi or unlimited data plans

## Testing

To verify the changes:

1. **Build and run the app**
2. **Check default poster size**: Should show large +60% posters
3. **Inspect image quality**: Posters should be sharp and crisp
4. **Change poster size**: Account → Appearance → Poster Size
   - Each size should maintain crisp quality
5. **Network monitoring**: Verify appropriate image sizes are fetched
   - +10%: Fetches w185 URLs
   - +60%: Fetches w500 URLs

## Git Status

- **Branch**: `cursor/default-poster-image-quality-796b`
- **Commit**: Set largest poster size (+60%) as default and fetch optimal image quality
- **Files changed**: 2 (MovieListView.swift, CollectionsHomeView.swift)
- **Lines changed**: +27 insertions, -6 deletions
