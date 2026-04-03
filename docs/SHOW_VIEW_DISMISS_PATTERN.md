# Show View Dismiss Pattern

This document describes the standard dismiss button pattern for show views in Min apps (podcast shows, video series, etc.).

## Overview

The dismiss button provides a consistent, animated way for users to close/dismiss show detail views. It follows these principles:

1. **Non-intrusive**: Hidden by default, appears only when user engages with content
2. **Contextual**: Size and visibility adapt to scroll position
3. **Always accessible**: Can be tapped at any scroll position
4. **Smooth**: All state changes are animated
5. **Consistent**: Positioned to align with microplayer and search controls

## Visual Behavior

### State 1: Hidden (Initial)
- Button is below viewport
- Not visible or interactive
- User has not scrolled

### State 2: Visible + Compact (Scrolling)
- User scrolls past threshold (default: 100px)
- Button slides up from bottom-left
- Size: 48px × 48px
- Shows icon only ("↓")
- Label hidden

### State 3: Visible + Expanded (At Bottom)
- User scrolls within 50px of bottom
- Button grows to 56px × 56px
- Icon becomes larger
- "Close" label appears below icon
- Indicates user can swipe up to dismiss

## Implementation

### Quick Start

```jsx
import React, { useRef } from 'react';
import { DismissButton } from '@min-apps/design-system/components';
import { useScrollDismiss } from '@min-apps/design-system/hooks';

function ShowView() {
  const scrollRef = useRef(null);
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollRef);

  return (
    <div>
      <div ref={scrollRef} style={{ overflowY: 'auto', height: '100vh' }}>
        {/* Show content here */}
      </div>
      
      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={() => navigate(-1)}
      />
    </div>
  );
}
```

### With AppLayout

```jsx
import { AppLayout } from '@min-apps/design-system/layouts';
import { AppHeader, DismissButton } from '@min-apps/design-system/components';
import { useScrollDismiss } from '@min-apps/design-system/hooks';

function PodcastShow() {
  const scrollRef = useRef(null);
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollRef);

  const handleDismiss = () => {
    // Navigate back or close modal
    navigate(-1);
  };

  return (
    <AppLayout
      header={
        <AppHeader 
          title="Podcast Title"
          backButton
          onBack={handleDismiss}
        />
      }
    >
      <div ref={scrollRef} style={{ height: '100%', overflowY: 'auto' }}>
        {/* Podcast header, episodes list, etc. */}
      </div>

      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={handleDismiss}
      />
    </AppLayout>
  );
}
```

## Design Specifications

### Sizing
- **Compact**: 48px × 48px (matches microplayer height)
- **Expanded**: 56px × 56px

### Positioning
- **Bottom**: 16px from bottom edge
- **Left**: 16px from left edge
- **Z-index**: 1200 (fixed layer)

### Spacing
- Aligned with microplayer left edge
- Aligned with search button (if present)
- Does not overlap with content

### Colors
- **Background**: `--color-surface-primary`
- **Text**: `--color-text-primary`
- **Hover**: `--color-hover-primary`
- **Active**: `--color-active-primary`
- **Shadow**: `shadows.buttonHover`

### Animation Timing
- **Slide in/out**: 250ms with ease-out
- **Expand/contract**: 250ms with ease-out
- **All state changes**: Smooth, coordinated
- **Easing**: `cubic-bezier(0, 0, 0.2, 1)`

## Scroll Thresholds

### Show Threshold
- **Default**: 100px
- **Purpose**: Prevent accidental appearance
- **Configurable**: Can be adjusted per use case

```jsx
const { isScrolled, isAtBottom } = useScrollDismiss(scrollRef, {
  scrollThreshold: 150, // Custom threshold
});
```

### Bottom Threshold
- **Default**: 50px
- **Purpose**: Expand before reaching absolute bottom
- **Configurable**: Can be adjusted per use case

```jsx
const { isScrolled, isAtBottom } = useScrollDismiss(scrollRef, {
  bottomThreshold: 100, // Expand earlier
});
```

## Accessibility

### ARIA Attributes
- `aria-label`: Descriptive label for screen readers
- `role`: Implicit button role
- `tabindex`: Default (0) for keyboard navigation

### Keyboard Support
- **Tab**: Focus the button
- **Enter/Space**: Activate dismiss action
- **Escape**: Consider also listening for ESC key globally

### Focus Management
When dismiss is triggered:
1. Close/dismiss the show view
2. Return focus to trigger element (if modal)
3. Announce navigation to screen readers

## Use Cases

### Podcast Show View
- Show podcast artwork and metadata
- List of episodes (scrollable)
- Dismiss returns to podcast list

### Video Series View
- Show series artwork and info
- List of episodes/seasons
- Dismiss returns to series list

### Playlist View
- Show playlist cover and details
- List of tracks/videos
- Dismiss returns to playlists

## Best Practices

### DO ✓
- Use for detail views with scrollable content
- Position in bottom-left corner
- Animate all state changes
- Make button always tappable when visible
- Use consistent icon and label
- Align with microplayer/search controls

### DON'T ✗
- Use for non-scrollable views (use header back button)
- Position elsewhere (breaks consistency)
- Show button immediately on view load
- Block interaction while animating
- Use different sizes (breaks alignment)
- Overlap with critical content

## Related Patterns

- **Back Button**: Use in header for primary navigation
- **Swipe Gestures**: Consider adding swipe-down to dismiss
- **Modal Dismissal**: Close button in top-right
- **Microplayer**: Positioned in bottom area with controls

## Examples

See complete examples in:
- `/integration-tools/templates/podcast-show-view.jsx` - React template
- `/examples/podcast-show-dismiss.html` - Interactive demo
- `/docs/dismiss-button.md` - Component documentation

## Migration Guide

If you have existing show views without this pattern:

1. Add scroll container ref
2. Import DismissButton and useScrollDismiss
3. Add the hook with your scroll ref
4. Render DismissButton with scroll states
5. Connect onClick to your dismiss handler
6. Test scroll behavior and thresholds
7. Verify alignment with microplayer

Example migration:

```jsx
// Before
function ShowView() {
  return (
    <AppLayout header={<AppHeader backButton onBack={goBack} />}>
      <div style={{ overflowY: 'auto' }}>
        {/* content */}
      </div>
    </AppLayout>
  );
}

// After
function ShowView() {
  const scrollRef = useRef(null);
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollRef);

  return (
    <AppLayout header={<AppHeader backButton onBack={goBack} />}>
      <div ref={scrollRef} style={{ overflowY: 'auto' }}>
        {/* content */}
      </div>
      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={goBack}
      />
    </AppLayout>
  );
}
```

## Questions?

For more details:
- See component API: `/docs/dismiss-button.md`
- Try interactive demo: `/examples/podcast-show-dismiss.html`
- View template: `/integration-tools/templates/podcast-show-view.jsx`
