# Oscar's Filter Toolbar Crash - Fix Summary

## Problem

The app was crashing instantly when filtering by "Oscar's Best and Worst" from the filter toolbar on the Home Screen, but worked fine when tapping the collection title.

## Root Cause

The crash was occurring in `MovieSearchSession.buildSourceCache()` when accessing SwiftData relationships. The issue affected **all** toolbar filters (lists, streaming services, genres, ratings), not just Oscar's Best and Worst - but Oscar's was likely the first one you tried.

### Technical Details

The previous implementation:
```swift
for movieData in movieDataList {
    for sourceContent in movieData.sourceContents ?? [] {
        if let sourceID = sourceContent.source?.identifier {  // ⚠️ CRASH HERE
            sourceIDs.insert(sourceID)
        }
    }
}
```

**Why it crashed:**
- Fetched all `MovieData` objects first
- Traversed their `sourceContents` and `dataSources` relationships
- SwiftData relationships can be "faulted" (not loaded into memory)
- Accessing `sourceContent.source?.identifier` on a faulted relationship caused a crash

**Why collection title tap worked:**
- Collection title tap uses a different code path
- It uses `restrictedMovieIDs` (pre-computed movie IDs) instead of filtering by list identifier
- Never calls `buildSourceCache()`, so never hits the crash

## Solution

Changed the approach to fetch junction table objects directly instead of traversing relationships from movies:

```swift
// Fetch SourceContent objects directly
let sourceContentDescriptor = FetchDescriptor<SourceContent>()
if let sourceContents = try? modelContext.fetch(sourceContentDescriptor) {
    for sourceContent in sourceContents {
        // Safely access relationships with guard
        guard let movieID = sourceContent.movie?.id,
              let sourceID = sourceContent.source?.identifier else {
            continue
        }
        cache[movieID, default: Set<String>()].insert(sourceID)
    }
}
```

**Benefits:**
1. **Safer**: Accessing relationships from junction tables is more reliable
2. **More efficient**: Fewer database queries and relationship traversals
3. **More defensive**: Guard statements prevent crashes even if relationships are nil

## Testing

To verify the fix works:

1. Build and run the app
2. Open the Home Screen
3. Tap the **list filter button** (📋) in the bottom toolbar
4. Select **"RT: Oscars Best and Worst"** (or any other list)
5. App should open search with the filter applied - **no crash!**
6. Also test:
   - Genre filter (🎭) - select any genre
   - Rating filter (🅁) - select any rating
   - Streaming service filter (▶️) - select any service

All toolbar filters should now work without crashing.

## Files Changed

- `WatchedIt/Search/MovieSearchSession.swift` - Fixed `buildSourceCache()` method

## Git

- **Branch**: `cursor/oscar-s-filter-toolbar-crash-768e`
- **Commit**: 408ee18
- **Status**: Pushed to remote, ready for PR
