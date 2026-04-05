/**
 * Data Updater Utility
 * Safely updates reference data (like movie databases) without affecting user data
 * 
 * Features:
 * - Version tracking
 * - Automatic backups before updates
 * - Rollback support
 * - Migration hooks
 */

import { createDataStorage } from './dataStorage.js';

/**
 * Update status enumeration
 */
export const UpdateStatus = {
  NOT_NEEDED: 'not_needed',
  AVAILABLE: 'available',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  FAILED: 'failed',
  ROLLED_BACK: 'rolled_back'
};

/**
 * Data Updater class
 */
export class DataUpdater {
  constructor(appId) {
    this.appId = appId;
    this.storage = createDataStorage(appId);
  }

  /**
   * Check if an update is needed
   * @param {string} currentVersion - The version currently in storage
   * @param {string} targetVersion - The version to update to
   * @returns {boolean} True if update is needed
   */
  isUpdateNeeded(currentVersion, targetVersion) {
    if (!currentVersion) return true;
    
    // Simple semantic version comparison (major.minor.patch)
    const parseVersion = (v) => v.split('.').map(Number);
    const current = parseVersion(currentVersion);
    const target = parseVersion(targetVersion);
    
    for (let i = 0; i < 3; i++) {
      if (target[i] > current[i]) return true;
      if (target[i] < current[i]) return false;
    }
    
    return false;
  }

  /**
   * Get update metadata
   */
  getUpdateMetadata() {
    return this.storage.getSystemData('update-metadata', {
      lastUpdateCheck: null,
      lastUpdateDate: null,
      lastUpdateVersion: null,
      updateStatus: UpdateStatus.NOT_NEEDED,
      backupAvailable: false
    });
  }

  /**
   * Save update metadata
   */
  saveUpdateMetadata(metadata) {
    return this.storage.saveSystemData('update-metadata', metadata);
  }

  /**
   * Create a backup before updating
   */
  createBackup() {
    try {
      const userData = this.storage.exportUserData();
      const referenceDataBackup = this._exportReferenceData();
      
      const backup = {
        timestamp: new Date().toISOString(),
        version: this.storage.getDataVersion(),
        userData,
        referenceData: referenceDataBackup
      };
      
      this.storage.saveSystemData('last-backup', backup);
      return true;
    } catch (error) {
      console.error('Error creating backup:', error);
      return false;
    }
  }

  /**
   * Restore from backup
   */
  restoreFromBackup() {
    try {
      const backup = this.storage.getSystemData('last-backup');
      
      if (!backup) {
        console.error('No backup available');
        return false;
      }
      
      // Restore user data
      if (backup.userData) {
        this.storage.importUserData(backup.userData);
      }
      
      // Restore reference data
      if (backup.referenceData) {
        this._importReferenceData(backup.referenceData);
      }
      
      // Restore version
      if (backup.version) {
        this.storage.setDataVersion(backup.version);
      }
      
      const metadata = this.getUpdateMetadata();
      metadata.updateStatus = UpdateStatus.ROLLED_BACK;
      metadata.lastRollbackDate = new Date().toISOString();
      this.saveUpdateMetadata(metadata);
      
      return true;
    } catch (error) {
      console.error('Error restoring from backup:', error);
      return false;
    }
  }

  /**
   * Update reference data safely
   * @param {string} targetVersion - Version identifier for the new data
   * @param {Object} newReferenceData - New reference data to install
   * @param {Function} migrationHook - Optional function to run before/after update
   * @returns {Object} Update result with status and details
   */
  async updateReferenceData(targetVersion, newReferenceData, migrationHook = null) {
    const currentVersion = this.storage.getDataVersion();
    
    // Check if update is needed
    if (!this.isUpdateNeeded(currentVersion, targetVersion)) {
      return {
        status: UpdateStatus.NOT_NEEDED,
        currentVersion,
        targetVersion,
        message: 'Already up to date'
      };
    }
    
    // Update metadata to in-progress
    let metadata = this.getUpdateMetadata();
    metadata.updateStatus = UpdateStatus.IN_PROGRESS;
    metadata.lastUpdateCheck = new Date().toISOString();
    this.saveUpdateMetadata(metadata);
    
    try {
      // Step 1: Create backup
      const backupSuccess = this.createBackup();
      if (!backupSuccess) {
        throw new Error('Failed to create backup');
      }
      
      metadata.backupAvailable = true;
      this.saveUpdateMetadata(metadata);
      
      // Step 2: Run pre-update migration hook
      if (migrationHook && typeof migrationHook.beforeUpdate === 'function') {
        await migrationHook.beforeUpdate(currentVersion, targetVersion);
      }
      
      // Step 3: Clear old reference data
      this.storage.clearReferenceData();
      
      // Step 4: Install new reference data
      Object.entries(newReferenceData).forEach(([key, value]) => {
        this.storage.saveReferenceData(key, value, targetVersion);
      });
      
      // Step 5: Update version
      this.storage.setDataVersion(targetVersion);
      
      // Step 6: Run post-update migration hook
      if (migrationHook && typeof migrationHook.afterUpdate === 'function') {
        await migrationHook.afterUpdate(currentVersion, targetVersion);
      }
      
      // Step 7: Update metadata to completed
      metadata.updateStatus = UpdateStatus.COMPLETED;
      metadata.lastUpdateDate = new Date().toISOString();
      metadata.lastUpdateVersion = targetVersion;
      this.saveUpdateMetadata(metadata);
      
      return {
        status: UpdateStatus.COMPLETED,
        currentVersion,
        targetVersion,
        message: `Successfully updated from ${currentVersion} to ${targetVersion}`
      };
      
    } catch (error) {
      console.error('Error updating reference data:', error);
      
      // Update failed - mark as failed
      metadata.updateStatus = UpdateStatus.FAILED;
      metadata.lastError = error.message;
      metadata.lastErrorDate = new Date().toISOString();
      this.saveUpdateMetadata(metadata);
      
      return {
        status: UpdateStatus.FAILED,
        currentVersion,
        targetVersion,
        error: error.message,
        message: 'Update failed. Backup is available for rollback.'
      };
    }
  }

  /**
   * Helper to export reference data for backup
   */
  _exportReferenceData() {
    if (typeof localStorage === 'undefined') {
      return {};
    }

    try {
      const referenceData = {};
      const prefix = `min-apps-${this.appId}-reference-`;
      
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key && key.startsWith(prefix)) {
          const dataKey = key.substring(prefix.length);
          const value = localStorage.getItem(key);
          referenceData[dataKey] = value ? JSON.parse(value) : null;
        }
      }
      
      return referenceData;
    } catch (error) {
      console.error('Error exporting reference data:', error);
      return {};
    }
  }

  /**
   * Helper to import reference data from backup
   */
  _importReferenceData(referenceData) {
    if (typeof localStorage === 'undefined') {
      return false;
    }

    try {
      // Clear existing reference data
      this.storage.clearReferenceData();
      
      // Import from backup
      Object.entries(referenceData).forEach(([key, value]) => {
        if (value && value.data !== undefined) {
          this.storage.saveReferenceData(key, value.data, value.version);
        }
      });
      
      return true;
    } catch (error) {
      console.error('Error importing reference data:', error);
      return false;
    }
  }
}

/**
 * Create a data updater instance
 */
export function createDataUpdater(appId) {
  return new DataUpdater(appId);
}

/**
 * Bootstrap helper for initial data installation
 * @param {string} appId - Application identifier
 * @param {string} version - Data version
 * @param {Object} bootstrapData - Initial reference data to install
 * @returns {Promise<Object>} Bootstrap result
 */
export async function bootstrapReferenceData(appId, version, bootstrapData) {
  const updater = createDataUpdater(appId);
  const storage = createDataStorage(appId);
  
  // Check if already bootstrapped
  const currentVersion = storage.getDataVersion();
  if (currentVersion && currentVersion !== '1.0.0') {
    return {
      status: 'already_bootstrapped',
      version: currentVersion,
      message: 'App already has reference data installed'
    };
  }
  
  // Perform initial installation
  return await updater.updateReferenceData(version, bootstrapData);
}
