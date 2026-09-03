# WatchedIt Data Contract Rules (iOS + tvOS)

These rules protect shared state and prevent data forking between iOS and tvOS.

## 1) Single Source of Truth
- All data models, persistence, and sync logic live in `WatchedItCore`.
- UI targets never write directly to SwiftData or CloudKit.
- All writes go through shared core APIs (e.g., `LocalDatabaseManager`, `CloudKitManager`).

## 2) Shared CloudKit Schema Only
- Same container, zones, record types, and field names for both targets.
- No platform-specific record types or parallel schemas.
- User status payloads must remain identical across platforms.

## 3) Catalog Is Local First, Cloud Updates Are Additive
- Catalog data is read from the bundled store for instant startup.
- Min Cloud catalog sync may update streaming availability and add titles without wiping user status or local lists.
- CloudKit sync applies to **user status and preferences only**, and only when iCloud backup is enabled.
- Local scrape/bundle refresh remains the backup if Min Cloud is unreachable.

## 4) Deterministic IDs
- Movie IDs must remain deterministic (`tmdb-`, `imdb-`, or `episode-`).
- No platform-specific ID logic or remapping.

## 5) Additive, Compatible Schema Changes
- Schema changes are additive unless both apps ship together.
- New fields must be optional or have defaults.
- Migration logic is shared and shipped to both targets.
- Catalog physical media (`PhysicalMedia` / `physicalMediaData`) is optional. Shipping data lives in bundled `physical_media.json` (keyed by TMDB id) and is merged at read time. Bootstrap JSON may also carry `physicalMedia` for admin edits. Manual overrides win over inferred Wikidata/list seeds.
- Theatrical availability (`TheatricalRun`) is live overlay only — not stored on `MovieData`. Min Cloud `GET /v1/mov/now-playing` (TMDB now-playing + IMAX release notes for catalog titles) or a local TMDB fallback refreshes `TheatricalCatalog` at launch. Buy-disc and ticket destinations are client-built search URLs, not persisted store links.

## 6) Idempotent Writes, Deterministic Conflict Rules
- Writes must be safe to apply multiple times.
- Conflict resolution must be deterministic (e.g., latest `lastUpdated` wins).
- Avoid destructive overwrites of user status.

## 7) No Duplicate Utilities
- Any code that touches:
  - user status
  - list membership
  - preference encoding
  - movie identifiers
  must live in shared core and be reused.

## 8) Release Guardrails
- Any PR that changes shared models or sync must:
  - document schema changes
  - confirm compatibility with both targets
  - update migration notes (if needed)

## 9) Testing Expectations
- Core tests must validate:
  - payload serialization/deserialization
  - merge behavior
  - ID stability

## 10) TV App Specialization Is UI-Only
- tvOS can customize layouts, focus, and navigation.
- tvOS must not change data formats or persistence rules.

## 11) Editing One App Must Not Break the Other
- Shared code lives in WatchedItCore (sources under `WatchedIt/`). Changes there affect both iOS and tvOS.
- Persistence, store URL, schema, and bootstrap logic must not assume a single platform; version checks must only replace the store on confirmed mismatch or known corruption, not when the version key is unreadable.
- See `.cursorrules` section **iOS + tvOS: Cross-Target Safety** for full guardrails.
