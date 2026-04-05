/**
 * Notifications Module
 * Public API for notification preferences and scheduling
 */

export {
  APP_IDS,
  CYCLISMO_NOTIFICATION_TYPES,
  PODLINK_NOTIFICATION_TYPES,
  WATCHEDIT_NOTIFICATION_TYPES,
  YOURTUBE_NOTIFICATION_TYPES,
  getDefaultPreferences,
  getNotificationTypes,
  VALIDATION_RULES
} from './notificationTypes.js';

export {
  loadNotificationPreferences,
  saveNotificationPreferences,
  updateNotificationPreference,
  clearNotificationPreferences,
  validatePreferences,
  hasEnabledNotifications,
  getEnabledNotifications,
  exportAllPreferences,
  importAllPreferences
} from './notificationPreferences.js';

export {
  calculateNextNotificationTime,
  getScheduledNotifications,
  createCyclismoMorningNotification,
  createCyclismoRecapNotification,
  createCyclismoStreamStartNotification,
  createMorningQueueNotification,
  createPriorityContentNotification,
  createNewEpisodesNotification,
  BackgroundJobConfig,
  NotificationPermissions
} from './notificationScheduler.js';

export {
  default as NotificationService,
  NotificationPermissionManager,
  WebNotificationService,
  Platform
} from './notificationService.js';

export {
  default as BackgroundJobScheduler,
  getScheduler,
  initializeBackgroundJobs,
  stopBackgroundJobs,
  restartBackgroundJobs,
  JobQueue,
  getJobQueue
} from './backgroundJobScheduler.js';

export {
  CyclismoJobHandlers,
  PodlinkJobHandlers,
  WatcheditJobHandlers,
  YourtubeJobHandlers,
  getJobHandlers
} from './jobHandlers.js';

export {
  default as NotificationManager,
  getNotificationManager,
  initializeNotifications,
  setupNotifications
} from './notificationManager.js';
