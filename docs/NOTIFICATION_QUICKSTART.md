# Notification System Quick Start

Get notifications working in 5 minutes!

## Step 1: Install the Package

```bash
npm install @min-apps/design-system
```

## Step 2: Initialize Notifications (3 lines)

```javascript
import { setupNotifications, APP_IDS } from '@min-apps/design-system/notifications';

// That's it! Everything is set up and running
const manager = await setupNotifications(APP_IDS.CYCLISMO);
```

## Step 3: Test It

```javascript
// Send a test notification
await manager.sendTestNotification();
```

## Done! 🎉

Notifications are now:
- ✅ Initialized
- ✅ Permissions requested
- ✅ Background jobs running
- ✅ Ready to send notifications

## What Happens Automatically

When you call `setupNotifications()`:

1. **Notification Service** initializes and registers service worker
2. **Permission Request** asks user for notification permissions
3. **Preferences** loads user notification settings from localStorage
4. **Background Jobs** schedules and starts all enabled notification jobs
5. **Job Handlers** connects your notification types to the scheduler

## Customize It

### Provide Your Own API Implementations

```javascript
import { 
  setupNotifications, 
  APP_IDS,
  CyclismoJobHandlers 
} from '@min-apps/design-system/notifications';

// Override the API methods with your real endpoints
const customHandlers = {
  ...CyclismoJobHandlers,
  
  async fetchRacesForToday() {
    const response = await fetch('/api/races/today');
    return response.json();
  },
  
  async fetchRecapContent(lastRace) {
    const response = await fetch(`/api/races/${lastRace.id}/recap');
    return response.json();
  }
};

// Pass custom handlers to setup
const manager = await setupNotifications(APP_IDS.CYCLISMO, {
  jobHandlers: customHandlers
});
```

### Control Permissions and Auto-Start

```javascript
const manager = await setupNotifications(APP_IDS.CYCLISMO, {
  requestPermissions: false,  // Don't auto-request
  autoStart: false            // Don't auto-start jobs
});

// Request permission when you're ready
const granted = await manager.requestPermissions();

if (granted) {
  // Start jobs
  manager.startJobs();
}
```

## Use the Settings UI

```javascript
import { NotificationSettingsPage, APP_IDS } from '@min-apps/design-system/notifications';

function SettingsScreen() {
  return (
    <NotificationSettingsPage
      appId={APP_IDS.CYCLISMO}
      onSave={(preferences) => {
        console.log('User updated preferences:', preferences);
      }}
    />
  );
}
```

## Manually Trigger a Job

```javascript
// Trigger the morning notification job right now
await manager.triggerJob('morning_races');
```

## Check Job Status

```javascript
// Get all jobs
const jobs = manager.getJobStatus();

// Get only running jobs
const running = manager.getRunningJobs();

console.log('Jobs:', jobs);
```

## Send Custom Notifications

```javascript
import NotificationService from '@min-apps/design-system/notifications';

await NotificationService.send({
  title: 'Custom Notification',
  body: 'Your custom message here',
  icon: '/icon.png',
  data: { url: '/some-page' }
});
```

## Common Use Cases

### Cyclismo: Race Notifications

```javascript
const manager = await setupNotifications(APP_IDS.CYCLISMO, {
  jobHandlers: {
    ...CyclismoJobHandlers,
    
    async fetchRacesForToday() {
      return await fetchFromYourAPI('/races/today');
    },
    
    async fetchUpcomingRaces() {
      return await fetchFromYourAPI('/races/upcoming');
    }
  }
});
```

### Podlink: Priority Podcasts

```javascript
const manager = await setupNotifications(APP_IDS.PODLINK, {
  jobHandlers: {
    ...PodlinkJobHandlers,
    
    async checkPriorityPodcasts(podcastIds) {
      const episodes = [];
      for (const id of podcastIds) {
        const latest = await fetchFromYourAPI(`/podcasts/${id}/latest`);
        episodes.push(latest);
      }
      return episodes;
    }
  }
});
```

### WatchedIt: New Episodes

```javascript
const manager = await setupNotifications(APP_IDS.WATCHEDIT, {
  jobHandlers: {
    ...WatcheditJobHandlers,
    
    async checkForNewEpisodes() {
      return await fetchFromYourAPI('/episodes/new');
    }
  }
});
```

## React Hook

```javascript
import { useEffect, useState } from 'react';
import { getNotificationManager, APP_IDS } from '@min-apps/design-system/notifications';

function useNotifications(appId) {
  const [manager, setManager] = useState(null);
  const [hasPermission, setHasPermission] = useState(false);

  useEffect(() => {
    setupNotifications(appId).then(mgr => {
      setManager(mgr);
      mgr.hasPermissions().then(setHasPermission);
    });
  }, [appId]);

  return { manager, hasPermission };
}

// Use in component
function App() {
  const { manager, hasPermission } = useNotifications(APP_IDS.CYCLISMO);

  return (
    <div>
      {hasPermission ? 'Notifications enabled!' : 'Enable notifications'}
    </div>
  );
}
```

## Troubleshooting

### "Notifications not appearing"

1. Check permissions:
```javascript
const status = await NotificationPermissionManager.getPermissionStatus();
console.log(status); // Should be 'granted'
```

2. Check jobs are running:
```javascript
const jobs = manager.getRunningJobs();
console.log(jobs); // Should show your jobs
```

3. Test with a simple notification:
```javascript
await manager.sendTestNotification();
```

### "Jobs not executing"

1. Check preferences are enabled:
```javascript
const prefs = loadNotificationPreferences(APP_IDS.CYCLISMO);
console.log(prefs.morning_races.enabled); // Should be true
```

2. Manually trigger to test:
```javascript
await manager.triggerJob('morning_races');
```

## What's Next?

- **Full Documentation**: See [notification-execution.md](./notification-execution.md)
- **UI Components**: See [notifications.md](./notifications.md)
- **Examples**: See [notification-integration-example.js](../examples/notification-integration-example.js)
- **Interactive Demo**: Open [working-notifications-demo.html](../examples/working-notifications-demo.html)

## API Summary

```javascript
// Main setup
setupNotifications(appId, options)

// Manager methods
manager.initialize()
manager.requestPermissions()
manager.hasPermissions()
manager.startJobs()
manager.stopJobs()
manager.triggerJob(jobType)
manager.sendTestNotification()
manager.getJobStatus()
manager.updatePreferences(prefs)

// Direct notification sending
NotificationService.send(notification)
NotificationService.scheduleNotification(notification, time)

// Permission management
NotificationPermissionManager.requestPermission()
NotificationPermissionManager.hasPermission()
NotificationPermissionManager.getPermissionStatus()
```

That's it! You're ready to send notifications. 🚀
