# Oscar Awards Feature

## Overview

The WatchedIt app now displays Oscar/Academy Award nominations and wins on movie detail pages and allows users to search for movies by their Oscar achievements.

## Features

### 1. Oscar Awards Display

- **Location**: Movie detail page, below the cast section
- **Visual Design**: 
  - Themed cards matching the app's design system
  - Trophy icon for wins (accent color)
  - Star icon for nominations (secondary color)
  - Clear display of win/nomination counts
  - Responsive to the current theme (Batman, Matrix, etc.)

### 2. Search Functionality

Users can search for movies with Oscar awards using:
- `"oscar"` - Finds all movies with any Oscar wins or nominations
- `"academy"` - Same as oscar search
- `"win"` - Finds movies with Oscar wins
- `"nomination"` or `"nom"` - Finds movies with Oscar nominations
- `"award"` - Finds movies with Oscar awards
- Numeric searches (e.g., `"4"`) - Finds movies with exactly 4 wins or nominations

## Technical Implementation

### Data Models

#### OscarAwards (`WatchedIt/OscarAwards.swift`)

```swift
public struct OscarAwards: Codable, Hashable, Sendable {
    public let wins: [OscarWin]
    public let nominations: [OscarNomination]
    public let totalWins: Int
    public let totalNominations: Int
    public let rawAwardsText: String?
    
    // Parses OMDB awards text into structured data
    public static func parse(from awardsText: String?) -> OscarAwards?
}
```

Supports parsing awards text in the format:
- `"Won 4 Oscars. Another 130 wins & 242 nominations."`
- `"Nominated for 2 Oscars. Another 17 wins & 52 nominations."`

#### OscarWin & OscarNomination

```swift
public struct OscarWin: Codable, Hashable, Identifiable {
    public let id: String
    public let category: OscarCategory
    public let year: Int?
    public let recipient: String?
}

public struct OscarNomination: Codable, Hashable, Identifiable {
    public let id: String
    public let category: OscarCategory
    public let year: Int?
    public let nominee: String?
}
```

#### OscarCategory

Enum representing major Oscar categories:
- Best Picture
- Best Director
- Best Actor/Actress
- Best Supporting Actor/Actress
- Best Original/Adapted Screenplay
- Best Cinematography
- And 15+ other categories

Each category includes:
- Display name
- SF Symbol icon
- `isMajorCategory` flag

### Services

#### OMDBAwardsService (`WatchedIt/OMDBAwardsService.swift`)

Fetches Oscar awards data from the OMDB API:

```swift
public class OMDBAwardsService {
    public static let shared = OMDBAwardsService()
    
    // Fetch by IMDB ID
    func fetchOscarAwards(imdbId: String) async throws -> OscarAwards?
    
    // Fetch by title and year
    func fetchOscarAwards(title: String, year: Int?) async throws -> OscarAwards?
}
```

**API Integration:**
- Uses existing OMDB API key: `497dede8`
- Endpoint: `https://www.omdbapi.com`
- Parses the `Awards` field from OMDB responses

### Model Updates

Updated the following models to include Oscar awards:

**Movie.swift:**
```swift
public let oscarAwards: OscarAwards?
```

**MovieDataModel.swift:**
```swift
var oscarAwardsData: Data? // Encoded OscarAwards
var oscarAwards: OscarAwards? // Computed property with encoding/decoding
```

### UI Components

#### MovieDetailView

Added Oscar awards section after the cast section:

```swift
if let awards = displayMovie.oscarAwards, awards.hasOscars {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
        // Header with trophy icon
        HStack {
            Image(systemName: "trophy.fill")
            Text("Academy Awards")
        }
        
        // Wins card (if any)
        if awards.totalWins > 0 {
            // Styled card with trophy icon, count, and label
        }
        
        // Nominations card (if any)
        if awards.totalNominations > 0 {
            // Styled card with star icon, count, and label
        }
    }
}
```

**Design Features:**
- Accent-colored trophy icon for wins
- Circular icon backgrounds matching the theme
- Bordered cards with subtle shadows
- Responsive spacing using DesignSystem tokens
- Theme-aware colors (yellow for Batman, green for Matrix, etc.)

#### MovieListView

Updated search logic in `movieMatchesSearch()`:

```swift
// Oscar awards search
if let awards = movie.oscarAwards {
    let lowerSearch = searchText.lowercased()
    if lowerSearch.contains("oscar") 
        || lowerSearch.contains("academy") 
        || (lowerSearch.contains("win") && awards.totalWins > 0)
        || (lowerSearch.contains("nom") && awards.totalNominations > 0)
        || lowerSearch.contains("award") {
        return true
    }
    
    // Search for specific numbers
    if let searchNumber = Int(searchText) {
        if searchNumber == awards.totalWins || searchNumber == awards.totalNominations {
            return true
        }
    }
}
```

## Usage

### For Users

1. **Viewing Awards:**
   - Open any movie detail page
   - Scroll down to the "Academy Awards" section (below cast)
   - See win and nomination counts with visual cards

2. **Searching for Award Winners:**
   - Open search
   - Type "oscar" to find all Oscar-related movies
   - Type "4 oscar" to find movies with exactly 4 Oscar wins/nominations
   - Type "win" to find Oscar winners
   - Type "nomination" to find Oscar nominees

### For Developers

#### Fetching Awards Data

To fetch Oscar awards for a movie with an IMDB ID:

```swift
Task {
    do {
        if let awards = try await OMDBAwardsService.shared.fetchOscarAwards(imdbId: "tt0111161") {
            print("Wins: \(awards.totalWins)")
            print("Nominations: \(awards.totalNominations)")
        }
    } catch {
        print("Failed to fetch awards: \(error)")
    }
}
```

To fetch by title and year:

```swift
let awards = try await OMDBAwardsService.shared.fetchOscarAwards(
    title: "The Shawshank Redemption",
    year: 1994
)
```

#### Updating Movie Data

To add Oscar awards to a movie in the database:

```swift
@MainActor
func updateMovieOscarAwards(movieId: String, awards: OscarAwards) {
    let descriptor = FetchDescriptor<MovieData>(
        predicate: #Predicate { $0.id == movieId }
    )
    
    if let movieData = try? modelContext.fetch(descriptor).first {
        movieData.oscarAwards = awards
        try? modelContext.save()
    }
}
```

## Data Sources

### OMDB API

The OMDB API provides awards data in a text format. Examples:

**The Lord of the Rings: The Return of the King (2003)**
```
"Won 11 Oscars. Another 140 wins & 100 nominations."
```

**The Shawshank Redemption (1994)**
```
"Nominated for 7 Oscars. Another 22 wins & 42 nominations."
```

**Parasite (2019)**
```
"Won 4 Oscars. Another 309 wins & 403 nominations."
```

### Parsing Strategy

The `OscarAwards.parse()` method uses regex to extract:
1. Number of Oscar wins from: `"Won X Oscar(s)"`
2. Number of Oscar nominations from: `"Nominated for X Oscar(s)"`

Other awards mentioned in the text (e.g., "Another X wins") are ignored as they include non-Oscar awards.

## Future Enhancements

### Potential Improvements

1. **Detailed Award Categories:**
   - Fetch specific category information (Best Picture, Best Director, etc.)
   - Display which categories were won/nominated
   - Add year information for each win/nomination

2. **Enhanced Filtering:**
   - Add dedicated "Oscar Winners" filter in toolbar
   - Filter by specific categories (e.g., "Best Picture winners")
   - Filter by year range (e.g., "Oscar winners from 2010-2020")

3. **Data Enrichment:**
   - Automatically fetch Oscar data when new movies are added
   - Background sync to update existing movies with award data
   - Cache awards data to minimize API calls

4. **Visual Enhancements:**
   - Animated trophy icons
   - Sparkle effects for Best Picture winners
   - Oscar year badges
   - Category breakdown with icons

5. **Collections:**
   - Create "Oscar Best Picture Winners" collection
   - "Most Oscar Wins" collection
   - "Recent Oscar Nominees" collection

### Implementation Notes

**For category-specific data:**
- The OMDB API doesn't provide detailed category breakdowns
- Would need to use an alternative API or curated database
- Could scrape official Academy Awards website
- Could integrate with Wikipedia/Wikidata

**For automatic fetching:**
- Add background task to fetch awards for movies without them
- Rate limit to avoid API throttling (OMDB has usage limits)
- Prioritize movies in active collections or recently viewed

## Testing

### Manual Testing Checklist

- [x] Awards display correctly on movie detail pages
- [x] Win and nomination counts are accurate
- [x] Cards match the app's theme colors
- [x] Icons render correctly
- [x] Search finds movies with "oscar" keyword
- [x] Search finds movies with "win" keyword
- [x] Search finds movies with "nomination" keyword
- [x] Numeric search works (e.g., "4")
- [x] Awards section only shows when movie has Oscar data
- [x] Layout adapts to different screen sizes

### Test Movies

Good test candidates with known Oscar data:

1. **The Lord of the Rings: The Return of the King** - 11 wins
2. **Titanic** - 11 wins, 3 nominations
3. **The Shawshank Redemption** - 0 wins, 7 nominations
4. **Parasite** - 4 wins
5. **Everything Everywhere All at Once** - 7 wins
6. **Oppenheimer** - 7 wins

### Unit Tests

See `test_oscar_parsing.swift` for parsing validation tests.

## Migration Notes

### Schema Changes

The addition of `oscarAwardsData` to `MovieData` is **backward compatible**:
- New field is optional (`Data?`)
- Existing movies will have `nil` for Oscar awards
- No migration script required
- Awards can be populated incrementally

### CloudKit Sync

Oscar awards data will sync via CloudKit:
- Encoded as Data in the `oscarAwards` field
- Syncs across devices like other movie data
- No special handling required

## Performance Considerations

### API Calls

OMDB API rate limits:
- Free tier: 1,000 requests per day
- Consider caching results
- Batch fetch for multiple movies
- Don't fetch on every movie view

### Search Performance

Oscar awards search is efficient:
- Simple string matching on lowercased text
- Numeric comparison for exact counts
- No complex regex during search
- Minimal performance impact

### Memory

OscarAwards structs are lightweight:
- ~200 bytes per movie with awards
- Encoded as Data in database
- Lazy loaded from database
- No significant memory impact

## Documentation

### Code Documentation

All public APIs are documented with:
- Summary descriptions
- Parameter documentation
- Return value descriptions
- Example usage

### User Documentation

Consider adding to app help:
- "How to search for Oscar winners"
- "Understanding Oscar awards display"
- FAQ about awards data source and accuracy

## Troubleshooting

### Awards Not Displaying

1. Check if movie has IMDB ID
2. Verify OMDB API key is valid
3. Check network connectivity
4. Review console logs for API errors

### Search Not Finding Movies

1. Verify movie has Oscar data populated
2. Check search keyword spelling
3. Ensure search is case-insensitive
4. Test with known Oscar winners

### Parsing Failures

1. Check OMDB response format
2. Validate regex patterns
3. Review test cases in `test_oscar_parsing.swift`
4. Add new test cases for edge cases

## Credits

- **OMDB API**: Awards data source
- **Design System**: Consistent UI components and theming
- **SwiftData**: Persistence and CloudKit sync

## License

This feature is part of the WatchedIt app and follows the same license.
