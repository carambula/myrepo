/**
 * WatchedIt (Mov Min) - Safe Database Updates Example
 * 
 * This example shows how to safely update the movie database
 * (e.g., adding Oscars data) without losing user data.
 */

import { 
  quickInit,
  createDataStorage,
  createAppInitializer
} from '@min-apps/design-system/storage';

// ======================
// Example 1: Quick Setup
// ======================

async function simpleSetup() {
  const movieData = {
    movies: {
      1: { id: 1, title: 'Oppenheimer', year: 2023, oscars: ['Best Picture', 'Best Director'] },
      2: { id: 2, title: 'Poor Things', year: 2023, oscars: ['Best Actress'] },
      3: { id: 3, title: 'The Holdovers', year: 2023, oscars: [] }
    },
    oscars: {
      2024: {
        bestPicture: 'Oppenheimer',
        bestDirector: 'Christopher Nolan',
        bestActress: 'Emma Stone'
      }
    }
  };

  const result = await quickInit(
    'watchedit',
    movieData,
    '2024.03.01'
  );

  console.log('Initialization result:', result);
}

// ======================
// Example 2: User Data Management
// ======================

function userDataExample() {
  const storage = createDataStorage('watchedit');

  // Save user's watchlist
  const watchlist = [
    { id: 1, addedAt: '2024-01-15' },
    { id: 2, addedAt: '2024-02-20' }
  ];
  storage.saveUserData('watchlist', watchlist);

  // Save ratings
  const ratings = {
    1: 5,  // Oppenheimer: 5 stars
    2: 4,  // Poor Things: 4 stars
    3: 3   // The Holdovers: 3 stars
  };
  storage.saveUserData('ratings', ratings);

  // Save viewing history
  const history = [
    { movieId: 1, watchedAt: '2024-01-20', location: 'theater' },
    { movieId: 2, watchedAt: '2024-02-25', location: 'streaming' }
  ];
  storage.saveUserData('viewing-history', history);

  // Retrieve user data
  console.log('Watchlist:', storage.getUserData('watchlist'));
  console.log('Ratings:', storage.getUserData('ratings'));
  console.log('History:', storage.getUserData('viewing-history'));
}

// ======================
// Example 3: Safe Database Update
// ======================

async function updateDatabase() {
  const storage = createDataStorage('watchedit');
  const initializer = createAppInitializer('watchedit');

  // BEFORE UPDATE: Save some user data
  console.log('Saving user data...');
  storage.saveUserData('watchlist', [1, 2, 3]);
  storage.saveUserData('ratings', { 1: 5, 2: 4 });
  
  console.log('User watchlist before update:', storage.getUserData('watchlist'));
  console.log('User ratings before update:', storage.getUserData('ratings'));

  // UPDATE: New database with additional Oscars data
  const updatedMovieData = {
    movies: {
      1: { id: 1, title: 'Oppenheimer', year: 2023, oscars: ['Best Picture', 'Best Director', 'Best Actor'] },
      2: { id: 2, title: 'Poor Things', year: 2023, oscars: ['Best Actress', 'Best Production Design'] },
      3: { id: 3, title: 'The Holdovers', year: 2023, oscars: [] },
      4: { id: 4, title: 'American Fiction', year: 2023, oscars: ['Best Adapted Screenplay'] } // NEW!
    },
    oscars: {
      2024: {
        bestPicture: 'Oppenheimer',
        bestDirector: 'Christopher Nolan',
        bestActor: 'Cillian Murphy',
        bestActress: 'Emma Stone',
        bestAdaptedScreenplay: 'American Fiction'
      }
    }
  };

  console.log('Updating database to version 2024.03.15...');
  
  const result = await initializer.initialize(
    updatedMovieData,
    '2024.03.15'
  );

  console.log('Update result:', result);

  // AFTER UPDATE: Verify user data is intact
  console.log('User watchlist after update:', storage.getUserData('watchlist'));
  console.log('User ratings after update:', storage.getUserData('ratings'));
  
  // VERIFY: User data should be unchanged!
  const watchlist = storage.getUserData('watchlist');
  const ratings = storage.getUserData('ratings');
  
  console.assert(
    JSON.stringify(watchlist) === JSON.stringify([1, 2, 3]),
    'Watchlist should be preserved!'
  );
  console.assert(
    JSON.stringify(ratings) === JSON.stringify({ 1: 5, 2: 4 }),
    'Ratings should be preserved!'
  );

  console.log('✅ User data preserved during update!');
}

// ======================
// Example 4: Custom Update UI
// ======================

async function customUpdateUI() {
  const initializer = createAppInitializer('watchedit', {
    updatePrompt: 'prompt',
    
    onUpdateAvailable: async ({ currentVersion, targetVersion }) => {
      console.log(`New database version available!`);
      console.log(`Current: ${currentVersion}`);
      console.log(`Available: ${targetVersion}`);
      
      // In a real app, show a dialog to the user
      const userConfirmed = confirm(
        `A new movie database (${targetVersion}) is available with updated Oscars data. Update now?`
      );
      
      return userConfirmed;
    },
    
    onUpdateStart: ({ currentVersion, targetVersion }) => {
      console.log(`Starting update from ${currentVersion} to ${targetVersion}...`);
      // Show progress indicator
    },
    
    onUpdateComplete: (result) => {
      if (result.success && result.updateApplied) {
        console.log(`✅ Successfully updated to ${result.currentVersion}`);
        // Show success message to user
      }
    },
    
    onUpdateError: (error, result) => {
      console.error('Update failed:', error);
      console.log('Your data is safe. You can try updating again later.');
      // Show error message to user
    }
  });

  const latestData = {
    movies: { /* ... */ },
    oscars: { /* ... */ }
  };

  await initializer.initialize(latestData, '2024.03.15');
}

// ======================
// Example 5: Manual Update from Settings
// ======================

async function settingsPageUpdate() {
  const initializer = createAppInitializer('watchedit');
  
  // Check for updates
  const updateInfo = initializer.checkForUpdates('2024.04.01');
  
  console.log('Update available:', updateInfo.updateAvailable);
  console.log('Current version:', updateInfo.currentVersion);
  console.log('Latest version:', updateInfo.latestVersion);
  
  if (updateInfo.updateAvailable) {
    const userClickedUpdate = true; // In real app, wait for user action
    
    if (userClickedUpdate) {
      const latestData = await fetchLatestMovieData(); // Fetch from server
      
      const result = await initializer.manualUpdate(
        latestData,
        '2024.04.01'
      );
      
      if (result.success) {
        console.log('Update completed successfully!');
      } else {
        console.error('Update failed:', result.message);
      }
    }
  }
}

async function fetchLatestMovieData() {
  // Simulate fetching from server
  return {
    movies: { /* ... */ },
    oscars: { /* ... */ }
  };
}

// ======================
// Example 6: Backup and Restore
// ======================

function backupRestoreExample() {
  const storage = createDataStorage('watchedit');

  // Export user data
  const backup = storage.exportUserData();
  console.log('Backup created:', backup);
  
  // Save to file or send to server
  const backupJson = JSON.stringify(backup, null, 2);
  console.log('Backup JSON:', backupJson);
  
  // Later, restore from backup
  const restoredBackup = JSON.parse(backupJson);
  const success = storage.importUserData(restoredBackup);
  
  if (success) {
    console.log('✅ User data restored successfully');
  } else {
    console.error('❌ Failed to restore user data');
  }
}

// ======================
// Example 7: Rollback
// ======================

async function rollbackExample() {
  const initializer = createAppInitializer('watchedit');
  
  // If an update caused issues, rollback
  const result = await initializer.rollback();
  
  if (result.success) {
    console.log('✅ Rolled back to previous version');
  } else {
    console.error('❌ Rollback failed:', result.message);
  }
}

// ======================
// Example 8: Complete App Integration
// ======================

class WatcheditApp {
  constructor() {
    this.storage = createDataStorage('watchedit');
    this.initializer = createAppInitializer('watchedit', {
      updatePrompt: 'notify',
      onUpdateComplete: (result) => {
        if (result.updateApplied) {
          this.onDatabaseUpdated(result.currentVersion);
        }
      }
    });
  }

  async initialize() {
    const latestData = await this.fetchLatestData();
    const latestVersion = '2024.03.01';
    
    const result = await this.initializer.initialize(latestData, latestVersion);
    
    if (!result.success) {
      console.warn('Failed to update database, using cached data');
    }
    
    return result;
  }

  async fetchLatestData() {
    // In production, fetch from server or bundle
    return {
      movies: { /* ... */ },
      oscars: { /* ... */ }
    };
  }

  // User data methods
  addToWatchlist(movieId) {
    const watchlist = this.storage.getUserData('watchlist', []);
    if (!watchlist.includes(movieId)) {
      watchlist.push(movieId);
      this.storage.saveUserData('watchlist', watchlist);
    }
  }

  removeFromWatchlist(movieId) {
    const watchlist = this.storage.getUserData('watchlist', []);
    const updated = watchlist.filter(id => id !== movieId);
    this.storage.saveUserData('watchlist', updated);
  }

  getWatchlist() {
    return this.storage.getUserData('watchlist', []);
  }

  setRating(movieId, rating) {
    const ratings = this.storage.getUserData('ratings', {});
    ratings[movieId] = rating;
    this.storage.saveUserData('ratings', ratings);
  }

  getRating(movieId) {
    const ratings = this.storage.getUserData('ratings', {});
    return ratings[movieId] || 0;
  }

  // Reference data methods
  getMovie(movieId) {
    const movies = this.storage.getReferenceData('movies', {});
    return movies[movieId] || null;
  }

  getAllMovies() {
    return this.storage.getReferenceData('movies', {});
  }

  getOscarWinners(year) {
    const oscars = this.storage.getReferenceData('oscars', {});
    return oscars[year] || null;
  }

  searchMovies(query) {
    const movies = this.storage.getReferenceData('movies', {});
    const lowerQuery = query.toLowerCase();
    
    return Object.values(movies).filter(movie =>
      movie.title.toLowerCase().includes(lowerQuery)
    );
  }

  onDatabaseUpdated(version) {
    console.log(`Database updated to ${version}`);
    // Refresh UI, invalidate caches, etc.
  }

  exportUserData() {
    return this.storage.exportUserData();
  }

  importUserData(backup) {
    return this.storage.importUserData(backup);
  }
}

// Usage
async function main() {
  const app = new WatcheditApp();
  
  // Initialize app with latest data
  await app.initialize();
  
  // Use the app
  app.addToWatchlist(1);
  app.setRating(1, 5);
  
  console.log('Watchlist:', app.getWatchlist());
  console.log('Rating for movie 1:', app.getRating(1));
  console.log('Movie 1 details:', app.getMovie(1));
}

// ======================
// Run Examples
// ======================

// Uncomment to run specific examples:
// simpleSetup();
// userDataExample();
// updateDatabase();
// customUpdateUI();
// settingsPageUpdate();
// backupRestoreExample();
// rollbackExample();
// main();

export {
  simpleSetup,
  userDataExample,
  updateDatabase,
  customUpdateUI,
  settingsPageUpdate,
  backupRestoreExample,
  rollbackExample,
  WatcheditApp
};
