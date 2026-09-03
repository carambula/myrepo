# Min Cloud

Shared Railway web service for **mov min** (WatchedIt) and **pod min** (PodLink).

The apps still work offline. Local scraping, bundled catalogs, and RSS fetches remain the backup. When Min Cloud is reachable, catalog updates, streaming availability, feed refresh, admin edits, accounts, social, and notifications run on the server so every user gets clean data without an app update.

iCloud stays available as an optional backup. People who do not want a web account keep using the apps locally (and iCloud if they want device-to-device sync).

## What it does

| Goal | How |
| --- | --- |
| Faster, more reliable updates | Incremental catalog APIs (`/v1/mov/catalog`, `/v1/pod/catalog`) plus scheduled jobs |
| Notifications | Device registration, preference sync, server-side new-episode queue |
| Server-side fetching | TMDB watch-provider refresh and RSS ingest; clients fall back locally |
| Cloud admin | `/admin` — edit movies/podcasts and run jobs without shipping a binary |
| User web + social | `/` — accounts, browse, follow, activity |
| Optional iCloud | Apps treat Min Cloud as primary when signed in; iCloud is a backup toggle |

## Local development

```bash
cd services/min-cloud
cp .env.example .env
docker compose up postgres -d
npm install
npm run migrate
npm run seed
npm test
npm run dev
```

- API and user site: http://localhost:4000
- Admin: http://localhost:4000/admin
- Health: http://localhost:4000/health

Set `ADMIN_TOKEN` and paste it into the admin page. Set `TMDB_API_KEY` to refresh streaming catalogues.

## Railway

1. Create a Railway project from `services/min-cloud`.
2. Add a Postgres plugin. Railway injects `DATABASE_URL`.
3. Set `ADMIN_TOKEN`, `SESSION_SECRET`, `CRON_SECRET`, and `PUBLIC_URL`.
4. Optionally set `TMDB_API_KEY`, `ADMIN_EMAILS`, and APNs/VAPID keys later.
5. Deploy. Migrations run on boot.
6. Seed or import the catalog:
   - `npm run seed` for the sample set
   - `POST /v1/admin/mov/import` with WatchedIt `bootstrap_data.json`
   - Admin “Add podcast” / iTunes enrich for PodLink defaults
7. Optional Railway cron hitting `POST /internal/jobs/all` with `x-cron-secret`.

In-process jobs also run when `ENABLE_JOBS=true` (default): podcast feeds every 30 minutes, streaming every 6 hours.

## Client configuration

Both apps read `mincloud.baseURL` from `UserDefaults` / Info settings, defaulting to `PUBLIC_URL` or `https://min-cloud.up.railway.app`. Override on device for local testing:

```
mincloud.baseURL = http://localhost:4000
```

## API surface

- `POST /v1/auth/register` `POST /v1/auth/login`
- `GET /v1/me` library, devices, notifications
- `GET /v1/mov/catalog?updatedSince=`
- `GET /v1/pod/catalog` `GET /v1/pod/feeds?url=`
- `GET /v1/social/feed` `POST /v1/social/follow`
- `GET /v1/admin/health` `POST /v1/admin/jobs/:name`

Local `bootstrap_web` consoles remain for offline catalog editing. Min Cloud is the source of truth once deployed.
