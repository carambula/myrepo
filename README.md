# Min Apps Design System

A unified design system for the min apps suite: **WatchedIt** (mov min), **podlink** (pod min), **yourtube** (vid min), and **Cyclismo guide** (cyc min).

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
src/
├── tokens/           # Design tokens (colors, spacing, typography, etc.)
├── themes/           # Theme configurations
├── appearance/       # Font override and appearance customization
├── assets/           # Font files and other assets
├── components/       # Shared UI components
├── layouts/          # Layout components and templates
├── notifications/    # Notification preferences and scheduling
├── onboarding/       # Onboarding flows and configurations
├── deepLinking/      # Deep linking system with min app bias
└── utils/            # Utility functions and helpers
```

## Documentation

See the `/docs` folder for detailed documentation on:
- Design tokens reference
- Component API documentation
- Theming guide
- Migration guide for existing apps
- **Font override system guide** (NEW)
- **Font override integration guide** (NEW)
- **List tap behavior guidelines** (NEW)
- Notification system guide
- Onboarding system guide
- Deep linking system guide
- Best practices

## License

MIT
