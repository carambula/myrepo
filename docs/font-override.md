# Font Override System

The font override system allows users to customize the fonts used throughout min apps by selecting from the Rotina font family. Each tier of the typography scale can use a different weight.

## Overview

The font override feature provides:

- **Custom font selection** from the Rotina family (8 weights)
- **Per-tier customization** for different text styles
- **Persistent settings** saved in localStorage
- **Easy integration** with existing apps
- **Fallback support** to system fonts when disabled

## Font Tiers

The typography system is organized into six tiers:

### 1. Display (`display`)
Used for the largest headings (H1, H2)
- **Default Rotina weight:** Bold (700)
- **Use cases:** Page titles, hero headings

### 2. Heading (`heading`)
Used for section headings (H3, H4, H5, H6)
- **Default Rotina weight:** SemiBold (600)
- **Use cases:** Section titles, card headers

### 3. Body (`body`)
Used for body text and paragraphs
- **Default Rotina weight:** Regular (400)
- **Use cases:** Article text, descriptions, content

### 4. UI (`ui`)
Used for buttons, labels, and UI controls
- **Default Rotina weight:** Medium (500)
- **Use cases:** Buttons, form labels, navigation

### 5. Caption (`caption`)
Used for small text and captions
- **Default Rotina weight:** Regular (400)
- **Use cases:** Image captions, metadata, timestamps

### 6. Mono (`mono`)
Used for code and monospace text
- **Default:** System monospace (not overridden by Rotina)
- **Use cases:** Code blocks, technical content

## Available Rotina Weights

| Weight Name | CSS Weight | Font File Base Name |
|-------------|------------|---------------------|
| ExtraThin   | 200        | Rotina-ExtraThin    |
| Thin        | 250        | Rotina-Thin         |
| Light       | 300        | Rotina-Light        |
| Regular     | 400        | Rotina-Regular      |
| Medium      | 500        | Rotina-Medium       |
| SemiBold    | 600        | Rotina-SemiBold     |
| Bold        | 700        | Rotina-Bold         |
| ExtraBold   | 800        | Rotina-ExtraBold    |

Each weight is available in both Roman and Italic styles.

## Installation

### 1. Copy Rotina Font Files

Copy the Rotina font files from the Nuform Redux app to your app's assets:

```bash
# From Nuform Redux app
cp -r path/to/nuform-redux/fonts/rotina/* node_modules/@min-apps/design-system/src/assets/fonts/rotina/
```

Required files (both .woff2 and .woff formats):
- Rotina-ExtraThin, Rotina-ExtraThinItalic
- Rotina-Thin, Rotina-ThinItalic
- Rotina-Light, Rotina-LightItalic
- Rotina-Regular, Rotina-Italic
- Rotina-Medium, Rotina-MediumItalic
- Rotina-SemiBold, Rotina-SemiBoldItalic
- Rotina-Bold, Rotina-BoldItalic
- Rotina-ExtraBold, Rotina-ExtraBoldItalic

### 2. Import Font Override Styles

In your app's main CSS or JavaScript entry point:

```javascript
// Import the font override CSS
import '@min-apps/design-system/src/assets/fonts/rotina/rotina.css';
```

### 3. Initialize Font Override

The font override system is automatically initialized when you call `initTheme()`:

```javascript
import { initTheme } from '@min-apps/design-system';

// This now initializes both theme and font override
initTheme();
```

## Usage

### Programmatic API

#### Enable Font Override with Default Settings

```javascript
import { enableFontOverride } from '@min-apps/design-system';

// Enable with default Rotina weights
enableFontOverride();
```

#### Enable with Custom Configuration

```javascript
import { enableFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';

enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.EXTRA_BOLD,
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.BOLD,
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.LIGHT,
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,
});
```

#### Update Individual Tier

```javascript
import { updateFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';

// Change just the display tier
updateFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.EXTRA_BOLD,
});
```

#### Disable Font Override

```javascript
import { disableFontOverride } from '@min-apps/design-system';

disableFontOverride();
```

#### Check if Enabled

```javascript
import { isFontOverrideEnabled } from '@min-apps/design-system';

if (isFontOverrideEnabled()) {
  console.log('Custom fonts are active');
}
```

#### Get Current Configuration

```javascript
import { getFontOverrideConfig } from '@min-apps/design-system';

const config = getFontOverrideConfig();
console.log(config);
// {
//   enabled: true,
//   fonts: {
//     display: { name: 'Bold', weight: 700 },
//     heading: { name: 'SemiBold', weight: 600 },
//     ...
//   }
// }
```

### React Component

Use the `FontOverrideSettings` component to provide a UI for users:

```javascript
import { FontOverrideSettings } from '@min-apps/design-system';

function AppearanceSettings() {
  return (
    <div>
      <h1>Appearance</h1>
      <FontOverrideSettings />
    </div>
  );
}
```

The component provides:
- Toggle to enable/disable font override
- Dropdown selectors for each font tier
- Live preview of each selected font
- Reset to defaults button
- Instructions for users

### Custom Component Example

Build your own settings UI:

```javascript
import React, { useState } from 'react';
import {
  getFontOverrideConfig,
  updateFontOverride,
  FONT_TIERS,
  ROTINA_WEIGHTS,
} from '@min-apps/design-system';

function CustomFontSelector() {
  const [config, setConfig] = useState(getFontOverrideConfig());

  const handleChange = (tier, weight) => {
    updateFontOverride({ [tier]: weight });
    setConfig(getFontOverrideConfig());
  };

  return (
    <div>
      <select
        value={config.fonts[FONT_TIERS.BODY]?.weight}
        onChange={(e) => {
          const weight = Object.values(ROTINA_WEIGHTS).find(
            w => w.weight === parseInt(e.target.value)
          );
          handleChange(FONT_TIERS.BODY, weight);
        }}
      >
        {Object.values(ROTINA_WEIGHTS).map(weight => (
          <option key={weight.weight} value={weight.weight}>
            {weight.name}
          </option>
        ))}
      </select>
    </div>
  );
}
```

## CSS Variables

When font override is enabled, the following CSS custom properties are set:

```css
--font-display: 'Rotina', [system-fallbacks];
--font-weight-display: 700;

--font-heading: 'Rotina', [system-fallbacks];
--font-weight-heading: 600;

--font-body: 'Rotina', [system-fallbacks];
--font-weight-body: 400;

--font-ui: 'Rotina', [system-fallbacks];
--font-weight-ui: 500;

--font-caption: 'Rotina', [system-fallbacks];
--font-weight-caption: 400;
```

### Using CSS Variables in Custom Styles

```css
/* Use the body font tier */
.my-component {
  font-family: var(--font-body);
  font-weight: var(--font-weight-body);
}

/* Use the display font tier */
.hero-title {
  font-family: var(--font-display);
  font-weight: var(--font-weight-display);
}
```

## How It Works

### 1. Font Loading

When font override is enabled, the system:
1. Dynamically loads `rotina.css` containing @font-face declarations
2. Sets CSS custom properties on `:root`
3. Updates `data-font-override="true"` attribute on `<html>`

### 2. Font Application

CSS rules apply fonts based on element type:

```css
/* Automatically applied by global.css */
body {
  font-family: var(--font-body, [system-fallbacks]);
}

h1, h2 {
  font-family: var(--font-display, var(--font-body, [system-fallbacks]));
}

h3, h4, h5, h6 {
  font-family: var(--font-heading, var(--font-body, [system-fallbacks]));
}

button, input, select, textarea, label {
  font-family: var(--font-ui, var(--font-body, [system-fallbacks]));
}
```

### 3. Persistence

Settings are saved to localStorage:

```javascript
localStorage.setItem('min-apps-font-override', JSON.stringify({
  enabled: true,
  fonts: { /* tier configurations */ }
}));
```

## Integration with Min Apps

### WatchedIt (Movie Tracking)

```javascript
// In WatchedIt's main app file
import { initTheme, enableFontOverride, FONT_TIERS, ROTINA_WEIGHTS } from '@min-apps/design-system';
import '@min-apps/design-system/src/assets/fonts/rotina/rotina.css';

// Initialize with custom weights for movie app
initTheme();
enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,
});
```

### PodLink (Podcast App)

Similar pattern for each app with app-specific defaults if desired.

## Best Practices

### 1. Provide User Control

Always give users a way to toggle font override on/off:

```javascript
<FontOverrideSettings />
```

### 2. Test with Font Override Enabled

Test your app with font override enabled to ensure proper rendering:

```javascript
// In development/test mode
enableFontOverride();
```

### 3. Handle Font Loading

The `font-display: swap` ensures text is visible even while fonts load.

### 4. Maintain Fallbacks

Always keep system font fallbacks in CSS:

```css
font-family: var(--font-body, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif);
```

### 5. Consider Performance

Font files are loaded only when font override is enabled, keeping initial page loads fast.

## Troubleshooting

### Fonts Not Appearing

1. **Check font files are copied:**
   ```bash
   ls node_modules/@min-apps/design-system/src/assets/fonts/rotina/
   ```

2. **Verify CSS is imported:**
   ```javascript
   import '@min-apps/design-system/src/assets/fonts/rotina/rotina.css';
   ```

3. **Check browser console for 404 errors**

4. **Verify font override is enabled:**
   ```javascript
   import { isFontOverrideEnabled } from '@min-apps/design-system';
   console.log(isFontOverrideEnabled());
   ```

### Fonts Look Wrong

1. **Check weight mappings** - ensure the right weight is selected for each tier
2. **Inspect CSS variables** - open DevTools and check `:root` for `--font-*` variables
3. **Verify @font-face** - check Network tab to see if fonts are loading

### Settings Not Persisting

1. **Check localStorage** - ensure it's available and not blocked
2. **Verify permissions** - some browsers block localStorage in private mode
3. **Check for errors** - open console and look for localStorage errors

## API Reference

### Constants

- `FONT_TIERS` - Object with tier names (DISPLAY, HEADING, BODY, UI, CAPTION, MONO)
- `ROTINA_WEIGHTS` - Object with weight definitions (EXTRA_THIN through EXTRA_BOLD)
- `DEFAULT_FONT_OVERRIDE` - Default tier-to-weight mappings

### Functions

- `enableFontOverride(fonts?)` - Enable with optional custom configuration
- `disableFontOverride()` - Disable and restore system fonts
- `updateFontOverride(fonts)` - Update specific tiers
- `applyFontOverride(config?)` - Apply configuration to document
- `removeFontOverride()` - Remove CSS variables and restore defaults
- `getFontOverrideConfig()` - Get current configuration
- `getSavedFontOverride()` - Get saved configuration from localStorage
- `saveFontOverride(config)` - Save configuration to localStorage
- `isFontOverrideEnabled()` - Check if font override is active
- `initFontOverride()` - Initialize on page load
- `createFontOverrideConfig(fonts)` - Create new configuration object

### Components

- `<FontOverrideSettings />` - Complete UI for font customization

## License

Ensure you have the appropriate license to use Rotina fonts in your applications. Rotina is a commercial typeface by Nuform Type and Sharp Type.

## See Also

- [Typography Tokens](./tokens.md#typography)
- [Theming Guide](./theming.md)
- [Component Styling](./component-styling.md)
