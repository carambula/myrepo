# WatchedIt (Mov Min) - Safe Database Updates Integration

## Problem Statement

When updating the movie database from bootstrap to include Oscars data, all user data was wiped out. This happened because the old approach didn't separate user data (watchlists, ratings, viewing history) from reference data (movie database).

## Solution

The design system now includes safe storage utilities that:

1. **Separate data namespaces** - User data, reference data, and system data are stored separately
2. **Automatic backups** - User data is backed up before any updates
3. **Version tracking** - Reference data updates are versioned and managed
4. **Rollback support** - Can restore previous state if updates fail

## Integration Steps

### Step 1: Update App Initialization

In your main app file (e.g., `App.jsx`, `index.js`):

```javascript
import { quickInit } from '@min-apps/design-system/storage';
import movieDatabase from './data/movies.json';
import oscarsData from './data/oscars-2024.json';

async function initializeApp() {
  // Combine movie database with Oscars data
  const referenceData = {
    movies: movieDatabase,
    oscars: oscarsData,
    lastUpdated: new Date().toISOString()
  };

  // Version format: YYYY.MM.DD or semantic versioning
  const dataVersion = '2024.03.01';

  const result = await quickInit(
    'watchedit',
    referenceData,
    dataVersion,
    {
      updatePrompt: 'notify',
      
      onUpdateStart: () => {
        console.log('Updating movie database...');
      },
      
      onUpdateComplete: (result) => {
        if (result.updateApplied) {
          console.log(`Database updated to version ${result.currentVersion}`);
        }
      },
      
      onUpdateError: (error) => {
        console.error('Database update failed:', error);
      }
    }
  );

  if (!result.success) {
    console.warn('Failed to initialize/update database, using cached data');
  }

  return result;
}

// Call during app startup
initializeApp().then(() => {
  // Continue with app rendering
});
```

### Step 2: Update User Data Storage

Replace all raw `localStorage` calls with safe storage:

#### Before (Unsafe):

```javascript
// DON'T DO THIS
function saveWatchlist(movies) {
  localStorage.setItem('watchlist', JSON.stringify(movies));
}

function getWatchlist() {
  const stored = localStorage.getItem('watchlist');
  return stored ? JSON.parse(stored) : [];
}
```

#### After (Safe):

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

const storage = createDataStorage('watchedit');

function saveWatchlist(movies) {
  storage.saveUserData('watchlist', movies);
}

function getWatchlist() {
  return storage.getUserData('watchlist', []);
}

function saveRating(movieId, rating) {
  const ratings = storage.getUserData('ratings', {});
  ratings[movieId] = rating;
  storage.saveUserData('ratings', ratings);
}

function getRating(movieId) {
  const ratings = storage.getUserData('ratings', {});
  return ratings[movieId] || 0;
}

function saveViewingHistory(movieId, timestamp) {
  const history = storage.getUserData('viewing-history', []);
  history.push({ movieId, timestamp });
  storage.saveUserData('viewing-history', history);
}
```

### Step 3: Access Reference Data

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

const storage = createDataStorage('watchedit');

function getMovieDatabase() {
  return storage.getReferenceData('movies', {});
}

function getOscarsData() {
  return storage.getReferenceData('oscars', {});
}

function getMovieById(id) {
  const movies = getMovieDatabase();
  return movies[id] || null;
}

function getOscarWinners(year) {
  const oscars = getOscarsData();
  return oscars.winners?.filter(w => w.year === year) || [];
}
```

### Step 4: Add Update UI (Optional)

Create a settings page to allow manual updates:

```javascript
import { createAppInitializer } from '@min-apps/design-system/storage';

function SettingsPage() {
  const [updateInfo, setUpdateInfo] = useState(null);
  const [updating, setUpdating] = useState(false);

  useEffect(() => {
    const initializer = createAppInitializer('watchedit');
    const info = initializer.checkForUpdates(LATEST_VERSION);
    setUpdateInfo(info);
  }, []);

  const handleUpdate = async () => {
    setUpdating(true);
    
    const initializer = createAppInitializer('watchedit', {
      onUpdateStart: () => {
        console.log('Starting update...');
      },
      onUpdateComplete: (result) => {
        console.log('Update complete:', result);
        setUpdating(false);
        setUpdateInfo(null);
      }
    });

    await initializer.manualUpdate(latestReferenceData, LATEST_VERSION);
  };

  return (
    <div>
      <h2>Database Settings</h2>
      
      {updateInfo?.updateAvailable ? (
        <div>
          <p>Update available!</p>
          <p>Current: {updateInfo.currentVersion}</p>
          <p>Latest: {updateInfo.latestVersion}</p>
          <button onClick={handleUpdate} disabled={updating}>
            {updating ? 'Updating...' : 'Update Database'}
          </button>
        </div>
      ) : (
        <p>Database is up to date ({updateInfo?.currentVersion})</p>
      )}
    </div>
  );
}
```

### Step 5: Add Backup/Restore Feature (Optional)

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

function BackupPage() {
  const storage = createDataStorage('watchedit');

  const handleExport = () => {
    const backup = storage.exportUserData();
    
    // Download as JSON file
    const blob = new Blob([JSON.stringify(backup, null, 2)], {
      type: 'application/json'
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `watchedit-backup-${new Date().toISOString()}.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleImport = (event) => {
    const file = event.target.files[0];
    const reader = new FileReader();
    
    reader.onload = (e) => {
      try {
        const backup = JSON.parse(e.target.result);
        const success = storage.importUserData(backup);
        
        if (success) {
          alert('Data restored successfully!');
        } else {
          alert('Failed to restore data');
        }
      } catch (error) {
        alert('Invalid backup file');
      }
    };
    
    reader.readAsText(file);
  };

  return (
    <div>
      <h2>Backup & Restore</h2>
      <button onClick={handleExport}>Export My Data</button>
      <input type="file" accept=".json" onChange={handleImport} />
    </div>
  );
}
```

## Migration from Existing App

If you have an existing WatchedIt app with user data:

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

async function migrateExistingUserData() {
  const storage = createDataStorage('watchedit');
  
  // List of old localStorage keys to migrate
  const oldKeys = [
    'watchlist',
    'ratings',
    'viewing-history',
    'favorites',
    'watchedit-preferences'
  ];

  console.log('Starting migration...');
  
  oldKeys.forEach(key => {
    const oldValue = localStorage.getItem(key);
    
    if (oldValue) {
      try {
        const parsed = JSON.parse(oldValue);
        
        // Save to new namespaced storage
        storage.saveUserData(key, parsed);
        
        // Remove old key
        localStorage.removeItem(key);
        
        console.log(`Migrated: ${key}`);
      } catch (error) {
        console.error(`Failed to migrate ${key}:`, error);
      }
    }
  });
  
  console.log('Migration complete');
}

// Run once on first startup with new system
async function initApp() {
  // Check if migration is needed
  const storage = createDataStorage('watchedit');
  const migrated = storage.getSystemData('migrated-to-safe-storage', false);
  
  if (!migrated) {
    await migrateExistingUserData();
    storage.saveSystemData('migrated-to-safe-storage', true);
  }
  
  // Continue with normal initialization
  await initializeApp();
}
```

## Example: Complete WatchedIt App Structure

```
watchedit-app/
├── src/
│   ├── data/
│   │   ├── movies.json              # Movie database
│   │   ├── oscars-2024.json         # Oscar winners data
│   │   └── version.js               # Export const VERSION = '2024.03.01'
│   ├── storage/
│   │   ├── initialization.js        # App init with safe updates
│   │   ├── userData.js              # User data access functions
│   │   └── referenceData.js         # Reference data access functions
│   ├── components/
│   │   ├── WatchlistPage.jsx
│   │   ├── MovieDetailPage.jsx
│   │   ├── SettingsPage.jsx         # With update UI
│   │   └── BackupPage.jsx           # Backup/restore UI
│   └── App.jsx
```

### Example: `src/storage/initialization.js`

```javascript
import { quickInit } from '@min-apps/design-system/storage';
import movieDatabase from '../data/movies.json';
import oscarsData from '../data/oscars-2024.json';
import { VERSION } from '../data/version.js';

export async function initWatchedit() {
  const referenceData = {
    movies: movieDatabase,
    oscars: oscarsData,
    genres: extractGenres(movieDatabase),
    directors: extractDirectors(movieDatabase)
  };

  return await quickInit('watchedit', referenceData, VERSION, {
    updatePrompt: 'notify',
    onUpdateComplete: (result) => {
      if (result.updateApplied) {
        console.log(`✅ Database updated to ${result.currentVersion}`);
      }
    }
  });
}
```

### Example: `src/storage/userData.js`

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

const storage = createDataStorage('watchedit');

export const UserData = {
  // Watchlist
  getWatchlist: () => storage.getUserData('watchlist', []),
  addToWatchlist: (movie) => {
    const list = storage.getUserData('watchlist', []);
    storage.saveUserData('watchlist', [...list, movie]);
  },
  removeFromWatchlist: (movieId) => {
    const list = storage.getUserData('watchlist', []);
    storage.saveUserData('watchlist', list.filter(m => m.id !== movieId));
  },

  // Ratings
  getRatings: () => storage.getUserData('ratings', {}),
  setRating: (movieId, rating) => {
    const ratings = storage.getUserData('ratings', {});
    ratings[movieId] = rating;
    storage.saveUserData('ratings', ratings);
  },

  // Viewing history
  getHistory: () => storage.getUserData('viewing-history', []),
  addToHistory: (movieId) => {
    const history = storage.getUserData('viewing-history', []);
    storage.saveUserData('viewing-history', [
      ...history,
      { movieId, timestamp: new Date().toISOString() }
    ]);
  },

  // Export/import
  exportData: () => storage.exportUserData(),
  importData: (backup) => storage.importUserData(backup)
};
```

### Example: `src/storage/referenceData.js`

```javascript
import { createDataStorage } from '@min-apps/design-system/storage';

const storage = createDataStorage('watchedit');

export const ReferenceData = {
  getMovies: () => storage.getReferenceData('movies', {}),
  getMovie: (id) => {
    const movies = storage.getReferenceData('movies', {});
    return movies[id] || null;
  },
  
  getOscars: () => storage.getReferenceData('oscars', {}),
  getOscarWinners: (year) => {
    const oscars = storage.getReferenceData('oscars', {});
    return oscars.winners?.filter(w => w.year === year) || [];
  },

  searchMovies: (query) => {
    const movies = storage.getReferenceData('movies', {});
    const lowerQuery = query.toLowerCase();
    return Object.values(movies).filter(m => 
      m.title.toLowerCase().includes(lowerQuery)
    );
  }
};
```

## Testing the Update Process

```javascript
// Test file: updateSafety.test.js
import { createDataStorage, createAppInitializer } from '@min-apps/design-system/storage';

describe('Safe Database Updates', () => {
  test('User data is preserved during updates', async () => {
    const storage = createDataStorage('watchedit-test');
    const initializer = createAppInitializer('watchedit-test');

    // Add user data
    storage.saveUserData('watchlist', [1, 2, 3]);
    storage.saveUserData('ratings', { 1: 5, 2: 4 });

    // Perform update
    await initializer.initialize(
      { movies: { /* new data */ } },
      '2.0.0'
    );

    // Verify user data is still there
    expect(storage.getUserData('watchlist')).toEqual([1, 2, 3]);
    expect(storage.getUserData('ratings')).toEqual({ 1: 5, 2: 4 });
  });

  test('Reference data is updated', async () => {
    const storage = createDataStorage('watchedit-test');
    const initializer = createAppInitializer('watchedit-test');

    // Old data
    storage.saveReferenceData('movies', { 1: { title: 'Old' } });

    // Update
    await initializer.initialize(
      { movies: { 1: { title: 'New' } } },
      '2.0.0'
    );

    // Verify reference data is updated
    const movies = storage.getReferenceData('movies');
    expect(movies[1].title).toBe('New');
  });
});
```

## Troubleshooting

### User reported data loss

1. Check if backup exists:
```javascript
const initializer = createAppInitializer('watchedit');
const result = await initializer.rollback();
```

2. Export user data for support:
```javascript
const storage = createDataStorage('watchedit');
const backup = storage.exportUserData();
console.log(backup); // Send to support
```

### Update not applying

1. Check version:
```javascript
const storage = createDataStorage('watchedit');
console.log('Current version:', storage.getDataVersion());
```

2. Force update:
```javascript
const initializer = createAppInitializer('watchedit');
await initializer.manualUpdate(latestData, latestVersion);
```

## Summary

✅ **Benefits:**
- User data is never lost during database updates
- Automatic backups before updates
- Version tracking for reference data
- Easy rollback if updates fail
- Export/import for user data portability

✅ **Migration Path:**
1. Update app initialization to use `quickInit`
2. Replace `localStorage` calls with `createDataStorage`
3. Run one-time migration for existing user data
4. Test thoroughly before release

✅ **Best Practices:**
- Always use namespaced storage
- Version your reference data updates
- Initialize on app start
- Handle update failures gracefully
- Test with real user data scenarios
