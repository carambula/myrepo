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
 * Web implementation note
 * 
 * For web apps, override the API methods with your actual implementations:
 * 
 * WatcheditBackgroundJobs.checkForNewEpisodes = async function() {
 *   const response = await fetch('/api/episodes/new');
 *   return response.json();
 * };
 * 
 * The BackgroundJobScheduler will automatically call this at the scheduled time.
 */
