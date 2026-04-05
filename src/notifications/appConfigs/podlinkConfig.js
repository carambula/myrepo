/**
 * Podlink Notification Configuration
 * Implementation guide and helpers for Podlink-specific notifications
 */

import { PODLINK_NOTIFICATION_TYPES } from '../notificationTypes.js';
import {
  createMorningQueueNotification,
  createPriorityContentNotification
} from '../notificationScheduler.js';

/**
 * Background job handlers for Podlink
 */
export const PodlinkBackgroundJobs = {
  /**
   * Morning queue notification job
   * Should run daily at the user's specified time
   * 
   * @param {Function} updatePodcastQueue - Your API function to update queue
   * @param {Function} getQueueData - Your API function to get queue data
   * @param {Function} generateAISummary - Optional Apple Intelligence summary generator
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async morningQueue(updatePodcastQueue, getQueueData, generateAISummary, sendNotification, settings) {
    if (!settings.enabled) return;

    try {
      await updatePodcastQueue();
      
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
   * Priority podcasts check job
   * Should run at regular intervals to check for new episodes
   * 
   * @param {Function} checkPriorityPodcasts - Your API function to check priority podcasts
   * @param {Function} sendNotification - Your platform notification sender
   * @param {Object} settings - Notification settings from preferences
   */
  async priorityPodcasts(checkPriorityPodcasts, sendNotification, settings) {
    if (!settings.enabled || !settings.priorityPodcastIds?.length) return;

    try {
      const newEpisodes = await checkPriorityPodcasts(settings.priorityPodcastIds);

      for (const episode of newEpisodes) {
        const notification = createPriorityContentNotification(episode, 'podcast');
        await sendNotification(notification);
      }
    } catch (error) {
      console.error('Error in priority podcasts job:', error);
    }
  }
};

/**
 * Schedule setup helper for Podlink
 */
export function getPodlinkScheduleConfig(preferences) {
  const schedules = [];

  if (preferences.morning_queue?.enabled) {
    schedules.push({
      id: 'podlink.morning_queue',
      type: 'daily',
      time: preferences.morning_queue.time,
      handler: 'PodlinkBackgroundJobs.morningQueue'
    });
  }

  if (preferences.priority_podcasts?.enabled && preferences.priority_podcasts.priorityPodcastIds?.length > 0) {
    schedules.push({
      id: 'podlink.priority_podcasts',
      type: 'interval',
      intervalMinutes: preferences.priority_podcasts.checkIntervalMinutes,
      handler: 'PodlinkBackgroundJobs.priorityPodcasts'
    });
  }

  return schedules;
}

/**
 * Apple Intelligence integration helper
 * For generating smart summaries of podcast queue
 */
export const AppleIntelligenceHelper = {
  /**
   * Generate summary using Apple Intelligence API
   * 
   * iOS 18+ example:
   */
  exampleSwiftCode: `
// Swift code for Apple Intelligence integration

import NaturalLanguage

class PodcastQueueSummarizer {
    func generateSummary(for episodes: [Episode]) async -> String {
        // Prepare episode data
        let episodeTexts = episodes.map { episode in
            "\\(episode.podcastName): \\(episode.title) - \\(episode.description)"
        }
        
        // Use Apple's summarization API (iOS 18+)
        let summarizer = NLSummarizer()
        summarizer.sourceLanguage = .english
        
        let combinedText = episodeTexts.joined(separator: "\\n\\n")
        
        do {
            let summary = try await summarizer.summarize(combinedText)
            return summary ?? "You have \\(episodes.count) new episodes"
        } catch {
            return "You have \\(episodes.count) new episodes"
        }
    }
}
`,

  /**
   * Format queue data for AI summary
   */
  formatQueueForSummary(episodes) {
    return episodes.map(ep => ({
      podcast: ep.podcastName,
      title: ep.title,
      description: ep.description?.substring(0, 200),
      duration: ep.duration,
      publishDate: ep.publishDate
    }));
  }
};

/**
 * Priority podcast management helpers
 */
export const PriorityPodcastManager = {
  /**
   * Add podcast to priority list
   */
  addPriorityPodcast(currentIds, podcastId) {
    if (currentIds.includes(podcastId)) {
      return currentIds;
    }
    return [...currentIds, podcastId];
  },

  /**
   * Remove podcast from priority list
   */
  removePriorityPodcast(currentIds, podcastId) {
    return currentIds.filter(id => id !== podcastId);
  },

  /**
   * Toggle podcast priority status
   */
  togglePriorityPodcast(currentIds, podcastId) {
    if (currentIds.includes(podcastId)) {
      return this.removePriorityPodcast(currentIds, podcastId);
    }
    return this.addPriorityPodcast(currentIds, podcastId);
  },

  /**
   * Check if podcast is priority
   */
  isPriorityPodcast(currentIds, podcastId) {
    return currentIds.includes(podcastId);
  }
};

/**
 * Web implementation note
 * 
 * For web apps, override the API methods with your actual implementations:
 * 
 * PodlinkBackgroundJobs.updatePodcastQueue = async function() {
 *   await fetch('/api/podcasts/update', { method: 'POST' });
 * };
 * 
 * PodlinkBackgroundJobs.checkPriorityPodcasts = async function(podcastIds) {
 *   const response = await fetch('/api/podcasts/check', {
 *     method: 'POST',
 *     body: JSON.stringify({ podcastIds })
 *   });
 *   return response.json();
 * };
 */
