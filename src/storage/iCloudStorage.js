/**
 * iCloud-Synced Storage
 * Storage layer that syncs user settings to iCloud
 * 
 * For native iOS/macOS apps:
 * - Uses NSUbiquitousKeyValueStore for iCloud Key-Value Storage
 * - Automatically syncs across user's devices
 * - Falls back to localStorage for web/testing
 * 
 * Implementation:
 * 1. Native apps provide webkit message handlers
 * 2. JavaScript calls native code via webkit.messageHandlers
 * 3. Native code reads/writes to NSUbiquitousKeyValueStore
 * 4. Changes sync automatically via iCloud
 */

/**
 * Detect if running in native iOS/macOS app with iCloud support
 */
function hasNativeICloudSupport() {
  return typeof window !== 'undefined' &&
         window.webkit &&
         window.webkit.messageHandlers &&
         window.webkit.messageHandlers.iCloudStorage;
}

/**
 * iCloud Storage Service
 */
export class ICloudStorage {
  constructor() {
    this.isNative = hasNativeICloudSupport();
    this.pendingCallbacks = new Map();
    this.callbackId = 0;
    
    if (this.isNative) {
      this.setupNativeListener();
    }
  }
  
  /**
   * Setup listener for native responses
   */
  setupNativeListener() {
    if (typeof window === 'undefined') return;
    
    window.handleICloudStorageResponse = (response) => {
      const { callbackId, value, error } = response;
      const callbacks = this.pendingCallbacks.get(callbackId);
      
      if (callbacks) {
        if (error) {
          callbacks.reject(new Error(error));
        } else {
          callbacks.resolve(value);
        }
        this.pendingCallbacks.delete(callbackId);
      }
    };
  }
  
  /**
   * Get item from iCloud storage
   */
  async getItem(key) {
    if (this.isNative) {
      return this.getNativeItem(key);
    }
    
    return this.getLocalItem(key);
  }
  
  /**
   * Set item in iCloud storage
   */
  async setItem(key, value) {
    if (this.isNative) {
      return this.setNativeItem(key, value);
    }
    
    return this.setLocalItem(key, value);
  }
  
  /**
   * Remove item from iCloud storage
   */
  async removeItem(key) {
    if (this.isNative) {
      return this.removeNativeItem(key);
    }
    
    return this.removeLocalItem(key);
  }
  
  /**
   * Clear all items from iCloud storage
   */
  async clear() {
    if (this.isNative) {
      return this.clearNative();
    }
    
    return this.clearLocal();
  }
  
  /**
   * Get all keys from iCloud storage
   */
  async keys() {
    if (this.isNative) {
      return this.getNativeKeys();
    }
    
    return this.getLocalKeys();
  }
  
  /**
   * Native iOS/macOS implementation
   */
  getNativeItem(key) {
    return new Promise((resolve, reject) => {
      const callbackId = this.callbackId++;
      this.pendingCallbacks.set(callbackId, { resolve, reject });
      
      window.webkit.messageHandlers.iCloudStorage.postMessage({
        action: 'getItem',
        key,
        callbackId
      });
      
      setTimeout(() => {
        if (this.pendingCallbacks.has(callbackId)) {
          this.pendingCallbacks.delete(callbackId);
          reject(new Error('iCloud storage timeout'));
        }
      }, 5000);
    });
  }
  
  setNativeItem(key, value) {
    return new Promise((resolve, reject) => {
      const callbackId = this.callbackId++;
      this.pendingCallbacks.set(callbackId, { resolve, reject });
      
      window.webkit.messageHandlers.iCloudStorage.postMessage({
        action: 'setItem',
        key,
        value,
        callbackId
      });
      
      setTimeout(() => {
        if (this.pendingCallbacks.has(callbackId)) {
          this.pendingCallbacks.delete(callbackId);
          reject(new Error('iCloud storage timeout'));
        }
      }, 5000);
    });
  }
  
  removeNativeItem(key) {
    return new Promise((resolve, reject) => {
      const callbackId = this.callbackId++;
      this.pendingCallbacks.set(callbackId, { resolve, reject });
      
      window.webkit.messageHandlers.iCloudStorage.postMessage({
        action: 'removeItem',
        key,
        callbackId
      });
      
      setTimeout(() => {
        if (this.pendingCallbacks.has(callbackId)) {
          this.pendingCallbacks.delete(callbackId);
          reject(new Error('iCloud storage timeout'));
        }
      }, 5000);
    });
  }
  
  clearNative() {
    return new Promise((resolve, reject) => {
      const callbackId = this.callbackId++;
      this.pendingCallbacks.set(callbackId, { resolve, reject });
      
      window.webkit.messageHandlers.iCloudStorage.postMessage({
        action: 'clear',
        callbackId
      });
      
      setTimeout(() => {
        if (this.pendingCallbacks.has(callbackId)) {
          this.pendingCallbacks.delete(callbackId);
          reject(new Error('iCloud storage timeout'));
        }
      }, 5000);
    });
  }
  
  getNativeKeys() {
    return new Promise((resolve, reject) => {
      const callbackId = this.callbackId++;
      this.pendingCallbacks.set(callbackId, { resolve, reject });
      
      window.webkit.messageHandlers.iCloudStorage.postMessage({
        action: 'keys',
        callbackId
      });
      
      setTimeout(() => {
        if (this.pendingCallbacks.has(callbackId)) {
          this.pendingCallbacks.delete(callbackId);
          reject(new Error('iCloud storage timeout'));
        }
      }, 5000);
    });
  }
  
  /**
   * Local storage fallback (for web/testing)
   */
  getLocalItem(key) {
    if (typeof localStorage === 'undefined') return null;
    return localStorage.getItem(key);
  }
  
  setLocalItem(key, value) {
    if (typeof localStorage === 'undefined') return;
    localStorage.setItem(key, value);
  }
  
  removeLocalItem(key) {
    if (typeof localStorage === 'undefined') return;
    localStorage.removeItem(key);
  }
  
  clearLocal() {
    if (typeof localStorage === 'undefined') return;
    localStorage.clear();
  }
  
  getLocalKeys() {
    if (typeof localStorage === 'undefined') return [];
    return Object.keys(localStorage);
  }
}

/**
 * Global iCloud storage instance
 */
let globalStorage = null;

/**
 * Get or create global iCloud storage instance
 */
export function getICloudStorage() {
  if (!globalStorage) {
    globalStorage = new ICloudStorage();
  }
  return globalStorage;
}

/**
 * Convenience methods
 */
export async function iCloudGet(key) {
  const storage = getICloudStorage();
  return storage.getItem(key);
}

export async function iCloudSet(key, value) {
  const storage = getICloudStorage();
  return storage.setItem(key, value);
}

export async function iCloudRemove(key) {
  const storage = getICloudStorage();
  return storage.removeItem(key);
}

export async function iCloudClear() {
  const storage = getICloudStorage();
  return storage.clear();
}

export async function iCloudKeys() {
  const storage = getICloudStorage();
  return storage.keys();
}

export default ICloudStorage;
