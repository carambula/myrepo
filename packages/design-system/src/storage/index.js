/**
 * Storage Module - Safe data management for min apps
 * 
 * Provides utilities for:
 * - Namespaced data storage (user, reference, system)
 * - Safe reference data updates without affecting user data
 * - Automatic backups and rollback
 * - Version tracking and migrations
 */

export {
  DataStorage,
  createDataStorage,
  STORAGE_NAMESPACES
} from './dataStorage.js';

export {
  DataUpdater,
  createDataUpdater,
  UpdateStatus,
  bootstrapReferenceData
} from './dataUpdater.js';

export {
  AppInitializer,
  createAppInitializer,
  quickInit,
  InitializationOptions
} from './appInitializer.js';
