# WatchedIt Bootstrap Web Editor

Local web UI for editing `WatchedIt/bootstrap_data.json`, refreshing podcast
episodes, and regenerating `bootstrap_database.store`.

The same UI now runs on Min Cloud at `/admin` (Railway), talking to Postgres
instead of `bootstrap_data.json`. This local console stays as an offline backup.

## Run

```bash
cd /Users/carambula/Documents/WatchedIt/bootstrap_web
node server.js
```

Open `http://localhost:4187`.

## Environment

- `TMDB_API_KEY` (optional): override the TMDB key used for metadata lookup.

