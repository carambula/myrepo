/**
 * Storage Module
 * iCloud-synced storage for all user settings and preferences
 */

export {
  default as ICloudStorage,
  getICloudStorage,
  iCloudGet,
  iCloudSet,
  iCloudRemove,
  iCloudClear,
  iCloudKeys
} from './iCloudStorage.js';

export {
  default as SettingsStorage,
  getSettingsStorage,
  CommonSettings
} from './settingsStorage.js';
