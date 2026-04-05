/**
 * App Initializer
 * Handles safe app startup with automatic data updates
 * 
 * This module provides a promoted, user-friendly way to update reference data
 * (like movie databases) on app start without affecting user data.
 */

import { createDataStorage } from './dataStorage.js';
import { createDataUpdater, UpdateStatus } from './dataUpdater.js';

/**
 * Initialization options
 */
export const InitializationOptions = {
  /**
   * Update prompts - how to notify users about available updates
   */
  UpdatePrompt: {
    SILENT: 'silent',           // Update automatically without prompting
    NOTIFY: 'notify',           // Show notification but auto-update
    PROMPT: 'prompt',           // Ask user before updating
    MANUAL: 'manual'            // Never auto-update
  },

  /**
   * Backup strategies
   */
  BackupStrategy: {
    ALWAYS: 'always',           // Always backup before updates
    FIRST_TIME: 'first_time',   // Only backup on first update
    NEVER: 'never'              // Don't create backups (not recommended)
  }
};

/**
 * App Initializer class
 */
export class AppInitializer {
  constructor(appId, options = {}) {
    this.appId = appId;
    this.storage = createDataStorage(appId);
    this.updater = createDataUpdater(appId);
    
    this.options = {
      updatePrompt: options.updatePrompt || InitializationOptions.UpdatePrompt.NOTIFY,
      backupStrategy: options.backupStrategy || InitializationOptions.BackupStrategy.ALWAYS,
      onUpdateAvailable: options.onUpdateAvailable || null,
      onUpdateStart: options.onUpdateStart || null,
      onUpdateComplete: options.onUpdateComplete || null,
      onUpdateError: options.onUpdateError || null,
      migrationHooks: options.migrationHooks || null
    };
  }

  /**
   * Initialize the app
   * Checks for and applies data updates on startup
   * 
   * @param {Object} latestReferenceData - The latest reference data package
   * @param {string} latestVersion - Version of the latest data
   * @returns {Promise<Object>} Initialization result
   */
  async initialize(latestReferenceData, latestVersion) {
    const result = {
      success: false,
      status: null,
      currentVersion: null,
      targetVersion: latestVersion,
      updateApplied: false,
      message: '',
      userDataIntact: true
    };

    try {
      // Get current version
      const currentVersion = this.storage.getDataVersion();
      result.currentVersion = currentVersion;

      // Check if this is first-time setup
      const isFirstTime = !currentVersion || currentVersion === '1.0.0';
      
      if (isFirstTime) {
        return await this._performFirstTimeSetup(latestReferenceData, latestVersion, result);
      }

      // Check if update is needed
      const updateNeeded = this.updater.isUpdateNeeded(currentVersion, latestVersion);
      
      if (!updateNeeded) {
        result.success = true;
        result.status = UpdateStatus.NOT_NEEDED;
        result.message = `App is up to date (version ${currentVersion})`;
        return result;
      }

      // Update is available
      return await this._performUpdate(latestReferenceData, latestVersion, result);

    } catch (error) {
      console.error('Error during app initialization:', error);
      result.success = false;
      result.status = UpdateStatus.FAILED;
      result.message = `Initialization failed: ${error.message}`;
      
      if (this.options.onUpdateError) {
        this.options.onUpdateError(error, result);
      }
      
      return result;
    }
  }

  /**
   * Perform first-time setup
   */
  async _performFirstTimeSetup(referenceData, version, result) {
    console.log('Performing first-time setup...');
    
    if (this.options.onUpdateStart) {
      this.options.onUpdateStart({
        isFirstTime: true,
        targetVersion: version
      });
    }

    const updateResult = await this.updater.updateReferenceData(
      version,
      referenceData,
      this.options.migrationHooks
    );

    result.success = updateResult.status === UpdateStatus.COMPLETED;
    result.status = updateResult.status;
    result.updateApplied = true;
    result.message = updateResult.message || 'First-time setup completed';
    result.currentVersion = version;

    if (this.options.onUpdateComplete) {
      this.options.onUpdateComplete(result);
    }

    return result;
  }

  /**
   * Perform update
   */
  async _performUpdate(referenceData, version, result) {
    // Notify about available update
    if (this.options.onUpdateAvailable) {
      const shouldUpdate = await this.options.onUpdateAvailable({
        currentVersion: result.currentVersion,
        targetVersion: version
      });

      // If prompt mode and user declined
      if (this.options.updatePrompt === InitializationOptions.UpdatePrompt.PROMPT && !shouldUpdate) {
        result.success = true;
        result.status = 'update_declined';
        result.message = 'Update available but not applied';
        return result;
      }
    }

    // Manual mode - don't auto-update
    if (this.options.updatePrompt === InitializationOptions.UpdatePrompt.MANUAL) {
      result.success = true;
      result.status = 'update_available';
      result.message = 'Update available. Use manual update to apply.';
      return result;
    }

    // Proceed with update
    if (this.options.onUpdateStart) {
      this.options.onUpdateStart({
        isFirstTime: false,
        currentVersion: result.currentVersion,
        targetVersion: version
      });
    }

    const updateResult = await this.updater.updateReferenceData(
      version,
      referenceData,
      this.options.migrationHooks
    );

    result.success = updateResult.status === UpdateStatus.COMPLETED;
    result.status = updateResult.status;
    result.updateApplied = updateResult.status === UpdateStatus.COMPLETED;
    result.message = updateResult.message;
    
    if (updateResult.status === UpdateStatus.COMPLETED) {
      result.currentVersion = version;
    }

    if (this.options.onUpdateComplete) {
      this.options.onUpdateComplete(result);
    }

    return result;
  }

  /**
   * Manually trigger an update
   * Useful for settings pages or when user explicitly requests update
   */
  async manualUpdate(referenceData, version) {
    const result = {
      success: false,
      status: null,
      previousVersion: this.storage.getDataVersion(),
      newVersion: version,
      updateApplied: false,
      message: ''
    };

    try {
      if (this.options.onUpdateStart) {
        this.options.onUpdateStart({
          isFirstTime: false,
          isManual: true,
          currentVersion: result.previousVersion,
          targetVersion: version
        });
      }

      const updateResult = await this.updater.updateReferenceData(
        version,
        referenceData,
        this.options.migrationHooks
      );

      result.success = updateResult.status === UpdateStatus.COMPLETED;
      result.status = updateResult.status;
      result.updateApplied = updateResult.status === UpdateStatus.COMPLETED;
      result.message = updateResult.message;

      if (this.options.onUpdateComplete) {
        this.options.onUpdateComplete(result);
      }

      return result;

    } catch (error) {
      console.error('Error during manual update:', error);
      result.success = false;
      result.status = UpdateStatus.FAILED;
      result.message = `Update failed: ${error.message}`;

      if (this.options.onUpdateError) {
        this.options.onUpdateError(error, result);
      }

      return result;
    }
  }

  /**
   * Check for available updates without applying them
   */
  checkForUpdates(latestVersion) {
    const currentVersion = this.storage.getDataVersion();
    const updateAvailable = this.updater.isUpdateNeeded(currentVersion, latestVersion);

    return {
      updateAvailable,
      currentVersion,
      latestVersion,
      metadata: this.updater.getUpdateMetadata()
    };
  }

  /**
   * Rollback to previous version
   */
  async rollback() {
    try {
      const success = this.updater.restoreFromBackup();
      
      return {
        success,
        message: success 
          ? 'Successfully rolled back to previous version'
          : 'Rollback failed - no backup available'
      };
    } catch (error) {
      console.error('Error during rollback:', error);
      return {
        success: false,
        message: `Rollback failed: ${error.message}`
      };
    }
  }

  /**
   * Export user data for safekeeping
   */
  exportUserData() {
    return this.storage.exportUserData();
  }

  /**
   * Import user data (restore from export)
   */
  importUserData(backup) {
    return this.storage.importUserData(backup);
  }
}

/**
 * Create an app initializer instance
 */
export function createAppInitializer(appId, options = {}) {
  return new AppInitializer(appId, options);
}

/**
 * Quick initialization helper for simple use cases
 * 
 * @param {string} appId - Application identifier
 * @param {Object} latestReferenceData - Latest reference data to install
 * @param {string} latestVersion - Version of the latest data
 * @param {Object} options - Optional configuration
 * @returns {Promise<Object>} Initialization result
 */
export async function quickInit(appId, latestReferenceData, latestVersion, options = {}) {
  const initializer = createAppInitializer(appId, options);
  return await initializer.initialize(latestReferenceData, latestVersion);
}
