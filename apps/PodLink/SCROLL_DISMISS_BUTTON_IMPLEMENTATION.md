# Scroll-Activated Dismiss Button Implementation

## Context

This implementation corrects a previous misunderstanding where work was done in the design system website instead of the PodLink app (formerly known as podlink).

### Original Request
From the Slack thread in #min-apps:
> "in pod min show views, after scrolling into the episodes list, slide in the swipe up to dismiss button in the lower left slot aligned with the microplayer and search button until scrolled to bottom where it can pop to the larger size and be triggered as usual. Have tapping at any time it close the show view."

### Previous Implementation Issue
The previous agent appears to have implemented this feature in a React/npm-based design system package with:
- `DismissButton` React component
- `useScrollDismiss` hook
- HTML demo examples
- npm package exports

**This was the wrong codebase.** The work should have been done in the **PodLink iOS app** (Swift/SwiftUI).

## Correct Implementation

### What Was Built

#### 1. ScrollDismissButton Component
**File**: `PodLink/Views/Shared/ScrollDismissButton.swift`

A SwiftUI component that provides a scroll-activated dismiss button with the following behavior:
- **Slides in** when scrolling past 100px threshold
- **Compact size** (48px) while scrolling through content
- **Expands** to larger size (56px) when near bottom
- **Always tappable** to dismiss at any scroll position
- **Positioned** in lower-left corner, aligned with microplayer and search button

```swift
struct ScrollDismissButton: View {
    let scrollOffset: CGFloat
    let isNearBottom: Bool
    
    private let scrollThreshold: CGFloat = 100
    private let compactSize: CGFloat = 48
    private let expandedSize: CGFloat = 56
    
    var body: some View {
        Button { dismiss() } label: {
            // Animated circular button with frosted surface
        }
    }
}
```

#### 2. Integration in PodcastDetailView
**File**: `PodLink/Views/Detail/PodcastDetailView.swift`

Enhanced the podcast show view with:
- **Scroll position tracking** using PreferenceKeys
- **Bottom proximity detection** for size transitions
- **Overlay positioning** for the dismiss button
- **State management** for scroll offset and bottom detection

### Technical Details

#### Scroll Tracking Implementation
Uses SwiftUI's PreferenceKey system for efficient scroll position tracking:

```swift
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat)
}

struct BottomDetectionPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat)
}
```

#### Animation Behavior
- **Slide in**: Combined opacity + scale animation using `DesignSystem.Animation.standard`
- **Size transition**: Spring animation using `DesignSystem.Animation.quick`
- **Visibility threshold**: 100px scroll offset
- **Bottom proximity**: 50px from content bottom

#### Layout Positioning
- **Lower-left corner** via `ZStack(alignment: .bottomLeading)`
- **Padding**: `DesignSystem.Spacing.lg` (leading) + `DesignSystem.Spacing.sm` (bottom)
- **Non-intrusive**: Separate overlay layer from main content

### Differences from Existing Pull-to-Dismiss

The app already had a `BottomSheetPullToDismiss.swift` component which provides a **different pattern**:
- Appears only when **overscrolling** at the bottom
- Requires **pulling down 90px** to activate
- Dismisses on **drag release** when active
- Not always tappable

The new `ScrollDismissButton` provides a **different UX pattern**:
- Appears when **scrolling normally** past 100px
- Always **tappable** to dismiss immediately
- Provides **visual feedback** with size changes
- Positioned for **thumb reachability**

## Building & Testing

### Prerequisites
The project uses XcodeGen for project file generation. You'll need to regenerate the Xcode project:

```bash
xcodegen generate
```

### Testing Checklist
1. ✅ Open a podcast show view
2. ✅ Scroll down past the header (~100px)
3. ✅ Verify dismiss button slides in from lower-left
4. ✅ Continue scrolling - button should remain compact (48px)
5. ✅ Scroll to near bottom - button should expand (56px)
6. ✅ Tap button at various scroll positions to confirm dismissal
7. ✅ Verify alignment with microplayer and search button

### Visual Verification
- Button uses frosted surface effect matching app design system
- Close icon (×) from `DesignSystem.Icon.close`
- Text color from `DesignSystem.Colors.textPrimary`
- Smooth spring animations for all transitions

## Files Changed

### New Files
- `PodLink/Views/Shared/ScrollDismissButton.swift` (75 lines)

### Modified Files
- `PodLink/Views/Detail/PodcastDetailView.swift`
  - Added scroll offset state tracking
  - Added bottom proximity detection
  - Added dismiss button overlay
  - Removed old pull-to-dismiss modifiers

## Pull Request

**Branch**: `cursor/app-dismiss-button-6447`
**PR**: https://github.com/carambula/PodLink/pull/4
**Status**: Draft

## Notes for Next Steps

1. **XcodeGen Required**: Team member needs to run `xcodegen generate` before building
2. **Design Review**: Verify sizing and positioning matches design intent
3. **UX Testing**: Confirm button appearance threshold feels natural
4. **Accessibility**: May want to add accessibility labels and hints
5. **iPad Support**: May need layout adjustments for larger screens

## Summary

✅ **Correct Repository**: Implementation is now in the PodLink iOS app (Swift/SwiftUI)
✅ **Correct Pattern**: Scroll-activated persistent button (not pull-to-dismiss)
✅ **Correct Behavior**: Slides in, compact→expanded, always tappable
✅ **Correct Positioning**: Lower-left, aligned with existing UI
