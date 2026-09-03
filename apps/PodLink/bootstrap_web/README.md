# PodLink Bootstrap Console

Web-based admin tool for managing PodLink's default podcast catalog, categories, media patterns, and theme presets.

For hosted admin, accounts, notifications, and scheduled RSS refresh, use `services/min-cloud` on Railway. This local console stays as an offline backup.

## Quick Start

```bash
node server.js
# → http://localhost:4189
```

## Features

- **Podcast Catalog**: Browse, search, add, and remove podcasts from `DefaultPodcasts.json`
- **Category Management**: Create, rename, and delete categories
- **iTunes Integration**: Search iTunes for podcasts and add them by ID
- **RSS Feed Preview**: Preview recent episodes from any podcast's RSS feed
- **Enrichment**: Bulk-enrich all podcasts with iTunes metadata (artwork, artist, feed URL)
- **Theme Presets**: CRUD for `theme_presets.json` (shared theme format)
- **Media Patterns**: View and edit `MediaPatterns.json`
- **Design System Tokens**: Parse and inspect tokens from `DesignSystem.swift`
- **Live Reload**: File watcher with SSE pushes changes to the browser
- **Data Health**: Quick overview of catalog completeness

## API

| Endpoint | Method | Description |
|---|---|---|
| `/api/bootstrap` | GET | Full podcast catalog |
| `/api/health` | GET | Data health metrics |
| `/api/categories` | POST | Add category |
| `/api/categories/:name` | PUT | Rename category |
| `/api/categories/:name` | DELETE | Delete category |
| `/api/podcasts` | POST | Add podcast to category |
| `/api/podcasts` | DELETE | Remove podcast from category |
| `/api/podcasts/enrich` | POST | Enrich all with iTunes metadata |
| `/api/itunes/search?term=` | GET | iTunes podcast search |
| `/api/itunes/lookup?id=` | GET | iTunes podcast lookup |
| `/api/feeds/preview` | POST | Preview RSS feed episodes |
| `/api/media-patterns` | GET/PUT | Media patterns CRUD |
| `/api/design-system/tokens` | GET | Parsed design system tokens |
| `/api/live/changes` | GET (SSE) | Live file change stream |
| `/api/themes` | GET/POST | Theme presets |
| `/api/themes/:id` | PUT/DELETE | Theme preset CRUD |
