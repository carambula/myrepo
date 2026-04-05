/**
 * Notification Preferences Manager
 * Handles reading, writing, and validating notification preferences
 */

import { getDefaultPreferences, VALIDATION_RULES } from './notificationTypes.js';

const STORAGE_KEY_PREFIX = 'min-apps-notifications';

/**
 * Get storage key for a specific app
 */
function getStorageKey(appId) {
  return `${STORAGE_KEY_PREFIX}-${appId}`;
}

/**
 * Load notification preferences for an app
 */
export function loadNotificationPreferences(appId) {
  if (typeof localStorage === 'undefined') {
    return getDefaultPreferences(appId);
  }

  try {
    const stored = localStorage.getItem(getStorageKey(appId));
    if (!stored) {
      return getDefaultPreferences(appId);
    }

    const parsed = JSON.parse(stored);
    const defaults = getDefaultPreferences(appId);
    
    return {
      ...defaults,
      ...parsed
    };
  } catch (error) {
    console.error('Error loading notification preferences:', error);
    return getDefaultPreferences(appId);
  }
}

/**
 * Save notification preferences for an app
 */
export function saveNotificationPreferences(appId, preferences) {
  if (typeof localStorage === 'undefined') {
    console.warn('localStorage not available');
    return false;
  }

  try {
    const validated = validatePreferences(appId, preferences);
    if (!validated.valid) {
      console.error('Invalid preferences:', validated.errors);
      return false;
    }

    localStorage.setItem(getStorageKey(appId), JSON.stringify(preferences));
    return true;
  } catch (error) {
    console.error('Error saving notification preferences:', error);
    return false;
  }
}

/**
 * Update a specific notification preference
 */
export function updateNotificationPreference(appId, notificationType, updates) {
  const currentPreferences = loadNotificationPreferences(appId);
  
  const updatedPreferences = {
    ...currentPreferences,
    [notificationType]: {
      ...currentPreferences[notificationType],
      ...updates
    }
  };

  return saveNotificationPreferences(appId, updatedPreferences);
}

/**
 * Clear notification preferences for an app
 */
export function clearNotificationPreferences(appId) {
  if (typeof localStorage === 'undefined') {
    return false;
  }

  try {
    localStorage.removeItem(getStorageKey(appId));
    return true;
  } catch (error) {
    console.error('Error clearing notification preferences:', error);
    return false;
  }
}

/**
 * Validate time format (HH:MM)
 */
function validateTime(time) {
  if (!time) return { valid: false, error: 'Time is required' };
  
  const { pattern, message } = VALIDATION_RULES.time;
  if (!pattern.test(time)) {
    return { valid: false, error: message };
  }
  
  return { valid: true };
}

/**
 * Validate numeric range
 */
function validateRange(value, rule) {
  if (value === undefined || value === null) {
    return { valid: false, error: 'Value is required' };
  }
  
  if (typeof value !== 'number') {
    return { valid: false, error: 'Value must be a number' };
  }
  
  if (value < rule.min || value > rule.max) {
    return { valid: false, error: rule.message };
  }
  
  return { valid: true };
}

/**
 * Validate notification preferences
 */
export function validatePreferences(appId, preferences) {
  const errors = {};
  let valid = true;

  Object.entries(preferences).forEach(([notificationType, settings]) => {
    const typeErrors = {};

    if (settings.time) {
      const timeValidation = validateTime(settings.time);
      if (!timeValidation.valid) {
        typeErrors.time = timeValidation.error;
        valid = false;
      }
    }

    if (settings.hoursAfterLastRace !== undefined) {
      const validation = validateRange(
        settings.hoursAfterLastRace,
        VALIDATION_RULES.hoursAfterLastRace
      );
      if (!validation.valid) {
        typeErrors.hoursAfterLastRace = validation.error;
        valid = false;
      }
    }

    if (settings.minutesBefore !== undefined) {
      const validation = validateRange(
        settings.minutesBefore,
        VALIDATION_RULES.minutesBefore
      );
      if (!validation.valid) {
        typeErrors.minutesBefore = validation.error;
        valid = false;
      }
    }

    if (settings.checkIntervalMinutes !== undefined) {
      const validation = validateRange(
        settings.checkIntervalMinutes,
        VALIDATION_RULES.checkIntervalMinutes
      );
      if (!validation.valid) {
        typeErrors.checkIntervalMinutes = validation.error;
        valid = false;
      }
    }

    if (Object.keys(typeErrors).length > 0) {
      errors[notificationType] = typeErrors;
    }
  });

  return { valid, errors };
}

/**
 * Check if any notifications are enabled for an app
 */
export function hasEnabledNotifications(appId) {
  const preferences = loadNotificationPreferences(appId);
  
  return Object.values(preferences).some(setting => setting.enabled === true);
}

/**
 * Get all enabled notification types for an app
 */
export function getEnabledNotifications(appId) {
  const preferences = loadNotificationPreferences(appId);
  
  return Object.entries(preferences)
    .filter(([_, settings]) => settings.enabled === true)
    .map(([type, settings]) => ({ type, settings }));
}

/**
 * Export all preferences (for backup/sync)
 */
export function exportAllPreferences() {
  if (typeof localStorage === 'undefined') {
    return null;
  }

  const allPreferences = {};
  const keys = Object.keys(localStorage);
  
  keys.forEach(key => {
    if (key.startsWith(STORAGE_KEY_PREFIX)) {
      try {
        allPreferences[key] = JSON.parse(localStorage.getItem(key));
      } catch (error) {
        console.error(`Error exporting preference ${key}:`, error);
      }
    }
  });

  return allPreferences;
}

/**
 * Import all preferences (from backup/sync)
 */
export function importAllPreferences(preferences) {
  if (typeof localStorage === 'undefined') {
    return false;
  }

  try {
    Object.entries(preferences).forEach(([key, value]) => {
      if (key.startsWith(STORAGE_KEY_PREFIX)) {
        localStorage.setItem(key, JSON.stringify(value));
      }
    });
    return true;
  } catch (error) {
    console.error('Error importing preferences:', error);
    return false;
  }
}
