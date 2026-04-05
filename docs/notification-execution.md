## Notification Execution Guide

This guide explains how to actually trigger and send notifications using the min apps notification system.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Notification Service](#notification-service)
3. [Background Job Scheduler](#background-job-scheduler)
4. [Job Handlers](#job-handlers)
5. [Notification Manager](#notification-manager)
6. [Platform-Specific Setup](#platform-specific-setup)
7. [Testing](#testing)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### Basic Setup (3 lines of code)

```javascript
import { setupNotifications, APP_IDS } from '@min-apps/design-system/notifications';

// This initializes everything and starts background jobs
const manager = await setupNotifications(APP_IDS.CYCLISMO);
```

That's it! The system will:
1. ✅ Request notification permissions
2. ✅ Load user preferences
3. ✅ Register background jobs
4. ✅ Start executing jobs based on schedule

### Send a Test Notification

```javascript
import { NotificationService } from '@min-apps/design-system/notifications';

await NotificationService.send({
  title: 'Hello!',
  body: 'This is a test notification',
  icon: '/icon-192.png'
});
```

## Notification Service

The `NotificationService` handles sending notifications across platforms.

### Basic Usage

```javascript
import NotificationService from '@min-apps/design-system/notifications';

// Send a notification
await NotificationService.send({
  title: 'Notification Title',
  body: 'Notification body text',
  icon: '/icon-192.png',
  badge: '/badge-72.png',
  tag: 'unique-tag',
  data: { url: '/race/123' }
});
```

### Check Permissions

```javascript
import { NotificationPermissionManager } from '@min-apps/design-system/notifications';

// Check permission status
const status = await NotificationPermissionManager.getPermissionStatus();
// Returns: 'granted', 'denied', 'default', or 'unsupported'

// Request permission
const granted = await NotificationPermissionManager.requestPermission();

// Check if granted
const hasPermission = await NotificationPermissionManager.hasPermission();
```

### Schedule a Notification

```javascript
import NotificationService from '@min-apps/design-system/notifications';

// Schedule for a specific time
const scheduledTime = new Date('2026-04-03T08:00:00');

const scheduled = NotificationService.scheduleNotification({
  title: 'Morning Reminder',
  body: 'Time to check your races!'
}, scheduledTime);

// Cancel it later
scheduled.cancel();
```

## Background Job Scheduler

The `BackgroundJobScheduler` manages recurring notification jobs.

### Initialize Jobs

```javascript
import { 
  initializeBackgroundJobs,
  APP_IDS,
  CyclismoJobHandlers
} from '@min-apps/design-system/notifications';

// Initialize jobs for an app
const scheduler = await initializeBackgroundJobs(
  APP_IDS.CYCLISMO,
  CyclismoJobHandlers
);
```

### Manual Job Control

```javascript
import { getScheduler } from '@min-apps/design-system/notifications';

const scheduler = getScheduler();

// Start all jobs
scheduler.startAll();

// Stop all jobs
scheduler.stopAll();

// Start a specific job
scheduler.startJob('cyclismo.morning_races');

// Stop a specific job
scheduler.stopJob('cyclismo.morning_races');

// Get job status
const status = scheduler.getJobStatus('cyclismo.morning_races');
console.log(status);
// {
//   id: 'cyclismo.morning_races',
//   type: 'daily',
//   time: '08:00',
//   status: 'scheduled',
//   lastRun: Date,
//   nextRun: Date
// }
```

### Register Custom Jobs

```javascript
import { getScheduler } from '@min-apps/design-system/notifications';

const scheduler = getScheduler();

scheduler.registerJob('my-custom-job', {
  type: 'interval',
  intervalMinutes: 30,
  handler: async () => {
    console.log('Custom job running!');
    // Your notification logic here
  }
});

scheduler.startJob('my-custom-job');
```

## Job Handlers

Job handlers contain the logic for fetching data and sending notifications.

### Using Built-in Handlers

```javascript
import { 
  CyclismoJobHandlers,
  NotificationService
} from '@min-apps/design-system/notifications';

// The handlers have mock data by default
// You need to override the API methods with your actual implementation

CyclismoJobHandlers.fetchRacesForToday = async function() {
  const response = await fetch('/api/races/today');
  return response.json();
};

CyclismoJobHandlers.fetchRecapContent = async function(lastRace) {
  const response = await fetch(`/api/races/${lastRace.id}/recap`);
  return response.json();
};
```

### Creating Custom Handlers

```javascript
import {
  createCyclismoMorningNotification,
  NotificationService
} from '@min-apps/design-system/notifications';

const myHandlers = {
  async morning_races(settings, notificationService) {
    if (!settings.enabled) return;
    
    try {
      // 1. Fetch your data
      const races = await fetch('/api/races/today').then(r => r.json());
      
      if (!races.length) return;
      
      // 2. Create notification payload
      const notification = createCyclismoMorningNotification({
        races,
        streamers: ['NBC Sports']
      });
      
      // 3. Send notification
      await notificationService.send(notification);
      
      console.log('Morning notification sent!');
    } catch (error) {
      console.error('Job failed:', error);
    }
  }
};
```

## Notification Manager

The `NotificationManager` provides a high-level API for managing everything.

### Full Example

```javascript
import { 
  getNotificationManager,
  APP_IDS 
} from '@min-apps/design-system/notifications';

const manager = getNotificationManager(APP_IDS.CYCLISMO);

// 1. Initialize
await manager.initialize();

// 2. Check permissions
const hasPermission = await manager.hasPermissions();

if (!hasPermission) {
  // 3. Request permissions
  const granted = await manager.requestPermissions();
  
  if (!granted) {
    console.log('User denied permissions');
    return;
  }
}

// 4. Start jobs
manager.startJobs();

// 5. Send test notification
await manager.sendTestNotification('cyclismo');

// 6. Manually trigger a job
await manager.triggerJob('morning_races');

// 7. Check job status
const jobs = manager.getJobStatus();
console.log('Running jobs:', jobs);

// 8. Update preferences
await manager.updatePreferences({
  morning_races: {
    enabled: true,
    time: '09:00'
  }
});

// 9. Shutdown when done
manager.shutdown();
```

### Using setupNotifications Helper

The easiest way to get started:

```javascript
import { setupNotifications, APP_IDS } from '@min-apps/design-system/notifications';

const manager = await setupNotifications(APP_IDS.CYCLISMO, {
  // Custom job handlers (optional)
  jobHandlers: myCustomHandlers,
  
  // Auto-request permissions (default: true)
  requestPermissions: true,
  
  // Auto-start jobs (default: true)
  autoStart: true
});

// Manager is ready to use!
await manager.sendTestNotification();
```

## Web Setup

### 1. Add Service Worker

Create `/public/service-worker.js`:

```javascript
// Copy from public/service-worker.js in this package
// Or create your own based on the template
```

### 2. Register Service Worker

```javascript
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/service-worker.js')
    .then(registration => {
      console.log('Service Worker registered:', registration);
    });
}
```

### 3. Initialize Notifications

```javascript
import { setupNotifications, APP_IDS } from '@min-apps/design-system/notifications';

// Initialize after service worker is ready
navigator.serviceWorker.ready.then(async () => {
  const manager = await setupNotifications(APP_IDS.CYCLISMO);
});
```

## React Integration

```javascript
import { useEffect, useState } from 'react';
import { getNotificationManager, APP_IDS } from '@min-apps/design-system/notifications';

function useNotifications(appId) {
  const [manager, setManager] = useState(null);
  const [hasPermission, setHasPermission] = useState(false);

  useEffect(() => {
    const init = async () => {
      const mgr = getNotificationManager(appId);
      await mgr.initialize();
      
      const permission = await mgr.hasPermissions();
      setHasPermission(permission);
      setManager(mgr);
      
      if (permission) {
        mgr.startJobs();
      }
    };

    init();

    return () => {
      if (manager) {
        manager.stopJobs();
      }
    };
  }, [appId]);

  const requestPermission = async () => {
    if (manager) {
      const granted = await manager.requestPermissions();
      setHasPermission(granted);
      if (granted) {
        manager.startJobs();
      }
      return granted;
    }
    return false;
  };

  return { manager, hasPermission, requestPermission };
}

// Usage in component
function App() {
  const { manager, hasPermission, requestPermission } = useNotifications(APP_IDS.CYCLISMO);

  return (
    <div>
      {!hasPermission && (
        <button onClick={requestPermission}>
          Enable Notifications
        </button>
      )}
      {manager && (
        <button onClick={() => manager.sendTestNotification()}>
          Send Test
        </button>
      )}
    </div>
  );
}
```

## Testing

### Test Permission Flow

```javascript
import { NotificationPermissionManager } from '@min-apps/design-system/notifications';

console.log('Testing permission flow...');

const status = await NotificationPermissionManager.getPermissionStatus();
console.log('Current status:', status);

if (status !== 'granted') {
  console.log('Requesting permission...');
  const granted = await NotificationPermissionManager.requestPermission();
  console.log('Permission granted:', granted);
}
```

### Test Sending Notification

```javascript
import NotificationService from '@min-apps/design-system/notifications';

console.log('Sending test notification...');

await NotificationService.send({
  title: 'Test',
  body: 'If you see this, notifications are working!',
  icon: '/icon-192.png'
});

console.log('Notification sent!');
```

### Test Background Jobs

```javascript
import { getNotificationManager, APP_IDS } from '@min-apps/design-system/notifications';

const manager = getNotificationManager(APP_IDS.CYCLISMO);
await manager.initialize();

console.log('Testing morning job...');
await manager.triggerJob('morning_races');

console.log('Check your notifications!');
```

### Test Job Scheduling

```javascript
import { getScheduler } from '@min-apps/design-system/notifications';

const scheduler = getScheduler();

// Register a test job that runs every minute
scheduler.registerJob('test-job', {
  type: 'interval',
  intervalMinutes: 1,
  handler: async () => {
    console.log('Test job running at:', new Date().toLocaleTimeString());
    
    await NotificationService.send({
      title: 'Test Job',
      body: `Job ran at ${new Date().toLocaleTimeString()}`
    });
  }
});

scheduler.startJob('test-job');

// Let it run for a few minutes, then stop
setTimeout(() => {
  scheduler.stopJob('test-job');
  console.log('Test job stopped');
}, 5 * 60 * 1000); // Stop after 5 minutes
```

## Troubleshooting

### Notifications Not Appearing

**Check 1: Permissions**
```javascript
const status = await NotificationPermissionManager.getPermissionStatus();
console.log('Permission status:', status);
// Should be 'granted'
```

**Check 2: Service Worker**
```javascript
if ('serviceWorker' in navigator) {
  const registration = await navigator.serviceWorker.getRegistration();
  console.log('Service Worker:', registration);
  // Should be registered
}
```

**Check 3: Job Status**
```javascript
const manager = getNotificationManager(APP_IDS.CYCLISMO);
const jobs = manager.getJobStatus();
console.log('Jobs:', jobs);
// Should show running/scheduled jobs
```

### Jobs Not Running

**Check 1: Manager Initialized**
```javascript
const manager = getNotificationManager(APP_IDS.CYCLISMO);
console.log('Initialized:', manager.isInitialized);
// Should be true
```

**Check 2: Jobs Started**
```javascript
const scheduler = getScheduler();
const runningJobs = scheduler.getRunningJobs();
console.log('Running jobs:', runningJobs);
// Should show your jobs
```

**Check 3: Preferences Enabled**
```javascript
import { loadNotificationPreferences, APP_IDS } from '@min-apps/design-system/notifications';

const prefs = loadNotificationPreferences(APP_IDS.CYCLISMO);
console.log('Preferences:', prefs);
// Check that enabled: true for your notification types
```

### Permission Denied

If users deny permission:

1. Show explanation of why you need permissions
2. Guide them to browser/system settings to re-enable
3. Provide alternative without notifications

```javascript
const granted = await manager.requestPermissions();

if (!granted) {
  showModal({
    title: 'Notifications Blocked',
    message: 'To receive race updates, please enable notifications in your browser settings.',
    actions: [
      { label: 'Show Me How', onClick: showSettingsGuide },
      { label: 'Maybe Later', onClick: closeModal }
    ]
  });
}
```

## Best Practices

1. **Request Permissions at the Right Time**
   - Don't request on first app load
   - Wait until user shows interest
   - Explain the value before requesting

2. **Test Thoroughly**
   - Test on different browsers
   - Test with permissions denied
   - Test background job timing

3. **Handle Errors Gracefully**
   - Jobs may fail (network errors, API down)
   - Permissions may be revoked
   - Service worker may fail to register

4. **Monitor Performance**
   - Don't run jobs too frequently
   - Batch API calls when possible
   - Clean up old data

5. **Respect User Preferences**
   - Allow disabling individual notification types
   - Provide quiet hours
   - Remember user choices

## Next Steps

- See [notification-integration-example.js](../examples/notification-integration-example.js) for complete examples
- See [working-notifications-demo.html](../examples/working-notifications-demo.html) for interactive testing
- See [notifications.md](./notifications.md) for UI components and preferences

## Support

For issues:
1. Check browser console for errors
2. Verify service worker is registered
3. Check notification permissions
4. Review job handler implementations
