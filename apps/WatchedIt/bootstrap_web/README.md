# WatchedIt Bootstrap Web Editor

Local web UI for editing `WatchedIt/bootstrap_data.json`, refreshing podcast
episodes, and regenerating `bootstrap_database.store`.

For the shared cloud admin and live streaming/feed jobs, use `services/min-cloud`
(Railway). This local console stays as an offline backup for catalog work.

## Run

```bash
cd /Users/carambula/Documents/WatchedIt/bootstrap_web
node server.js
```

Open `http://localhost:4187`.

## Environment

- `TMDB_API_KEY` (optional): override the TMDB key used for metadata lookup.

