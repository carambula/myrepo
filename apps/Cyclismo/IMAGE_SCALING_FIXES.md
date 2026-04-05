# Image Scaling Fixes

## Problem
Race images (particularly wide map images) were being improperly scaled, cropped, or stretched throughout the Cyclismo app due to conflicting aspect ratio constraints and the use of `.fill` content mode.

## Root Causes

### 1. Conflicting Aspect Ratio Modifiers
In `RaceListView.swift`, the `raceRowImage` function had two conflicting aspect ratio modifiers:
- Inner image used `.aspectRatio(contentMode: .fill)` 
- Outer container used `.aspectRatio(aspectRatio, contentMode: .fit)`

This created a conflict where the image would fill its container, but then the container would be sized with a different aspect ratio, causing distortion.

### 2. Fixed Square Frames for Non-Square Images
In `RaceListView.swift`, the `upcomingRaceCard` function forced all images into a 200×200 square frame with `.fill` mode:
```swift
.frame(width: 200, height: 200)
```

This caused wide images (like race maps) to be vertically cropped, cutting off important content.

### 3. Hero Image Cropping
In `RaceDetailView.swift`, the `heroImage` function used `.scaledToFill()` with a fixed height of 240, causing wide images to be cropped.

## Solutions Applied

### Fix 1: RaceListView - Calendar Row Images
**File:** `Cyclismo/RaceListView.swift` (lines 1347-1365)

**Before:**
```swift
BlurredAsyncImage(url: url) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)  // ❌ Crops image
        .raceImageTwoTone()
}
.aspectRatio(aspectRatio, contentMode: .fit)  // ❌ Conflicting constraint
```

**After:**
```swift
BlurredAsyncImage(url: url) { image in
    image
        .resizable()
        .aspectRatio(aspectRatio, contentMode: .fit)  // ✅ Maintains aspect ratio
        .raceImageTwoTone()
}
```

**Impact:** Calendar row images now properly maintain their aspect ratio and display without cropping.

### Fix 2: RaceListView - Recent Race Cards
**File:** `Cyclismo/RaceListView.swift` (lines 1187-1201)

**Before:**
```swift
BlurredAsyncImage(url: url) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)  // ❌ Crops to fill square
        .raceImageTwoTone()
}
.frame(width: 200, height: 200)  // Square frame
```

**After:**
```swift
BlurredAsyncImage(url: url) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fit)  // ✅ Fits within square
        .raceImageTwoTone()
}
.frame(width: 200, height: 200)  // Square frame
```

**Impact:** Recent race cards now show the full image content without cropping, letterboxing wide images within the square frame.

### Fix 3: RaceDetailView - Hero Image
**File:** `Cyclismo/RaceDetailView.swift` (lines 281-309)

**Before:**
```swift
image
    .resizable()
    .scaledToFill()  // ❌ Crops image
    .raceImageTwoTone()
    .frame(maxWidth: .infinity)
```

**After:**
```swift
image
    .resizable()
    .scaledToFit()  // ✅ Fits image
    .raceImageTwoTone()
    .frame(maxWidth: .infinity)
```

**Impact:** Hero images in race detail view now display fully without cropping.

## Image Content Modes Explained

### `.fill` (Previous Behavior)
- Scales image to completely fill the frame
- Crops parts of the image that don't fit
- **Problem:** Wide map images lost vertical content

### `.fit` (New Behavior)
- Scales image to fit entirely within the frame
- Maintains full image visibility
- May add letterboxing/pillarboxing if aspect ratios don't match
- **Benefit:** All image content is visible

## Testing Recommendations

1. **Recent Races Section:**
   - Verify map images show complete geographical area
   - Check that wide images are not vertically cropped
   - Confirm images display within the 200×200 card frame

2. **Calendar Rows:**
   - Test all display styles (Default, Race Name Overlay, Full Overlay, Bold Overlay)
   - Verify images maintain proper aspect ratios (16:9, 4:3, 3:1)
   - Check that images don't appear stretched or distorted

3. **Race Detail View:**
   - Open various races with different image aspect ratios
   - Confirm hero images are fully visible
   - Check that wide map images are not cropped

4. **Edge Cases:**
   - Test with very wide images (panoramic race maps)
   - Test with tall images (portrait orientation)
   - Test with square images
   - Verify placeholder rectangles also maintain correct aspect ratios

## Files Modified

1. `Cyclismo/RaceListView.swift`
   - `upcomingRaceCard` function (line ~1189)
   - `raceRowImage` function (line ~1347)

2. `Cyclismo/RaceDetailView.swift`
   - `heroImage` function (line ~281)

## Not Changed

**Podcast badge tiles** (24×24 px) intentionally kept `.scaledToFill()` because:
- They are small square artwork/icons
- Cropping is acceptable for consistency
- All podcast artwork is expected to be square

## Expected Visual Changes

**Before Fix:**
- Race map images appeared zoomed in and cropped
- Important geographical context was cut off
- Images could appear distorted

**After Fix:**
- Full race map images are visible
- All geographical context is preserved
- Images maintain natural proportions
- Some images may have letterboxing (black bars) if they're very wide

This is the expected and correct behavior for proper image display.
