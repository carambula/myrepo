## iCloud Sync Documentation

All user settings in min apps are automatically synced to iCloud and available across all user devices.

## Overview

The min apps use **NSUbiquitousKeyValueStore** (iOS/macOS) to sync user settings via iCloud. All preferences, notification settings, and app configuration are stored in iCloud and automatically synchronized across devices.

### What Gets Synced

✅ **Notification preferences** - All notification settings for each app  
✅ **Theme preferences** - Light/dark mode, custom themes  
✅ **App settings** - Any user preferences specific to each app  
✅ **User configuration** - Display settings, privacy settings, etc.

### Benefits

- 🔄 **Automatic sync** - Settings sync automatically across all devices
- 📱 **Multi-device** - Change settings on iPhone, see them on Mac instantly
- ☁️ **iCloud backup** - Settings are backed up to iCloud
- 🔒 **Secure** - Settings are encrypted in iCloud
- 🚀 **No user action** - Works automatically when signed into iCloud

## Implementation (Native iOS/macOS Apps)

### Step 1: Enable iCloud in Xcode

1. Open your Xcode project
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "iCloud"
6. Enable "Key-value storage"

### Step 2: Add Swift Handler

Copy the `ICloudStorageHandler.swift` file to your project:

```swift
// File: ICloudStorageHandler.swift
// (Located in src/storage/ICloudStorageHandler.swift)
```

### Step 3: Configure WKWebView

In your view controller:

```swift
import UIKit
import WebKit

class MinAppViewController: UIViewController {
    var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        
        // Configure iCloud storage
        webView.configureICloudStorage()
        
        view.addSubview(webView)
        
        // Load your app
        if let url = URL(string: "https://yourapp.com") {
            webView.load(URLRequest(url: url))
        }
    }
}
```

### Step 4: Test iCloud Sync

1. Run app on Device 1
2. Change a setting (e.g., enable notifications)
3. Run app on Device 2 (same iCloud account)
4. Settings appear automatically!

## JavaScript Usage

### Using Settings Storage

```javascript
import { getSettingsStorage } from '@min-apps/design-system/storage';

const settings = getSettingsStorage('cyclismo');

// Get a setting
const theme = await settings.get('theme', 'light');

// Set a setting (syncs to iCloud automatically)
await settings.set('theme', 'dark');

// Get all settings
const allSettings = await settings.getAll();

// Remove a setting
await settings.remove('theme');

// Clear all settings
await settings.clearAll();
```

### Using iCloud Storage Directly

```javascript
import { iCloudGet, iCloudSet } from '@min-apps/design-system/storage';

// Get value
const value = await iCloudGet('my-key');

// Set value (syncs to iCloud)
await iCloudSet('my-key', 'my-value');
```

### Notification Preferences (Already iCloud-Synced)

```javascript
import { 
  loadNotificationPreferences,
  saveNotificationPreferences 
} from '@min-apps/design-system/notifications';

// Load preferences (from iCloud)
const prefs = await loadNotificationPreferences('cyclismo');

// Save preferences (to iCloud)
await saveNotificationPreferences('cyclismo', updatedPrefs);
```

### Listen for iCloud Sync Changes

When settings change on another device:

```javascript
window.addEventListener('icloudsync', (event) => {
  console.log('iCloud sync received:', event.detail);
  
  const { changedKeys, reason } = event.detail;
  
  // Reload affected settings
  for (const key of changedKeys) {
    // Reload UI or data based on changed keys
    if (key.includes('notifications')) {
      reloadNotificationSettings();
    }
  }
});
```

## Common Settings

Use predefined setting keys for consistency:

```javascript
import { CommonSettings, getSettingsStorage } from '@min-apps/design-system/storage';

const settings = getSettingsStorage('cyclismo');

// Theme
await settings.set(CommonSettings.THEME, 'dark');
await settings.set(CommonSettings.THEME_AUTO, true);

// Display
await settings.set(CommonSettings.FONT_SIZE, 'large');
await settings.set(CommonSettings.COMPACT_MODE, false);

// Privacy
await settings.set(CommonSettings.ANALYTICS_ENABLED, true);
await settings.set(CommonSettings.CRASH_REPORTS_ENABLED, true);
```

## Storage Architecture

```
┌─────────────────────────────────────────┐
│   JavaScript (WebView)                  │
│                                         │
│   settings.set('theme', 'dark')         │
└──────────────┬──────────────────────────┘
               │ webkit.messageHandlers
               ▼
┌─────────────────────────────────────────┐
│   Swift (Native App)                    │
│                                         │
│   ICloudStorageHandler                  │
│   - Receives message from JS            │
│   - Writes to NSUbiquitousKeyValueStore │
└──────────────┬──────────────────────────┘
               │ iCloud API
               ▼
┌─────────────────────────────────────────┐
│   iCloud (Apple Servers)                │
│                                         │
│   NSUbiquitousKeyValueStore             │
│   - Stores key-value pairs              │
│   - Syncs across devices                │
│   - Encrypted                           │
└──────────────┬──────────────────────────┘
               │ Push notification
               ▼
┌─────────────────────────────────────────┐
│   Other Devices                         │
│                                         │
│   - Receive iCloud sync                 │
│   - Update local storage                │
│   - Trigger JS sync event               │
└─────────────────────────────────────────┘
```

## Storage Limits

NSUbiquitousKeyValueStore has limits:

- **Total storage**: 1 MB per app
- **Keys**: Up to 1024 keys
- **Value size**: Up to 1 MB per value (but stay well below this)

These limits are more than sufficient for user settings. For reference:
- Notification preferences: ~2 KB per app
- Theme settings: ~500 bytes
- All settings combined: Typically < 10 KB

## Fallback Behavior

If iCloud is not available:

1. **localStorage fallback**: Settings stored locally
2. **No sync**: Settings don't sync across devices
3. **Still functional**: App works normally

The system automatically detects and uses iCloud when available.

## Testing

### Test on Simulator

1. Configure iCloud in Simulator:
   - Settings → Apple ID → Sign in
   - Enable iCloud Drive

2. Run app and change settings

3. Run on another simulator (same Apple ID)

4. Settings should sync!

### Test on Device

1. Use two physical devices with same Apple ID
2. Change settings on Device 1
3. Settings appear on Device 2 within seconds

### Test Sync Conflicts

iCloud handles conflicts automatically:
- Last-write-wins for most settings
- Notifications from iCloud when conflicts occur
- Your app can handle conflicts in the sync event listener

## Debugging

### Check iCloud Status

```swift
// In Swift
let iCloudStore = NSUbiquitousKeyValueStore.default

// Synchronize to force sync
let synced = iCloudStore.synchronize()
print("iCloud synced: \(synced)")

// Get all keys
let dict = iCloudStore.dictionaryRepresentation
print("iCloud keys: \(dict.keys)")
```

### Check from JavaScript

```javascript
// Get all settings
const settings = getSettingsStorage('cyclismo');
const all = await settings.getAll();
console.log('All settings:', all);

// Check if using iCloud
import { getICloudStorage } from '@min-apps/design-system/storage';
const storage = getICloudStorage();
console.log('Using iCloud:', storage.isNative);
```

### Enable iCloud Logging

In Swift:

```swift
// Add to your AppDelegate
import os.log

let logger = OSLog(subsystem: "com.yourapp", category: "iCloud")

// Log iCloud events
os_log("iCloud sync: %@", log: logger, type: .info, message)
```

## Best Practices

### 1. Use Specific Keys

```javascript
// Good
await settings.set('cyclismo-notification-morning-races', true);

// Bad
await settings.set('n1', true);
```

### 2. Keep Values Small

```javascript
// Good
await settings.set('theme', 'dark');

// Bad
await settings.set('all-data', hugeObjectMB);
```

### 3. Handle Sync Events

```javascript
// Listen for changes from other devices
window.addEventListener('icloudsync', async (event) => {
  const { changedKeys } = event.detail;
  
  for (const key of changedKeys) {
    if (key.includes('notification')) {
      const prefs = await loadNotificationPreferences('cyclismo');
      updateUI(prefs);
    }
  }
});
```

### 4. Provide Feedback

```javascript
// Show sync status to user
await settings.set('theme', 'dark');
showToast('Settings synced to iCloud');
```

### 5. Test Offline

Test that your app works when:
- iCloud is unavailable
- User is not signed into iCloud
- Network is offline

## Migration from localStorage

If you have existing apps using localStorage:

```javascript
// 1. Check if data exists in localStorage
const oldData = localStorage.getItem('my-setting');

if (oldData) {
  // 2. Migrate to iCloud storage
  const settings = getSettingsStorage('myapp');
  await settings.set('my-setting', JSON.parse(oldData));
  
  // 3. Remove from localStorage
  localStorage.removeItem('my-setting');
  
  console.log('Migrated to iCloud!');
}
```

## Security & Privacy

- **Encryption**: All data encrypted in transit and at rest
- **User control**: User controls iCloud sync in Settings
- **Privacy**: Only user can access their own iCloud data
- **No tracking**: iCloud sync doesn't track users

## Troubleshooting

### Settings not syncing

1. Check iCloud is enabled in Capabilities
2. Verify user is signed into iCloud
3. Check network connectivity
4. Force sync with `iCloudStore.synchronize()`

### Settings sync slowly

- Normal: Sync can take 5-10 seconds
- Force sync for faster updates
- Use local caching for UI responsiveness

### Settings lost

- Check iCloud storage quota (Settings → Apple ID → iCloud)
- Verify key-value storage is enabled
- Check for app deletion/reinstall

## Examples

See complete examples:
- [Cyclismo Settings Example](../examples/cyclismo-settings-example.js)
- [iCloud Sync Example](../examples/icloud-sync-example.js)
- [Settings Migration Example](../examples/settings-migration-example.js)

## Support

For issues:
1. Check iCloud status in device Settings
2. Verify Xcode capabilities are configured
3. Test on physical device (not just simulator)
4. Check Apple's iCloud status page
