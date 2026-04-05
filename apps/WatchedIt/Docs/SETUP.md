# WatchedIt Setup (iOS + tvOS)

## Requirements
- Xcode 16+
- iOS 17+ and tvOS 17+ deployment targets

## Targets
- `WatchedIt` (iOS)
- `WatchedItTV` (tvOS)

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

If you update the bootstrap data:
1. Run `swift generate_bootstrap_database.swift`
2. Ensure the new `bootstrap_database.store` is bundled

## Running
1. Open `WatchedIt.xcodeproj`
2. Select target (iOS or tvOS)
3. Build and run on simulator or device

## Shared Core Package
The tvOS target depends on `WatchedItCore` (local Swift package).
This package uses core files from `WatchedIt/` and is referenced in the project.
