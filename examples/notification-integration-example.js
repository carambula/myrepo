/**
 * Notification Integration Example
 * Shows how to integrate the notification system into a min app
 */

import {
  setupNotifications,
  getNotificationManager,
  APP_IDS,
  CyclismoJobHandlers,
  PodlinkJobHandlers,
  WatcheditJobHandlers,
  YourtubeJobHandlers
} from '@min-apps/design-system/notifications';

/**
 * Example 1: Basic Setup
 * Initialize notifications when your app starts
 */
export async function basicSetup() {
  // This will:
  // 1. Initialize the notification service
  // 2. Request permissions (if not already granted)
  // 3. Load user preferences
  // 4. Start background jobs
  const manager = await setupNotifications(APP_IDS.CYCLISMO, {
    requestPermissions: true,  // Auto-request permissions
    autoStart: true            // Auto-start jobs
  });

  console.log('Notifications ready!');
  console.log('Running jobs:', manager.getRunningJobs());
}

/**
 * Example 2: Custom Job Handlers
 * Provide your own API implementations
 */
export async function setupWithCustomHandlers() {
  // Create custom job handlers that connect to your API
  const customHandlers = {
    ...CyclismoJobHandlers,
    
    // Override the API methods with your actual implementations
    async fetchRacesForToday() {
      const response = await fetch('/api/races/today');
      return response.json();
    },
    
    async fetchRecapContent(lastRace) {
      const response = await fetch(`/api/races/${lastRace.id}/recap`);
      return response.json();
    },
    
    async fetchUpcomingRaces() {
      const response = await fetch('/api/races/upcoming');
      return response.json();
    },
    
    async getSavedRaces() {
      const response = await fetch('/api/user/saved-races');
      return response.json();
    }
  };

  const manager = await setupNotifications(APP_IDS.CYCLISMO, {
    jobHandlers: customHandlers,
    requestPermissions: true,
    autoStart: true
  });

  return manager;
}

/**
 * Example 3: Manual Control
 * Full control over initialization and job management
 */
export async function manualSetup() {
  const manager = getNotificationManager(APP_IDS.PODLINK);

  // 1. Initialize (without auto-requesting permissions)
  await manager.initialize();

  // 2. Check if we have permissions
  const hasPermission = await manager.hasPermissions();

  if (!hasPermission) {
    // Show your own UI to explain why you need permissions
    showPermissionExplanationModal();
    
    // Then request
    const granted = await manager.requestPermissions();
    
    if (!granted) {
      console.log('User denied permissions');
      return;
    }
  }

  // 3. Start jobs manually
  manager.startJobs();

  // 4. Get job status
  const jobs = manager.getJobStatus();
  console.log('Jobs:', jobs);

  return manager;
}

/**
 * Example 4: Send Test Notification
 * Test that notifications are working
 */
export async function sendTestNotification() {
  const manager = getNotificationManager(APP_IDS.CYCLISMO);
  
  await manager.initialize();
  
  // Send a test notification
  await manager.sendTestNotification('cyclismo');
  
  console.log('Test notification sent!');
}

/**
 * Example 5: Manually Trigger a Job
 * Trigger a background job on-demand
 */
export async function triggerJobManually() {
  const manager = getNotificationManager(APP_IDS.CYCLISMO);
  
  await manager.initialize();
  
  // Manually trigger the morning races job
  await manager.triggerJob('morning_races');
  
  console.log('Job triggered!');
}

/**
 * Example 6: Update Preferences and Restart Jobs
 * When user changes notification settings
 */
export async function updateNotificationSettings(newPreferences) {
  const manager = getNotificationManager(APP_IDS.CYCLISMO);
  
  // Update preferences and restart jobs with new settings
  await manager.updatePreferences(newPreferences);
  
  console.log('Preferences updated, jobs restarted');
}

/**
 * Example 7: React Hook
 * Use notifications in a React component
 */
export function useNotifications(appId) {
  const [manager, setManager] = React.useState(null);
  const [hasPermission, setHasPermission] = React.useState(false);
  const [jobs, setJobs] = React.useState([]);

  React.useEffect(() => {
    const initManager = async () => {
      const mgr = await setupNotifications(appId, {
        requestPermissions: false, // Don't auto-request in React
        autoStart: true
      });
      
      setManager(mgr);
      
      const permission = await mgr.hasPermissions();
      setHasPermission(permission);
      
      const runningJobs = mgr.getRunningJobs();
      setJobs(runningJobs);
    };

    initManager();

    return () => {
      // Cleanup
      if (manager) {
        manager.stopJobs();
      }
    };
  }, [appId]);

  const requestPermission = async () => {
    if (manager) {
      const granted = await manager.requestPermissions();
      setHasPermission(granted);
      return granted;
    }
    return false;
  };

  const sendTest = async () => {
    if (manager) {
      await manager.sendTestNotification(appId);
    }
  };

  return {
    manager,
    hasPermission,
    jobs,
    requestPermission,
    sendTest
  };
}

/**
 * Example 8: Podlink with Priority Podcasts
 * Set up Podlink with custom podcast checking
 */
export async function setupPodlink() {
  const customHandlers = {
    ...PodlinkJobHandlers,
    
    async updatePodcastQueue() {
      // Fetch all podcast feeds
      const feeds = await fetch('/api/podcasts/feeds').then(r => r.json());
      
      // Update local database
      for (const feed of feeds) {
        await updateLocalFeed(feed);
      }
    },
    
    async getQueueData() {
      const queue = await fetch('/api/podcasts/queue').then(r => r.json());
      const lastCheck = localStorage.getItem('last-queue-check');
      
      const newItems = lastCheck
        ? queue.filter(item => new Date(item.publishDate) > new Date(lastCheck))
        : queue;
      
      localStorage.setItem('last-queue-check', new Date().toISOString());
      
      return { newItems, queue };
    },
    
    async checkPriorityPodcasts(podcastIds) {
      const episodes = [];
      
      for (const podcastId of podcastIds) {
        const response = await fetch(`/api/podcasts/${podcastId}/latest`);
        const latest = await response.json();
        
        const lastCheck = localStorage.getItem(`last-check-${podcastId}`);
        
        if (!lastCheck || new Date(latest.publishDate) > new Date(lastCheck)) {
          episodes.push(latest);
          localStorage.setItem(`last-check-${podcastId}`, new Date().toISOString());
        }
      }
      
      return episodes;
    }
  };

  const manager = await setupNotifications(APP_IDS.PODLINK, {
    jobHandlers: customHandlers,
    requestPermissions: true,
    autoStart: true
  });

  return manager;
}

/**
 * Example 9: WatchedIt Simple Setup
 * Minimal setup for WatchedIt
 */
export async function setupWatchedIt() {
  const customHandlers = {
    ...WatcheditJobHandlers,
    
    async checkForNewEpisodes() {
      const response = await fetch('/api/episodes/new');
      const episodes = await response.json();
      
      const lastCheck = localStorage.getItem('watchedit-last-check');
      
      if (lastCheck) {
        return episodes.filter(ep => 
          new Date(ep.publishDate) > new Date(lastCheck)
        );
      }
      
      localStorage.setItem('watchedit-last-check', new Date().toISOString());
      return episodes;
    }
  };

  const manager = await setupNotifications(APP_IDS.WATCHEDIT, {
    jobHandlers: customHandlers,
    requestPermissions: true,
    autoStart: true
  });

  return manager;
}

/**
 * Example 10: Yourtube with Apple Intelligence
 * Set up Yourtube with AI summaries
 */
export async function setupYoutubeWithAI() {
  const customHandlers = {
    ...YourtubeJobHandlers,
    
    async generateAISummary(videos) {
      // Call your AI service
      const response = await fetch('/api/ai/summarize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ videos })
      });
      
      const { summary } = await response.json();
      return summary;
    },
    
    async checkPriorityChannels(channelIds) {
      const videos = [];
      
      for (const channelId of channelIds) {
        const response = await fetch(`/api/channels/${channelId}/latest`);
        const latest = await response.json();
        
        const lastCheck = localStorage.getItem(`yt-last-check-${channelId}`);
        
        if (!lastCheck || new Date(latest.publishDate) > new Date(lastCheck)) {
          videos.push(latest);
          localStorage.setItem(`yt-last-check-${channelId}`, new Date().toISOString());
        }
      }
      
      return videos;
    }
  };

  const manager = await setupNotifications(APP_IDS.YOURTUBE, {
    jobHandlers: customHandlers,
    requestPermissions: true,
    autoStart: true
  });

  return manager;
}

/**
 * Helper: Show permission explanation
 */
function showPermissionExplanationModal() {
  // Your UI code to explain why you need permissions
  console.log('Showing permission explanation...');
}

/**
 * Helper: Update local feed
 */
async function updateLocalFeed(feed) {
  // Your database update logic
  console.log('Updating feed:', feed.id);
}
