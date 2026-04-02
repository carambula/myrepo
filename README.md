# Min Apps Design System

A unified design system for the min apps suite: **WatchedIt** (mov min), **podlink** (pod min), **yourtube** (vid min), and **Cyclismo guide** (cyc min).

## Overview

This design system harmonizes the visual and interface language across all min apps, providing:

- **Design Tokens**: Centralized color, spacing, typography, and other design values
- **Theming System**: Interchangeable themes that work across all apps
- **Shared Components**: Common UI components with consistent styling
- **Layout Patterns**: Standardized margins, positioning, and spacing
- **Templates**: Pre-built page layouts and component compositions
- **Notification System**: Unified notification preferences and background job scheduling
- **Onboarding System**: Consistent, beautiful first-run experiences for all apps
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
import { Button, ListItem, AppHeader } from '@min-apps/design-system/components';
```

### Import Layout Components

```javascript
import { AppLayout, ContentContainer } from '@min-apps/design-system/layouts';
```

### Apply Global Styles

```javascript
import '@min-apps/design-system/styles.css';
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
src/
├── tokens/           # Design tokens (colors, spacing, typography, etc.)
├── themes/           # Theme configurations
├── components/       # Shared UI components
├── layouts/          # Layout components and templates
├── notifications/    # Notification preferences and scheduling
├── onboarding/       # Onboarding flows and configurations
├── storage/          # Safe data storage and update utilities
└── utils/            # Utility functions and helpers
```

## Documentation

See the `/docs` folder for detailed documentation on:
- Design tokens reference
- Component API documentation
- Theming guide
- Migration guide for existing apps
- Notification system guide
- Onboarding system guide
- **Safe data updates guide** (NEW) - Prevent user data loss during database updates
- Best practices

## License

MIT
