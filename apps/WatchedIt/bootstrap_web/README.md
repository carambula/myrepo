# WatchedIt Bootstrap Web Editor

Local web UI for editing `WatchedIt/bootstrap_data.json`, refreshing podcast
episodes, and regenerating `bootstrap_database.store`.

The same UI now runs on Min Cloud at `/admin` (Railway), talking to Postgres
instead of `bootstrap_data.json`. This local console stays as an offline backup.

iOS Xcode builds pull the live catalog from Min Cloud into
`WatchedIt/bootstrap_data.cloud.json` (gitignored) and regenerate
`bootstrap_database.store`. Set `SKIP_CLOUD_BOOTSTRAP=1` to bake the
committed JSON instead.

## Run

```bash
cd /Users/carambula/Documents/WatchedIt/bootstrap_web
node server.js
```

Open `http://localhost:4187`.

## Environment

- `TMDB_API_KEY` (optional): override the TMDB key used for metadata lookup.

