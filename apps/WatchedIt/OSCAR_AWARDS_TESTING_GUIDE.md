# Oscar Awards Testing Guide

## Quick Start

This guide will help you test the Oscar awards feature in the WatchedIt app.

## Prerequisites

- WatchedIt app installed and running
- Movies in the database (from bootstrap or manually added)
- Network connectivity (for fetching awards from OMDB)

## Testing Checklist

### Phase 1: Display Testing

#### Test 1: Awards Display on Movie Detail Page

**Steps:**
1. Open the WatchedIt app
2. Navigate to a movie that you know has Oscar wins (e.g., "The Lord of the Rings: The Return of the King")
3. Scroll down past the cast section
4. Look for the "Academy Awards" section

**Expected Results:**
- ✅ Section header shows "Academy Awards" with trophy icon
- ✅ Trophy icon is in the accent color (yellow for Batman theme)
- ✅ Win count card displays with gold/yellow styling
- ✅ Nomination count card displays (if applicable)
- ✅ Numbers are accurate
- ✅ Cards have rounded corners and subtle borders

**Test Movies:**
- **Titanic** - Should show 11 wins
- **The Shawshank Redemption** - Should show 7 nominations, 0 wins
- **Parasite** - Should show 4 wins
- **Everything Everywhere All at Once** - Should show 7 wins

#### Test 2: Movies Without Awards

**Steps:**
1. Navigate to a movie without Oscar awards (e.g., recent action movie)
2. Scroll through the entire detail page

**Expected Results:**
- ✅ No "Academy Awards" section is displayed
- ✅ No empty cards or placeholders
- ✅ Page layout flows normally from cast to sources/streaming

#### Test 3: Theme Integration

**Steps:**
1. Open a movie detail page with Oscar awards
2. Go to Account → Themes
3. Switch to "I'm Batman" theme
4. Return to movie details

**Expected Results:**
- ✅ Trophy icon and win card accent color is yellow (Batman theme)
- ✅ Cards adapt to the dark navy background
- ✅ Text remains readable

**Repeat with other themes:**
- Matrix theme: Green accents
- Default theme: Blue accents

### Phase 2: Search Testing

#### Test 4: General Oscar Search

**Steps:**
1. Open search
2. Type "oscar"
3. Review results

**Expected Results:**
- ✅ All movies with Oscar wins or nominations appear
- ✅ Movies without Oscar data don't appear
- ✅ Results update in real-time as you type

#### Test 5: Specific Keyword Searches

Test each keyword individually:

| Keyword | Expected Results |
|---------|------------------|
| `"academy"` | All Oscar-related movies |
| `"win"` | Only movies with Oscar wins |
| `"nomination"` | Only movies with Oscar nominations |
| `"nom"` | Same as "nomination" |
| `"award"` | All Oscar-related movies |

**Steps:**
1. Clear search
2. Type keyword
3. Verify results match expected filter

**Expected Results:**
- ✅ Search is case-insensitive
- ✅ Partial matches work ("nomin" finds "nomination")
- ✅ Real-time filtering

#### Test 6: Numeric Search

**Steps:**
1. Clear search
2. Type "11"
3. Review results

**Expected Results:**
- ✅ Movies with exactly 11 wins appear (e.g., Titanic, LOTR: Return of the King)
- ✅ Movies with exactly 11 nominations appear
- ✅ Other movies (with year 2011, etc.) may also appear

**Test Numbers:**
- `"1"` - Movies with 1 win or 1 nomination
- `"4"` - Movies with 4 wins (Parasite, etc.)
- `"7"` - Movies with 7 wins or nominations

#### Test 7: Combined Search

**Steps:**
1. Open search
2. Type "oscar win 4"
3. Review results

**Expected Results:**
- ✅ Movies with 4 Oscar wins appear (Parasite, etc.)
- ✅ Search finds movies matching any of the keywords

### Phase 3: Data Fetching Testing

#### Test 8: Fetch Awards via OMDB (Manual Testing)

**Note:** This requires running Swift code or using the app's data update mechanism.

**Test Code:**
```swift
import Foundation

Task {
    let service = OMDBAwardsService.shared
    
    // Test 1: Fetch by IMDB ID
    if let awards = try? await service.fetchOscarAwards(imdbId: "tt0111161") {
        print("✅ The Shawshank Redemption:")
        print("   Wins: \(awards.totalWins)")
        print("   Nominations: \(awards.totalNominations)")
    }
    
    // Test 2: Fetch by title and year
    if let awards = try? await service.fetchOscarAwards(title: "Titanic", year: 1997) {
        print("✅ Titanic:")
        print("   Wins: \(awards.totalWins)")
        print("   Nominations: \(awards.totalNominations)")
    }
}
```

**Expected Console Output:**
```
🏆 OMDB API CALL: Fetching awards for IMDB ID tt0111161
✅ OMDB: Parsed Oscar awards - 0 wins, 7 nominations
✅ The Shawshank Redemption:
   Wins: 0
   Nominations: 7

🏆 OMDB API CALL: Fetching awards for 'Titanic' (1997)
✅ OMDB: Parsed Oscar awards - 11 wins, 0 nominations
✅ Titanic:
   Wins: 11
   Nominations: 0
```

#### Test 9: Parsing Edge Cases

Run the parsing test script:

```bash
cd /workspace
swift test_oscar_parsing.swift
```

**Expected Output:**
```
🧪 Testing Oscar Awards Parsing

Test 1: "Won 4 Oscars. Another 130 wins & 242 nominations."
  ✅ Parsed successfully:
     - Total Wins: 4
     - Total Nominations: 0
     - Has Oscars: true

Test 2: "Nominated for 2 Oscars. Another 17 wins & 52 nominations."
  ✅ Parsed successfully:
     - Total Wins: 0
     - Total Nominations: 2
     - Has Oscars: true
...
```

### Phase 4: UI/UX Testing

#### Test 10: Responsive Layout

**Steps:**
1. Open movie detail with Oscar awards
2. Rotate device (if on iPad/iPhone)
3. Use split-screen mode (if on iPad)

**Expected Results:**
- ✅ Awards cards adapt to available width
- ✅ Text remains readable
- ✅ No overlapping elements
- ✅ Spacing is consistent

#### Test 11: Accessibility

**Steps:**
1. Enable VoiceOver (Settings → Accessibility → VoiceOver)
2. Navigate to movie detail with Oscar awards
3. Focus on the Academy Awards section

**Expected Results:**
- ✅ Trophy icon has appropriate label
- ✅ Win count is announced correctly
- ✅ Nomination count is announced correctly
- ✅ Section header is clear

#### Test 12: Dark Mode

**Steps:**
1. Enable Dark Mode (Settings → Display & Brightness → Dark)
2. Open movie detail with Oscar awards

**Expected Results:**
- ✅ Cards have appropriate dark background
- ✅ Text is readable
- ✅ Borders are visible but subtle
- ✅ Icon colors remain vibrant

### Phase 5: Performance Testing

#### Test 13: Search Performance

**Steps:**
1. Ensure database has 1000+ movies
2. Open search
3. Type "oscar" quickly
4. Observe response time

**Expected Results:**
- ✅ Results appear within 300ms
- ✅ No lag or stuttering
- ✅ Keyboard remains responsive
- ✅ Smooth scrolling in results

#### Test 14: Memory Usage

**Steps:**
1. Open Instruments (Xcode → Product → Profile → Allocations)
2. Navigate through 10-20 movies with Oscar awards
3. Monitor memory usage

**Expected Results:**
- ✅ No significant memory growth
- ✅ No memory leaks
- ✅ Stable memory footprint

## Known Issues & Edge Cases

### Edge Case 1: Mixed Wins and Nominations

**Example:** "Won 3 Oscars and nominated for 5 more. Another 50 wins & 100 nominations."

**Current Behavior:** Only parses wins (3) and ignores "nominated for 5 more"
**Reason:** OMDB typically uses "Nominated for X Oscars" for films that didn't win
**Impact:** Low - most OMDB responses use consistent format

### Edge Case 2: Historic Award Names

**Example:** "Won 1 Academy Award of Merit."

**Current Behavior:** May not parse correctly
**Reason:** Regex expects "Oscar" or "Oscars"
**Impact:** Low - rare in OMDB data

### Edge Case 3: API Rate Limiting

**Scenario:** Fetching awards for many movies quickly

**Expected Behavior:** 
- First 1000 requests succeed
- Subsequent requests fail with 429 error
- Error is logged but doesn't crash app

**Mitigation:**
- Cache results
- Fetch incrementally
- Respect rate limits

## Regression Testing

After making changes to the Oscar awards feature, re-run:

1. All display tests (Tests 1-3)
2. All search tests (Tests 4-7)
3. Parsing test script
4. Performance tests if code changes affect filtering

## Bug Reporting

When reporting bugs, include:

1. **Description:** What went wrong?
2. **Expected:** What should have happened?
3. **Actual:** What actually happened?
4. **Steps to Reproduce:**
5. **Movie Details:** Title, year, IMDB ID
6. **Screenshots:** If visual issue
7. **Console Logs:** Error messages
8. **Device:** iPhone/iPad model, iOS version
9. **App Version:** WatchedIt version/build

## Sample Test Data

### Movies with Known Oscar Counts

| Title | Year | IMDB ID | Wins | Nominations |
|-------|------|---------|------|-------------|
| The Lord of the Rings: The Return of the King | 2003 | tt0167260 | 11 | 0 |
| Titanic | 1997 | tt0120338 | 11 | 3 |
| West Side Story | 1961 | tt0055614 | 10 | 1 |
| Ben-Hur | 1959 | tt0052618 | 11 | 1 |
| The Shawshank Redemption | 1994 | tt0111161 | 0 | 7 |
| Parasite | 2019 | tt6751668 | 4 | 2 |
| Everything Everywhere All at Once | 2022 | tt6710474 | 7 | 4 |
| Oppenheimer | 2023 | tt15398776 | 7 | 6 |

### OMDB Awards Text Samples

```
# Titanic
"Won 11 Oscars. Another 103 wins & 89 nominations."

# The Shawshank Redemption
"Nominated for 7 Oscars. Another 22 wins & 42 nominations."

# Parasite
"Won 4 Oscars. Another 309 wins & 403 nominations."

# The Godfather
"Won 3 Oscars. Another 32 wins & 31 nominations."
```

## Automated Testing

### Unit Tests

Create unit tests for:

```swift
// OscarAwards parsing
func testOscarAwardsParsing() {
    let text = "Won 4 Oscars. Another 130 wins & 242 nominations."
    let awards = OscarAwards.parse(from: text)
    XCTAssertEqual(awards?.totalWins, 4)
    XCTAssertEqual(awards?.totalNominations, 0)
}

// Search functionality
func testOscarSearch() {
    let movie = Movie(title: "Test", oscarAwards: OscarAwards(totalWins: 4, totalNominations: 0))
    XCTAssertTrue(movieMatchesSearch(movie, searchText: "oscar"))
    XCTAssertTrue(movieMatchesSearch(movie, searchText: "4"))
    XCTAssertTrue(movieMatchesSearch(movie, searchText: "win"))
}
```

### Integration Tests

Test OMDB API integration:

```swift
func testOMDBAwardsService() async throws {
    let service = OMDBAwardsService.shared
    let awards = try await service.fetchOscarAwards(imdbId: "tt0111161")
    XCTAssertNotNil(awards)
    XCTAssertGreaterThan(awards!.totalNominations, 0)
}
```

### UI Tests

Test UI elements:

```swift
func testOscarAwardsDisplay() {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to movie with Oscar awards
    app.tables.cells.containing(.staticText, identifier: "Titanic").tap()
    
    // Verify Academy Awards section exists
    XCTAssertTrue(app.staticTexts["Academy Awards"].exists)
    XCTAssertTrue(app.images["trophy.fill"].exists)
}
```

## Success Criteria

The Oscar awards feature is working correctly when:

- ✅ All display tests pass
- ✅ All search tests pass
- ✅ Parsing test script completes successfully
- ✅ No console errors related to awards
- ✅ UI matches design specifications
- ✅ Theme integration works correctly
- ✅ Search performance is acceptable (<300ms)
- ✅ No memory leaks
- ✅ Accessible to VoiceOver users
- ✅ Works in light and dark mode

## Next Steps

After successful testing:

1. Submit pull request with test results
2. Request code review
3. Create user documentation
4. Consider adding automated tests to CI/CD
5. Plan data population strategy for existing movies

## Resources

- [OSCAR_AWARDS_FEATURE.md](/workspace/OSCAR_AWARDS_FEATURE.md) - Full feature documentation
- [test_oscar_parsing.swift](/workspace/test_oscar_parsing.swift) - Parsing validation script
- [OMDB API Documentation](http://www.omdbapi.com/) - Awards data source
