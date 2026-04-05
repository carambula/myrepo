/**
 * Notification Scheduler
 * Utilities for scheduling background jobs and notifications
 * 
 * Note: This provides the interface and helpers for web applications.
 * Background jobs are executed using:
 * - Web: Service Workers, Notification API, Background Sync API
 * - Browser timers (setTimeout/setInterval) for scheduling
 */

import { getEnabledNotifications } from './notificationPreferences.js';
import { APP_IDS, CYCLISMO_NOTIFICATION_TYPES, PODLINK_NOTIFICATION_TYPES } from './notificationTypes.js';

/**
 * Calculate next notification time from time string (HH:MM)
 */
export function calculateNextNotificationTime(timeString, timezone) {
  const [hours, minutes] = timeString.split(':').map(Number);
  const now = new Date();
  const next = new Date(now);
  
  next.setHours(hours, minutes, 0, 0);
  
  if (next <= now) {
    next.setDate(next.getDate() + 1);
  }
  
  return next;
}

/**
 * Get all scheduled notifications for an app
 */
export function getScheduledNotifications(appId) {
  const enabled = getEnabledNotifications(appId);
  const scheduled = [];

  enabled.forEach(({ type, settings }) => {
    if (settings.time) {
      scheduled.push({
        id: `${appId}-${type}`,
        appId,
        type,
        nextTime: calculateNextNotificationTime(settings.time, settings.timezone),
        settings
      });
    }

    if (settings.checkIntervalMinutes) {
      scheduled.push({
        id: `${appId}-${type}`,
        appId,
        type,
        interval: settings.checkIntervalMinutes * 60 * 1000,
        settings
      });
    }
  });

  return scheduled;
}

/**
 * Create notification payload for Cyclismo morning races
 */
export function createCyclismoMorningNotification(racesData) {
  const { races, streamers } = racesData;
  
  if (!races || races.length === 0) {
    return null;
  }

  const raceTimes = races.map(r => r.time).join(', ');
  const raceNames = races.map(r => r.name).join(', ');
  
  return {
    title: `${races.length} Race${races.length > 1 ? 's' : ''} Today`,
    body: `${raceNames}\nTimes: ${raceTimes}\nStreamers: ${streamers.join(', ')}`,
    data: {
      type: CYCLISMO_NOTIFICATION_TYPES.MORNING_RACES,
      races
    }
  };
}

/**
 * Create notification payload for Cyclismo recap
 */
export function createCyclismoRecapNotification(recapData) {
  const { podcasts, replays } = recapData;
  
  const items = [];
  if (podcasts?.length > 0) {
    items.push(`${podcasts.length} podcast${podcasts.length > 1 ? 's' : ''}`);
  }
  if (replays?.length > 0) {
    items.push(`${replays.length} replay${replays.length > 1 ? 's' : ''}`);
  }
  
  if (items.length === 0) {
    return null;
  }

  return {
    title: 'Race Recap Available',
    body: `${items.join(' and ')} available from today's races`,
    data: {
      type: CYCLISMO_NOTIFICATION_TYPES.RECAP,
      podcasts,
      replays
    }
  };
}

/**
 * Create notification payload for Cyclismo stream start
 */
export function createCyclismoStreamStartNotification(race, minutesBefore) {
  return {
    title: `Race Starting ${minutesBefore === 5 ? 'Soon' : `in ${minutesBefore} min`}`,
    body: `${race.name} is about to start streaming`,
    data: {
      type: CYCLISMO_NOTIFICATION_TYPES.STREAM_START,
      race
    }
  };
}

/**
 * Create notification payload for Podlink/Yourtube morning queue
 */
export function createMorningQueueNotification(queueData, useAppleIntelligence = false) {
  const { newItems, queue } = queueData;
  
  if (!newItems || newItems.length === 0) {
    return null;
  }

  let body = `${newItems.length} new item${newItems.length > 1 ? 's' : ''} in your queue`;
  
  if (useAppleIntelligence && queueData.aiSummary) {
    body = queueData.aiSummary;
  } else if (newItems.length <= 3) {
    body = newItems.map(item => item.title).join('\n');
  }

  return {
    title: 'Your Queue Update',
    body,
    data: {
      type: PODLINK_NOTIFICATION_TYPES.MORNING_QUEUE,
      newItems,
      queue
    }
  };
}

/**
 * Create notification payload for priority podcast/channel
 */
export function createPriorityContentNotification(content, contentType = 'podcast') {
  return {
    title: `New ${contentType === 'podcast' ? 'Episode' : 'Video'}`,
    body: `${content.channelName || content.podcastName}: ${content.title}`,
    data: {
      type: contentType === 'podcast' 
        ? PODLINK_NOTIFICATION_TYPES.PRIORITY_PODCASTS 
        : 'priority_channels',
      content
    }
  };
}

/**
 * Create notification payload for WatchedIt new episodes
 */
export function createNewEpisodesNotification(episodes) {
  if (!episodes || episodes.length === 0) {
    return null;
  }

  const episodeList = episodes.slice(0, 3).map(e => e.title).join('\n');
  const more = episodes.length > 3 ? `\n+${episodes.length - 3} more` : '';

  return {
    title: `${episodes.length} New Episode${episodes.length > 1 ? 's' : ''}`,
    body: episodeList + more,
    data: {
      type: 'new_episodes',
      episodes
    }
  };
}

/**
 * Background job configuration helpers
 */
export const BackgroundJobConfig = {
  /**
   * Get background job identifiers for an app
   */
  getJobIdentifiers(appId) {
    const enabled = getEnabledNotifications(appId);
    return enabled.map(({ type }) => `${appId}.${type}`);
  },

  /**
   * Get minimum fetch interval (in seconds) for background job scheduling
   */
  getMinimumFetchInterval(appId) {
    const enabled = getEnabledNotifications(appId);
    const intervals = enabled
      .filter(({ settings }) => settings.checkIntervalMinutes)
      .map(({ settings }) => settings.checkIntervalMinutes * 60);
    
    return intervals.length > 0 ? Math.min(...intervals) : 3600;
  },

  /**
   * Check if app should schedule daily notifications
   */
  hasDailyNotifications(appId) {
    const enabled = getEnabledNotifications(appId);
    return enabled.some(({ settings }) => settings.time);
  },

  /**
   * Check if app should schedule interval-based notifications
   */
  hasIntervalNotifications(appId) {
    const enabled = getEnabledNotifications(appId);
    return enabled.some(({ settings }) => settings.checkIntervalMinutes);
  }
};

/**
 * Permission helpers
 */
export const NotificationPermissions = {
  /**
   * Request notification permissions (platform-specific implementation needed)
   */
  async request() {
    if (typeof Notification !== 'undefined' && Notification.requestPermission) {
      const permission = await Notification.requestPermission();
      return permission === 'granted';
    }
    return false;
  },

  /**
   * Check current notification permission status
   */
  async check() {
    if (typeof Notification !== 'undefined') {
      return Notification.permission === 'granted';
    }
    return false;
  },

  /**
   * Web platform permission guide
   */
  platformGuide: {
    web: 'Use Notification.requestPermission() API',
    info: 'For web apps, use the Web Notification API'
  }
};
