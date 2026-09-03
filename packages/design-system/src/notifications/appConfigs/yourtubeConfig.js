/**
 * Yourtube (Vid Min) Notification Configuration
 * Implementation guide and helpers for Yourtube-specific notifications
 */

import { YOURTUBE_NOTIFICATION_TYPES } from '../notificationTypes.js';
import {
  createMorningQueueNotification,
  createPriorityContentNotification
} from '../notificationScheduler.js';

/**
 * Background job handlers for Yourtube
 */
export const YourtubeBackgroundJobs = {
  /**
   * Morning queue notification job
   * Should run daily at the user's specified time
   * 
   * @param {Function} updateVideoQueue - Your API function to update queue
   * @param {Function} getQueueData - Your API function to get queue data
   * @param {Function} generateAISummary - Optional Apple Intelligence summary generator
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async morningQueue(updateVideoQueue, getQueueData, generateAISummary, sendNotification, settings) {
    if (!settings.enabled) return;

    try {
      await updateVideoQueue();
      
      const queueData = await getQueueData();
      
      if (settings.useAppleIntelligence && generateAISummary) {
        queueData.aiSummary = await generateAISummary(queueData.newItems);
      }

      const notification = createMorningQueueNotification(
        queueData,
        settings.useAppleIntelligence
      );
      
      if (notification) {
        await sendNotification(notification);
      }
    } catch (error) {
      console.error('Error in morning queue job:', error);
    }
  },

  /**
   * Priority channels check job
   * Should run at regular intervals to check for new videos
   * 
   * @param {Function} checkPriorityChannels - Your API function to check priority channels
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async priorityChannels(checkPriorityChannels, sendNotification, settings) {
    if (!settings.enabled || !settings.priorityChannelIds?.length) return;

    try {
      const newVideos = await checkPriorityChannels(settings.priorityChannelIds);

      for (const video of newVideos) {
        const notification = createPriorityContentNotification(video, 'video');
        await sendNotification(notification);
      }
    } catch (error) {
      console.error('Error in priority channels job:', error);
    }
  }
};

/**
 * Schedule setup helper for Yourtube
 */
export function getYourtubeScheduleConfig(preferences) {
  const schedules = [];

  if (preferences.morning_queue?.enabled) {
    schedules.push({
      id: 'yourtube.morning_queue',
      type: 'daily',
      time: preferences.morning_queue.time,
      handler: 'YourtubeBackgroundJobs.morningQueue'
    });
  }

  if (preferences.priority_channels?.enabled && preferences.priority_channels.priorityChannelIds?.length > 0) {
    schedules.push({
      id: 'yourtube.priority_channels',
      type: 'interval',
      intervalMinutes: preferences.priority_channels.checkIntervalMinutes,
      handler: 'YourtubeBackgroundJobs.priorityChannels'
    });
  }

  return schedules;
}

/**
 * Priority channel management helpers
 */
export const PriorityChannelManager = {
  /**
   * Add channel to priority list
   */
  addPriorityChannel(currentIds, channelId) {
    if (currentIds.includes(channelId)) {
      return currentIds;
    }
    return [...currentIds, channelId];
  },

  /**
   * Remove channel from priority list
   */
  removePriorityChannel(currentIds, channelId) {
    return currentIds.filter(id => id !== channelId);
  },

  /**
   * Toggle channel priority status
   */
  togglePriorityChannel(currentIds, channelId) {
    if (currentIds.includes(channelId)) {
      return this.removePriorityChannel(currentIds, channelId);
    }
    return this.addPriorityChannel(currentIds, channelId);
  },

  /**
   * Check if channel is priority
   */
  isPriorityChannel(currentIds, channelId) {
    return currentIds.includes(channelId);
  }
};

/**
 * Video tracking helper
 * Utilities for tracking notified videos
 */
export const VideoTracker = {
  /**
   * Get last check timestamp
   */
  getLastCheckTime() {
    if (typeof localStorage === 'undefined') return null;
    const timestamp = localStorage.getItem('yourtube-last-video-check');
    return timestamp ? new Date(timestamp) : null;
  },

  /**
   * Set last check timestamp
   */
  setLastCheckTime(time = new Date()) {
    if (typeof localStorage === 'undefined') return;
    localStorage.setItem('yourtube-last-video-check', time.toISOString());
  },

  /**
   * Mark videos as notified
   */
  markVideosNotified(videoIds) {
    if (typeof localStorage === 'undefined') return;
    
    const notified = this.getNotifiedVideos();
    const updated = [...new Set([...notified, ...videoIds])];
    
    localStorage.setItem('yourtube-notified-videos', JSON.stringify(updated));
  },

  /**
   * Get list of notified video IDs
   */
  getNotifiedVideos() {
    if (typeof localStorage === 'undefined') return [];
    
    const stored = localStorage.getItem('yourtube-notified-videos');
    return stored ? JSON.parse(stored) : [];
  },

  /**
   * Filter videos not yet notified
   */
  filterUnnotifiedVideos(videos) {
    const notified = this.getNotifiedVideos();
    return videos.filter(video => !notified.includes(video.id));
  }
};

/**
 * iOS implementation example
 */
export const iOSImplementationExample = `
// Swift implementation for Yourtube

import BackgroundTasks
import UserNotifications

class YourtubeNotificationManager {
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.yourtube.morning_queue",
            using: nil
        ) { task in
            self.handleMorningQueueTask(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.yourtube.priority_channels",
            using: nil
        ) { task in
            self.handlePriorityChannelsTask(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleMorningQueue(at time: String, useAI: Bool) {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.yourtube.morning_queue"
        )
        
        let nextTime = calculateNextDailyTime(from: time)
        request.earliestBeginDate = nextTime
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule morning queue: \\(error)")
        }
    }
    
    func handleMorningQueueTask(task: BGAppRefreshTask) {
        let queue = DispatchQueue.global()
        
        queue.async {
            Task {
                do {
                    // Update video feeds
                    await self.updateVideoQueue()
                    
                    // Get queue data
                    let queueData = await self.getQueueData()
                    
                    // Generate AI summary if enabled
                    let preferences = self.loadPreferences()
                    var summary: String?
                    if preferences.useAppleIntelligence {
                        summary = await self.generateAISummary(for: queueData.newVideos)
                    }
                    
                    // Send notification
                    if !queueData.newVideos.isEmpty {
                        await self.sendQueueNotification(
                            newCount: queueData.newVideos.count,
                            summary: summary
                        )
                    }
                    
                    // Reschedule
                    self.scheduleMorningQueue(
                        at: preferences.time,
                        useAI: preferences.useAppleIntelligence
                    )
                    
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
    
    func handlePriorityChannelsTask(task: BGAppRefreshTask) {
        let queue = DispatchQueue.global()
        
        queue.async {
            Task {
                do {
                    let preferences = self.loadPreferences()
                    let channelIds = preferences.priorityChannelIds
                    
                    let newVideos = await self.checkPriorityChannels(channelIds)
                    
                    for video in newVideos {
                        await self.sendPriorityVideoNotification(video)
                    }
                    
                    // Reschedule with same interval
                    self.schedulePriorityChannelsCheck(
                        intervalMinutes: preferences.checkIntervalMinutes
                    )
                    
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
}
`;

/**
 * Android implementation example
 */
export const androidImplementationExample = `
// Kotlin implementation for Yourtube

import androidx.work.*
import java.util.concurrent.TimeUnit

class YourtubeNotificationManager(private val context: Context) {
    fun scheduleMorningQueue(time: String, useAI: Boolean) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
            
        val data = workDataOf("use_ai" to useAI)
        
        val workRequest = PeriodicWorkRequestBuilder<MorningQueueWorker>(
            1, TimeUnit.DAYS
        )
            .setConstraints(constraints)
            .setInitialDelay(calculateDelayUntilTime(time), TimeUnit.MILLISECONDS)
            .setInputData(data)
            .build()
            
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "yourtube_morning_queue",
            ExistingPeriodicWorkPolicy.REPLACE,
            workRequest
        )
    }
    
    fun schedulePriorityChannelsCheck(intervalMinutes: Int, channelIds: List<String>) {
        val data = workDataOf(
            "channel_ids" to channelIds.toTypedArray()
        )
        
        val workRequest = PeriodicWorkRequestBuilder<PriorityChannelsWorker>(
            intervalMinutes.toLong(), TimeUnit.MINUTES
        )
            .setInputData(data)
            .build()
            
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "yourtube_priority_channels",
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }
}

class MorningQueueWorker(context: Context, params: WorkerParameters) 
    : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        return try {
            val useAI = inputData.getBoolean("use_ai", false)
            
            updateVideoQueue()
            val queueData = getQueueData()
            
            if (queueData.newVideos.isNotEmpty()) {
                val summary = if (useAI) {
                    generateAISummary(queueData.newVideos)
                } else {
                    null
                }
                
                sendQueueNotification(queueData.newVideos.size, summary)
            }
            
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}

class PriorityChannelsWorker(context: Context, params: WorkerParameters) 
    : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        return try {
            val channelIds = inputData.getStringArray("channel_ids")?.toList() ?: emptyList()
            
            val newVideos = checkPriorityChannels(channelIds)
            
            newVideos.forEach { video ->
                sendPriorityVideoNotification(video)
            }
            
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
`;
