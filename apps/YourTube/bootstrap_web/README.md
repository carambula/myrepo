# YourTube Bootstrap Console

Web-based admin tool for managing YourTube's curated channel catalog, categories, and theme presets.

## Quick Start

```bash
# Optional: set YouTube Data API key for search/enrich features
export YOUTUBE_API_KEY=your_key_here

node server.js
# → http://localhost:4190
```

## Features

- **Channel Catalog**: Browse, search, add, and remove curated YouTube channels
- **Category Management**: Organize channels into categories
- **YouTube API Integration**: Search YouTube for channels, fetch metadata, enrich channel data
- **Manual Channel Add**: Add channels by ID without API key
- **Recent Videos**: Preview recent uploads for any channel
- **Enrichment**: Bulk-enrich all channels with YouTube API metadata (thumbnails, subscriber counts, descriptions)
- **Theme Presets**: CRUD for `theme_presets.json` (shared theme format)
- **Design System Tokens**: Parse and inspect tokens from `DesignSystem.swift`
- **Live Reload**: File watcher with SSE pushes changes to the browser
- **Data Health**: Quick overview of catalog completeness and API key status

## Data

Channel data is stored in `YourTube/bootstrap_data.json` with the structure:

```json
{
  "generatedDate": "2026-04-04T...",
  "categories": [{ "name": "Tech" }, { "name": "Gaming" }],
  "channels": [
    {
      "channelID": "UCxxxxxxxx",
      "title": "Channel Name",
      "description": "...",
      "thumbnailURL": "https://...",
      "category": "Tech",
      "subscriberCount": "1230000",
      "videoCount": "450",
      "uploadsPlaylistID": "UUxxxxxxxx"
    }
  ]
}
```

## API

| Endpoint | Method | Description |
|---|---|---|
| `/api/bootstrap` | GET | Full channel catalog |
| `/api/health` | GET | Data health metrics |
| `/api/categories` | POST | Add category |
| `/api/categories/:name` | DELETE | Delete category |
| `/api/channels` | POST | Add channel |
| `/api/channels/:id` | PUT | Update channel |
| `/api/channels/:id` | DELETE | Remove channel |
| `/api/channels/enrich` | POST | Enrich all with YouTube API |
| `/api/youtube/search?q=` | GET | YouTube channel search |
| `/api/youtube/channel?id=` | GET | YouTube channel details |
| `/api/youtube/videos?channelId=` | GET | Recent videos for channel |
| `/api/design-system/tokens` | GET | Parsed design system tokens |
| `/api/live/changes` | GET (SSE) | Live file change stream |
| `/api/themes` | GET/POST | Theme presets |
| `/api/themes/:id` | PUT/DELETE | Theme preset CRUD |
