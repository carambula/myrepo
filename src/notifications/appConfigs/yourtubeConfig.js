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
 * Web implementation note
 * 
 * For web apps, override the API methods with your actual implementations:
 * 
 * YourtubeBackgroundJobs.updateVideoQueue = async function() {
 *   await fetch('/api/videos/update', { method: 'POST' });
 * };
 * 
 * YourtubeBackgroundJobs.checkPriorityChannels = async function(channelIds) {
 *   const response = await fetch('/api/channels/check', {
 *     method: 'POST',
 *     body: JSON.stringify({ channelIds })
 *   });
 *   return response.json();
 * };
 * 
 * YourtubeBackgroundJobs.generateAISummary = async function(videos) {
 *   const response = await fetch('/api/ai/summarize', {
 *     method: 'POST',
 *     body: JSON.stringify({ videos })
 *   });
 *   const { summary } = await response.json();
 *   return summary;
 * };
 */
