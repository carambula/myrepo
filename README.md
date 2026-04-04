# Min Apps Design System

A unified design system for the min apps suite: **WatchedIt** (mov min), **podlink** (pod min), **yourtube** (vid min), and **Cyclismo guide** (cyc min).

## Native apps (iOS / Android) — read this first

The suite ships as **native** apps. **`global.css` and JavaScript tokens do not change what Xcode or Gradle compile.** To align margins and spacing with mov min, each app must use the generated artifacts in **[`native/`](./native/)**:

- **[`native/MinPageMargins.swift`](./native/MinPageMargins.swift)** + **[`native/MinPageInsets.swift`](./native/MinPageInsets.swift)** — **both** required on iOS: constants plus `uiEdgeInsets(traitCollection:)` / size-class padding so **phones use 12pt horizontal**, not 16pt everywhere
- **[`native/android/values/min_page_content_insets.xml`](./native/android/values/min_page_content_insets.xml)** + **[`values-sw600dp/`](./native/android/values-sw600dp/min_page_content_insets.xml)** — use `@dimen/min_page_padding_*` so **handsets vs tablets** track automatically (same as web mobile vs desktop margins)
- **[`native/android/values/min_page_margins.xml`](./native/android/values/min_page_margins.xml)** — explicit token pairs when needed
- **[`native/spacing.json`](./native/spacing.json)** — full spacing scale for tooling or hand wiring

Regenerate after editing [`src/tokens/spacing.js`](./src/tokens/spacing.js):

```bash
npm run build:native
```

Full workflow: **[docs/native-tokens.md](./docs/native-tokens.md)** and **[native/README.md](./native/README.md)**.

## Overview

This design system harmonizes the visual and interface language across all min apps, providing:

- **Design Tokens**: Centralized color, spacing, typography, and other design values
- **Theming System**: Interchangeable themes that work across all apps
- **Font Override System**: Custom font selection from the Rotina family with per-tier customization
- **Shared Components**: Common UI components with consistent styling
- **Layout Patterns**: Standardized margins, positioning, and spacing
- **Templates**: Pre-built page layouts and component compositions
- **Notification System**: Unified notification preferences and background job scheduling
- **Onboarding System**: Consistent, beautiful first-run experiences for all apps
- **Deep Linking System**: Comprehensive deep linking with bias towards min apps and user preference support
- **Storage System**: Safe data storage with automatic backups and version-controlled updates

## Installation

```bash
npm install @min-apps/design-system
```

## Usage

### Import Design Tokens

```javascript
import { tokens } from '@min-apps/design-system/tokens';
import { lightTheme, darkTheme } from '@min-apps/design-system/themes';
```

### Import Components

```javascript
import { Button, ListItem, AppHeader, BottomSheet } from '@min-apps/design-system/components';
```

### Import Layout Components

```javascript
import { AppLayout, ContentContainer } from '@min-apps/design-system/layouts';
```

### Apply Global Styles

```javascript
import '@min-apps/design-system/styles.css';
```

### Use Font Override System

```javascript
import { 
  FontOverrideSettings,
  enableFontOverride,
  FONT_TIERS,
  ROTINA_WEIGHTS 
} from '@min-apps/design-system';
import '@min-apps/design-system/src/assets/fonts/rotina/rotina.css';

// Add font override settings UI to your appearance page
<FontOverrideSettings />

// Or programmatically enable with custom configuration
enableFontOverride({
  [FONT_TIERS.DISPLAY]: ROTINA_WEIGHTS.BOLD,
  [FONT_TIERS.HEADING]: ROTINA_WEIGHTS.SEMIBOLD,
  [FONT_TIERS.BODY]: ROTINA_WEIGHTS.REGULAR,
  [FONT_TIERS.UI]: ROTINA_WEIGHTS.MEDIUM,
  [FONT_TIERS.CAPTION]: ROTINA_WEIGHTS.REGULAR,
});
```

### Use Notification System

```javascript
import { 
  NotificationSettingsPage,
  loadNotificationPreferences,
  APP_IDS 
} from '@min-apps/design-system/notifications';

// Render notification settings page
<NotificationSettingsPage appId={APP_IDS.CYCLISMO} />

// Load preferences programmatically
const preferences = loadNotificationPreferences(APP_IDS.CYCLISMO);
```

### Use Onboarding System

```javascript
import {
  OnboardingContainer,
  cyclismoOnboardingConfig,
  OnboardingManager,
} from '@min-apps/design-system/onboarding';

// Check if onboarding should be shown
if (OnboardingManager.shouldShowOnboarding('cyclismo')) {
  // Render onboarding
  <OnboardingContainer
    config={cyclismoOnboardingConfig}
    onComplete={(settings) => {
      // Apply default settings and navigate to app
    }}
    onRequestNotifications={async () => {
      const permission = await Notification.requestPermission();
    }}
  />
}
```

### Use Deep Linking System

```javascript
import { 
  DeepLink,
  openLink,
  DeepLinkPreferencesPanel 
} from '@min-apps/design-system/deepLinking';

// Use DeepLink component for automatic deep linking
<DeepLink href="https://www.themoviedb.org/movie/550">
  Check out Fight Club
</DeepLink>

// Open links programmatically
await openLink('https://www.youtube.com/watch?v=dQw4w9WgXcQ');

// Add preferences UI to settings
<DeepLinkPreferencesPanel title="Link Preferences" />
```

### Use Bottom Sheet Component

```javascript
import { BottomSheet } from '@min-apps/design-system/components';
import '@min-apps/design-system/components/BottomSheet.css';

// Use BottomSheet with blur and darkening effects
<BottomSheet 
  isOpen={isOpen}
  onClose={() => setIsOpen(false)}
  detent="large"
  onDetentChange={(newDetent) => setDetent(newDetent)}
>
  <h2>Sheet Content</h2>
  <p>The backdrop blur and darkening intensifies as the sheet approaches large detent.</p>
</BottomSheet>
```

### Use Safe Storage System

```javascript
import { 
  quickInit,
  createDataStorage
} from '@min-apps/design-system/storage';

// Initialize app with safe database updates
await quickInit('watchedit', movieDatabase, '2024.03.01', {
  updatePrompt: 'notify',
  onUpdateComplete: (result) => {
    console.log('Database updated!', result);
  }
});

// Use namespaced storage for user data
const storage = createDataStorage('watchedit');
storage.saveUserData('watchlist', [1, 2, 3]);
storage.saveUserData('ratings', { 1: 5, 2: 4 });

// User data is preserved during reference data updates
const watchlist = storage.getUserData('watchlist', []);
```

## Design Principles

### Consistency
All apps share the same:
- Margins and padding values
- Top positioning for common elements
- SVG asset sizing and placement
- Button styles and positioning
- List element patterns and spacing

### Theming
Themes can be interchanged between apps. Each theme defines:
- Color palette
- Typography scale
- Spacing system
- Shadow and elevation values
- Border radius values

### Accessibility
All components follow WCAG 2.1 AA standards with:
- Proper color contrast
- Keyboard navigation
- Screen reader support
- Focus indicators

## Structure

```
native/               # Generated: Swift, Kotlin, Android dimens, spacing.json (npm run build:native)
scripts/              # build-native-tokens.js — compile tokens → native/
src/
├── tokens/           # Design tokens (colors, spacing, typography, etc.) — source for native/
├── themes/           # Theme configurations
├── appearance/       # Font override and appearance customization
├── assets/           # Font files and other assets
├── components/       # Shared UI components
├── layouts/          # Layout components and templates
├── notifications/    # Notification preferences and scheduling
├── onboarding/       # Onboarding flows and configurations
├── deepLinking/      # Deep linking system with min app bias
├── storage/          # Safe data storage and update utilities
└── utils/            # Utility functions and helpers
```

## Documentation

See the `/docs` folder for detailed documentation on:
- **Native tokens** — [docs/native-tokens.md](./docs/native-tokens.md) (how iOS/Android consume this repo)
- Design tokens reference
- Component API documentation
- Theming guide
- Migration guide for existing apps
- **Art tile guidelines** (NEW) - Standardized radii for primary content artwork
- **Font override system guide**
- **Font override integration guide**
- **List tap behavior guidelines**
- Notification system guide
- Onboarding system guide
- Deep linking system guide
- **Safe data updates guide** (NEW) - Prevent user data loss during database updates
- Best practices

## License

MIT
