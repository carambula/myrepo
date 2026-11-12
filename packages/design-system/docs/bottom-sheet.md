# Bottom Sheet Component

The Bottom Sheet component provides an iOS-style bottom sheet with backdrop blur and darkening effects that intensify as the sheet approaches larger detent sizes.

## Overview

The Bottom Sheet implements a modal overlay that slides up from the bottom of the screen, similar to iOS native bottom sheets. A key feature is the progressive backdrop effect: as the sheet expands to larger detent sizes, the content behind becomes more blurred and darkened.

## Features

- **Progressive Backdrop Effects**: Blur and darkening increase with detent size
  - Small detent: 2px blur, 10% opacity
  - Medium detent: 8px blur, 30% opacity
  - Large detent: 16px blur, 50% opacity
- **Three Detent Sizes**: Small (30vh), Medium (50vh), Large (90vh)
- **Drag Support**: Optional dragging to resize or dismiss
- **Edge swipe to dismiss**: Start on any sheet edge, then drag the sheet omnidirectionally until it flings away or snaps back
- **Smooth Transitions**: All state changes are smoothly animated
- **iOS-style Handle**: Visual indicator for dragging
- **Responsive**: Works on all screen sizes

## Installation

```javascript
import { BottomSheet } from '@min-apps/design-system/components';
import '@min-apps/design-system/components/BottomSheet.css';
```

## Basic Usage

```javascript
import React, { useState } from 'react';
import { BottomSheet } from '@min-apps/design-system/components';

function MyComponent() {
  const [isOpen, setIsOpen] = useState(false);
  const [detent, setDetent] = useState('medium');

  return (
    <>
      <button onClick={() => setIsOpen(true)}>
        Open Sheet
      </button>

      <BottomSheet
        isOpen={isOpen}
        onClose={() => setIsOpen(false)}
        detent={detent}
        onDetentChange={setDetent}
      >
        <h2>Sheet Content</h2>
        <p>Your content goes here</p>
      </BottomSheet>
    </>
  );
}
```

## Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `isOpen` | `boolean` | `false` | Controls whether the sheet is visible |
| `onClose` | `function` | - | Callback when sheet should close (backdrop click or drag dismiss) |
| `detent` | `'small' \| 'medium' \| 'large'` | `'medium'` | Current detent size |
| `onDetentChange` | `function` | - | Callback when detent changes (via drag) |
| `enableDrag` | `boolean` | `true` | Enable drag-to-resize and drag-to-dismiss |
| `enableEdgeSwipe` | `boolean` | `true` | Enable omnidirectional edge-swipe-to-dismiss |
| `children` | `ReactNode` | - | Content to display in the sheet |
| `className` | `string` | `''` | Additional CSS classes |

## Detent Sizes

### Small Detent
- **Height**: 30% of viewport height
- **Backdrop Blur**: 2px
- **Backdrop Opacity**: 10% (rgba(0, 0, 0, 0.1))
- **Use Case**: Quick actions, minimal content overlay

### Medium Detent
- **Height**: 50% of viewport height
- **Backdrop Blur**: 8px
- **Backdrop Opacity**: 30% (rgba(0, 0, 0, 0.3))
- **Use Case**: Standard content presentation, forms

### Large Detent
- **Height**: 90% of viewport height
- **Backdrop Blur**: 16px
- **Backdrop Opacity**: 50% (rgba(0, 0, 0, 0.5))
- **Use Case**: Full content views, immersive experiences

## Backdrop Effects

The backdrop effect progressively intensifies as the sheet approaches larger sizes:

```css
/* Small detent */
backdrop-filter: blur(2px);
background-color: rgba(0, 0, 0, 0.1);

/* Medium detent */
backdrop-filter: blur(8px);
background-color: rgba(0, 0, 0, 0.3);

/* Large detent */
backdrop-filter: blur(16px);
background-color: rgba(0, 0, 0, 0.5);
```

This creates a natural visual hierarchy and helps focus attention on the sheet content while still allowing users to see what's underneath.

## Advanced Usage

### Dynamic Detent Changes

```javascript
function AdvancedSheet() {
  const [detent, setDetent] = useState('small');

  const expandToLarge = () => {
    setDetent('large');
  };

  return (
    <BottomSheet
      isOpen={true}
      detent={detent}
      onDetentChange={setDetent}
    >
      <h2>Start Small</h2>
      <button onClick={expandToLarge}>
        Expand to Large
      </button>
    </BottomSheet>
  );
}
```

### Disable Dragging

```javascript
<BottomSheet
  isOpen={isOpen}
  onClose={handleClose}
  detent="large"
  enableDrag={false}
>
  <div>Content without drag support</div>
</BottomSheet>
```

### Custom Styling

```javascript
<BottomSheet
  isOpen={isOpen}
  onClose={handleClose}
  detent="medium"
  className="my-custom-sheet"
>
  <div>Custom styled content</div>
</BottomSheet>
```

```css
.my-custom-sheet .min-bottom-sheet {
  border-top-left-radius: 24px;
  border-top-right-radius: 24px;
}

.my-custom-sheet .min-bottom-sheet__content {
  padding: 0 24px 32px;
}
```

## Drag Behavior

When `enableDrag` is `true`:

1. **Drag Down**: Users can drag the sheet down to resize or dismiss
2. **Detent Snapping**: Sheet snaps to the nearest detent size
3. **Dismiss Threshold**: Dragging down more than 20% of viewport height dismisses the sheet
4. **Detent Change**: Dragging down more than 10% of viewport height switches to a smaller detent

## Edge swipe to dismiss

When `enableEdgeSwipe` is `true` (the default), a pan that **starts on a sheet edge** (top grabber, left, right, or bottom) takes over the sheet:

1. The sheet follows the finger in realtime in any direction, not just down
2. The card scales down slightly and the backdrop fades as it leaves rest
3. Releasing past 120px of travel, or flinging away from rest, sends the sheet off along the drag trajectory at a clamped speed (neither a crawl nor a teleport)
4. Releasing earlier springs the sheet back to its original position

Native min apps attach the same interaction via MinAppKit's `.edgeSwipeToDismiss()` (composed into `.pullToDismissEngine()`, and used by YourTube's sheet modifier). Native sheets activate from the top and side edges so the home indicator can still take bottom-edge swipes. System interactive dismiss is disabled so the card can track the finger without fighting UIKit's sheet controller; the presentation is hidden before SwiftUI dismisses so the card cannot snap back on screen.

## Accessibility

- **Backdrop Click**: Clicking the backdrop closes the sheet
- **Keyboard Support**: Can be extended with keyboard navigation
- **Focus Management**: Content is scrollable with proper overflow handling
- **Touch Support**: Full touch gesture support for mobile devices

## Browser Support

- **Modern Browsers**: Full support in Chrome, Safari, Firefox, Edge
- **Backdrop Blur**: Uses `backdrop-filter` with `-webkit-` prefix for Safari
- **iOS Safari**: Optimized with `-webkit-overflow-scrolling: touch`
- **Fallback**: Graceful degradation for browsers without backdrop-filter support

## Design Tokens Used

- `borders.radii.xl`: 16px border radius for sheet corners
- `zIndex.modalBackdrop`: 1300 for backdrop layer
- `zIndex.modal`: 1400 for sheet layer
- `transitions.duration.normal`: 0.3s for smooth animations
- `transitions.easing.smooth`: cubic-bezier(0.4, 0, 0.2, 1)
- `effects.backdropBlur`: Blur values for different detent sizes
- `effects.backdropDarkness`: Opacity values for backdrop

## Examples

See `/examples/bottom-sheet-example.html` for a complete interactive demo.

## Best Practices

1. **Choose Appropriate Detents**: Use small for quick actions, medium for forms, large for full content
2. **Progressive Disclosure**: Start with smaller detents and allow users to expand as needed
3. **Backdrop Context**: Leverage the blur effect to show context while maintaining focus
4. **Scrollable Content**: Ensure content is scrollable for sheets with lots of content
5. **Clear Exit Path**: Always provide obvious ways to close (backdrop click, close button)

## Related Components

- `Modal`: For full-screen overlays without detent sizes
- `Drawer`: For side-sliding panels
- `Dialog`: For alert-style confirmations

## Migration from Native iOS

If migrating from iOS `UISheetPresentationController`:

| iOS | Web Component |
|-----|---------------|
| `.medium()` detent | `detent="medium"` |
| `.large()` detent | `detent="large"` |
| Custom detent height | Use CSS custom properties |
| `prefersGrabberVisible` | Always visible via handle |
| `preferredCornerRadius` | Customize via CSS |
