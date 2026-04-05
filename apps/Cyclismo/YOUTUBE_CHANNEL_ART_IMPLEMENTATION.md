# YouTube Channel Art Caching Implementation

## Problem
YouTube channel artwork was showing up blank in the Cyclismo app for sources like "Lanterne Rouge (YouTube)" because the existing `fetchArtworkURL` method only looked for `<itunes:image>` tags in RSS feeds, which YouTube feeds don't include.

## Solution
Implemented YouTube-specific artwork fetching using YouTube's oembed API, which doesn't require authentication.

### Changes Made

#### `Cyclismo/PodcastEpisodeFeedService.swift`

1. **Detection**: Added `isYouTubeFeed()` to detect YouTube feed URLs
2. **Channel ID Extraction**: Added `extractYouTubeChannelID()` to parse channel IDs from feed URLs like:
   - `https://www.youtube.com/feeds/videos.xml?channel_id=UC77UtoyivVHkpApL0wGfH5w`
3. **Artwork Fetching**: Added `fetchYouTubeChannelArtwork()` that:
   - Constructs YouTube oembed API URL: `https://www.youtube.com/oembed?url=https://www.youtube.com/channel/{CHANNEL_ID}&format=json`
   - Fetches JSON response containing `thumbnail_url`
   - Caches the result with 24-hour TTL (same as podcast artwork)

### How It Works

1. When `fetchArtworkURL()` is called for a podcast source:
   - First checks the in-memory cache
   - If it's a YouTube feed, uses the new YouTube-specific flow
   - Otherwise, uses the existing iTunes podcast feed parsing

2. For YouTube channels:
   - Extracts channel ID from feed URL
   - Calls YouTube oembed API (no auth required)
   - Parses JSON response for `thumbnail_url`
   - Caches result using `UnifiedDataCache` with key `youtube-channel-artwork:{channelID}`

3. Caching:
   - In-memory actor cache for quick access
   - Persistent disk cache via `UnifiedDataCache` (24-hour TTL)
   - Prevents repeated API calls for the same channel

### Testing

To test this fix:

1. Build and run the Cyclismo app
2. Navigate to a race detail view that has Lanterne Rouge YouTube episodes
3. Verify that the channel artwork (red/white logo) appears next to the YouTube episode entries
4. Previously, these would show as blank/generic placeholder boxes

### API Used

**YouTube oembed API** (no authentication required):
- Endpoint: `https://www.youtube.com/oembed`
- Parameters:
  - `url`: YouTube channel URL
  - `format`: json
- Response includes:
  - `thumbnail_url`: Channel avatar URL
  - `author_name`: Channel name
  - Other metadata (not currently used)

### Affected Sources

Currently affects:
- "Lanterne Rouge (YouTube)" - Channel ID: UC77UtoyivVHkpApL0wGfH5w

Any future YouTube channel sources added to the podcast sources list will automatically benefit from this implementation.

## Performance Considerations

- First load: ~100-300ms API call to YouTube oembed
- Subsequent loads: Instant (served from cache)
- Cache TTL: 24 hours (artwork rarely changes)
- Fallback: If oembed fails, returns nil and caches that result to avoid repeated failures
