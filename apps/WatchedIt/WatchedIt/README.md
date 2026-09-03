# WatchedIt

A SwiftUI app for tracking movies from a bundled, offline catalog with iCloud-backed user status.

## Features

- ✅ Offline catalog bundled in the app
- ✅ Checklist functionality to mark movies as watched
- ✅ iCloud-backed user status restore/backup
- ✅ Movie details including:
  - Poster/backdrop artwork
  - Key credits (director, cast)
  - Streaming service information
  - Links to podcast episodes
- ✅ Search functionality

## Setup Instructions

### 1. CloudKit Configuration

1. Open the project in Xcode
2. Go to your project settings → Signing & Capabilities
3. Ensure CloudKit is enabled
4. The container identifier should be: `iCloud.com.Carambula-Projects.WatchedIt`
5. If you need to change it, update:
   - `WatchedIt.entitlements`
   - `CloudKitManager.swift` (container identifier)

### 2. First Run

1. Build and run the app
2. Sign in to iCloud if prompted
3. The app uses the bundled catalog on first launch

## Architecture

- **Movie.swift**: Core data models
- **CloudKitManager.swift**: Handles iCloud user data
- **MovieDataService.swift**: URL helpers for images/trailers
- **MovieListView.swift**: Main list view with search
- **MovieDetailView.swift**: Detailed movie information view

## Data Pipeline (Build-Time)

- Update data via the web UI and export JSON
- Run `swift generate_bootstrap_database.swift`
- Bundle `bootstrap_database.store` (and WAL/SHM) in the app

