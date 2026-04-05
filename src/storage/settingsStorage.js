/**
 * Settings Storage
 * iCloud-synced storage for all user settings across min apps
 * 
 * All user preferences, settings, and configuration are stored here
 * and automatically synced via iCloud to all user devices.
 */

import { getICloudStorage } from './iCloudStorage.js';

const SETTINGS_PREFIX = 'min-apps-settings';

/**
 * Get storage instance
 */
function getStorage() {
  return getICloudStorage();
}

/**
 * Get storage key for a setting
 */
function getSettingsKey(appId, settingName) {
  return `${SETTINGS_PREFIX}-${appId}-${settingName}`;
}

/**
 * Settings Storage Manager
 */
export class SettingsStorage {
  constructor(appId) {
    this.appId = appId;
    this.storage = getStorage();
  }
  
  /**
   * Get a setting value
   */
  async get(settingName, defaultValue = null) {
    try {
      const key = getSettingsKey(this.appId, settingName);
      const value = await this.storage.getItem(key);
      
      if (value === null) {
        return defaultValue;
      }
      
      return JSON.parse(value);
    } catch (error) {
      console.error(`Error getting setting ${settingName}:`, error);
      return defaultValue;
    }
  }
  
  /**
   * Set a setting value
   */
  async set(settingName, value) {
    try {
      const key = getSettingsKey(this.appId, settingName);
      await this.storage.setItem(key, JSON.stringify(value));
      return true;
    } catch (error) {
      console.error(`Error setting ${settingName}:`, error);
      return false;
    }
  }
  
  /**
   * Remove a setting
   */
  async remove(settingName) {
    try {
      const key = getSettingsKey(this.appId, settingName);
      await this.storage.removeItem(key);
      return true;
    } catch (error) {
      console.error(`Error removing setting ${settingName}:`, error);
      return false;
    }
  }
  
  /**
   * Get all settings for this app
   */
  async getAll() {
    try {
      const prefix = `${SETTINGS_PREFIX}-${this.appId}-`;
      const keys = await this.storage.keys();
      const settings = {};
      
      for (const key of keys) {
        if (key.startsWith(prefix)) {
          const settingName = key.replace(prefix, '');
          const value = await this.storage.getItem(key);
          
          try {
            settings[settingName] = JSON.parse(value);
          } catch {
            settings[settingName] = value;
          }
        }
      }
      
      return settings;
    } catch (error) {
      console.error('Error getting all settings:', error);
      return {};
    }
  }
  
  /**
   * Clear all settings for this app
   */
  async clearAll() {
    try {
      const prefix = `${SETTINGS_PREFIX}-${this.appId}-`;
      const keys = await this.storage.keys();
      
      for (const key of keys) {
        if (key.startsWith(prefix)) {
          await this.storage.removeItem(key);
        }
      }
      
      return true;
    } catch (error) {
      console.error('Error clearing all settings:', error);
      return false;
    }
  }
  
  /**
   * Export settings for backup
   */
  async export() {
    return this.getAll();
  }
  
  /**
   * Import settings from backup
   */
  async import(settings) {
    try {
      for (const [settingName, value] of Object.entries(settings)) {
        await this.set(settingName, value);
      }
      return true;
    } catch (error) {
      console.error('Error importing settings:', error);
      return false;
    }
  }
}

/**
 * Get settings storage for an app
 */
export function getSettingsStorage(appId) {
  return new SettingsStorage(appId);
}

/**
 * Common settings helpers
 */
export const CommonSettings = {
  // Theme settings
  THEME: 'theme',
  THEME_AUTO: 'theme-auto',
  
  // Display settings
  FONT_SIZE: 'font-size',
  COMPACT_MODE: 'compact-mode',
  
  // Privacy settings
  ANALYTICS_ENABLED: 'analytics-enabled',
  CRASH_REPORTS_ENABLED: 'crash-reports-enabled',
  
  // Notification settings (handled by notification system)
  NOTIFICATIONS: 'notifications',
  
  // App-specific settings keys
  // Add more as needed per app
};

/**
 * Listen for iCloud sync changes
 */
if (typeof window !== 'undefined') {
  window.handleICloudSync = (syncInfo) => {
    console.log('iCloud sync received:', syncInfo);
    
    // Dispatch custom event for apps to listen to
    const event = new CustomEvent('icloudsync', {
      detail: syncInfo
    });
    
    window.dispatchEvent(event);
  };
}

export default SettingsStorage;
