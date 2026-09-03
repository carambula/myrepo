# Dismiss Button - Quick Start Guide

## What is it?

An animated button component for podcast show views (and similar detail screens) that:
- **Slides in** from bottom-left when user scrolls
- **Stays compact** (48px) while scrolling
- **Expands** (56px) when near bottom of content
- **Always works** - tappable at any scroll position to dismiss the view

## 30-Second Integration

```jsx
import { useRef } from 'react';
import { DismissButton } from '@min-apps/design-system/components';
import { useScrollDismiss } from '@min-apps/design-system/hooks';

function ShowView() {
  const scrollRef = useRef(null);
  const { isScrolled, isAtBottom } = useScrollDismiss(scrollRef);

  return (
    <>
      <div ref={scrollRef} style={{ overflowY: 'auto', height: '100vh' }}>
        {/* Your content */}
      </div>
      
      <DismissButton
        isVisible={isScrolled}
        isExpanded={isAtBottom}
        onClick={() => navigate(-1)}
      />
    </>
  );
}
```

## See It In Action

Open the interactive demo (no build required):

```bash
open examples/podcast-show-dismiss.html
```

## Files Overview

| File | Purpose |
|------|---------|
| `src/components/DismissButton.js` | The button component |
| `src/hooks/useScrollDismiss.js` | Scroll tracking hook |
| `examples/podcast-show-dismiss.html` | Interactive demo |
| `integration-tools/templates/podcast-show-view.jsx` | Full implementation example |
| `docs/dismiss-button.md` | Complete API documentation |
| `docs/SHOW_VIEW_DISMISS_PATTERN.md` | Pattern guidelines |
| `docs/DISMISS_BUTTON_SUMMARY.md` | Detailed summary |

## Key Props

### DismissButton

```jsx
<DismissButton
  isVisible={boolean}      // Show/hide button
  isExpanded={boolean}     // Compact or expanded size
  onClick={function}       // Required - dismiss handler
  icon={string}           // Optional - default: "↓"
  label={string}          // Optional - default: "Close"
/>
```

### useScrollDismiss Hook

```jsx
const { isScrolled, isAtBottom } = useScrollDismiss(scrollContainerRef, {
  scrollThreshold: 100,    // Show after 100px scroll
  bottomThreshold: 50,     // Expand when 50px from bottom
});
```

## Common Use Cases

### Podcast Show View
```jsx
// Show podcast details with episodes list
<PodcastShowView />  // See template for full example
```

### Video Series View
```jsx
// Similar pattern for video content
<VideoSeriesView />  
```

### Any Scrollable Detail View
```jsx
// Generic implementation
<DetailView>
  <ScrollableContent ref={scrollRef} />
  <DismissButton ... />
</DetailView>
```

## Behavior Timeline

1. **Page loads** → Button hidden
2. **User scrolls 100px** → Button slides in (compact, 48px)
3. **User scrolls more** → Button stays compact
4. **Near bottom** → Button expands (56px, shows label)
5. **User taps** → View dismisses (works at any time)

## Design Specs

- **Position**: Bottom-left (16px from edges)
- **Compact**: 48×48px (aligned with microplayer)
- **Expanded**: 56×56px
- **Animation**: 250ms ease-out
- **Z-index**: 1200

## Next Steps

1. **Try the demo**: `open examples/podcast-show-dismiss.html`
2. **Read the API**: `docs/dismiss-button.md`
3. **See full example**: `integration-tools/templates/podcast-show-view.jsx`
4. **Review patterns**: `docs/SHOW_VIEW_DISMISS_PATTERN.md`

## Need Help?

- 📖 Full API docs: `docs/dismiss-button.md`
- 📋 Pattern guide: `docs/SHOW_VIEW_DISMISS_PATTERN.md`
- 📝 Implementation summary: `docs/DISMISS_BUTTON_SUMMARY.md`
- 🎨 Interactive demo: `examples/podcast-show-dismiss.html`
- 💻 Code example: `integration-tools/templates/podcast-show-view.jsx`

---

**Status**: ✅ Ready to use  
**Version**: Unreleased (in PR #14)  
**Branch**: `cursor/min-show-dismiss-animation-d4e4`
