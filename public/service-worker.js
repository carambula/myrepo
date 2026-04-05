/**
 * Service Worker for Min Apps
 * Handles push notifications and background sync
 */

const CACHE_NAME = 'min-apps-v1';
const NOTIFICATION_TAG_PREFIX = 'min-apps';

/**
 * Install event
 */
self.addEventListener('install', (event) => {
  console.log('Service Worker installing...');
  self.skipWaiting();
});

/**
 * Activate event
 */
self.addEventListener('activate', (event) => {
  console.log('Service Worker activating...');
  event.waitUntil(self.clients.claim());
});

/**
 * Push event - handles incoming push notifications
 */
self.addEventListener('push', (event) => {
  console.log('Push event received:', event);
  
  if (!event.data) {
    console.log('Push event has no data');
    return;
  }
  
  let notification;
  try {
    notification = event.data.json();
  } catch (error) {
    notification = {
      title: 'Notification',
      body: event.data.text()
    };
  }
  
  const { title, body, icon, badge, tag, data, actions = [] } = notification;
  
  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: icon || '/icon-192.png',
      badge: badge || '/badge-72.png',
      tag: tag || `${NOTIFICATION_TAG_PREFIX}-${Date.now()}`,
      data: data || {},
      actions,
      requireInteraction: false,
      silent: false
    })
  );
});

/**
 * Notification click event
 */
self.addEventListener('notificationclick', (event) => {
  console.log('Notification clicked:', event.notification);
  
  event.notification.close();
  
  const notificationData = event.notification.data || {};
  const url = notificationData.url || '/';
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if (client.url === url && 'focus' in client) {
            return client.focus();
          }
        }
        
        if (clients.openWindow) {
          return clients.openWindow(url);
        }
      })
  );
  
  if (event.action) {
    console.log('Action clicked:', event.action);
    
    clients.matchAll({ type: 'window' }).then((clientList) => {
      if (clientList.length > 0) {
        clientList[0].postMessage({
          type: 'notification-action',
          action: event.action,
          notification: event.notification.data
        });
      }
    });
  } else {
    clients.matchAll({ type: 'window' }).then((clientList) => {
      if (clientList.length > 0) {
        clientList[0].postMessage({
          type: 'notification-click',
          notification: event.notification.data
        });
      }
    });
  }
});

/**
 * Background sync event (for future use)
 */
self.addEventListener('sync', (event) => {
  console.log('Background sync event:', event.tag);
  
  if (event.tag.startsWith('check-notifications-')) {
    const appId = event.tag.replace('check-notifications-', '');
    
    event.waitUntil(
      checkAndSendNotifications(appId)
    );
  }
});

/**
 * Message event - receive messages from main thread
 */
self.addEventListener('message', (event) => {
  console.log('Service Worker received message:', event.data);
  
  if (event.data && event.data.type === 'SHOW_NOTIFICATION') {
    const { title, body, icon, badge, tag, data } = event.data.notification;
    
    self.registration.showNotification(title, {
      body,
      icon: icon || '/icon-192.png',
      badge: badge || '/badge-72.png',
      tag: tag || `${NOTIFICATION_TAG_PREFIX}-${Date.now()}`,
      data: data || {}
    });
  }
  
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

/**
 * Helper: Check and send notifications
 * This would be called by background sync
 */
async function checkAndSendNotifications(appId) {
  console.log(`Checking notifications for ${appId}`);
  
  try {
    const response = await fetch(`/api/notifications/check?app=${appId}`);
    
    if (!response.ok) {
      throw new Error('Failed to check notifications');
    }
    
    const notifications = await response.json();
    
    for (const notification of notifications) {
      await self.registration.showNotification(notification.title, {
        body: notification.body,
        icon: notification.icon || '/icon-192.png',
        badge: notification.badge || '/badge-72.png',
        tag: notification.tag,
        data: notification.data || {}
      });
    }
  } catch (error) {
    console.error('Error checking notifications:', error);
  }
}

/**
 * Periodic background sync (Chrome 80+)
 */
self.addEventListener('periodicsync', (event) => {
  console.log('Periodic sync event:', event.tag);
  
  if (event.tag.startsWith('check-notifications-')) {
    const appId = event.tag.replace('check-notifications-', '');
    event.waitUntil(checkAndSendNotifications(appId));
  }
});
