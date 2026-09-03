# Min Cloud

Shared Railway web service for **mov min** (WatchedIt) and **pod min** (PodLink).

The apps still work offline. Local scraping, bundled catalogs, and RSS fetches remain the backup. When Min Cloud is reachable, catalog updates, streaming availability, feed refresh, admin edits, accounts, social, and notifications run on the server so every user gets clean data without an app update.

iCloud stays available as an optional backup. People who do not want a web account keep using the apps locally (and iCloud if they want device-to-device sync).

## What it does

| Goal | How |
| --- | --- |
| Faster, more reliable updates | Incremental catalog APIs (`/v1/mov/catalog`, `/v1/pod/catalog`) plus scheduled jobs |
| Notifications | Anonymous device watch, preference sync, server-side new-episode inbox. Local alerts work without an account. |
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
- Admin: http://localhost:4000/admin — the WatchedIt bootstrap editor, pointed at Postgres
- Legacy job console: http://localhost:4000/admin/jobs
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
   - or `ADMIN_TOKEN=... node scripts/import-bootstrap.mjs` (also applies `physical_media.json`)
   - Admin “Add podcast” / iTunes enrich for PodLink defaults
7. Optional Railway cron hitting `POST /internal/jobs/all` with `x-cron-secret`.

In-process jobs also run when `ENABLE_JOBS=true` (default): podcast feeds every 30 minutes, streaming every 6 hours.

## Live deployment

- Project: [min-cloud](https://railway.com/project/eb333f4f-f09f-4ed8-9cfc-eaf4a66f09cf)
- API / user site: https://min-cloud-production.up.railway.app
- Admin: https://min-cloud-production.up.railway.app/admin
- Health: https://min-cloud-production.up.railway.app/health

Copy `ADMIN_TOKEN` from the Railway service variables to sign into admin. Do not commit it.

## Client configuration

Both apps read `mincloud.baseURL` from `UserDefaults` / Info settings, defaulting to `https://min-cloud-production.up.railway.app`. Override on device for local testing:

```
mincloud.baseURL = http://localhost:4000
```

## Podcast updates (pod min)

`pod.feeds.refresh` runs every 30 minutes against every show in `pod_podcasts`. That set starts as the curated catalog and grows when someone follows a feed:

- **No account:** the app still uses `GET /v1/pod/feeds?url=` (no login). Following a show also `POST /v1/pod/watch` with a local `deviceId`, which upserts the feed into the shared refresh set. Curated catalog refresh happens either way.
- **Signed in:** followed shows are also written to `user_library_pod`, so the same refresh job can enqueue per-user inbox items.
- **New episode notifications:** yes. Priority / per-show flags enqueue into `notification_queue` for accounts and anonymous devices. The app also fires local notifications when a fresh fetch sees a newer episode than the last baseline. First ingest does not notify. APNs push is not wired yet; the inbox API and local alerts are the delivery surfaces.

## API surface

- `POST /v1/auth/register` `POST /v1/auth/login`
- `GET /v1/me` library, devices, notifications
- `GET /v1/mov/catalog?updatedSince=` (includes `physicalMedia` when known)
- `POST /v1/admin/mov/physical-media` with WatchedIt `physical_media.json`
- `GET /v1/pod/catalog` `GET /v1/pod/feeds?url=`
- `POST /v1/devices/register` `POST /v1/pod/watch` `GET /v1/devices/:deviceId/inbox` — no account required
- `GET /v1/social/feed` `POST /v1/social/follow`
- `GET /v1/admin/health` `POST /v1/admin/jobs/:name`

Local `bootstrap_web` consoles remain for offline catalog editing. Min Cloud is the source of truth once deployed.
