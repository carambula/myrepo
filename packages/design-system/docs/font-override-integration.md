# Font Override Integration Guide for Min Apps

This guide provides step-by-step instructions for integrating the font override feature into each of the four min apps: WatchedIt, PodLink, YourTube, and Cyclismo Guide.

## Prerequisites

1. The design system package must be installed: `@min-apps/design-system`
2. Rotina font files must be available from the Nuform Redux app
3. Basic understanding of the min apps design system

## Universal Integration Steps

These steps apply to all four apps:

### Step 1: Copy Rotina Font Files

First, locate the Rotina font files in the Nuform Redux app repository. Then copy them to your app's public assets or the design system package:

**Option A: Copy to design system (recommended)**
```bash
# From the root of the Nuform Redux app
cp src/assets/fonts/rotina/*.woff2 path/to/node_modules/@min-apps/design-system/src/assets/fonts/rotina/
cp src/assets/fonts/rotina/*.woff path/to/node_modules/@min-apps/design-system/src/assets/fonts/rotina/
```

**Option B: Copy to your app's public folder**
```bash
# Copy to your app's public assets
mkdir -p public/fonts/rotina
cp path/to/nuform-redux/fonts/rotina/* public/fonts/rotina/
```

Required files (32 total):
- `Rotina-ExtraThin.woff2` and `.woff`
- `Rotina-ExtraThinItalic.woff2` and `.woff`
- `Rotina-Thin.woff2` and `.woff`
- `Rotina-ThinItalic.woff2` and `.woff`
- `Rotina-Light.woff2` and `.woff`
- `Rotina-LightItalic.woff2` and `.woff`
- `Rotina-Regular.woff2` and `.woff`
- `Rotina-Italic.woff2` and `.woff`
- `Rotina-Medium.woff2` and `.woff`
- `Rotina-MediumItalic.woff2` and `.woff`
- `Rotina-SemiBold.woff2` and `.woff`
- `Rotina-SemiBoldItalic.woff2` and `.woff`
- `Rotina-Bold.woff2` and `.woff`
- `Rotina-BoldItalic.woff2` and `.woff`
- `Rotina-ExtraBold.woff2` and `.woff`
- `Rotina-ExtraBoldItalic.woff2` and `.woff`

### Step 2: Import Font CSS

In your app's main entry point (usually `index.js`, `main.js`, or `App.js`):

```javascript
// Import Rotina fonts
import '@min-apps/design-system/src/assets/fonts/rotina/rotina.css';

// Or if you copied to public folder, import custom CSS:
// import './fonts/rotina.css';
```

### Step 3: Font Override Auto-Initializes

The font override system automatically initializes when you call `initTheme()`, which you should already have in your app:

```javascript
import { initTheme } from '@min-apps/design-system';

// This now initializes both theme AND font override
initTheme();
```

No additional initialization code is needed!

### Step 4: Add Font Settings to Appearance Page

Add the `FontOverrideSettings` component to your app's settings or appearance page:

```javascript
import { FontOverrideSettings } from '@min-apps/design-system';

function SettingsPage() {
  return (
    <div className="settings-page">
      <h1>Settings</h1>
      
      {/* Existing settings sections */}
      <ThemeToggle />
      
      {/* Add font override settings */}
      <FontOverrideSettings />
    </div>
  );
}
```

### Step 5: Import Component Styles

Import the font override component styles:

```javascript
import '@min-apps/design-system/src/components/FontOverrideSettings.css';
```

Or add to your existing CSS bundle.

---

## App-Specific Integration

### WatchedIt (Movie Tracking App)

**Theme:** Purple (#7C3AED)

#### Recommended Font Configuration

For a cinematic, bold feel:

```javascript
import { enableFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';

// Optional: Set app-specific default fonts
enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.EXTRA_BOLD,  // Strong movie titles
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.BOLD,        // Section headers
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,        // Descriptions
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.SEMIBOLD,         // Buttons
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.LIGHT,       // Metadata
});
```

#### Integration Location

Add `FontOverrideSettings` to:
- Settings page (`src/pages/Settings.js` or similar)
- Appearance/Preferences section

#### Example Settings Page

```javascript
// src/pages/Settings.js
import React from 'react';
import { ThemeToggle, FontOverrideSettings } from '@min-apps/design-system';
import '@min-apps/design-system/src/components/FontOverrideSettings.css';

export function SettingsPage() {
  return (
    <div className="watchedit-settings">
      <h1>Settings</h1>
      
      <section>
        <h2>Appearance</h2>
        <ThemeToggle />
        <FontOverrideSettings />
      </section>
    </div>
  );
}
```

---

### PodLink (Podcast App)

**Theme:** Orange (#F59E0B)

#### Recommended Font Configuration

For an approachable, audio-focused feel:

```javascript
import { enableFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';

// Optional: Set app-specific default fonts
enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,        // Podcast titles
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,    // Episode titles
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,        // Show notes
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,           // Player controls
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,     // Episode info
});
```

#### Integration Location

Add `FontOverrideSettings` to:
- Settings page
- Account/Preferences section
- May want to place near audio quality settings

#### Audio Player Considerations

The UI tier fonts will apply to player controls. Test that button labels remain legible:

```css
/* Ensure player controls work with custom fonts */
.player-button {
  font-family: var(--font-ui);
  font-weight: var(--font-weight-ui);
}
```

---

### YourTube (Video App)

**Theme:** Red (#EF4444)

#### Recommended Font Configuration

For a modern, video-focused feel:

```javascript
import { enableFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';

// Optional: Set app-specific default fonts
enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,        // Video titles
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,    // Channel names
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,        // Descriptions
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,           // Video controls
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,     // View counts, dates
});
```

#### Integration Location

Add `FontOverrideSettings` to:
- Settings page
- User preferences section

#### Video Overlay Considerations

If you have video overlays with text, ensure contrast is maintained:

```css
/* Video overlay text */
.video-overlay-title {
  font-family: var(--font-display);
  font-weight: var(--font-weight-display);
  text-shadow: 0 2px 4px rgba(0, 0, 0, 0.5); /* Maintain readability */
}
```

---

### Cyclismo Guide (Cycling App)

**Theme:** Green (#10B981)

#### Recommended Font Configuration

For a clean, performance-focused feel:

```javascript
import { enableFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';

// Optional: Set app-specific default fonts
enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,        // Race names
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,    // Stage headers
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.LIGHT,          // Race details (clean, airy)
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,           // Map controls
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,     // Stats, distances
});
```

#### Integration Location

Add `FontOverrideSettings` to:
- Settings page
- User preferences section
- May want to place near map settings

#### Map Label Considerations

If you have map overlays with labels, ensure they remain legible:

```css
/* Map labels and markers */
.map-label {
  font-family: var(--font-caption);
  font-weight: var(--font-weight-caption);
  font-size: 12px;
}

/* Race stage markers */
.stage-marker {
  font-family: var(--font-ui);
  font-weight: var(--font-weight-ui);
}
```

---

## Testing Checklist

After integration, test each of the following:

### Visual Testing

- [ ] All heading sizes (H1-H6) render correctly
- [ ] Body text is legible and properly spaced
- [ ] Button labels are clear and properly sized
- [ ] Form labels and inputs look correct
- [ ] Captions and small text are readable
- [ ] Font weights are visually distinct

### Functional Testing

- [ ] Font override toggle works (enable/disable)
- [ ] Font tier selectors update the UI immediately
- [ ] Settings persist after page reload
- [ ] Settings persist across browser sessions
- [ ] Reset to defaults button works correctly
- [ ] Font preview displays correctly for each weight

### Responsive Testing

- [ ] Fonts work well on mobile devices
- [ ] Fonts work well on tablets
- [ ] Fonts work well on desktop
- [ ] Font loading doesn't cause layout shift
- [ ] Fonts load properly on slow connections

### Accessibility Testing

- [ ] Text remains readable with custom fonts
- [ ] Contrast ratios meet WCAG standards
- [ ] Font weights provide proper hierarchy
- [ ] Screen readers work correctly
- [ ] Keyboard navigation still functions

### Performance Testing

- [ ] Initial page load time (fonts should lazy-load)
- [ ] Font swap behavior (FOUT/FOIT)
- [ ] Bundle size impact
- [ ] Subsequent page loads (cached fonts)

---

## Common Issues and Solutions

### Issue: Fonts Not Loading

**Solution:**
1. Check font files are in the correct location
2. Verify CSS import path is correct
3. Check browser console for 404 errors
4. Ensure CORS headers if serving from different domain

### Issue: Font Override Not Persisting

**Solution:**
1. Check localStorage is available (not disabled)
2. Verify no browser extensions blocking storage
3. Check for JavaScript errors in console
4. Test in incognito/private mode

### Issue: Fonts Look Blurry

**Solution:**
1. Ensure `font-display: swap` is set (already in rotina.css)
2. Check browser zoom level (should be 100%)
3. Verify font files aren't corrupted
4. Test on different devices

### Issue: Layout Shifts When Font Loads

**Solution:**
1. Set `font-display: swap` (already configured)
2. Consider setting size-adjust in @font-face
3. Preload critical fonts:
```html
<link rel="preload" href="/fonts/rotina/Rotina-Regular.woff2" as="font" type="font/woff2" crossorigin>
```

### Issue: Font Doesn't Apply to Certain Elements

**Solution:**
1. Check if element has inline styles overriding font-family
2. Verify CSS specificity isn't preventing application
3. Add explicit font-family using CSS variables:
```css
.custom-element {
  font-family: var(--font-body);
}
```

---

## Advanced Customization

### Per-App Custom Font Presets

Create app-specific presets users can choose from:

```javascript
// In your app's settings
const WATCHEDIT_PRESETS = {
  cinematic: {
    [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.EXTRA_BOLD,
    [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.BOLD,
    [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,
    [FONT_TIERS.UI]: ROTINA_WEIGHTS.SEMIBOLD,
    [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.LIGHT,
  },
  classic: {
    [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,
    [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,
    [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,
    [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,
    [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,
  },
  minimal: {
    [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.LIGHT,
    [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.REGULAR,
    [FONT_TIERS.BODY]: ROTINA_WEIGHTS.LIGHT,
    [FONT_TIERS.UI]: ROTINA_WEIGHTS.REGULAR,
    [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.THIN,
  },
};
```

### Custom Settings UI

Build a custom UI that matches your app's design:

```javascript
import React, { useState } from 'react';
import { enableFontOverride } from '@min-apps/design-system';

function WatcheditFontSettings() {
  const [preset, setPreset] = useState('classic');

  const applyPreset = (presetName) => {
    setPreset(presetName);
    enableFontOverride(WATCHEDIT_PRESETS[presetName]);
  };

  return (
    <div className="font-presets">
      <h3>Font Style</h3>
      <div className="preset-buttons">
        {Object.keys(WATCHEDIT_PRESETS).map(name => (
          <button
            key={name}
            onClick={() => applyPreset(name)}
            className={preset === name ? 'active' : ''}
          >
            {name.charAt(0).toUpperCase() + name.slice(1)}
          </button>
        ))}
      </div>
    </div>
  );
}
```

---

## Migration Timeline

Suggested rollout approach:

1. **Week 1:** WatchedIt (most mature app, test integration)
2. **Week 2:** Review feedback, adjust if needed
3. **Week 3:** PodLink and YourTube (parallel integration)
4. **Week 4:** Cyclismo Guide
5. **Week 5:** User testing and refinements

---

## Support and Resources

- [Font Override Documentation](./font-override.md)
- [Typography Tokens Reference](./tokens.md#typography)
- [Design System GitHub Issues](https://github.com/min-apps/design-system/issues)

---

## Conclusion

The font override system provides a powerful way to customize the visual identity of each min app while maintaining consistency through the design system. By following this guide, each app can offer users the ability to personalize their experience with the beautiful Rotina typeface.
