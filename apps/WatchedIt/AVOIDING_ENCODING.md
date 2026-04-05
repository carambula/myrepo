# Avoiding Encoding/Decoding for Fresh Starts

## Current State

✅ **Already Implemented**: Pre-populated database approach avoids JSON parsing on app start
- Database is pre-generated and bundled with app
- App just copies the database file on first launch (no encoding/decoding)
- Zero processing time for fresh starts

## Where Encoding Still Happens

1. **During Database Generation** (one-time, before bundling)
   - Script reads JSON and creates database
   - This is fine - happens once, not on user's device

2. **At Runtime** (when accessing complex properties)
   - Properties like `podcastEpisode`, `rewatchablesDiscussion` are computed
   - They encode/decode from `Data` storage
   - This happens lazily when properties are accessed

## Optimization Opportunities

### Option 1: Store Simple Types Directly (No Encoding)
For bootstrap data (which has no podcast episodes), we can store:
- `sourceTitle` as String (direct, no encoding)
- `rank` as Int? (direct, no encoding)
- Skip encoding podcastEpisode/rewatchablesDiscussion (set to nil)

### Option 2: Lazy Encoding Only
- Don't encode complex types during generation
- Only encode when user actually syncs/refreshes sources with new data

### Option 3: Use Relationships Instead of Encoding
- Move podcast episode data to separate `PodcastEpisode` entity
- Use SwiftData relationships instead of encoded Data

## Recommended Approach

For **fresh starts** (pre-populated database):
- ✅ Already optimized: Just copy database file (instant)
- Store simple properties directly (rank, sourceTitle, sourceUrl)
- Skip encoding complex nested objects (not needed for bootstrap data)

For **runtime** (user interactions):
- Lazy encoding only when needed
- Consider migrating to relationship-based storage for complex data

## Next Steps

1. Update `generate_bootstrap_database.swift` to create `SourceContent` entries
2. Store only simple types during generation (no encoding)
3. Encoding happens later only when user syncs new podcast episodes





