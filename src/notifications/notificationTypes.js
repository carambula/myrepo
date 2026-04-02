/**
 * Notification Types and Configurations
 * Data structures for managing notification preferences across all min apps
 */

/**
 * App identifiers
 */
export const APP_IDS = {
  CYCLISMO: 'cyclismo',
  PODLINK: 'podlink',
  WATCHEDIT: 'watchedit',
  YOURTUBE: 'yourtube'
};

/**
 * Cyclismo notification types
 */
export const CYCLISMO_NOTIFICATION_TYPES = {
  MORNING_RACES: 'morning_races',
  RECAP: 'recap',
  STREAM_START: 'stream_start'
};

/**
 * Podlink notification types
 */
export const PODLINK_NOTIFICATION_TYPES = {
  MORNING_QUEUE: 'morning_queue',
  PRIORITY_PODCASTS: 'priority_podcasts'
};

/**
 * WatchedIt notification types
 */
export const WATCHEDIT_NOTIFICATION_TYPES = {
  NEW_EPISODES: 'new_episodes'
};

/**
 * Yourtube notification types (future expansion)
 */
export const YOURTUBE_NOTIFICATION_TYPES = {
  MORNING_QUEUE: 'morning_queue',
  PRIORITY_CHANNELS: 'priority_channels'
};

/**
 * Default notification preferences for Cyclismo
 */
export const DEFAULT_CYCLISMO_PREFERENCES = {
  [CYCLISMO_NOTIFICATION_TYPES.MORNING_RACES]: {
    enabled: false,
    time: '08:00',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
  },
  [CYCLISMO_NOTIFICATION_TYPES.RECAP]: {
    enabled: false,
    hoursAfterLastRace: 3
  },
  [CYCLISMO_NOTIFICATION_TYPES.STREAM_START]: {
    enabled: false,
    minutesBefore: 5,
    onlySavedRaces: false
  }
};

/**
 * Default notification preferences for Podlink
 */
export const DEFAULT_PODLINK_PREFERENCES = {
  [PODLINK_NOTIFICATION_TYPES.MORNING_QUEUE]: {
    enabled: false,
    time: '08:00',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    useAppleIntelligence: true
  },
  [PODLINK_NOTIFICATION_TYPES.PRIORITY_PODCASTS]: {
    enabled: false,
    checkIntervalMinutes: 60,
    priorityPodcastIds: []
  }
};

/**
 * Default notification preferences for WatchedIt
 */
export const DEFAULT_WATCHEDIT_PREFERENCES = {
  [WATCHEDIT_NOTIFICATION_TYPES.NEW_EPISODES]: {
    enabled: false,
    time: '09:00',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
  }
};

/**
 * Default notification preferences for Yourtube
 */
export const DEFAULT_YOURTUBE_PREFERENCES = {
  [YOURTUBE_NOTIFICATION_TYPES.MORNING_QUEUE]: {
    enabled: false,
    time: '08:00',
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    useAppleIntelligence: true
  },
  [YOURTUBE_NOTIFICATION_TYPES.PRIORITY_CHANNELS]: {
    enabled: false,
    checkIntervalMinutes: 60,
    priorityChannelIds: []
  }
};

/**
 * Get default preferences for a specific app
 */
export function getDefaultPreferences(appId) {
  switch (appId) {
    case APP_IDS.CYCLISMO:
      return DEFAULT_CYCLISMO_PREFERENCES;
    case APP_IDS.PODLINK:
      return DEFAULT_PODLINK_PREFERENCES;
    case APP_IDS.WATCHEDIT:
      return DEFAULT_WATCHEDIT_PREFERENCES;
    case APP_IDS.YOURTUBE:
      return DEFAULT_YOURTUBE_PREFERENCES;
    default:
      return {};
  }
}

/**
 * Get notification types for a specific app
 */
export function getNotificationTypes(appId) {
  switch (appId) {
    case APP_IDS.CYCLISMO:
      return CYCLISMO_NOTIFICATION_TYPES;
    case APP_IDS.PODLINK:
      return PODLINK_NOTIFICATION_TYPES;
    case APP_IDS.WATCHEDIT:
      return WATCHEDIT_NOTIFICATION_TYPES;
    case APP_IDS.YOURTUBE:
      return YOURTUBE_NOTIFICATION_TYPES;
    default:
      return {};
  }
}

/**
 * Notification preference validation schema
 */
export const VALIDATION_RULES = {
  time: {
    pattern: /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/,
    message: 'Time must be in HH:MM format (24-hour)'
  },
  hoursAfterLastRace: {
    min: 1,
    max: 12,
    message: 'Hours must be between 1 and 12'
  },
  minutesBefore: {
    min: 5,
    max: 60,
    message: 'Minutes must be between 5 and 60'
  },
  checkIntervalMinutes: {
    min: 15,
    max: 360,
    message: 'Check interval must be between 15 and 360 minutes'
  }
};
