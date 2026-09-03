# WatchedIt Architecture (iOS + tvOS)

## Overview
WatchedIt uses a shared core module and separate platform UIs.

- **Shared core**: data models, persistence, CloudKit sync, services
- **iOS UI**: existing SwiftUI views under `WatchedIt/`
- **tvOS UI**: SwiftUI views under `WatchedItTV/`

## Shared Core Module
The local Swift package `WatchedItCore` reuses the existing core files from `WatchedIt/`:

- Models: `MovieData`, `UserMovieData`, `DataSource`, `SourceContent`
- Managers: `LocalDatabaseManager`, `ThemeManager`
- Services: `CloudKitManager`, `BootstrapDataService`, `MovieDataService`
- Utilities: `TitleCleaner`, `RewatchablesCategories`, preferences

This package is referenced by the tvOS target.

## CloudKit User Data Sync
User status data lives in a dedicated CloudKit zone and is shared between iOS and tvOS.

- Container: `iCloud.com.Carambula-Projects.WatchedIt`
- Zone: `UserMovieDataZone`
- Record type: `UserMovieData`

Sync rules:
- Restore on fresh install only when local status is empty.
- Push on status changes only; avoid automatic bulk uploads.
- Do not sync the catalog; catalog is always local via bundled store.

## Catalog / Bootstrap Store
The app bundles a pre-populated SwiftData store for instant startup.

- Resource: `bootstrap_database.store`
- Bootstrap import JSON is build-time only.
- Both iOS and tvOS targets include the bundled store in app resources.
- When Min Cloud is reachable, `MinCloudCatalogSync` applies server catalog + streaming updates on top of the local store. The bundled store remains the offline backup.

## Min Cloud
Optional Railway-hosted service (`services/min-cloud`) for accounts, social, notifications, admin catalog edits, and scheduled TMDB/RSS jobs. iCloud remains an optional backup for user status when the user does not want a web account.

## Project Structure
```
WatchedIt/
├── WatchedIt/          # iOS app + core files (shared via package)
├── WatchedItTV/        # tvOS app + UI
├── Packages/
│   └── WatchedItCore/  # Local Swift package
└── Docs/
    ├── ARCHITECTURE.md
    └── SETUP.md
```
