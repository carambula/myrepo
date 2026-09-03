# Onboarding System

The min apps design system includes a complete onboarding flow system that allows each app to guide new users through initial setup, including notification preferences configuration.

## Overview

The onboarding system provides:

- **Reusable Components**: Pre-built onboarding flow and step components
- **Notification Integration**: Built-in notification preferences step
- **State Management**: Automatic tracking of onboarding completion
- **App-Specific Flows**: Customizable steps for each min app
- **Responsive Design**: Mobile-optimized onboarding experience

## Quick Start

### Basic Implementation

```javascript
import { 
  OnboardingFlow, 
  getDefaultOnboardingSteps,
  useOnboardingState 
} from '@min-apps/design-system/onboarding';
import { APP_IDS } from '@min-apps/design-system/notifications';

function App() {
  const { showOnboarding, markAsCompleted } = useOnboardingState(APP_IDS.CYCLISMO);
  const steps = getDefaultOnboardingSteps(APP_IDS.CYCLISMO);

  if (showOnboarding) {
    return (
      <OnboardingFlow
        steps={steps}
        appId={APP_IDS.CYCLISMO}
        onComplete={markAsCompleted}
      />
    );
  }

  return <YourApp />;
}
```

## Components

### OnboardingFlow

Main container component that manages the onboarding flow with step navigation and progress tracking.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `steps` | `Array<Step>` | `[]` | Array of step configurations |
| `appId` | `string` | required | App identifier (from APP_IDS) |
| `onComplete` | `function` | - | Called when onboarding completes |
| `onSkip` | `function` | - | Called when user skips onboarding |
| `showSkip` | `boolean` | `true` | Whether to show skip button |

#### Step Object

```javascript
{
  id: 'welcome',           // Unique step identifier
  component: WelcomeStep   // React component to render
}
```

### OnboardingStep

Generic step component with title, description, and navigation buttons.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | `string` | required | Step title |
| `description` | `string` | - | Step description |
| `icon` | `string` | - | Emoji or icon to display |
| `children` | `node` | - | Step content |
| `onNext` | `function` | - | Called when next is clicked |
| `onBack` | `function` | - | Called when back is clicked |
| `isFirstStep` | `boolean` | - | Whether this is the first step |
| `isLastStep` | `boolean` | - | Whether this is the last step |
| `nextLabel` | `string` | `'Continue'` | Text for next button |
| `backLabel` | `string` | `'Back'` | Text for back button |
| `showNext` | `boolean` | `true` | Whether to show next button |
| `showBack` | `boolean` | `true` | Whether to show back button |

#### Example

```javascript
function CustomStep({ onNext, onBack, isFirstStep, isLastStep }) {
  return (
    <OnboardingStep
      title="Welcome!"
      description="Let's get started"
      icon="👋"
      onNext={onNext}
      onBack={onBack}
      isFirstStep={isFirstStep}
      isLastStep={isLastStep}
    >
      <p>Your custom content here</p>
    </OnboardingStep>
  );
}
```

### OnboardingNotificationStep

Pre-configured step for setting up notification preferences during onboarding.

#### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `appId` | `string` | required | App identifier |
| `title` | `string` | auto-generated | Custom title (optional) |
| `description` | `string` | auto-generated | Custom description (optional) |
| `onNext` | `function` | - | Called when next is clicked |
| `onBack` | `function` | - | Called when back is clicked |
| `isFirstStep` | `boolean` | - | Whether this is the first step |
| `isLastStep` | `boolean` | - | Whether this is the last step |
| `onManagePriorityPodcasts` | `function` | - | Podlink: manage priority podcasts |
| `onManagePriorityChannels` | `function` | - | Yourtube: manage priority channels |

This component automatically renders the appropriate notification settings based on the `appId`.

## Default Onboarding Flows

Each app has a default 3-step onboarding flow:

### Cyclismo Guide

1. **Welcome** - Introduction to Cyclismo Guide
2. **Features** - Race schedules, stream notifications, and replays
3. **Notifications** - Configure race alerts and stream reminders

### podlink

1. **Welcome** - Introduction to podlink
2. **Features** - Queue summaries and priority podcasts
3. **Notifications** - Configure queue notifications and priority alerts

### WatchedIt

1. **Welcome** - Introduction to WatchedIt
2. **Features** - Episode tracking and notifications
3. **Notifications** - Configure new episode notifications

### yourtube

1. **Welcome** - Introduction to yourtube
2. **Features** - Queue management and priority channels
3. **Notifications** - Configure queue notifications and priority alerts

## Custom Onboarding Flows

You can create custom onboarding flows by defining your own steps:

```javascript
import { OnboardingFlow, OnboardingStep } from '@min-apps/design-system/onboarding';

function MyWelcomeStep({ onNext, onBack, isFirstStep, isLastStep }) {
  return (
    <OnboardingStep
      title="Custom Welcome"
      description="Your custom onboarding experience"
      icon="🎉"
      onNext={onNext}
      onBack={onBack}
      isFirstStep={isFirstStep}
      isLastStep={isLastStep}
    >
      <div>Your custom content</div>
    </OnboardingStep>
  );
}

const customSteps = [
  { id: 'welcome', component: MyWelcomeStep },
  { id: 'notifications', component: OnboardingNotificationStep }
];

function App() {
  return (
    <OnboardingFlow
      steps={customSteps}
      appId={APP_IDS.CYCLISMO}
      onComplete={(data) => console.log('Completed!', data)}
    />
  );
}
```

## State Management

### useOnboardingState Hook

Manage onboarding state and completion status.

#### Returns

```javascript
{
  completed: boolean,        // Whether onboarding is completed
  showOnboarding: boolean,   // Whether to show onboarding UI
  markAsCompleted: function, // Mark onboarding as complete
  restart: function          // Restart onboarding
}
```

#### Example

```javascript
import { useOnboardingState } from '@min-apps/design-system/onboarding';
import { APP_IDS } from '@min-apps/design-system/notifications';

function App() {
  const { showOnboarding, markAsCompleted, restart } = useOnboardingState(APP_IDS.CYCLISMO);

  if (showOnboarding) {
    return <OnboardingFlow onComplete={markAsCompleted} />;
  }

  return (
    <div>
      <YourApp />
      <button onClick={restart}>Restart Onboarding</button>
    </div>
  );
}
```

### Utility Functions

#### isOnboardingCompleted

```javascript
import { isOnboardingCompleted } from '@min-apps/design-system/onboarding';

const completed = isOnboardingCompleted(APP_IDS.CYCLISMO);
```

#### setOnboardingCompleted

```javascript
import { setOnboardingCompleted } from '@min-apps/design-system/onboarding';

setOnboardingCompleted(APP_IDS.CYCLISMO, true);
```

#### resetOnboarding

```javascript
import { resetOnboarding } from '@min-apps/design-system/onboarding';

resetOnboarding(APP_IDS.CYCLISMO);
```

## Integration with Notifications

The onboarding system integrates seamlessly with the notification preferences system. The `OnboardingNotificationStep` component:

1. Automatically loads current notification preferences
2. Renders app-specific notification settings
3. Validates user input
4. Saves preferences to localStorage
5. Passes preferences data to the `onComplete` callback

### Example with Notification Data

```javascript
function App() {
  const { showOnboarding, markAsCompleted } = useOnboardingState(APP_IDS.CYCLISMO);

  const handleComplete = (data) => {
    console.log('Notification preferences:', data.notificationPreferences);
    markAsCompleted();
  };

  if (showOnboarding) {
    return (
      <OnboardingFlow
        appId={APP_IDS.CYCLISMO}
        onComplete={handleComplete}
      />
    );
  }

  return <YourApp />;
}
```

## Styling

All onboarding components use CSS custom properties for theming:

```css
:root {
  --color-primary: #007AFF;
  --color-primary-dark: #0051D5;
  --color-background: #F2F2F7;
  --color-surface: #FFFFFF;
  --color-surface-hover: #F9F9F9;
  --color-border: #E5E5EA;
  --color-text-primary: #000000;
  --color-text-secondary: #6C6C70;
  --color-text-on-primary: #FFFFFF;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
}
```

You can customize the appearance by overriding these variables in your app.

## Best Practices

1. **Keep It Short**: Limit onboarding to 3-5 essential steps
2. **Allow Skip**: Let users skip onboarding and explore on their own
3. **Save Progress**: The system automatically saves completion status
4. **Mobile-First**: All components are responsive by default
5. **Clear CTAs**: Use descriptive button labels ("Get Started" vs "Continue")
6. **Visual Feedback**: Progress bar shows users where they are
7. **Enable Restart**: Provide a way for users to restart onboarding from settings

## Platform-Specific Considerations

### iOS

Request notification permissions before showing the notification settings step:

```javascript
import { requestNotificationPermission } from './notifications';

function CustomNotificationStep(props) {
  const handleNext = async () => {
    await requestNotificationPermission();
    props.onNext();
  };

  return <OnboardingNotificationStep {...props} onNext={handleNext} />;
}
```

### Android

Notification permissions are requested at runtime on Android 13+. Consider adding an explanation step before the notification settings.

### Web

Web notifications require explicit user permission. Add context explaining why notifications are useful before requesting permission.

## Examples

See `/examples/onboarding-example.html` for a complete interactive demo.

## API Reference

### OnboardingFlow

```typescript
interface OnboardingFlowProps {
  steps: Step[];
  appId: string;
  onComplete?: (data: object) => void;
  onSkip?: (data: object) => void;
  showSkip?: boolean;
}

interface Step {
  id: string;
  component: React.ComponentType<StepProps>;
}

interface StepProps {
  appId: string;
  data: object;
  onNext: (data?: object) => void;
  onBack: () => void;
  isFirstStep: boolean;
  isLastStep: boolean;
}
```

### OnboardingStep

```typescript
interface OnboardingStepProps {
  title: string;
  description?: string;
  icon?: string;
  children?: React.ReactNode;
  onNext?: () => void;
  onBack?: () => void;
  isFirstStep?: boolean;
  isLastStep?: boolean;
  nextLabel?: string;
  backLabel?: string;
  showNext?: boolean;
  showBack?: boolean;
}
```

### OnboardingNotificationStep

```typescript
interface OnboardingNotificationStepProps {
  appId: string;
  title?: string;
  description?: string;
  onNext?: (data: object) => void;
  onBack?: () => void;
  isFirstStep?: boolean;
  isLastStep?: boolean;
  onManagePriorityPodcasts?: () => void;
  onManagePriorityChannels?: () => void;
}
```

### useOnboardingState

```typescript
interface OnboardingState {
  completed: boolean;
  showOnboarding: boolean;
  markAsCompleted: () => void;
  restart: () => void;
}

function useOnboardingState(appId: string): OnboardingState;
```

## Troubleshooting

### Onboarding Not Showing

1. Check that `showOnboarding` is `true`
2. Verify localStorage is available
3. Check for console errors
4. Ensure steps array is not empty

### Preferences Not Saving

1. Verify localStorage is enabled
2. Check for validation errors
3. Ensure appId is correct
4. Review browser console for errors

### Styling Issues

1. Verify CSS custom properties are defined
2. Check for conflicting styles
3. Ensure components are wrapped in proper containers
4. Test on different screen sizes

## Migration Guide

If you have an existing onboarding flow, here's how to migrate:

### Before

```javascript
function MyOnboarding() {
  return (
    <div>
      <h1>Welcome</h1>
      <button>Next</button>
    </div>
  );
}
```

### After

```javascript
import { OnboardingFlow, getDefaultOnboardingSteps } from '@min-apps/design-system/onboarding';

function MyOnboarding() {
  const steps = getDefaultOnboardingSteps(APP_IDS.CYCLISMO);
  
  return (
    <OnboardingFlow
      steps={steps}
      appId={APP_IDS.CYCLISMO}
      onComplete={() => console.log('Done!')}
    />
  );
}
```

## Support

For issues or questions, refer to:

- [Notification System Documentation](./notifications.md)
- [Component API Documentation](./components.md)
- [Examples](/examples/onboarding-example.html)
