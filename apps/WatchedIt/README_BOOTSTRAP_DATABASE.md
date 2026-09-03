# Pre-Populated Bootstrap Database

This app now uses a **pre-populated SwiftData database** instead of JSON for faster initial data loading.

## Benefits

- **Faster**: No JSON parsing overhead - database is ready to use immediately
- **Smaller**: 5.3MB database vs 6.4MB JSON (17% smaller)
- **Native**: Works directly with SwiftData - no import step needed
- **Better Performance**: SQLite is optimized for queries and relationships

## Generating the Database

To regenerate the bootstrap database after updating `bootstrap_data.json`:

```bash
cd /Users/carambula/Documents/WatchedIt
swift generate_bootstrap_database.swift
```

This will:
1. Load `WatchedIt/bootstrap_data.json`
2. Create a SwiftData database with all movies, sources, and links
3. Output `WatchedIt/bootstrap_database.store` (5.3MB)

## Adding to Xcode Project

1. **Add the database file to Xcode:**
   - Right-click on `WatchedIt` folder in Xcode
   - Select "Add Files to WatchedIt..."
   - Select `bootstrap_database.store`
   - ✅ Check "Copy items if needed"
   - ✅ Check "Add to targets: WatchedIt"
   - Click "Add"

2. **Verify it's in the bundle:**
   - Select `bootstrap_database.store` in Xcode
   - In File Inspector, ensure "Target Membership" includes "WatchedIt"

## How It Works

On **first app launch**:
1. App checks if user's database exists
2. If not, copies `bootstrap_database.store` from bundle to user's database location
3. App starts with 2,686 movies and 11 sources immediately available
4. No JSON parsing, no import step, no waiting

For **existing users**:
- If they already have a database, the pre-populated one is ignored
- They can still use the bootstrap migration dialog if needed

## File Sizes

- `bootstrap_data.json`: 6.4MB (original)
- `bootstrap_database.store`: 5.3MB (17% smaller)
- Contains: 2,686 movies, 11 sources, 2,686 links

## Cloud-era source of truth

Min Cloud Postgres is the live catalog. The files in git (`bootstrap_data.json` + `bootstrap_database.store`) are the **offline first-launch bundle**.

On an iOS Xcode build, `build_bootstrap_database.sh` now:

1. Pulls `GET /v1/mov/catalog` into `WatchedIt/bootstrap_data.cloud.json` (gitignored)
2. Regenerates `bootstrap_database.store` from that pull
3. Falls back to the committed JSON if you are offline, `node` is missing, or `SKIP_CLOUD_BOOTSTRAP=1`

If SwiftData moves an old `default.store` aside (schema / persistence mismatch), the next launch copies this freshly built bundle. Existing installs can also use Settings → **Refresh Catalog from Min Cloud** without rebuilding.

```bash
# Pull only (writes bootstrap_data.cloud.json)
MIN_CLOUD_URL=https://min-cloud-production.up.railway.app \
  node ../../services/min-cloud/scripts/export-bootstrap.mjs

# Offline / airplane build
SKIP_CLOUD_BOOTSTRAP=1 ./build_bootstrap_database.sh
```

## Updating the Database

When you update the bootstrap data:

1. Edit on Min Cloud `/admin`, or update `bootstrap_data.json` offline
2. Build in Xcode (pulls cloud + regenerates the store) or run `./build_bootstrap_database.sh`
3. The new `bootstrap_database.store` is bundled automatically

The database will automatically be included in the app bundle and used on first launch.

## Enrich Before Build

If you want the bundled database to include directors, cast, streaming services,
and other TMDB metadata out of the box, enrich the JSON first and then regenerate
the database. The enrichment script is incremental: it reads
`bootstrap_data_enriched.json` (stored at the repo root) if it exists and only fills in missing fields.

```bash
cd /Users/carambula/Documents/WatchedIt
swift enrich_bootstrap_data.swift
swift generate_bootstrap_database.swift
```

Convenience script (does both in order):

```bash
cd /Users/carambula/Documents/WatchedIt
./build_bootstrap_database.sh
```

Note: enrichment makes many TMDB API calls and can take time.





