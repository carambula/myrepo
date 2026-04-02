# Onboarding Quick Start Guide

## 5-Minute Setup

Get onboarding working in your min app in 5 minutes.

### Step 1: Install

```bash
npm install @min-apps/design-system
```

### Step 2: Import

```javascript
import {
  OnboardingContainer,
  OnboardingManager,
  cyclismoOnboardingConfig,  // or podlinkOnboardingConfig, yourtubeOnboardingConfig, watcheditOnboardingConfig
} from '@min-apps/design-system';
```

### Step 3: Add to Your App

```javascript
function App() {
  const [showOnboarding, setShowOnboarding] = React.useState(
    OnboardingManager.shouldShowOnboarding('cyclismo')
  );

  if (showOnboarding) {
    return (
      <OnboardingContainer
        config={cyclismoOnboardingConfig}
        onComplete={() => setShowOnboarding(false)}
        onSkip={() => setShowOnboarding(false)}
      />
    );
  }

  return <YourMainApp />;
}
```

That's it! You now have a complete onboarding experience.

## What You Get

Each app's onboarding includes:

### WatchedIt (Movie Tracking)
1. Welcome screen
2. Feature highlights (Track, Discover, Watchlist, Podcasts)
3. Notification permission request
4. Theme selection
5. Ready screen

### Podlink (Podcast Manager)
1. Welcome screen
2. Feature highlights (Queue, Priority, Apple Intelligence, Minimal)
3. Notification permission request
4. Priority podcast setup
5. Theme selection
6. Ready screen

### Yourtube (Video Queue)
1. Welcome screen
2. Feature highlights (Queue, Priority, Apple Intelligence, Focus)
3. Notification permission request
4. Priority channel setup
5. Theme selection
6. Ready screen

### Cyclismo Guide (Race Tracking)
1. Welcome screen
2. Feature highlights (Schedule, Alerts, Recaps, Save)
3. Notification permission request
4. Notification customization
5. Theme selection
6. Ready screen

## Common Tasks

### Request Notification Permission

```javascript
<OnboardingContainer
  config={cyclismoOnboardingConfig}
  onRequestNotifications={async () => {
    const permission = await Notification.requestPermission();
    console.log('Permission:', permission);
  }}
/>
```

### Apply Settings After Onboarding

```javascript
<OnboardingContainer
  config={cyclismoOnboardingConfig}
  onComplete={(defaultSettings) => {
    // Save settings to your backend
    await api.saveSettings(defaultSettings);
    
    // Apply notification preferences
    saveNotificationPreferences('cyclismo', defaultSettings.notifications);
    
    // Navigate to main app
    setShowOnboarding(false);
  }}
/>
```

### Reset Onboarding (for Testing)

```javascript
import { OnboardingManager } from '@min-apps/design-system';

// Reset onboarding
OnboardingManager.resetOnboarding('cyclismo');

// Force show onboarding again
const shouldShow = OnboardingManager.shouldShowOnboarding('cyclismo');
console.log(shouldShow); // true
```

### Check Completion Status

```javascript
// Check if user completed onboarding
const isComplete = OnboardingManager.hasCompletedOnboarding('cyclismo');

// Get completion date
const completedAt = OnboardingManager.getCompletionDate('cyclismo');

// Get all completed onboardings
const allCompleted = OnboardingManager.getAllCompletedOnboardings();
```

## Customization

### Use Custom Icons

```javascript
const customConfig = {
  ...cyclismoOnboardingConfig,
  steps: cyclismoOnboardingConfig.steps.map(step => ({
    ...step,
    icon: `/my-icons/${step.id}.svg`,
  })),
};

<OnboardingContainer config={customConfig} />
```

### Customize Button Text

The last step's `ctaText` is used for the final button:

```javascript
const config = {
  ...cyclismoOnboardingConfig,
  steps: cyclismoOnboardingConfig.steps.map((step, index) => 
    index === cyclismoOnboardingConfig.steps.length - 1
      ? { ...step, ctaText: 'Let\'s Go!' }
      : step
  ),
};
```

### Add Custom Steps

```javascript
const config = {
  ...cyclismoOnboardingConfig,
  steps: [
    ...cyclismoOnboardingConfig.steps.slice(0, 2),
    {
      id: 'custom-step',
      title: 'Custom Feature',
      description: 'This is a custom step',
      features: [
        {
          icon: '/custom-icon.svg',
          title: 'Custom Title',
          description: 'Custom description',
        },
      ],
    },
    ...cyclismoOnboardingConfig.steps.slice(2),
  ],
};
```

## Styling

All components use design system tokens and CSS variables:

```css
/* Override onboarding styles */
.min-onboarding-flow {
  /* Your custom styles */
}

/* Customize icon container */
.min-onboarding-step__icon-container {
  background: linear-gradient(135deg, #FF6B6B, #FF4757);
}

/* Customize buttons */
.min-onboarding-flow__next {
  background-color: #custom-color;
}
```

## Best Practices

### ✅ Do
- Keep onboarding to 5-6 steps maximum
- Show clear benefits for permissions
- Allow users to skip
- Save progress so users can resume
- Use app-specific icons and branding
- Test on mobile devices

### ❌ Don't
- Force users through onboarding
- Request permissions without context
- Use generic placeholder content
- Skip theme selection step
- Forget to apply settings after completion

## Debugging

### Onboarding Not Showing

```javascript
// Check if already completed
const isComplete = OnboardingManager.hasCompletedOnboarding('cyclismo');
console.log('Is completed:', isComplete);

// Force reset if needed
if (isComplete) {
  OnboardingManager.resetOnboarding('cyclismo');
}
```

### Progress Not Saving

```javascript
// Check localStorage
const stored = localStorage.getItem('min-apps-onboarding-cyclismo');
console.log('Stored value:', stored);

// Manually save progress
OnboardingManager.saveCurrentStep('cyclismo', 3);
```

### Permissions Not Working

```javascript
// Check browser support
if ('Notification' in window) {
  console.log('Notifications supported');
  console.log('Current permission:', Notification.permission);
} else {
  console.log('Notifications not supported');
}
```

## Example: Complete Integration

```javascript
import React, { useState, useEffect } from 'react';
import {
  OnboardingContainer,
  OnboardingManager,
  cyclismoOnboardingConfig,
} from '@min-apps/design-system';
import { saveNotificationPreferences } from '@min-apps/design-system/notifications';

function App() {
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check onboarding status on mount
    const shouldShow = OnboardingManager.shouldShowOnboarding('cyclismo');
    setShowOnboarding(shouldShow);
    setLoading(false);
  }, []);

  const handleOnboardingComplete = async (defaultSettings) => {
    try {
      // Save notification preferences
      saveNotificationPreferences('cyclismo', defaultSettings.notifications);
      
      // Send to backend
      await fetch('/api/user/settings', {
        method: 'POST',
        body: JSON.stringify(defaultSettings),
      });
      
      // Mark as completed
      setShowOnboarding(false);
      
      // Show success message
      alert('Welcome to Cyclismo!');
    } catch (error) {
      console.error('Error saving settings:', error);
    }
  };

  const handleRequestNotifications = async () => {
    try {
      const permission = await Notification.requestPermission();
      
      if (permission === 'granted') {
        console.log('Notifications enabled');
      } else {
        console.log('Notifications denied');
      }
    } catch (error) {
      console.error('Error requesting notifications:', error);
    }
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  if (showOnboarding) {
    return (
      <OnboardingContainer
        config={cyclismoOnboardingConfig}
        onComplete={handleOnboardingComplete}
        onSkip={() => setShowOnboarding(false)}
        onRequestNotifications={handleRequestNotifications}
      />
    );
  }

  return <MainApp />;
}

export default App;
```

## Next Steps

- Read the [full onboarding documentation](./onboarding.md)
- Check the [interactive example](../examples/onboarding-example.html)
- Customize your app's onboarding configuration
- Test on different devices and screen sizes
- Integrate with your analytics to track completion rates

## Support

Need help? Check:
1. [Full Documentation](./onboarding.md)
2. [Examples](../examples/)
3. [Component API](./components.md)
