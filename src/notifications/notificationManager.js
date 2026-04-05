/**
 * Notification Manager
 * High-level API for initializing and managing the notification system
 */

import NotificationService, { NotificationPermissionManager } from './notificationService.js';
import { initializeBackgroundJobs, stopBackgroundJobs, restartBackgroundJobs, getScheduler } from './backgroundJobScheduler.js';
import { getJobHandlers } from './jobHandlers.js';
import { loadNotificationPreferences, saveNotificationPreferences } from './notificationPreferences.js';

/**
 * Notification Manager
 * Main entry point for notification system
 */
export class NotificationManager {
  constructor(appId, options = {}) {
    this.appId = appId;
    this.options = options;
    this.isInitialized = false;
    this.scheduler = null;
    this.jobHandlers = null;
  }
  
  /**
   * Initialize notification system
   */
  async initialize() {
    if (this.isInitialized) {
      console.warn('Notification manager already initialized');
      return this;
    }
    
    console.log(`Initializing notification system for ${this.appId}...`);
    
    try {
      await NotificationService.initialize();
      
      const hasPermission = await NotificationPermissionManager.hasPermission();
      
      if (!hasPermission) {
        console.warn('Notification permissions not granted. Call requestPermissions() to request.');
      }
      
      this.jobHandlers = this.options.jobHandlers || getJobHandlers(this.appId);
      
      this.scheduler = await initializeBackgroundJobs(this.appId, this.jobHandlers);
      
      this.isInitialized = true;
      
      console.log(`Notification system initialized for ${this.appId}`);
      
      return this;
    } catch (error) {
      console.error('Failed to initialize notification system:', error);
      throw error;
    }
  }
  
  /**
   * Request notification permissions
   */
  async requestPermissions() {
    const granted = await NotificationPermissionManager.requestPermission();
    
    if (granted) {
      console.log('Notification permissions granted');
      
      if (!this.isInitialized) {
        await this.initialize();
      }
    } else {
      console.warn('Notification permissions denied');
    }
    
    return granted;
  }
  
  /**
   * Check if permissions are granted
   */
  async hasPermissions() {
    return NotificationPermissionManager.hasPermission();
  }
  
  /**
   * Send a test notification
   */
  async sendTestNotification(type = 'default') {
    const testNotifications = {
      default: {
        title: 'Test Notification',
        body: 'This is a test notification from min apps',
        icon: '/icon-192.png'
      },
      cyclismo: {
        title: '2 Races Today',
        body: 'Stage 5, Stage 6\nTimes: 14:00, 16:30\nStreamers: NBC Sports, Eurosport',
        icon: '/icon-192.png',
        tag: 'cyclismo-morning'
      },
      podlink: {
        title: 'Your Queue Update',
        body: '3 new episodes in your queue',
        icon: '/icon-192.png',
        tag: 'podlink-queue'
      },
      watchedit: {
        title: '5 New Episodes',
        body: 'New Episode 1\nNew Episode 2\nNew Episode 3\n+2 more',
        icon: '/icon-192.png',
        tag: 'watchedit-episodes'
      },
      yourtube: {
        title: 'Your Queue Update',
        body: '4 new videos in your queue',
        icon: '/icon-192.png',
        tag: 'yourtube-queue'
      }
    };
    
    const notification = testNotifications[type] || testNotifications.default;
    
    return NotificationService.send(notification);
  }
  
  /**
   * Update preferences and restart jobs
   */
  async updatePreferences(preferences) {
    saveNotificationPreferences(this.appId, preferences);
    
    if (this.isInitialized) {
      await restartBackgroundJobs(this.appId, this.jobHandlers);
    }
  }
  
  /**
   * Get current preferences
   */
  getPreferences() {
    return loadNotificationPreferences(this.appId);
  }
  
  /**
   * Start all jobs
   */
  startJobs() {
    if (!this.isInitialized) {
      throw new Error('Notification manager not initialized');
    }
    
    this.scheduler.startAll();
  }
  
  /**
   * Stop all jobs
   */
  stopJobs() {
    if (!this.isInitialized) {
      throw new Error('Notification manager not initialized');
    }
    
    this.scheduler.stopAll();
  }
  
  /**
   * Get job status
   */
  getJobStatus() {
    if (!this.isInitialized) {
      return [];
    }
    
    return this.scheduler.getAllJobs();
  }
  
  /**
   * Get running jobs
   */
  getRunningJobs() {
    if (!this.isInitialized) {
      return [];
    }
    
    return this.scheduler.getRunningJobs();
  }
  
  /**
   * Manually trigger a job
   */
  async triggerJob(jobType) {
    if (!this.isInitialized) {
      throw new Error('Notification manager not initialized');
    }
    
    const handler = this.jobHandlers[jobType];
    
    if (!handler) {
      throw new Error(`No handler found for job type: ${jobType}`);
    }
    
    const preferences = this.getPreferences();
    const settings = preferences[jobType];
    
    await handler.call(this.jobHandlers, settings, NotificationService);
  }
  
  /**
   * Set custom job handler
   */
  setJobHandler(jobType, handler) {
    if (!this.jobHandlers) {
      this.jobHandlers = {};
    }
    
    this.jobHandlers[jobType] = handler;
  }
  
  /**
   * Shutdown notification system
   */
  shutdown() {
    if (this.isInitialized) {
      this.stopJobs();
      this.isInitialized = false;
      console.log(`Notification system shut down for ${this.appId}`);
    }
  }
}

/**
 * Global notification managers by app ID
 */
const managers = new Map();

/**
 * Get or create notification manager for an app
 */
export function getNotificationManager(appId, options) {
  if (!managers.has(appId)) {
    managers.set(appId, new NotificationManager(appId, options));
  }
  
  return managers.get(appId);
}

/**
 * Initialize notification system for an app
 */
export async function initializeNotifications(appId, options = {}) {
  const manager = getNotificationManager(appId, options);
  await manager.initialize();
  return manager;
}

/**
 * Quick setup helper
 */
export async function setupNotifications(appId, options = {}) {
  console.log(`Setting up notifications for ${appId}...`);
  
  const manager = await initializeNotifications(appId, options);
  
  const hasPermission = await manager.hasPermissions();
  
  if (!hasPermission && options.requestPermissions !== false) {
    console.log('Requesting notification permissions...');
    await manager.requestPermissions();
  }
  
  if (options.autoStart !== false) {
    manager.startJobs();
  }
  
  console.log(`Notifications setup complete for ${appId}`);
  
  return manager;
}

/**
 * Export default manager class
 */
export default NotificationManager;
