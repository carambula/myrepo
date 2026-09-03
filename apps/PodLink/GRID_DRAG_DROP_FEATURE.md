# Grid Drag and Drop Sorting Feature

## Overview

This feature enables long-press drag and drop reordering of podcasts in the PodLink main screen grid view. Users can customize their podcast order by pressing and holding on any podcast artwork, then dragging it to a new position.

## Implementation Details

### Core Components

#### 1. State Management
- **`draggedPodcast: Podcast?`** - Tracks which podcast is currently being dragged
- **`followedPodcasts: [Podcast]`** - The ordered array of followed podcasts
- Binding passed to `PodcastDropDelegate` for real-time updates

#### 2. Drag Source
```swift
.onDrag {
    draggedPodcast = podcast
    return NSItemProvider(object: podcast.id as NSString)
}
```
- Applied to each grid item in the `LazyVGrid`
- Sets the dragged podcast state
- Provides an `NSItemProvider` with the podcast ID

#### 3. Drop Target
```swift
.onDrop(of: [.text], delegate: PodcastDropDelegate(
    podcast: podcast,
    podcasts: $followedPodcasts,
    draggedPodcast: $draggedPodcast,
    onReorder: savePodcastOrder
))
```
- Applied to each grid item
- Accepts text drops (the podcast ID)
- Uses custom delegate for drop handling

#### 4. Drop Delegate
**`PodcastDropDelegate`** implements `DropDelegate` protocol:

- **`dropEntered(info:)`** - Called when dragged item enters a drop target
  - Calculates `fromIndex` and `toIndex`
  - Moves the podcast in the array with animation
  - Calls `onReorder()` to persist changes
  - Uses spring animation (response: 0.3, dampingFraction: 0.7) for smooth reordering

- **`performDrop(info:)`** - Called when user releases the drag
  - Clears `draggedPodcast` state
  - Returns `true` to indicate successful drop

### Persistence

#### `savePodcastOrder()`
```swift
private func savePodcastOrder() {
    if let data = try? JSONEncoder().encode(followedPodcasts) {
        UserDefaults.standard.set(data, forKey: "followedPodcasts")
        NotificationCenter.default.post(name: .followedPodcastsDidChange, object: nil)
    }
}
```

- Encodes the reordered podcast array
- Saves to UserDefaults with key `"followedPodcasts"`
- Posts notification to trigger UI updates elsewhere in the app
- Called immediately after each reorder operation

## User Experience

### Interaction Flow

1. **Long Press** - User presses and holds on any podcast artwork in the grid
2. **Visual Feedback** - iOS provides standard drag lift animation
3. **Drag** - User drags the podcast to a new position
4. **Live Reordering** - Other podcasts shift positions with smooth spring animation as the dragged item moves over them
5. **Drop** - User releases to place the podcast in the new position
6. **Persistence** - Order is immediately saved to UserDefaults

### Animation Details

- **Spring Animation**: `response: 0.3, dampingFraction: 0.7`
  - Quick, responsive animation
  - Natural bounce effect
  - Smooth transitions between positions

### Grid Layout Support

- Works seamlessly with `LazyVGrid` adaptive columns
- Respects current artwork size settings (plus10, plus20, plus40, plus60)
- Compatible with "show titles" toggle
- Maintains spacing and alignment during reordering

## Technical Considerations

### Performance
- Minimal state changes - only updates when actual reordering occurs
- Efficient array manipulation using `IndexSet` and `move(fromOffsets:toOffset:)`
- Lazy loading preserved with `LazyVGrid`

### Edge Cases Handled
- **Same podcast**: Drop delegate checks `draggedPodcast.id != podcast.id` to prevent no-op
- **Missing indices**: Guard statement ensures both from/to indices exist
- **State cleanup**: `draggedPodcast` is always set to `nil` in `performDrop`

### Compatibility
- **Grid view only** - Drag and drop is only enabled in grid layout mode
- **List view** - List view does not have drag and drop (intentional design choice)
- **Search/filtering** - Works with the current podcast list state

## Files Modified

### `PodLink/Views/Main/PodcastListView.swift`

**Added:**
- State variable `@State private var draggedPodcast: Podcast?`
- `.onDrag` modifier to grid items
- `.onDrop` modifier to grid items  
- `savePodcastOrder()` method
- `PodcastDropDelegate` struct implementing `DropDelegate` protocol

**Changes:**
- Grid layout now supports drag and drop reordering
- Podcast order persists immediately to UserDefaults
- Notifications posted to keep UI in sync

## Testing Recommendations

### Manual Testing
1. **Basic Drag and Drop**
   - Follow 3+ podcasts
   - Switch to grid view
   - Long-press on a podcast artwork
   - Drag to a new position
   - Verify smooth animation
   - Verify new order persists after app restart

2. **Edge Cases**
   - Try dragging the first podcast to last position
   - Try dragging the last podcast to first position
   - Try dragging between middle positions
   - Verify animation smoothness with different artwork sizes

3. **Layout Modes**
   - Verify drag and drop works in grid mode
   - Verify drag and drop is NOT active in list mode (expected)
   - Test with "show titles" enabled and disabled
   - Test with different poster size settings

4. **Persistence**
   - Reorder podcasts
   - Kill and restart app
   - Verify order is preserved
   - Verify latest episodes still match correct podcasts

### Automated Testing Scenarios
- Array reordering logic (from index, to index calculations)
- UserDefaults persistence and retrieval
- State cleanup after drop operation

## Future Enhancements

### Potential Improvements
1. **Haptic Feedback** - Add light impact feedback when drag begins and ends
2. **Visual Drop Indicator** - Highlight the drop zone with a subtle border or glow
3. **Batch Reordering** - Allow selecting multiple podcasts for group reordering
4. **Sort Options** - Add preset sort options (alphabetical, recently updated, most played)
5. **List View Support** - Consider adding drag handles to list view rows for reordering

### Related Features
- Could be extended to reorder episodes within a podcast
- Could be used to reorder queue items in the playback queue
- Similar pattern could apply to theme reordering in the theme builder

## Design System Integration

This feature follows PodLink's established patterns:

- **Animation** - Uses spring animations matching other interactive elements
- **Gesture** - Standard iOS long-press drag gesture (no custom implementation needed)
- **Persistence** - UserDefaults pattern consistent with other app settings
- **Notifications** - NotificationCenter pattern for cross-view updates
- **State Management** - @State and @Binding pattern from SwiftUI best practices

## Accessibility

The drag and drop implementation uses iOS native gestures which automatically support:
- VoiceOver drag and drop announcements
- Standard iOS accessibility hints
- Alternative interaction methods for users who cannot perform gestures

Consider adding explicit VoiceOver labels for improved experience in future iterations.
