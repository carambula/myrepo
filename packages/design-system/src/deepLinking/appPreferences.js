/**
 * App Preferences Manager
 * 
 * Manages user preferences for which apps to use for different content types.
 * This ensures that when a user clicks a link, we respect their preferred apps.
 */

import { APP_IDS, CONTENT_TYPES, CONTENT_TYPE_TO_APPS } from './urlSchemes.js';

const STORAGE_KEY = 'min-apps-deep-link-preferences';

/**
 * Default app preferences structure
 */
const DEFAULT_PREFERENCES = {
  version: 1,
  lastUpdated: null,
  preferences: {
    [CONTENT_TYPES.MOVIE]: null,
    [CONTENT_TYPES.TV_SHOW]: null,
    [CONTENT_TYPES.PERSON]: null,
    [CONTENT_TYPES.PODCAST]: null,
    [CONTENT_TYPES.PODCAST_EPISODE]: null,
    [CONTENT_TYPES.VIDEO]: null,
    [CONTENT_TYPES.CHANNEL]: null,
    [CONTENT_TYPES.PLAYLIST]: null,
    [CONTENT_TYPES.RACE]: null,
    [CONTENT_TYPES.RIDER]: null,
    [CONTENT_TYPES.TEAM]: null,
    [CONTENT_TYPES.STAGE]: null,
  },
  // Global fallback preferences
  fallbackBehavior: 'deeplink', // 'deeplink' | 'web' | 'ask'
  // Which external apps to prefer (e.g., for podcasts: Apple Podcasts, Spotify, etc.)
  externalAppPreferences: {
    podcast: null, // null means use min app, or 'apple-podcasts', 'spotify', etc.
    video: null, // null means use min app, or 'youtube-app', etc.
  },
  // Whether to always try the min app first before external apps
  preferMinApps: true,
};

/**
 * Load deep link preferences from storage
 */
export function loadDeepLinkPreferences() {
  try {
    if (typeof localStorage === 'undefined') {
      return { ...DEFAULT_PREFERENCES };
    }

    const stored = localStorage.getItem(STORAGE_KEY);
    if (!stored) {
      return { ...DEFAULT_PREFERENCES };
    }

    const parsed = JSON.parse(stored);
    
    // Merge with defaults to handle any new content types
    return {
      ...DEFAULT_PREFERENCES,
      ...parsed,
      preferences: {
        ...DEFAULT_PREFERENCES.preferences,
        ...parsed.preferences,
      },
      externalAppPreferences: {
        ...DEFAULT_PREFERENCES.externalAppPreferences,
        ...parsed.externalAppPreferences,
      },
    };
  } catch (error) {
    console.error('Error loading deep link preferences:', error);
    return { ...DEFAULT_PREFERENCES };
  }
}

/**
 * Save deep link preferences to storage
 */
export function saveDeepLinkPreferences(preferences) {
  try {
    if (typeof localStorage === 'undefined') {
      console.warn('localStorage not available, cannot save deep link preferences');
      return false;
    }

    const toSave = {
      ...preferences,
      lastUpdated: new Date().toISOString(),
    };

    localStorage.setItem(STORAGE_KEY, JSON.stringify(toSave));
    return true;
  } catch (error) {
    console.error('Error saving deep link preferences:', error);
    return false;
  }
}

/**
 * Get the preferred app for a specific content type
 */
export function getPreferredApp(contentType, preferences = null) {
  const prefs = preferences || loadDeepLinkPreferences();
  
  // Check if user has set a preference
  const userPreference = prefs.preferences[contentType];
  if (userPreference) {
    return userPreference;
  }

  // Fall back to the default app for this content type
  const availableApps = CONTENT_TYPE_TO_APPS[contentType];
  if (availableApps && availableApps.length > 0) {
    return availableApps[0];
  }

  return null;
}

/**
 * Set the preferred app for a specific content type
 */
export function setPreferredApp(contentType, appId) {
  const preferences = loadDeepLinkPreferences();
  
  // Validate that the app can handle this content type
  const availableApps = CONTENT_TYPE_TO_APPS[contentType];
  if (!availableApps || !availableApps.includes(appId)) {
    console.warn(`App ${appId} cannot handle content type ${contentType}`);
    return false;
  }

  preferences.preferences[contentType] = appId;
  return saveDeepLinkPreferences(preferences);
}

/**
 * Reset preferences for a specific content type
 */
export function resetPreference(contentType) {
  const preferences = loadDeepLinkPreferences();
  preferences.preferences[contentType] = null;
  return saveDeepLinkPreferences(preferences);
}

/**
 * Reset all preferences to defaults
 */
export function resetAllPreferences() {
  try {
    if (typeof localStorage !== 'undefined') {
      localStorage.removeItem(STORAGE_KEY);
    }
    return true;
  } catch (error) {
    console.error('Error resetting deep link preferences:', error);
    return false;
  }
}

/**
 * Get all apps installed/available (this would be implemented by the host app)
 */
export function getInstalledApps() {
  // This is a placeholder that the host app should override
  // It should return an array of APP_IDS that are installed
  return Object.values(APP_IDS);
}

/**
 * Set fallback behavior when no preference is set
 */
export function setFallbackBehavior(behavior) {
  if (!['deeplink', 'web', 'ask'].includes(behavior)) {
    console.warn(`Invalid fallback behavior: ${behavior}`);
    return false;
  }

  const preferences = loadDeepLinkPreferences();
  preferences.fallbackBehavior = behavior;
  return saveDeepLinkPreferences(preferences);
}

/**
 * Set whether to prefer min apps over external apps
 */
export function setPreferMinApps(prefer) {
  const preferences = loadDeepLinkPreferences();
  preferences.preferMinApps = Boolean(prefer);
  return saveDeepLinkPreferences(preferences);
}

/**
 * Set external app preference for a category
 */
export function setExternalAppPreference(category, appIdentifier) {
  const preferences = loadDeepLinkPreferences();
  
  if (!preferences.externalAppPreferences.hasOwnProperty(category)) {
    console.warn(`Unknown external app category: ${category}`);
    return false;
  }

  preferences.externalAppPreferences[category] = appIdentifier;
  return saveDeepLinkPreferences(preferences);
}

/**
 * Get summary of current preferences
 */
export function getPreferencesSummary() {
  const preferences = loadDeepLinkPreferences();
  const summary = {
    configured: [],
    defaults: [],
    fallbackBehavior: preferences.fallbackBehavior,
    preferMinApps: preferences.preferMinApps,
  };

  Object.entries(preferences.preferences).forEach(([contentType, appId]) => {
    const defaultApp = CONTENT_TYPE_TO_APPS[contentType]?.[0];
    
    if (appId) {
      summary.configured.push({
        contentType,
        appId,
        isDefault: appId === defaultApp,
      });
    } else if (defaultApp) {
      summary.defaults.push({
        contentType,
        appId: defaultApp,
      });
    }
  });

  return summary;
}

/**
 * Validate preferences object
 */
export function validatePreferences(preferences) {
  const errors = [];

  if (!preferences || typeof preferences !== 'object') {
    errors.push('Preferences must be an object');
    return { valid: false, errors };
  }

  if (preferences.preferences) {
    Object.entries(preferences.preferences).forEach(([contentType, appId]) => {
      if (appId !== null) {
        const availableApps = CONTENT_TYPE_TO_APPS[contentType];
        if (!availableApps || !availableApps.includes(appId)) {
          errors.push(`Invalid app ${appId} for content type ${contentType}`);
        }
      }
    });
  }

  if (preferences.fallbackBehavior) {
    if (!['deeplink', 'web', 'ask'].includes(preferences.fallbackBehavior)) {
      errors.push(`Invalid fallback behavior: ${preferences.fallbackBehavior}`);
    }
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * Export preferences as JSON
 */
export function exportPreferences() {
  const preferences = loadDeepLinkPreferences();
  return JSON.stringify(preferences, null, 2);
}

/**
 * Import preferences from JSON
 */
export function importPreferences(json) {
  try {
    const preferences = typeof json === 'string' ? JSON.parse(json) : json;
    const validation = validatePreferences(preferences);
    
    if (!validation.valid) {
      console.error('Invalid preferences:', validation.errors);
      return false;
    }

    return saveDeepLinkPreferences(preferences);
  } catch (error) {
    console.error('Error importing preferences:', error);
    return false;
  }
}
