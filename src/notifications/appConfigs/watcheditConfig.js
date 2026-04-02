/**
 * WatchedIt (Mov Min) Notification Configuration
 * Implementation guide and helpers for WatchedIt-specific notifications
 */

import { WATCHEDIT_NOTIFICATION_TYPES } from '../notificationTypes.js';
import { createNewEpisodesNotification } from '../notificationScheduler.js';

/**
 * Background job handlers for WatchedIt
 */
export const WatcheditBackgroundJobs = {
  /**
   * New episodes check job
   * Should run daily at the user's specified time
   * 
   * @param {Function} checkForNewEpisodes - Your API function to check for new episodes
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async newEpisodes(checkForNewEpisodes, sendNotification, settings) {
    if (!settings.enabled) return;

    try {
      const newEpisodes = await checkForNewEpisodes();

      if (!newEpisodes || newEpisodes.length === 0) {
        console.log('No new episodes, skipping notification');
        return;
      }

      const notification = createNewEpisodesNotification(newEpisodes);
      
      if (notification) {
        await sendNotification(notification);
      }
    } catch (error) {
      console.error('Error in new episodes job:', error);
    }
  }
};

/**
 * Schedule setup helper for WatchedIt
 */
export function getWatcheditScheduleConfig(preferences) {
  const schedules = [];

  if (preferences.new_episodes?.enabled) {
    schedules.push({
      id: 'watchedit.new_episodes',
      type: 'daily',
      time: preferences.new_episodes.time,
      handler: 'WatcheditBackgroundJobs.newEpisodes'
    });
  }

  return schedules;
}

/**
 * Episode checking helper
 * Utilities for tracking and detecting new episodes
 */
export const EpisodeTracker = {
  /**
   * Get last check timestamp
   */
  getLastCheckTime() {
    if (typeof localStorage === 'undefined') return null;
    const timestamp = localStorage.getItem('watchedit-last-episode-check');
    return timestamp ? new Date(timestamp) : null;
  },

  /**
   * Set last check timestamp
   */
  setLastCheckTime(time = new Date()) {
    if (typeof localStorage === 'undefined') return;
    localStorage.setItem('watchedit-last-episode-check', time.toISOString());
  },

  /**
   * Filter episodes newer than last check
   */
  getNewEpisodesSinceLastCheck(allEpisodes) {
    const lastCheck = this.getLastCheckTime();
    if (!lastCheck) return allEpisodes;

    return allEpisodes.filter(episode => {
      const publishDate = new Date(episode.publishDate);
      return publishDate > lastCheck;
    });
  },

  /**
   * Mark episodes as notified
   */
  markEpisodesNotified(episodeIds) {
    if (typeof localStorage === 'undefined') return;
    
    const notified = this.getNotifiedEpisodes();
    const updated = [...new Set([...notified, ...episodeIds])];
    
    localStorage.setItem('watchedit-notified-episodes', JSON.stringify(updated));
  },

  /**
   * Get list of notified episode IDs
   */
  getNotifiedEpisodes() {
    if (typeof localStorage === 'undefined') return [];
    
    const stored = localStorage.getItem('watchedit-notified-episodes');
    return stored ? JSON.parse(stored) : [];
  },

  /**
   * Clear old notified episodes (older than 30 days)
   */
  cleanupOldNotifications() {
    if (typeof localStorage === 'undefined') return;
    
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    localStorage.setItem('watchedit-last-cleanup', thirtyDaysAgo.toISOString());
  }
};

/**
 * iOS Background Task example for WatchedIt
 */
export const iOSImplementationExample = `
// Swift implementation for WatchedIt

import BackgroundTasks
import UserNotifications

class WatcheditNotificationManager {
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.watchedit.new_episodes",
            using: nil
        ) { task in
            self.handleNewEpisodesTask(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleNewEpisodesCheck(at time: String) {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.watchedit.new_episodes"
        )
        
        let nextCheckTime = calculateNextDailyTime(from: time)
        request.earliestBeginDate = nextCheckTime
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule new episodes check: \\(error)")
        }
    }
    
    func handleNewEpisodesTask(task: BGAppRefreshTask) {
        let queue = DispatchQueue.global()
        
        queue.async {
            Task {
                do {
                    let newEpisodes = await self.checkForNewEpisodes()
                    
                    if !newEpisodes.isEmpty {
                        await self.sendNewEpisodesNotification(newEpisodes)
                    }
                    
                    // Schedule next check
                    self.scheduleNewEpisodesCheck(at: self.getPreferredTime())
                    
                    task.setTaskCompleted(success: true)
                } catch {
                    task.setTaskCompleted(success: false)
                }
            }
        }
        
        task.expirationHandler = {
            queue.async {
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func checkForNewEpisodes() async -> [Episode] {
        // Fetch podcasts from your API
        let podcasts = await fetchUserPodcasts()
        var newEpisodes: [Episode] = []
        
        let lastCheck = UserDefaults.standard.object(
            forKey: "lastEpisodeCheck"
        ) as? Date ?? Date.distantPast
        
        for podcast in podcasts {
            let episodes = await fetchEpisodes(for: podcast.id)
            let new = episodes.filter { $0.publishDate > lastCheck }
            newEpisodes.append(contentsOf: new)
        }
        
        UserDefaults.standard.set(Date(), forKey: "lastEpisodeCheck")
        
        return newEpisodes
    }
    
    private func sendNewEpisodesNotification(_ episodes: [Episode]) async {
        let content = UNMutableNotificationContent()
        content.title = "\\(episodes.count) New Episode\\(episodes.count > 1 ? "s" : "")"
        
        let episodeList = episodes.prefix(3).map { $0.title }.joined(separator: "\\n")
        let more = episodes.count > 3 ? "\\n+\\(episodes.count - 3) more" : ""
        content.body = episodeList + more
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        try? await UNUserNotificationCenter.current().add(request)
    }
}
`;

/**
 * Android WorkManager example for WatchedIt
 */
export const androidImplementationExample = `
// Kotlin implementation for WatchedIt

import androidx.work.*
import java.util.concurrent.TimeUnit

class WatcheditNotificationManager(private val context: Context) {
    fun scheduleNewEpisodesCheck(time: String) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
            
        val delay = calculateDelayUntilTime(time)
        
        val workRequest = PeriodicWorkRequestBuilder<NewEpisodesWorker>(
            1, TimeUnit.DAYS
        )
            .setConstraints(constraints)
            .setInitialDelay(delay, TimeUnit.MILLISECONDS)
            .build()
            
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "watchedit_new_episodes",
            ExistingPeriodicWorkPolicy.REPLACE,
            workRequest
        )
    }
    
    fun cancelNewEpisodesCheck() {
        WorkManager.getInstance(context)
            .cancelUniqueWork("watchedit_new_episodes")
    }
}

class NewEpisodesWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        return try {
            val newEpisodes = checkForNewEpisodes()
            
            if (newEpisodes.isNotEmpty()) {
                sendNewEpisodesNotification(newEpisodes)
            }
            
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
    
    private suspend fun checkForNewEpisodes(): List<Episode> {
        val lastCheck = getLastCheckTime()
        val podcasts = fetchUserPodcasts()
        val newEpisodes = mutableListOf<Episode>()
        
        podcasts.forEach { podcast ->
            val episodes = fetchEpisodes(podcast.id)
            newEpisodes.addAll(
                episodes.filter { it.publishDate > lastCheck }
            )
        }
        
        setLastCheckTime(System.currentTimeMillis())
        return newEpisodes
    }
    
    private fun sendNewEpisodesNotification(episodes: List<Episode>) {
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle("\\${episodes.size} New Episode\\${if (episodes.size > 1) "s" else ""}")
            .setContentText(episodes.take(3).joinToString("\\n") { it.title })
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
            
        NotificationManagerCompat.from(applicationContext)
            .notify(NOTIFICATION_ID, notification)
    }
}
`;
