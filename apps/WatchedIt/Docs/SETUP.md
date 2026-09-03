# WatchedIt Setup (iOS + tvOS)

## Requirements
- Xcode 16+
- iOS 17+ and tvOS 17+ deployment targets

## Targets
- `WatchedIt` (iOS)
- `WatchedItTV` (tvOS)

## Min Cloud
Optional Railway service in `services/min-cloud`. Point the app at it with `UserDefaults` key `mincloud.baseURL`. Catalog refresh and accounts live there; the bundled store and local scrape stay as backup.

## CloudKit
Both targets use the same CloudKit container and zone:

- Container: `iCloud.com.Carambula-Projects.WatchedIt`
- Zone: `UserMovieDataZone`

Ensure entitlements are set:
- iOS: `WatchedIt/WatchedIt.entitlements`
- tvOS: `WatchedItTV/WatchedItTV.entitlements`

## Bundled Data
Both targets must include:
- `bootstrap_database.store`

The iOS Xcode Run Script pulls the live Min Cloud catalog (no admin token) into `bootstrap_data.cloud.json` and regenerates the store before copy-bundle. tvOS uses whatever store the last iOS/cloud build wrote.

Offline: `SKIP_CLOUD_BOOTSTRAP=1` and the committed `bootstrap_data.json`.

Already-running installs: Settings → Refresh Catalog from Min Cloud.

## Running
1. Open `WatchedIt.xcodeproj`
2. Select target (iOS or tvOS)
3. Build and run on simulator or device

## Shared Core Package
The tvOS target depends on `WatchedItCore` (local Swift package).
This package uses core files from `WatchedIt/` and is referenced in the project.
