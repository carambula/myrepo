/**
 * Notification Service
 * Handles sending push notifications across different platforms
 */

/**
 * Platform detection
 */
export const Platform = {
  isWeb() {
    return typeof window !== 'undefined' && typeof navigator !== 'undefined';
  },
  
  isIOS() {
    return typeof window !== 'undefined' && 
           /iPad|iPhone|iPod/.test(navigator.userAgent) &&
           !window.MSStream;
  },
  
  isAndroid() {
    return typeof window !== 'undefined' && 
           /Android/.test(navigator.userAgent);
  },
  
  hasNotificationAPI() {
    return this.isWeb() && 'Notification' in window;
  },
  
  hasServiceWorker() {
    return this.isWeb() && 'serviceWorker' in navigator;
  }
};

/**
 * Notification Permission Manager
 */
export class NotificationPermissionManager {
  /**
   * Check current permission status
   */
  static async getPermissionStatus() {
    if (!Platform.hasNotificationAPI()) {
      return 'unsupported';
    }
    
    return Notification.permission;
  }
  
  /**
   * Request notification permission
   */
  static async requestPermission() {
    if (!Platform.hasNotificationAPI()) {
      throw new Error('Notifications not supported on this platform');
    }
    
    if (Notification.permission === 'granted') {
      return true;
    }
    
    if (Notification.permission === 'denied') {
      return false;
    }
    
    const permission = await Notification.requestPermission();
    return permission === 'granted';
  }
  
  /**
   * Check if permissions are granted
   */
  static async hasPermission() {
    const status = await this.getPermissionStatus();
    return status === 'granted';
  }
}

/**
 * Web Push Notification Service
 */
export class WebNotificationService {
  /**
   * Send a notification using the Web Notification API
   */
  static async sendNotification({ title, body, icon, badge, tag, data, actions = [] }) {
    const hasPermission = await NotificationPermissionManager.hasPermission();
    
    if (!hasPermission) {
      throw new Error('Notification permission not granted');
    }
    
    if (Platform.hasServiceWorker()) {
      return this.sendServiceWorkerNotification({ title, body, icon, badge, tag, data, actions });
    }
    
    return this.sendDirectNotification({ title, body, icon, badge, tag, data });
  }
  
  /**
   * Send notification via Service Worker
   */
  static async sendServiceWorkerNotification({ title, body, icon, badge, tag, data, actions }) {
    try {
      const registration = await navigator.serviceWorker.ready;
      
      await registration.showNotification(title, {
        body,
        icon: icon || '/icon-192.png',
        badge: badge || '/badge-72.png',
        tag,
        data,
        actions,
        requireInteraction: false,
        silent: false
      });
      
      return { success: true, method: 'service-worker' };
    } catch (error) {
      console.error('Service Worker notification error:', error);
      return this.sendDirectNotification({ title, body, icon, badge, tag, data });
    }
  }
  
  /**
   * Send notification directly (fallback)
   */
  static async sendDirectNotification({ title, body, icon, badge, tag, data }) {
    try {
      const notification = new Notification(title, {
        body,
        icon: icon || '/icon-192.png',
        badge: badge || '/badge-72.png',
        tag,
        data,
        requireInteraction: false
      });
      
      return { success: true, method: 'direct', notification };
    } catch (error) {
      console.error('Direct notification error:', error);
      throw error;
    }
  }
}

/**
 * Unified Notification Service
 * Detects platform and sends notifications appropriately
 */
export class NotificationService {
  static listeners = new Map();
  
  /**
   * Initialize notification service
   */
  static async initialize() {
    if (Platform.hasServiceWorker()) {
      await this.registerServiceWorker();
    }
    
    const hasPermission = await NotificationPermissionManager.hasPermission();
    
    if (!hasPermission) {
      console.warn('Notification permissions not granted');
    }
    
    return hasPermission;
  }
  
  /**
   * Register service worker
   */
  static async registerServiceWorker() {
    if (!Platform.hasServiceWorker()) {
      return null;
    }
    
    try {
      const registration = await navigator.serviceWorker.register('/service-worker.js');
      console.log('Service Worker registered:', registration);
      return registration;
    } catch (error) {
      console.error('Service Worker registration failed:', error);
      return null;
    }
  }
  
  /**
   * Send notification
   */
  static async send(notification) {
    const { title, body, icon, badge, tag, data, actions } = notification;
    
    if (Platform.hasNotificationAPI()) {
      return WebNotificationService.sendNotification({
        title,
        body,
        icon,
        badge,
        tag,
        data,
        actions
      });
    }
    
    console.warn('Notifications not supported, notification not sent:', notification);
    return { success: false, error: 'unsupported' };
  }
  
  /**
   * Schedule a notification (using setTimeout for now)
   * In production, this should use platform-specific scheduling
   */
  static scheduleNotification(notification, scheduledTime) {
    const now = new Date();
    const delay = scheduledTime.getTime() - now.getTime();
    
    if (delay <= 0) {
      return this.send(notification);
    }
    
    const timerId = setTimeout(() => {
      this.send(notification);
      this.listeners.delete(timerId);
    }, delay);
    
    this.listeners.set(timerId, { notification, scheduledTime });
    
    return {
      timerId,
      cancel: () => {
        clearTimeout(timerId);
        this.listeners.delete(timerId);
      }
    };
  }
  
  /**
   * Cancel a scheduled notification
   */
  static cancelScheduledNotification(timerId) {
    const listener = this.listeners.get(timerId);
    
    if (listener) {
      clearTimeout(timerId);
      this.listeners.delete(timerId);
      return true;
    }
    
    return false;
  }
  
  /**
   * Cancel all scheduled notifications
   */
  static cancelAllScheduledNotifications() {
    this.listeners.forEach((_, timerId) => {
      clearTimeout(timerId);
    });
    
    this.listeners.clear();
  }
  
  /**
   * Get all scheduled notifications
   */
  static getScheduledNotifications() {
    return Array.from(this.listeners.entries()).map(([timerId, data]) => ({
      timerId,
      ...data
    }));
  }
}

/**
 * Notification click handler
 */
if (Platform.isWeb()) {
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'notification-click') {
        const { notification } = event.data;
        
        if (notification.data?.url) {
          window.location.href = notification.data.url;
        }
      }
    });
  }
}

/**
 * Export default service
 */
export default NotificationService;
