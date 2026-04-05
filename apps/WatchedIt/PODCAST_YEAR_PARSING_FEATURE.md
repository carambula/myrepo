# Podcast Film Year Parsing Feature

## Problem

When fetching latest podcast episodes (e.g., from The Rewatchables), the app could add the wrong movie when multiple films share the same title but were released in different years.

**Example:** 
- Episode about "Crazy Stupid Love" (2011 American film with Steve Carell, Ryan Gosling, Emma Stone)
- App incorrectly added "Crazy Stupid Love" (2022 Indian film)

## Root Cause

The `PodcastEpisodeIntakeService` only parsed years from episode *titles* (looking for patterns like "(2011)" at the end), but ignored the episode *description* which often contains:
- Year information ("the 2011 film", "from 2011", "released in 2011")
- Cast/director names for validation ("starring Steve Carell", "directed by...")

## Solution

Enhanced the podcast episode intake pipeline to:

1. **Extract year from episode descriptions** using multiple patterns
2. **Extract cast/director names** from descriptions for validation
3. **Use this metadata to improve TMDB matching** when multiple candidates exist

## Changes Made

### 1. PodcastEpisodeIntakeService.swift

#### New Method: `extractYearFromDescription(_:)`
Parses episode descriptions for year hints using these patterns:
- `"the 2011 film"` or `"2011 film"`
- `"from 2011"` or `"in 2011"`
- `"released in 2011"`
- `"2011's"` or `"2011 release"`
- `"(2011)"` or `"[2011]"`

```swift
public func extractYearFromDescription(_ description: String) -> Int?
```

#### New Method: `extractPersonNamesFromDescription(_:)`
Extracts cast/director names for validation:
- `"starring Steve Carell"`
- `"with Ryan Gosling"`
- `"directed by Glenn Ficarra"`

```swift
public func extractPersonNamesFromDescription(_ description: String) -> [String]
```

#### Updated Method: `buildTMDBSearchInput(rawTitle:description:)`
Now accepts optional description parameter to extract year when not in title:

```swift
public func buildTMDBSearchInput(rawTitle: String, description: String? = nil) -> PodcastTMDBSearchInput
```

#### Updated Method: `enrichCandidate(_:source:now:)`
- Passes episode description to year extraction
- Extracts person names for validation
- Logs successful matches with year info for debugging

### 2. MovieDataService.swift

#### Updated Method: `searchMovieBestMatch(title:year:preferredYear:expectedPersonNames:)`
Enhanced movie matching algorithm with person name validation:

**Scoring System:**
- **+100 points**: Exact year match
- **+75 points**: Person name match (cast/director)
- **+50 points**: Year within 1 year, or exact title match
- **+30 points**: Partial title match
- **+10 points**: Has poster (likely main release)
- **-50 points**: Year difference > 5 years

When `expectedPersonNames` is provided:
1. Fetches credits for top 5 candidates
2. Validates if expected names match cast or crew
3. Boosts score significantly for matches

```swift
func searchMovieBestMatch(
    title: String, 
    year: Int? = nil, 
    preferredYear: Int? = nil, 
    expectedPersonNames: [String]? = nil
) async throws -> TMDBMovie?
```

## Testing

Created `test_podcast_year_parsing.swift` to validate extraction logic:

### Test Cases
1. ✅ "the 2011 film Crazy Stupid Love, starring Steve Carell..."
2. ✅ "the classic film (1999) starring Tom Hanks"
3. ✅ "the movie from 2015 that changed everything"
4. ✅ "released in 2008 and became a cult classic"
5. ✅ "2010's Inception with the crew"
6. ✅ "directed by Christopher Nolan"
7. ✅ "Starring Tom Cruise and featuring Nicole Kidman"

**Run tests:**
```bash
swift test_podcast_year_parsing.swift
```

## Example Flow

### Before (Incorrect Match)
```
Episode: "Crazy Stupid Love with Steve Carell and Ryan Gosling"
Description: "Sean, Amanda, and Chris discuss the 2011 film..."

1. Parse title → "Crazy Stupid Love" (no year)
2. Search TMDB → Multiple results
3. Pick first result → Wrong movie (2022 Indian film) ❌
```

### After (Correct Match)
```
Episode: "Crazy Stupid Love with Steve Carell and Ryan Gosling"
Description: "Sean, Amanda, and Chris discuss the 2011 film starring Steve Carell..."

1. Parse title → "Crazy Stupid Love" (no year in title)
2. Parse description → Year: 2011, Names: ["Steve Carell"]
3. Search TMDB with year → Multiple candidates
4. Score candidates:
   - 2011 film: +100 (year) +75 (Steve Carell match) = 175
   - 2022 film: -50 (wrong year) = -50
5. Pick best match → Correct movie ✅
```

## Logging

Enhanced logging for debugging:

```
📅 Extracted year 2011 from description using pattern: ...
🎬 TMDB: Validating matches using expected person names: Steve Carell
   ✅ Person match found: 'Steve Carell' in 'Crazy Stupid Love' (2011)
🎯 TMDB: Selected best match 'Crazy Stupid Love' (ID: 123, Year: 2011, Score: 175.0)
✅ Matched 'Crazy Stupid Love' to 'Crazy, Stupid, Love.' (2011) using year hint: 2011
```

## Performance Impact

- **Minimal overhead**: Year extraction uses simple regex patterns (< 1ms)
- **Conditional person validation**: Only fetches credits when multiple candidates exist
- **Batch optimization**: Limits credit fetching to top 5 candidates
- **No breaking changes**: All new parameters are optional with backward compatibility

## Edge Cases Handled

1. **Year in title takes precedence** over description (e.g., "The Matrix (1999)")
2. **No year available**: Falls back to existing title-based matching
3. **Multiple candidates with same year**: Person name validation helps disambiguate
4. **Credits unavailable**: Gracefully degrades to year + title matching
5. **False name extraction**: Filters out common false positives (names containing "The", >30 chars)

## Future Improvements

Potential enhancements (not implemented):

1. Extract full cast list using comma-separated parsing
2. Add genre hints from description ("action thriller", "romantic comedy")
3. Parse plot summaries for additional validation
4. Cache person name → movie associations for faster lookup
5. Support international release years (e.g., "UK release: 2012")

## Migration Notes

- **No database migration required**
- **No API changes** (all new parameters are optional)
- **Backward compatible** with existing podcast intake code
- **Safe to deploy** without data cleanup

## Related Files

- `WatchedIt/PodcastEpisodeIntakeService.swift` - Year/person extraction logic
- `WatchedIt/MovieDataService.swift` - Enhanced TMDB matching
- `test_podcast_year_parsing.swift` - Test suite
- `.cursorrules` - Project guidelines (see "Bootstrap Database" section)
