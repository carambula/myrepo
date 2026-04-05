# Pull-to-Dismiss Fix for Non-Scrollable Content

## Problem

The pull-to-dismiss gesture in Cyclismo race detail views only worked when:
1. The content was scrollable (content height > visible height)
2. The user scrolled to the bottom
3. The user then pulled past the bottom

This meant that race details with minimal content (e.g., races with no stages, podcasts, or results) could not be dismissed using the pull gesture.

## Root Cause

In `BottomSheetPullToDismiss.swift`, the `updateMetrics(for:)` method had this condition:

```swift
let nextIsAtBottom = distanceFromBottom < 10 && contentHeight > (scrollViewHeight - inset.top - inset.bottom)
```

The second part of the condition (`contentHeight > scrollViewHeight`) would fail for short content, meaning `isAtBottom` would always be `false`, and the pull-to-dismiss gesture would never activate.

## Solution

The fix detects whether content is scrollable and handles both cases:

```swift
let visibleHeight = scrollViewHeight - inset.top - inset.bottom
let isContentScrollable = contentHeight > visibleHeight

if isContentScrollable {
    // Previous behavior: must scroll to bottom first
    nextIsAtBottom = distanceFromBottom < 10
    nextOverscroll = nextIsAtBottom ? max(0, contentOffsetY - maxOffsetY) : 0
} else {
    // New behavior: always ready for pull-to-dismiss
    nextIsAtBottom = true
    nextOverscroll = max(0, contentOffsetY - maxOffsetY)
}
```

## Behavior

### For Scrollable Content (unchanged)
- User must scroll to the bottom
- Then pull past the bottom to reveal the close button
- Works as before

### For Non-Scrollable Content (fixed)
- Content is always considered "at bottom"
- User can pull down from any position
- Close button appears when pulling down
- Activates and dismisses when pulled far enough

## User Experience

1. **Pull to show button** (50pt pull): Disabled close button appears
2. **Pull further to activate** (90pt pull): Button becomes active, grows 4%, changes to accent color, triggers haptic
3. **Release**: Sheet dismisses
4. **Scroll back up**: Button hides, sheet stays open

## Testing

To test the fix:

1. Find a race with minimal content (e.g., upcoming race with no podcasts or stages)
2. Open the race detail view
3. Pull down on the sheet content
4. The close button should appear at the bottom center
5. Pull further to activate it
6. Release to dismiss

## Files Changed

- `Cyclismo/BottomSheetPullToDismiss.swift`: Updated `updateMetrics(for:)` method to handle non-scrollable content

## Compatibility

- Works on iOS 15+
- No changes to public API
- Backward compatible with existing scrollable content
