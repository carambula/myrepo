# YouTube Channel Art Testing Guide

## Quick Test

1. **Build the app**: Open Xcode and build the Cyclismo app
2. **Navigate to a race**: Find a race with YouTube content (e.g., Paris-Nice 2026)
3. **Check the race detail view**: Look for "Lanterne Rouge (YouTube)" entries in the podcast/content section
4. **Verify artwork**: The Lanterne Rouge channel logo should now appear (red/white logo)

## Expected Behavior

### Before the Fix
- YouTube channel entries showed blank/generic placeholder boxes
- Only the text "Lanterne Rouge (YouTube)" was visible
- No visual distinction between different YouTube sources

### After the Fix
- YouTube channel logo appears next to each entry
- First load: Brief loading time (~100-300ms)
- Subsequent loads: Instant (cached)
- Artwork persists for 24 hours before refresh

## Detailed Testing Steps

### Test 1: Initial Load (No Cache)
1. Clean build the app (delete derived data if needed)
2. Open a race detail with YouTube content
3. **Expected**: Channel artwork loads within 1 second
4. **Check**: Image shows the Lanterne Rouge logo

### Test 2: Cached Load
1. Navigate away from the race detail
2. Navigate back to the same race
3. **Expected**: Artwork appears instantly (from cache)
4. No network request should be made

### Test 3: Offline Behavior
1. Load a race with cached artwork
2. Enable airplane mode
3. Navigate to the race detail
4. **Expected**: Cached artwork still displays
5. Navigate to a new race (no cache)
6. **Expected**: Graceful fallback to placeholder

### Test 4: Error Handling
1. Modify the YouTube oembed URL to an invalid endpoint (for testing only)
2. Build and run
3. **Expected**: Falls back to placeholder, doesn't crash
4. Caches the failure to avoid repeated requests

### Test 5: Multiple YouTube Sources
If multiple YouTube sources exist:
1. Verify each has distinct artwork
2. Check that cache keys are unique per channel
3. Confirm no artwork mixing between channels

## Manual Network Inspection

### Using Charles Proxy or Network Link Conditioner

1. **First Load**:
   - Look for request to: `https://www.youtube.com/oembed?url=https://www.youtube.com/channel/UC77UtoyivVHkpApL0wGfH5w&format=json`
   - Should see 200 OK response
   - Response body contains `thumbnail_url`

2. **Cached Load**:
   - No request to YouTube oembed
   - Data served from UnifiedDataCache

3. **Response Example**:
```json
{
  "title": "Lanterne Rouge Cycling",
  "author_name": "Lanterne Rouge Cycling",
  "author_url": "https://www.youtube.com/@LanterneRougeCycling",
  "type": "video",
  "height": 113,
  "width": 200,
  "version": "1.0",
  "provider_name": "YouTube",
  "provider_url": "https://www.youtube.com/",
  "thumbnail_height": 225,
  "thumbnail_width": 225,
  "thumbnail_url": "https://yt3.ggpht.com/ytc/..."
}
```

## Verifying Cache Persistence

### In-Memory Cache (Actor)
- Cache persists for the app session
- Cleared when app terminates

### Disk Cache (UnifiedDataCache)
- Persists across app launches
- TTL: 24 hours
- Location: App's caches directory

### To Force Cache Refresh
1. Delete app and reinstall
2. Wait 24 hours for TTL expiration
3. Clear app data via Settings → General → iPhone Storage

## Edge Cases to Test

### Invalid Channel IDs
- Feed URL without `channel_id=` parameter
- Malformed channel ID
- **Expected**: Graceful fallback, no crash

### Network Errors
- Slow network (use Network Link Conditioner)
- Timeout after 10 seconds
- **Expected**: Returns nil, shows placeholder

### JSON Parsing Errors
- Unexpected JSON structure
- Missing `thumbnail_url` field
- **Expected**: Returns nil, shows placeholder

## Performance Benchmarks

### Target Metrics
- First load: < 500ms
- Cached load: < 50ms
- Memory overhead: < 1MB for artwork cache
- No UI blocking

### Testing Performance
1. Use Instruments (Time Profiler)
2. Monitor network activity
3. Check main thread blocking
4. Verify async/await correctness

## Known Limitations

1. **Requires Internet**: First load needs network access
2. **YouTube API Availability**: Depends on YouTube oembed service uptime
3. **Artwork Quality**: Limited by YouTube's provided thumbnail resolution
4. **Cache Invalidation**: No manual refresh option (waits for 24h TTL)

## Troubleshooting

### Artwork Not Showing
1. Check network connectivity
2. Verify feed URL contains `channel_id=`
3. Check Xcode console for error messages
4. Confirm oembed API is accessible

### Artwork Shows Wrong Image
1. Clear app cache
2. Verify channel ID extraction is correct
3. Check if YouTube channel changed artwork

### Performance Issues
1. Check if caching is working (no repeated requests)
2. Verify cache TTL is appropriate
3. Monitor network timeouts

## Success Criteria

✅ Lanterne Rouge YouTube entries show channel logo
✅ Artwork loads quickly on first view
✅ Subsequent views use cached artwork
✅ No crashes or errors
✅ Graceful fallback for failures
✅ Minimal performance impact
