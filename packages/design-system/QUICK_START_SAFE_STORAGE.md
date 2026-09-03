# Quick Start: Safe Storage System

## Problem Solved

Updating reference data (like movie databases) was wiping out user data (watchlists, ratings). **Not anymore!**

## 30-Second Setup

```javascript
import { quickInit, createDataStorage } from '@min-apps/design-system/storage';

// 1. Initialize on app start
await quickInit('watchedit', movieDatabase, '2024.03.01');

// 2. Use safe storage
const storage = createDataStorage('watchedit');
storage.saveUserData('watchlist', [1, 2, 3]);
storage.saveUserData('ratings', { 1: 5, 2: 4 });

// 3. Update database safely (user data preserved!)
await quickInit('watchedit', updatedMovieDatabase, '2024.04.01');
```

## Key Concepts

### Three Data Namespaces

| Namespace | Purpose | Example Data | Can Be Updated? |
|-----------|---------|--------------|-----------------|
| **USER** | User-specific data | Watchlists, ratings, viewing history | ❌ Never (protected) |
| **REFERENCE** | App-provided data | Movie database, Oscar winners | ✅ Yes (safe updates) |
| **SYSTEM** | App state | Theme, preferences, last update check | ✅ Yes |

### Basic API

```javascript
const storage = createDataStorage('watchedit');

// User data (protected)
storage.saveUserData('watchlist', data);
const watchlist = storage.getUserData('watchlist', defaultValue);

// Reference data (updatable)
storage.saveReferenceData('movies', data);
const movies = storage.getReferenceData('movies', defaultValue);

// System data
storage.saveSystemData('theme', 'dark');
const theme = storage.getSystemData('theme', 'light');
```

## Common Scenarios

### Scenario 1: First-Time App Setup

```javascript
import { quickInit } from '@min-apps/design-system/storage';

await quickInit('watchedit', initialMovieDatabase, '1.0.0');
```

### Scenario 2: Update Database with Oscars Data

```javascript
// User has watchlist: [1, 2, 3] and ratings: { 1: 5, 2: 4 }

// Update reference data (Oscars 2024)
await quickInit('watchedit', moviesWithOscars2024, '2024.03.01');

// User data still intact!
// watchlist: [1, 2, 3] ✅
// ratings: { 1: 5, 2: 4 } ✅
```

### Scenario 3: Manual Update from Settings

```javascript
import { createAppInitializer } from '@min-apps/design-system/storage';

const initializer = createAppInitializer('watchedit');

// Check for updates
const info = initializer.checkForUpdates('2024.04.01');
if (info.updateAvailable) {
  await initializer.manualUpdate(newData, '2024.04.01');
}
```

### Scenario 4: Backup User Data

```javascript
const storage = createDataStorage('watchedit');

// Export
const backup = storage.exportUserData();
saveToFile(backup); // or send to server

// Import
const restored = loadFromFile();
storage.importUserData(restored);
```

### Scenario 5: Rollback Failed Update

```javascript
const initializer = createAppInitializer('watchedit');

// If update went wrong
await initializer.rollback();
```

## Update Strategies

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `silent` | Auto-update without notification | Most apps |
| `notify` | Auto-update with notification | Default recommended |
| `prompt` | Ask user before updating | User preference |
| `manual` | Never auto-update | Settings page only |

```javascript
await quickInit('watchedit', data, version, {
  updatePrompt: 'notify'
});
```

## Migration from Old Code

### Before (Unsafe)

```javascript
// ❌ DON'T DO THIS
localStorage.setItem('watchlist', JSON.stringify([1, 2, 3]));
const watchlist = JSON.parse(localStorage.getItem('watchlist'));
```

### After (Safe)

```javascript
// ✅ DO THIS
const storage = createDataStorage('watchedit');
storage.saveUserData('watchlist', [1, 2, 3]);
const watchlist = storage.getUserData('watchlist', []);
```

## Complete Example

```javascript
import { 
  quickInit,
  createDataStorage,
  createAppInitializer
} from '@min-apps/design-system/storage';

// App initialization
async function initApp() {
  const result = await quickInit(
    'watchedit',
    movieDatabase,
    '2024.03.01',
    {
      updatePrompt: 'notify',
      onUpdateComplete: (result) => {
        if (result.updateApplied) {
          console.log(`Database updated to ${result.currentVersion}`);
        }
      }
    }
  );
  
  if (!result.success) {
    console.warn('Using cached data');
  }
}

// User data management
const storage = createDataStorage('watchedit');

function addToWatchlist(movieId) {
  const list = storage.getUserData('watchlist', []);
  storage.saveUserData('watchlist', [...list, movieId]);
}

function setRating(movieId, rating) {
  const ratings = storage.getUserData('ratings', {});
  ratings[movieId] = rating;
  storage.saveUserData('ratings', ratings);
}

// Reference data access
function getMovie(movieId) {
  const movies = storage.getReferenceData('movies', {});
  return movies[movieId];
}
```

## Resources

- **Full Guide**: `docs/safe-data-updates.md`
- **WatchedIt Integration**: `integration-tools/app-specific/watchedit-data-safety.md`
- **Examples**: `examples/watchedit-safe-updates.js`

## API Reference

### `quickInit(appId, data, version, options?)`

Quick initialization with automatic updates.

### `createDataStorage(appId)`

Create a storage instance for an app.

### `createAppInitializer(appId, options?)`

Create an initializer for advanced control.

### `createDataUpdater(appId)`

Create an updater for low-level update control.

## Support

If user data was lost, check for automatic backup:

```javascript
const initializer = createAppInitializer('watchedit');
await initializer.rollback(); // Restore from backup
```
