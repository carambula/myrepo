# Safe Data Updates Guide

## Overview

The storage module provides a safe, robust way to update reference data (like movie databases, Oscar winners, etc.) without affecting user data (watchlists, ratings, viewing history).

## The Problem

Previously, updating reference data could accidentally wipe out user data because everything was stored in the same namespace. For example, updating the movie database with new Oscar winners would clear `localStorage`, deleting users' watchlists and ratings.

## The Solution

The new storage system separates data into three namespaces:

1. **USER** - User-specific data that must never be lost
2. **REFERENCE** - App-provided data that can be updated
3. **SYSTEM** - App state and preferences

## Quick Start

### Basic Initialization

```javascript
import { quickInit } from '@min-apps/design-system/storage';

// In your app's initialization code
async function initApp() {
  const result = await quickInit(
    'watchedit',                    // App ID
    movieDatabaseWithOscars,        // Your reference data
    '2024.03.01',                   // Version identifier
    {
      updatePrompt: 'notify',       // Show notification but auto-update
      onUpdateComplete: (result) => {
        console.log('Database updated!', result);
      }
    }
  );

  if (result.success) {
    console.log('App initialized successfully');
  }
}
```

### Storing User Data Safely

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

const storage = createDataStorage('watchedit');

// Save user's watchlist (will never be lost during updates)
storage.saveUserData('watchlist', {
  movies: [
    { id: 1, title: 'Oppenheimer', added: '2024-01-15' },
    { id: 2, title: 'Poor Things', added: '2024-02-20' }
  ]
});

// Save user's ratings
storage.saveUserData('ratings', {
  1: 5,  // Movie ID 1: 5 stars
  2: 4   // Movie ID 2: 4 stars
});

// Retrieve user data
const watchlist = storage.getUserData('watchlist', { movies: [] });
const ratings = storage.getUserData('ratings', {});
```

### Storing Reference Data

```javascript
// Save movie database (can be replaced during updates)
storage.saveReferenceData('movies', {
  1: { id: 1, title: 'Oppenheimer', year: 2023, oscars: ['Best Picture'] },
  2: { id: 2, title: 'Poor Things', year: 2023, oscars: ['Best Actress'] }
});

// Retrieve reference data
const movies = storage.getReferenceData('movies', {});
```

## Advanced Usage

### Custom Initialization

```javascript
import { 
  createAppInitializer, 
  InitializationOptions 
} from '@min-apps/design-system/storage';

const initializer = createAppInitializer('watchedit', {
  updatePrompt: InitializationOptions.UpdatePrompt.PROMPT,  // Ask before updating
  
  onUpdateAvailable: async ({ currentVersion, targetVersion }) => {
    // Show custom UI to user
    const shouldUpdate = await showUpdateDialog(currentVersion, targetVersion);
    return shouldUpdate;
  },
  
  onUpdateStart: ({ currentVersion, targetVersion }) => {
    showProgressBar('Updating database...');
  },
  
  onUpdateComplete: (result) => {
    hideProgressBar();
    if (result.success) {
      showNotification('Database updated successfully!');
    }
  },
  
  onUpdateError: (error, result) => {
    hideProgressBar();
    showError('Update failed. Your data is safe. You can try again later.');
  }
});

// Initialize with latest data
await initializer.initialize(latestMovieDatabase, '2024.03.01');
```

### Migration Hooks

If you need to transform user data when updating:

```javascript
const migrationHooks = {
  beforeUpdate: async (currentVersion, targetVersion) => {
    console.log(`Preparing to update from ${currentVersion} to ${targetVersion}`);
    
    // Example: Migrate old data format
    const storage = createDataStorage('watchedit');
    const oldWatchlist = storage.getUserData('watchlist');
    
    if (oldWatchlist && Array.isArray(oldWatchlist)) {
      // Upgrade from array to object format
      storage.saveUserData('watchlist', {
        version: 2,
        movies: oldWatchlist
      });
    }
  },
  
  afterUpdate: async (currentVersion, targetVersion) => {
    console.log(`Successfully updated to ${targetVersion}`);
    
    // Example: Clean up old system data
    const storage = createDataStorage('watchedit');
    // Perform any post-update cleanup
  }
};

await initializer.initialize(
  latestMovieDatabase, 
  '2024.03.01',
  { migrationHooks }
);
```

### Manual Updates

For settings pages or admin interfaces:

```javascript
import { createAppInitializer } from '@min-apps/design-system/storage';

const initializer = createAppInitializer('watchedit');

// Check for updates
const updateInfo = initializer.checkForUpdates('2024.03.15');
console.log('Update available:', updateInfo.updateAvailable);
console.log('Current version:', updateInfo.currentVersion);
console.log('Latest version:', updateInfo.latestVersion);

// Manually trigger update
if (updateInfo.updateAvailable) {
  const result = await initializer.manualUpdate(
    newMovieDatabase,
    '2024.03.15'
  );
  
  if (result.success) {
    console.log('Updated successfully!');
  }
}
```

### Backup and Restore

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

const storage = createDataStorage('watchedit');

// Export user data for backup
const backup = storage.exportUserData();
console.log('Backup created:', backup);

// Save backup to file or server
await saveBackupToServer(backup);

// Later, restore from backup
const restoredBackup = await loadBackupFromServer();
const success = storage.importUserData(restoredBackup);

if (success) {
  console.log('User data restored successfully!');
}
```

### Rollback

If an update causes issues:

```javascript
import { createAppInitializer } from '@min-apps/design-system/storage';

const initializer = createAppInitializer('watchedit');

// Rollback to previous version
const result = await initializer.rollback();

if (result.success) {
  console.log('Successfully rolled back to previous version');
} else {
  console.error('Rollback failed:', result.message);
}
```

## Update Strategies

### Silent Updates (Recommended for Most Apps)

Updates happen automatically without user intervention:

```javascript
await quickInit('watchedit', movieData, '2024.03.01', {
  updatePrompt: 'silent'
});
```

### Notify on Update

Updates happen automatically but show a notification:

```javascript
await quickInit('watchedit', movieData, '2024.03.01', {
  updatePrompt: 'notify',
  onUpdateComplete: (result) => {
    showToast(`Database updated to ${result.currentVersion}`);
  }
});
```

### Prompt Before Update

Ask user permission before updating:

```javascript
await quickInit('watchedit', movieData, '2024.03.01', {
  updatePrompt: 'prompt',
  onUpdateAvailable: async ({ currentVersion, targetVersion }) => {
    return await confirm(
      `New database version ${targetVersion} is available. Update now?`
    );
  }
});
```

### Manual Only

Never auto-update, require explicit user action:

```javascript
await quickInit('watchedit', movieData, '2024.03.01', {
  updatePrompt: 'manual'
});

// Later, in settings page:
if (userClickedUpdate) {
  await initializer.manualUpdate(movieData, '2024.03.01');
}
```

## Best Practices

### 1. Always Use Namespaced Storage

❌ **Don't:**
```javascript
localStorage.setItem('watchlist', JSON.stringify(data));
```

✅ **Do:**
```javascript
const storage = createDataStorage('watchedit');
storage.saveUserData('watchlist', data);
```

### 2. Use Semantic Versioning

Version your reference data updates:

```javascript
'2024.01.15'  // Date-based
'1.2.3'       // Semantic version
'oscars-2024' // Descriptive
```

### 3. Initialize on App Start

Always initialize your app with the latest data on startup:

```javascript
// In your main app file
async function main() {
  await quickInit('watchedit', latestData, latestVersion);
  // Rest of app initialization
}
```

### 4. Test Updates in Development

Before releasing an update:

```javascript
// Test the update process
const testStorage = createDataStorage('watchedit-test');
const testInitializer = createAppInitializer('watchedit-test');

// Verify user data is preserved
testStorage.saveUserData('test-watchlist', [1, 2, 3]);
await testInitializer.initialize(newData, newVersion);
const preserved = testStorage.getUserData('test-watchlist');
console.assert(preserved.length === 3, 'User data should be preserved');
```

### 5. Handle Update Failures Gracefully

```javascript
const result = await initializer.initialize(newData, newVersion);

if (!result.success) {
  // Don't block app startup on failed updates
  console.error('Update failed, continuing with current data');
  
  // Optionally show user-friendly message
  showNotification('Unable to update database. App will continue normally.');
}
```

## Migration from Old Storage

If you have an existing app using raw `localStorage`:

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

async function migrateExistingData() {
  const storage = createDataStorage('watchedit');
  
  // Migrate old watchlist
  const oldWatchlist = localStorage.getItem('watchlist');
  if (oldWatchlist) {
    storage.saveUserData('watchlist', JSON.parse(oldWatchlist));
    localStorage.removeItem('watchlist');
  }
  
  // Migrate old ratings
  const oldRatings = localStorage.getItem('ratings');
  if (oldRatings) {
    storage.saveUserData('ratings', JSON.parse(oldRatings));
    localStorage.removeItem('ratings');
  }
  
  console.log('Migration complete');
}

// Run once on app startup
await migrateExistingData();
```

## Troubleshooting

### Update Not Working

Check the version comparison:

```javascript
const storage = createDataStorage('watchedit');
console.log('Current version:', storage.getDataVersion());

const updater = createDataUpdater('watchedit');
const needed = updater.isUpdateNeeded('1.0.0', '2.0.0');
console.log('Update needed:', needed);
```

### User Data Lost

If user data was lost, check for rollback:

```javascript
const initializer = createAppInitializer('watchedit');
const result = await initializer.rollback();

if (result.success) {
  console.log('Data restored from backup');
}
```

### Storage Quota Exceeded

Monitor storage usage:

```javascript
// Check available storage
if (navigator.storage && navigator.storage.estimate) {
  const estimate = await navigator.storage.estimate();
  console.log('Storage used:', estimate.usage);
  console.log('Storage quota:', estimate.quota);
  console.log('Percentage used:', (estimate.usage / estimate.quota * 100).toFixed(2) + '%');
}
```

## API Reference

See the inline documentation in:
- `src/storage/dataStorage.js` - Core storage operations
- `src/storage/dataUpdater.js` - Update and migration utilities
- `src/storage/appInitializer.js` - App initialization and lifecycle
