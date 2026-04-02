# Onboarding System Documentation

## Overview

The min apps design system includes a comprehensive onboarding system that provides a consistent, beautiful first-run experience across all four apps (WatchedIt, Podlink, Yourtube, Cyclismo Guide). The onboarding flows are designed to:

- Introduce users to app features in a clear, engaging way
- Request necessary permissions (notifications, etc.)
- Allow theme customization
- Set up initial preferences
- Maintain design consistency across all apps

## Table of Contents

1. [Architecture](#architecture)
2. [Components](#components)
3. [App-Specific Configurations](#app-specific-configurations)
4. [Implementation Guide](#implementation-guide)
5. [Customization](#customization)
6. [Best Practices](#best-practices)

## Architecture

The onboarding system consists of:

1. **Core Components** - Reusable UI components for building onboarding flows
2. **Flow Manager** - Handles navigation and state management
3. **Configuration Files** - App-specific onboarding steps and content
4. **Persistence Layer** - Tracks onboarding progress and completion

```
src/
├── components/
│   ├── OnboardingFlow.js          # Container with navigation
│   ├── OnboardingStep.js          # Individual step wrapper
│   ├── FeatureHighlight.js        # Feature showcase component
│   ├── PermissionRequest.js       # Permission request UI
│   └── OnboardingContainer.js     # Complete integration
├── onboarding/
│   ├── onboardingManager.js       # State management
│   ├── watcheditOnboarding.js     # WatchedIt config
│   ├── podlinkOnboarding.js       # Podlink config
│   ├── yourtubeOnboarding.js      # Yourtube config
│   └── cyclismoOnboarding.js      # Cyclismo config
```

## Components

### OnboardingFlow

The main container component that manages navigation through onboarding steps.

```javascript
import { OnboardingFlow } from '@min-apps/design-system';

<OnboardingFlow
  currentStep={1}
  totalSteps={5}
  onNext={() => setStep(step + 1)}
  onPrevious={() => setStep(step - 1)}
  onSkip={handleSkip}
  onComplete={handleComplete}
  showSkip={true}
  showPrevious={true}
  nextButtonText="Next"
  previousButtonText="Previous"
  skipButtonText="Skip"
  completeButtonText="Get Started"
>
  {/* Step content goes here */}
</OnboardingFlow>
```

**Props:**
- `currentStep` (number) - Current step number (1-indexed)
- `totalSteps` (number) - Total number of steps
- `onNext` (function) - Called when user clicks next
- `onPrevious` (function) - Called when user clicks previous
- `onSkip` (function) - Called when user skips onboarding
- `onComplete` (function) - Called when user completes onboarding
- `showSkip` (boolean) - Show skip button
- `showPrevious` (boolean) - Show previous button
- `nextButtonText` (string) - Text for next button
- `previousButtonText` (string) - Text for previous button
- `skipButtonText` (string) - Text for skip button
- `completeButtonText` (string) - Text for complete button

### OnboardingStep

Individual step component with icon, title, description, and content.

```javascript
import { OnboardingStep } from '@min-apps/design-system';

<OnboardingStep
  icon="/assets/welcome-icon.svg"
  iconAlt="Welcome"
  title="Welcome to Our App"
  description="Let's get you started with a quick tour."
  stepNumber={1}
  totalSteps={5}
>
  {/* Additional content */}
</OnboardingStep>
```

**Props:**
- `icon` (string) - Icon image URL
- `iconAlt` (string) - Alt text for icon
- `title` (string) - Step title
- `description` (string) - Step description
- `stepNumber` (number) - Current step number
- `totalSteps` (number) - Total steps (for progress dots)
- `children` (node) - Additional content

### FeatureHighlight

Displays a feature with icon, title, and description.

```javascript
import { FeatureHighlight } from '@min-apps/design-system';

<FeatureHighlight
  icon="/assets/feature-icon.svg"
  title="Smart Queue"
  description="Automatically organize your content in a smart queue."
/>
```

**Props:**
- `icon` (string) - Feature icon URL
- `iconAlt` (string) - Alt text for icon
- `title` (string) - Feature title
- `description` (string) - Feature description

### PermissionRequest

UI for requesting user permissions with benefits list.

```javascript
import { PermissionRequest } from '@min-apps/design-system';

<PermissionRequest
  icon="/assets/notification-icon.svg"
  title="Enable Notifications"
  description="Get notified about important updates."
  benefits={[
    'Never miss new content',
    'Daily summaries',
    'Customizable timing',
  ]}
  permissionType="notifications"
  onGrant={handleGrantPermission}
  onDeny={handleDenyPermission}
  grantButtonText="Allow"
  denyButtonText="Not Now"
/>
```

**Props:**
- `icon` (string) - Permission icon URL
- `title` (string) - Permission request title
- `description` (string) - Permission description
- `benefits` (array) - Array of benefit strings
- `permissionType` (string) - Type of permission ('notifications', etc.)
- `onGrant` (function) - Called when user grants permission
- `onDeny` (function) - Called when user denies permission
- `grantButtonText` (string) - Text for grant button
- `denyButtonText` (string) - Text for deny button

### OnboardingContainer

High-level component that integrates everything. This is the recommended way to implement onboarding.

```javascript
import { OnboardingContainer } from '@min-apps/design-system';
import { cyclismoOnboardingConfig } from '@min-apps/design-system/onboarding';

<OnboardingContainer
  config={cyclismoOnboardingConfig}
  onComplete={(settings) => {
    console.log('Onboarding completed with settings:', settings);
    navigateToApp();
  }}
  onSkip={() => {
    console.log('Onboarding skipped');
    navigateToApp();
  }}
  onRequestNotifications={async () => {
    const permission = await Notification.requestPermission();
    console.log('Permission:', permission);
  }}
  onSelectTheme={(theme) => {
    console.log('Theme selected:', theme);
  }}
/>
```

**Props:**
- `config` (object) - App-specific onboarding configuration
- `onComplete` (function) - Called when onboarding is completed
- `onSkip` (function) - Called when user skips onboarding
- `onRequestNotifications` (function) - Called when requesting notification permission
- `onSelectTheme` (function) - Called when user selects a theme

## App-Specific Configurations

Each app has a detailed configuration file that defines its onboarding flow.

### WatchedIt Configuration

```javascript
import { watcheditOnboardingConfig } from '@min-apps/design-system/onboarding';

// Configuration includes:
// - Welcome step
// - Feature highlights (Track, Discover, Watchlist, Podcasts)
// - Notification permission request
// - Theme selection
// - Ready step
```

**Steps:**
1. Welcome to WatchedIt
2. Discover Features (4 key features)
3. Notification Permission
4. Theme Selection
5. You're All Set!

### Podlink Configuration

```javascript
import { podlinkOnboardingConfig } from '@min-apps/design-system/onboarding';

// Configuration includes:
// - Welcome step
// - Feature highlights (Queue, Priority, Apple Intelligence, Minimal)
// - Notification permission request
// - Priority podcast setup
// - Theme selection
// - Ready step
```

**Steps:**
1. Welcome to Podlink
2. Powerful Yet Simple (4 key features)
3. Never Miss an Episode (Notifications)
4. Set Priority Podcasts
5. Theme Selection
6. Ready to Listen!

### Yourtube Configuration

```javascript
import { yourtubeOnboardingConfig } from '@min-apps/design-system/onboarding';

// Configuration includes:
// - Welcome step
// - Feature highlights (Queue, Priority, Apple Intelligence, Focus)
// - Notification permission request
// - Priority channel setup
// - Theme selection
// - Ready step
```

**Steps:**
1. Welcome to Yourtube
2. Watch Intentionally (4 key features)
3. Stay in the Loop (Notifications)
4. Choose Priority Channels
5. Theme Selection
6. You're Ready!

### Cyclismo Configuration

```javascript
import { cyclismoOnboardingConfig } from '@min-apps/design-system/onboarding';

// Configuration includes:
// - Welcome step
// - Feature highlights (Schedule, Alerts, Recaps, Save)
// - Notification permission request
// - Notification customization
// - Theme selection
// - Ready step
```

**Steps:**
1. Welcome to Cyclismo
2. Follow Every Race (4 key features)
3. Race Day Notifications
4. Customize Notifications
5. Theme Selection
6. Ready to Race!

## Implementation Guide

### Basic Implementation

1. **Install the design system:**

```bash
npm install @min-apps/design-system
```

2. **Import the onboarding container and config:**

```javascript
import React from 'react';
import {
  OnboardingContainer,
  cyclismoOnboardingConfig,
  OnboardingManager,
} from '@min-apps/design-system';

function App() {
  const [showOnboarding, setShowOnboarding] = React.useState(
    OnboardingManager.shouldShowOnboarding('cyclismo')
  );

  if (showOnboarding) {
    return (
      <OnboardingContainer
        config={cyclismoOnboardingConfig}
        onComplete={(settings) => {
          // Apply default settings
          applySettings(settings);
          setShowOnboarding(false);
        }}
        onSkip={() => {
          setShowOnboarding(false);
        }}
        onRequestNotifications={async () => {
          const permission = await Notification.requestPermission();
          return permission === 'granted';
        }}
      />
    );
  }

  return <MainApp />;
}
```

### Advanced Implementation

For more control, you can build custom onboarding flows using individual components:

```javascript
import React from 'react';
import {
  OnboardingFlow,
  OnboardingStep,
  FeatureHighlight,
  PermissionRequest,
} from '@min-apps/design-system';

function CustomOnboarding() {
  const [step, setStep] = React.useState(1);

  const renderStep = () => {
    switch (step) {
      case 1:
        return (
          <OnboardingStep
            icon="/assets/welcome.svg"
            title="Welcome"
            description="Let's get started"
            stepNumber={step}
            totalSteps={3}
          />
        );
      
      case 2:
        return (
          <OnboardingStep
            title="Key Features"
            description="What you can do"
            stepNumber={step}
            totalSteps={3}
          >
            <FeatureHighlight
              icon="/assets/feature1.svg"
              title="Feature One"
              description="Description here"
            />
          </OnboardingStep>
        );
      
      case 3:
        return (
          <PermissionRequest
            title="Enable Notifications"
            description="Stay updated"
            benefits={['Benefit 1', 'Benefit 2']}
            onGrant={handleGrant}
            onDeny={handleDeny}
          />
        );
    }
  };

  return (
    <OnboardingFlow
      currentStep={step}
      totalSteps={3}
      onNext={() => setStep(step + 1)}
      onPrevious={() => setStep(step - 1)}
      onComplete={handleComplete}
    >
      {renderStep()}
    </OnboardingFlow>
  );
}
```

## OnboardingManager API

The `OnboardingManager` utility helps track onboarding state:

### Methods

```javascript
import { OnboardingManager } from '@min-apps/design-system';

// Check if onboarding is completed
const isCompleted = OnboardingManager.hasCompletedOnboarding('cyclismo');

// Mark onboarding as completed
OnboardingManager.markOnboardingComplete('cyclismo');

// Reset onboarding (for testing or re-onboarding)
OnboardingManager.resetOnboarding('cyclismo');

// Save current step
OnboardingManager.saveCurrentStep('cyclismo', 3);

// Get current step
const currentStep = OnboardingManager.getCurrentStep('cyclismo');

// Get completion date
const completedAt = OnboardingManager.getCompletionDate('cyclismo');

// Check if onboarding should be shown
const shouldShow = OnboardingManager.shouldShowOnboarding('cyclismo');

// Skip onboarding
OnboardingManager.skipOnboarding('cyclismo');

// Get all completed onboardings
const completed = OnboardingManager.getAllCompletedOnboardings();
```

## Customization

### Custom Step Types

You can extend the onboarding configuration with custom step types:

```javascript
const customConfig = {
  appId: 'myapp',
  appName: 'My App',
  steps: [
    {
      id: 'welcome',
      type: 'custom-welcome',
      title: 'Welcome',
      customData: {
        // Your custom data
      },
    },
  ],
};
```

### Styling

All onboarding components use design tokens and CSS variables:

```css
/* Override onboarding styles */
.min-onboarding-flow {
  /* Custom styles */
}

.min-onboarding-step__icon-container {
  /* Custom icon container */
  background: linear-gradient(135deg, var(--color-primary-main), var(--color-accent-main));
}
```

### Custom Icons

Replace default icons with your own:

```javascript
const config = {
  ...cyclismoOnboardingConfig,
  steps: cyclismoOnboardingConfig.steps.map(step => ({
    ...step,
    icon: `/my-custom-icons/${step.id}.svg`,
  })),
};
```

## Best Practices

### 1. Keep It Short

Limit onboarding to 5-6 steps maximum. Users want to start using the app quickly.

✅ **Good:**
- Welcome
- Key features (3-4 highlights)
- Permissions
- Theme
- Ready

❌ **Avoid:**
- Too many individual feature screens
- Lengthy explanations
- Unnecessary customization steps

### 2. Request Permissions Contextually

Explain why you need permissions before requesting them.

✅ **Good:**
```javascript
{
  title: 'Stay Updated',
  description: 'Get notified about new episodes from podcasts you follow.',
  benefits: [
    'Never miss new content',
    'Daily queue summaries',
    'Customizable timing',
  ],
}
```

❌ **Avoid:**
- Requesting permissions without context
- Generic "Enable notifications" without benefits

### 3. Show, Don't Just Tell

Use visual elements to demonstrate features:

```javascript
<FeatureHighlight
  icon="/icon.svg"
  title="Smart Queue"
  description="See how content automatically organizes based on your preferences."
/>
```

### 4. Allow Skipping

Always provide a skip option. Some users prefer to explore on their own:

```javascript
<OnboardingFlow
  showSkip={true}
  skipButtonText="Skip for now"
  onSkip={handleSkip}
/>
```

### 5. Persist Progress

Save the current step so users can resume if they exit:

```javascript
const currentStep = OnboardingManager.getCurrentStep('cyclismo');
OnboardingManager.saveCurrentStep('cyclismo', newStep);
```

### 6. Theme Integration

Ensure onboarding uses the app's theme colors:

```javascript
// Apply app theme before showing onboarding
import { applyTheme } from '@min-apps/design-system';
applyTheme('cyclismo');
```

### 7. Mobile Optimization

All onboarding components are responsive, but test on mobile:

```javascript
// Components automatically adjust spacing and font sizes
// Test on various screen sizes to ensure readability
```

### 8. Accessibility

Ensure all interactive elements are keyboard accessible:

```javascript
// All buttons have proper focus states
// Icons have alt text
// Colors meet contrast requirements
```

## Testing

### Test Onboarding Flow

```javascript
import { OnboardingManager } from '@min-apps/design-system';

// Reset onboarding for testing
OnboardingManager.resetOnboarding('cyclismo');

// Verify flow
const shouldShow = OnboardingManager.shouldShowOnboarding('cyclismo');
console.log('Should show onboarding:', shouldShow); // true

// Complete onboarding
OnboardingManager.markOnboardingComplete('cyclismo');

// Verify completion
const isComplete = OnboardingManager.hasCompletedOnboarding('cyclismo');
console.log('Is completed:', isComplete); // true
```

### Test Individual Components

```javascript
import { render, screen, fireEvent } from '@testing-library/react';
import { OnboardingStep } from '@min-apps/design-system';

test('renders onboarding step', () => {
  render(
    <OnboardingStep
      title="Welcome"
      description="Get started"
      stepNumber={1}
      totalSteps={3}
    />
  );
  
  expect(screen.getByText('Welcome')).toBeInTheDocument();
  expect(screen.getByText('Get started')).toBeInTheDocument();
});
```

## Examples

See `/examples/onboarding-example.html` for a complete working example.

## Support

For issues or questions:
1. Check this documentation
2. Review app-specific configurations
3. See component API documentation
4. Check example implementations

## Migration from Custom Onboarding

If you have existing onboarding, here's how to migrate:

1. **Map existing steps to configuration:**

```javascript
// Old custom onboarding
const oldSteps = [
  { title: 'Welcome', content: '...' },
  { title: 'Features', content: '...' },
];

// New configuration
const newConfig = {
  steps: [
    { id: 'welcome', title: 'Welcome', description: '...' },
    { id: 'features', title: 'Features', features: [...] },
  ],
};
```

2. **Replace components:**

```javascript
// Old
<CustomOnboardingStep>...</CustomOnboardingStep>

// New
<OnboardingStep>...</OnboardingStep>
```

3. **Update state management:**

```javascript
// Old
localStorage.setItem('onboarding-complete', 'true');

// New
OnboardingManager.markOnboardingComplete('cyclismo');
```

## Changelog

### Version 1.0.0
- Initial release
- Complete onboarding system for all 4 apps
- OnboardingManager for state persistence
- Full design token integration
- Mobile-responsive components
