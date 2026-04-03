/**
 * Data Storage Utility
 * Provides safe, namespaced storage for user data and reference data
 * 
 * Key concepts:
 * - USER data: User-specific data that should never be lost (watchlists, ratings, etc.)
 * - REFERENCE data: App-provided data that can be updated (movie database, Oscar winners)
 * - SYSTEM data: App state and preferences
 */

const STORAGE_NAMESPACES = {
  USER: 'user',
  REFERENCE: 'reference',
  SYSTEM: 'system'
};

/**
 * Generate a namespaced storage key
 * @param {string} appId - Application identifier (e.g., 'watchedit')
 * @param {string} namespace - Data namespace (user/reference/system)
 * @param {string} key - Data key
 * @returns {string} Namespaced storage key
 */
function getStorageKey(appId, namespace, key) {
  return `min-apps-${appId}-${namespace}-${key}`;
}

/**
 * Storage API for managing app data with proper isolation
 */
export class DataStorage {
  constructor(appId) {
    this.appId = appId;
  }

  /**
   * Save user data (always preserved during updates)
   */
  saveUserData(key, data) {
    if (typeof localStorage === 'undefined') {
      console.warn('localStorage not available');
      return false;
    }

    try {
      const storageKey = getStorageKey(this.appId, STORAGE_NAMESPACES.USER, key);
      localStorage.setItem(storageKey, JSON.stringify({
        data,
        timestamp: new Date().toISOString(),
        version: this.getDataVersion()
      }));
      return true;
    } catch (error) {
      console.error('Error saving user data:', error);
      return false;
    }
  }

  /**
   * Load user data
   */
  getUserData(key, defaultValue = null) {
    if (typeof localStorage === 'undefined') {
      return defaultValue;
    }

    try {
      const storageKey = getStorageKey(this.appId, STORAGE_NAMESPACES.USER, key);
      const stored = localStorage.getItem(storageKey);
      
      if (!stored) {
        return defaultValue;
      }

      const parsed = JSON.parse(stored);
      return parsed.data !== undefined ? parsed.data : defaultValue;
    } catch (error) {
      console.error('Error loading user data:', error);
      return defaultValue;
    }
  }

  /**
   * Save reference data (can be replaced during updates)
   */
  saveReferenceData(key, data, version = null) {
    if (typeof localStorage === 'undefined') {
      console.warn('localStorage not available');
      return false;
    }

    try {
      const storageKey = getStorageKey(this.appId, STORAGE_NAMESPACES.REFERENCE, key);
      localStorage.setItem(storageKey, JSON.stringify({
        data,
        timestamp: new Date().toISOString(),
        version: version || this.getDataVersion()
      }));
      return true;
    } catch (error) {
      console.error('Error saving reference data:', error);
      return false;
    }
  }

  /**
   * Load reference data
   */
  getReferenceData(key, defaultValue = null) {
    if (typeof localStorage === 'undefined') {
      return defaultValue;
    }

    try {
      const storageKey = getStorageKey(this.appId, STORAGE_NAMESPACES.REFERENCE, key);
      const stored = localStorage.getItem(storageKey);
      
      if (!stored) {
        return defaultValue;
      }

      const parsed = JSON.parse(stored);
      return parsed.data !== undefined ? parsed.data : defaultValue;
    } catch (error) {
      console.error('Error loading reference data:', error);
      return defaultValue;
    }
  }

  /**
   * Save system data (preferences, app state)
   */
  saveSystemData(key, data) {
    if (typeof localStorage === 'undefined') {
      console.warn('localStorage not available');
      return false;
    }

    try {
      const storageKey = getStorageKey(this.appId, STORAGE_NAMESPACES.SYSTEM, key);
      localStorage.setItem(storageKey, JSON.stringify({
        data,
        timestamp: new Date().toISOString()
      }));
      return true;
    } catch (error) {
      console.error('Error saving system data:', error);
      return false;
    }
  }

  /**
   * Load system data
   */
  getSystemData(key, defaultValue = null) {
    if (typeof localStorage === 'undefined') {
      return defaultValue;
    }

    try {
      const storageKey = getStorageKey(this.appId, STORAGE_NAMESPACES.SYSTEM, key);
      const stored = localStorage.getItem(storageKey);
      
      if (!stored) {
        return defaultValue;
      }

      const parsed = JSON.parse(stored);
      return parsed.data !== undefined ? parsed.data : defaultValue;
    } catch (error) {
      console.error('Error loading system data:', error);
      return defaultValue;
    }
  }

  /**
   * Get current data version
   */
  getDataVersion() {
    return this.getSystemData('data-version', '1.0.0');
  }

  /**
   * Set data version
   */
  setDataVersion(version) {
    return this.saveSystemData('data-version', version);
  }

  /**
   * Clear only reference data (safe for updates)
   */
  clearReferenceData() {
    if (typeof localStorage === 'undefined') {
      return false;
    }

    try {
      const prefix = `min-apps-${this.appId}-${STORAGE_NAMESPACES.REFERENCE}-`;
      const keysToRemove = [];
      
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith(prefix)) {
          keysToRemove.push(key);
        }
      }
      
      keysToRemove.forEach(key => localStorage.removeItem(key));
      return true;
    } catch (error) {
      console.error('Error clearing reference data:', error);
      return false;
    }
  }

  /**
   * Get all user data keys
   */
  getUserDataKeys() {
    if (typeof localStorage === 'undefined') {
      return [];
    }

    try {
      const prefix = `min-apps-${this.appId}-${STORAGE_NAMESPACES.USER}-`;
      const keys = [];
      
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith(prefix)) {
          keys.push(key.substring(prefix.length));
        }
      }
      
      return keys;
    } catch (error) {
      console.error('Error getting user data keys:', error);
      return [];
    }
  }

  /**
   * Export all user data for backup
   */
  exportUserData() {
    if (typeof localStorage === 'undefined') {
      return null;
    }

    try {
      const userData = {};
      const keys = this.getUserDataKeys();
      
      keys.forEach(key => {
        userData[key] = this.getUserData(key);
      });
      
      return {
        appId: this.appId,
        exportDate: new Date().toISOString(),
        version: this.getDataVersion(),
        data: userData
      };
    } catch (error) {
      console.error('Error exporting user data:', error);
      return null;
    }
  }

  /**
   * Import user data from backup
   */
  importUserData(backup) {
    if (typeof localStorage === 'undefined') {
      return false;
    }

    try {
      if (!backup || !backup.data || backup.appId !== this.appId) {
        console.error('Invalid backup data');
        return false;
      }

      Object.entries(backup.data).forEach(([key, value]) => {
        this.saveUserData(key, value);
      });
      
      return true;
    } catch (error) {
      console.error('Error importing user data:', error);
      return false;
    }
  }
}

/**
 * Create a storage instance for an app
 */
export function createDataStorage(appId) {
  return new DataStorage(appId);
}

export { STORAGE_NAMESPACES };
