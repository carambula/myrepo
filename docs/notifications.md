# Notification System Documentation

## Overview

The min apps design system includes a comprehensive notification preferences system that allows each app (Cyclismo, Podlink, WatchedIt, Yourtube) to manage user notification preferences and schedule background jobs.

## Table of Contents

1. [Architecture](#architecture)
2. [Notification Types](#notification-types)
3. [UI Components](#ui-components)
4. [Preference Management](#preference-management)
5. [Background Jobs](#background-jobs)
6. [Platform Integration](#platform-integration)
7. [Examples](#examples)

## Architecture

The notification system consists of four main parts:

1. **Data structures** - Type definitions and default preferences
2. **UI Components** - React components for settings pages
3. **Preference Management** - Functions for storing/retrieving preferences
4. **Scheduling Utilities** - Helpers for background job configuration

## Notification Types

### Cyclismo Guide

#### 1. Morning Race Notification
- **When**: Daily at specified time (if races that day)
- **Content**: Race names, times, and streamers
- **Settings**:
  - `enabled` (boolean)
  - `time` (HH:MM string)
  - `timezone` (string)

#### 2. Recap Notification
- **When**: X hours after last race concludes
- **Content**: Available podcasts and replays
- **Settings**:
  - `enabled` (boolean)
  - `hoursAfterLastRace` (number, 1-12)

#### 3. Stream Start Notification
- **When**: X minutes before each race stream starts
- **Content**: Race name and start time
- **Settings**:
  - `enabled` (boolean)
  - `minutesBefore` (number, 5-60)
  - `onlySavedRaces` (boolean)

### Podlink

#### 1. Morning Queue Summary
- **When**: Daily at specified time
- **Content**: Summary of queue and new episodes
- **Settings**:
  - `enabled` (boolean)
  - `time` (HH:MM string)
  - `timezone` (string)
  - `useAppleIntelligence` (boolean)

#### 2. Priority Podcasts
- **When**: Regular intervals to check priority podcasts
- **Content**: New episodes from priority podcasts
- **Settings**:
  - `enabled` (boolean)
  - `checkIntervalMinutes` (number, 15-360)
  - `priorityPodcastIds` (array of strings)

### WatchedIt (Mov Min)

#### 1. New Episodes
- **When**: Daily at specified time
- **Content**: New podcast episodes available
- **Settings**:
  - `enabled` (boolean)
  - `time` (HH:MM string)
  - `timezone` (string)

### Yourtube (Vid Min)

#### 1. Morning Queue Summary
- **When**: Daily at specified time
- **Content**: Summary of queue and new videos
- **Settings**:
  - `enabled` (boolean)
  - `time` (HH:MM string)
  - `timezone` (string)
  - `useAppleIntelligence` (boolean)

#### 2. Priority Channels
- **When**: Regular intervals to check priority channels
- **Content**: New videos from priority channels
- **Settings**:
  - `enabled` (boolean)
  - `checkIntervalMinutes` (number, 15-360)
  - `priorityChannelIds` (array of strings)

## UI Components

### NotificationSettingsPage

Main settings page component that routes to app-specific settings.

```javascript
import { NotificationSettingsPage } from '@min-apps/design-system';

function Settings() {
  return (
    <NotificationSettingsPage
      appId="cyclismo"
      onManagePriorityPodcasts={() => navigateToPodcasts()}
      onSave={(prefs) => console.log('Saved:', prefs)}
    />
  );
}
```

### Individual Components

Each app has a dedicated settings component:

- `CyclismoNotificationSettings`
- `PodlinkNotificationSettings`
- `WatcheditNotificationSettings`
- `YourtubeNotificationSettings`

### Reusable Components

- `NotificationToggle` - Toggle switch for enabling/disabling
- `TimePickerInput` - Time selection input
- `NumberInput` - Numeric input with validation
- `NotificationSettingsGroup` - Collapsible settings group

## Preference Management

### Loading Preferences

```javascript
import { loadNotificationPreferences, APP_IDS } from '@min-apps/design-system';

const preferences = loadNotificationPreferences(APP_IDS.CYCLISMO);
```

### Saving Preferences

```javascript
import { saveNotificationPreferences } from '@min-apps/design-system';

const success = saveNotificationPreferences(APP_IDS.CYCLISMO, preferences);
```

### Updating Individual Settings

```javascript
import { updateNotificationPreference } from '@min-apps/design-system';

updateNotificationPreference(
  APP_IDS.CYCLISMO,
  'morning_races',
  { enabled: true, time: '08:00' }
);
```

### Validation

```javascript
import { validatePreferences } from '@min-apps/design-system';

const validation = validatePreferences(APP_IDS.CYCLISMO, preferences);
if (!validation.valid) {
  console.error('Errors:', validation.errors);
}
```

## Background Jobs

### Getting Scheduled Notifications

```javascript
import { getScheduledNotifications } from '@min-apps/design-system';

const scheduled = getScheduledNotifications(APP_IDS.CYCLISMO);
// Returns array of scheduled notification configs
```

### Creating Notification Payloads

```javascript
import {
  createCyclismoMorningNotification,
  createCyclismoRecapNotification,
  createCyclismoStreamStartNotification
} from '@min-apps/design-system';

// Morning races
const notification = createCyclismoMorningNotification({
  races: [
    { name: 'Tour de France Stage 1', time: '14:00' }
  ],
  streamers: ['NBC Sports', 'Eurosport']
});

// Recap
const recap = createCyclismoRecapNotification({
  podcasts: [{ title: 'Stage 1 Recap' }],
  replays: [{ title: 'Full Stage Replay' }]
});
```

### Background Job Configuration

```javascript
import { BackgroundJobConfig } from '@min-apps/design-system';

// Get minimum fetch interval for iOS
const interval = BackgroundJobConfig.getMinimumFetchInterval(APP_IDS.PODLINK);

// Check if app has daily notifications
const hasDaily = BackgroundJobConfig.hasDailyNotifications(APP_IDS.CYCLISMO);

// Check if app has interval notifications
const hasInterval = BackgroundJobConfig.hasIntervalNotifications(APP_IDS.PODLINK);
```

## Platform Integration

### iOS (Swift)

The notification system provides iOS background task implementation examples in each app config file.

```swift
import BackgroundTasks
import UserNotifications

// Import configuration from JavaScript
// Use CyclismoBackgroundJobs handlers as templates

class NotificationManager {
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.cyclismo.morning_races",
            using: nil
        ) { task in
            self.handleMorningRacesTask(task: task as! BGAppRefreshTask)
        }
    }
}
```

See app-specific config files for complete examples:
- `src/notifications/appConfigs/cyclismoConfig.js`
- `src/notifications/appConfigs/podlinkConfig.js`
- `src/notifications/appConfigs/watcheditConfig.js`
- `src/notifications/appConfigs/yourtubeConfig.js`

### Android (Kotlin)

WorkManager examples are provided for Android integration.

```kotlin
import androidx.work.*

class NotificationManager(private val context: Context) {
    fun scheduleMorningNotification(time: String) {
        val workRequest = PeriodicWorkRequestBuilder<MorningWorker>(
            1, TimeUnit.DAYS
        ).build()
        
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "morning_notification",
            ExistingPeriodicWorkPolicy.REPLACE,
            workRequest
        )
    }
}
```

### Web (Service Workers)

For web implementations, use the Notification API with Service Workers.

```javascript
// Request permission
import { NotificationPermissions } from '@min-apps/design-system';

const granted = await NotificationPermissions.request();

// Schedule with Service Worker
if ('serviceWorker' in navigator) {
  const registration = await navigator.serviceWorker.ready;
  
  // Use scheduled notifications (if supported)
  if ('showNotification' in registration) {
    registration.showNotification('Title', {
      body: 'Message',
      icon: '/icon.png'
    });
  }
}
```

## Examples

### Example 1: Basic Settings Page

```javascript
import React from 'react';
import { NotificationSettingsPage, APP_IDS } from '@min-apps/design-system';

export function CyclismoSettings() {
  const handleSave = (preferences) => {
    console.log('Settings saved:', preferences);
    // Update your backend/sync
  };

  return (
    <NotificationSettingsPage
      appId={APP_IDS.CYCLISMO}
      onSave={handleSave}
    />
  );
}
```

### Example 2: Custom Integration

```javascript
import {
  loadNotificationPreferences,
  updateNotificationPreference,
  APP_IDS,
  CYCLISMO_NOTIFICATION_TYPES
} from '@min-apps/design-system';

function MyCustomSettings() {
  const [prefs, setPrefs] = useState(
    loadNotificationPreferences(APP_IDS.CYCLISMO)
  );

  const toggleMorningNotif = () => {
    const enabled = !prefs.morning_races.enabled;
    updateNotificationPreference(
      APP_IDS.CYCLISMO,
      CYCLISMO_NOTIFICATION_TYPES.MORNING_RACES,
      { enabled }
    );
    setPrefs(loadNotificationPreferences(APP_IDS.CYCLISMO));
  };

  return (
    <button onClick={toggleMorningNotif}>
      {prefs.morning_races.enabled ? 'Disable' : 'Enable'} Morning Notifications
    </button>
  );
}
```

### Example 3: Background Job Implementation

```javascript
import {
  CyclismoBackgroundJobs,
  loadNotificationPreferences,
  APP_IDS
} from '@min-apps/design-system';

// Your platform-specific background job runner
async function runMorningRacesJob() {
  const preferences = loadNotificationPreferences(APP_IDS.CYCLISMO);
  const settings = preferences.morning_races;

  await CyclismoBackgroundJobs.morningRaces(
    // Your API function to fetch races
    async () => {
      const response = await fetch('/api/races/today');
      return response.json();
    },
    // Your platform notification sender
    async (notification) => {
      await sendPlatformNotification(notification);
    },
    // Settings
    settings
  );
}
```

### Example 4: Priority Podcast Management

```javascript
import {
  loadNotificationPreferences,
  updateNotificationPreference,
  PriorityPodcastManager,
  APP_IDS,
  PODLINK_NOTIFICATION_TYPES
} from '@min-apps/design-system';

function PodcastList({ podcasts }) {
  const preferences = loadNotificationPreferences(APP_IDS.PODLINK);
  const priorityIds = preferences.priority_podcasts.priorityPodcastIds;

  const togglePriority = (podcastId) => {
    const updated = PriorityPodcastManager.togglePriorityPodcast(
      priorityIds,
      podcastId
    );
    
    updateNotificationPreference(
      APP_IDS.PODLINK,
      PODLINK_NOTIFICATION_TYPES.PRIORITY_PODCASTS,
      { priorityPodcastIds: updated }
    );
  };

  return podcasts.map(podcast => (
    <div key={podcast.id}>
      {podcast.name}
      <button onClick={() => togglePriority(podcast.id)}>
        {PriorityPodcastManager.isPriorityPodcast(priorityIds, podcast.id)
          ? '★ Priority'
          : '☆ Set Priority'}
      </button>
    </div>
  ));
}
```

## Storage

Preferences are stored in `localStorage` with the following keys:

- `min-apps-notifications-cyclismo`
- `min-apps-notifications-podlink`
- `min-apps-notifications-watchedit`
- `min-apps-notifications-yourtube`

### Export/Import

```javascript
import {
  exportAllPreferences,
  importAllPreferences
} from '@min-apps/design-system';

// Backup
const backup = exportAllPreferences();
localStorage.setItem('notification-backup', JSON.stringify(backup));

// Restore
const backup = JSON.parse(localStorage.getItem('notification-backup'));
importAllPreferences(backup);
```

## Validation Rules

All inputs are validated against the following rules:

- **time**: HH:MM format (24-hour)
- **hoursAfterLastRace**: 1-12 hours
- **minutesBefore**: 5-60 minutes
- **checkIntervalMinutes**: 15-360 minutes

## Best Practices

1. **Request Permissions Early**: Ask for notification permissions during onboarding
2. **Provide Defaults**: Use sensible defaults for all notification settings
3. **Validate Input**: Always validate user input before saving
4. **Handle Errors**: Gracefully handle background job failures
5. **Test Thoroughly**: Test notifications on all platforms
6. **Respect User Preferences**: Never send notifications if disabled
7. **Provide Feedback**: Show confirmation when settings are saved
8. **Optimize Frequency**: Don't check too frequently to save battery

## Troubleshooting

### Notifications Not Appearing

1. Check permissions are granted
2. Verify settings are enabled
3. Check background task registration
4. Review platform-specific logs

### Settings Not Saving

1. Check localStorage is available
2. Verify validation passes
3. Check for JavaScript errors

### Background Jobs Not Running

1. Verify platform background task registration
2. Check battery optimization settings (Android)
3. Ensure network connectivity for API calls
4. Review platform task scheduling limits

## API Reference

See individual module documentation:

- [Notification Types](../src/notifications/notificationTypes.js)
- [Preference Management](../src/notifications/notificationPreferences.js)
- [Scheduler Utilities](../src/notifications/notificationScheduler.js)
- [App Configurations](../src/notifications/appConfigs/)

## Support

For issues or questions:
1. Check this documentation
2. Review code comments in source files
3. Check platform-specific documentation (iOS/Android)
4. Review example implementations in app configs
