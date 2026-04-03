# Dismiss Button Component

The `DismissButton` is an animated button component designed for show views (podcast shows, video shows, etc.) that provides a smooth user experience for dismissing/closing the view.

## Features

- **Slide-in animation**: Appears from the bottom-left when user starts scrolling
- **Compact mode**: Small 48px size while scrolling, aligned with microplayer and search button
- **Expanded mode**: Grows to 56px when scrolled to the bottom
- **Always tappable**: Can be triggered at any scroll position to close the view
- **Smooth transitions**: All state changes are animated with easing functions
- **Accessible**: Proper ARIA labels and keyboard support

## Usage

### Basic Usage

```jsx
import React, { useRef } from 'react';
import { DismissButton } from '@min-apps/design-system/components';
import { useScrollDismiss } from '@min-apps/design-system/hooks';

function MyShowView() {
  const scrollContainerRef = useRef(null);
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef);

  const handleDismiss = () => {
    // Navigate back or close modal
    console.log('Closing view');
  };

  return (
    <div>
      <div ref={scrollContainerRef} style={{ overflowY: 'auto', height: '100%' }}>
        {/* Your scrollable content */}
      </div>

      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={handleDismiss}
      />
    </div>
  );
}
```

### With Custom Icon and Label

```jsx
<DismissButton
  isVisible={isScrolled}
  isExpanded={isAtBottom}
  onClick={handleDismiss}
  icon="✕"
  label="Dismiss"
/>
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `isVisible` | `boolean` | `false` | Controls slide-in animation. Set to `true` when scrolled. |
| `isExpanded` | `boolean` | `false` | Controls expansion. Set to `true` when at bottom. |
| `onClick` | `function` | - | **Required.** Handler called when button is tapped. |
| `label` | `string` | `'Close'` | Label text shown when expanded. |
| `icon` | `string` | `'↓'` | Icon/emoji shown in the button. |
| `className` | `string` | `''` | Additional CSS classes. |

## Scroll Hook

The `useScrollDismiss` hook tracks scroll position and manages the button states.

### useScrollDismiss API

```jsx
const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef, options);
```

**Parameters:**
- `scrollContainerRef` (required): React ref to the scrollable container
- `options` (optional): Configuration object
  - `scrollThreshold` (number, default: `100`): Pixels to scroll before showing button
  - `bottomThreshold` (number, default: `50`): Distance from bottom to trigger expansion

**Returns:**
- `isScrolled` (boolean): `true` when scrolled past threshold
- `isAtBottom` (boolean): `true` when near bottom of scroll container

### Advanced Scroll Configuration

```jsx
const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef, {
  scrollThreshold: 150,  // Show button after 150px scroll
  bottomThreshold: 100,  // Expand when within 100px of bottom
});
```

## Complete Example

See the [Podcast Show View Template](/integration-tools/templates/podcast-show-view.jsx) for a full implementation example.

## Positioning

The dismiss button is positioned in the **bottom-left corner** of the view:
- `bottom: 16px` (spacing[4])
- `left: 16px` (spacing[4])
- `z-index: 1200` (fixed layer)

This positioning aligns it with typical microplayer and search button locations in min apps.

## Animation States

### Hidden State (Default)
- `transform: translateY(80px)` - Below viewport
- `opacity: 0` - Invisible
- `pointer-events: none` - Not interactive

### Visible + Compact (Scrolling)
- `transform: translateY(0)` - In viewport
- `opacity: 1` - Visible
- `width/height: 48px` - Compact size
- Label hidden

### Visible + Expanded (At Bottom)
- `transform: translateY(0)` - In viewport
- `opacity: 1` - Visible
- `width/height: 56px` - Expanded size
- Label visible

## Styling

The button uses design system tokens for consistent styling:
- Background: `--color-surface-primary`
- Text: `--color-text-primary`
- Hover: `--color-hover-primary`
- Active: `--color-active-primary`
- Shadow: `shadows.buttonHover`

### Custom Styling

```jsx
<DismissButton
  isVisible={isScrolled}
  isExpanded={isAtBottom}
  onClick={handleDismiss}
  className="custom-dismiss-button"
  style={{ /* custom inline styles */ }}
/>
```

## Accessibility

- Uses semantic `<button>` element
- Includes `aria-label` for screen readers
- Keyboard accessible (can be focused and activated with Enter/Space)
- Disabled state when hidden (`pointer-events: none`)

## Performance

The scroll hook is optimized for performance:
- Uses `requestAnimationFrame` for smooth scrolling
- Passive event listeners
- Debounced state updates
- Cleans up event listeners on unmount

## Browser Support

Works in all modern browsers that support:
- CSS transforms
- CSS transitions
- requestAnimationFrame
- Passive event listeners

## Related Components

- `AppHeader` - Header component with back button
- `EpisodeListItem` - List item for episodes
- `AppLayout` - Main layout wrapper

## Related Hooks

- `useScrollDismiss` - Scroll position tracking for dismiss button
