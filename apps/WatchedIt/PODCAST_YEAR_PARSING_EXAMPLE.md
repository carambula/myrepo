# Podcast Year Parsing - Real Example

## The Problem: Crazy Stupid Love Episode

### Actual Rewatchables Episode Data

**Episode Title:**
```
"Crazy Stupid Love" With Steve Carell and Ryan Gosling
```

**Episode Description:**
```
Sean, Amanda, and Chris discuss the 2011 film Crazy Stupid Love, 
starring Steve Carell, Ryan Gosling, Julianne Moore, and Emma Stone.
The romantic comedy follows a middle-aged man learning to date again 
with help from a smooth-talking bachelor.
```

**Episode Date:** February 15, 2024

### TMDB Search Results for "Crazy Stupid Love"

When searching TMDB, multiple results are returned:

| TMDB ID | Title | Year | Country | Cast |
|---------|-------|------|---------|------|
| 50544 | Crazy, Stupid, Love. | 2011 | USA | Steve Carell, Ryan Gosling, Emma Stone, Julianne Moore |
| 987654 | Crazy Stupid Love | 2022 | India | Arvind Swamy, Simran, Amala Paul |

## Before: Wrong Match ❌

### What Happened

1. **Title Parsing:**
   ```
   Raw: "Crazy Stupid Love" With Steve Carell and Ryan Gosling
   Cleaned: "Crazy Stupid Love"
   Year extracted: None (no parentheses in title)
   ```

2. **TMDB Search:**
   ```
   Query: "Crazy Stupid Love"
   Year filter: None
   Results: [2011 USA film, 2022 India film]
   ```

3. **Matching Logic (OLD):**
   ```
   Candidate 1: "Crazy, Stupid, Love." (2011)
     Score: 50 (exact title match) + 10 (has poster) = 60
   
   Candidate 2: "Crazy Stupid Love" (2022)
     Score: 50 (exact title match) + 10 (has poster) = 60
   ```

4. **Result:** 
   - Both candidates tied with score 60
   - TMDB returns results ordered by popularity
   - 2022 film happened to be first → **WRONG MOVIE ADDED** ❌

### User Impact

User sees the 2022 Indian film in their collection instead of the 2011 American film that was actually discussed on the podcast.

## After: Correct Match ✅

### What Happens Now

1. **Title Parsing:**
   ```
   Raw: "Crazy Stupid Love" With Steve Carell and Ryan Gosling
   Cleaned: "Crazy Stupid Love"
   Year from title: None
   ```

2. **Description Parsing (NEW):**
   ```
   Description: "...discuss the 2011 film Crazy Stupid Love, starring Steve Carell..."
   
   Year extraction:
     Pattern: "(?:the\s+)?((?:19|20)\d{2})\s+film"
     Match: "the 2011 film"
     Extracted year: 2011 ✅
   
   Person extraction:
     Pattern: "(?:starring|stars?)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)"
     Match: "starring Steve Carell"
     Extracted names: ["Steve Carell", "Emma Stone"] ✅
   ```

3. **TMDB Search:**
   ```
   Query: "Crazy Stupid Love"
   Year filter: 2011
   Results: [2011 USA film, 2022 India film]
   Expected persons: ["Steve Carell", "Emma Stone"]
   ```

4. **Matching Logic (NEW):**
   ```
   Candidate 1: "Crazy, Stupid, Love." (2011)
     Year: 2011 → +100 (exact match)
     Title: Similar → +50
     Poster: Yes → +10
     Cast validation:
       Fetching credits... ✅
       Steve Carell found in cast → +75
       Emma Stone found in cast → +75
     TOTAL SCORE: 310 ✅
   
   Candidate 2: "Crazy Stupid Love" (2022)
     Year: 2022 → -50 (11 years off)
     Title: Similar → +50
     Poster: Yes → +10
     Cast validation:
       Fetching credits... ✅
       Steve Carell NOT in cast → +0
       Emma Stone NOT in cast → +0
     TOTAL SCORE: 10
   ```

5. **Result:**
   - Best match: "Crazy, Stupid, Love." (2011) with score 310
   - **CORRECT MOVIE ADDED** ✅

### Logs

```
📅 Extracted year 2011 from description using pattern: (?:the\s+)?((?:19|20)\d{2})\s+film
🎬 TMDB: Validating matches using expected person names: Steve Carell, Emma Stone
🌐 TMDB API CALL: GET https://api.themoviedb.org/3/movie/50544?api_key=***
   ✅ Person match found: 'Steve Carell' in 'Crazy, Stupid, Love.' (2011)
   ✅ Person match found: 'Emma Stone' in 'Crazy, Stupid, Love.' (2011)
🎯 TMDB: Selected best match 'Crazy, Stupid, Love.' (ID: 50544, Year: 2011, Score: 310.0)
✅ Matched 'Crazy Stupid Love' to 'Crazy, Stupid, Love.' (2011) using year hint: 2011
```

## Scoring Breakdown

### Scoring System

| Factor | Points | Description |
|--------|--------|-------------|
| Exact year match | +100 | Most important for disambiguation |
| Person name match | +75 each | Strong validation signal |
| Year within 1 year | +50 | Handles re-releases, region differences |
| Exact title match | +50 | Good baseline |
| Partial title match | +30 | Handles punctuation differences |
| Has poster | +10 | Indicates main release |
| Year 2-5 years off | +25 to 0 | Decreasing penalty |
| Year >5 years off | -50 | Strong penalty |

### Example Calculations

**2011 Film (Correct):**
```
+100  Exact year (2011 == 2011)
 +75  Steve Carell in cast
 +75  Emma Stone in cast
 +50  Title similarity
 +10  Has poster
----
+310  TOTAL (WINNER)
```

**2022 Film (Wrong):**
```
 -50  Wrong year (|2022 - 2011| = 11)
  +0  Steve Carell NOT in cast
  +0  Emma Stone NOT in cast
 +50  Title similarity
 +10  Has poster
----
 +10  TOTAL
```

## Other Examples

### Example 2: The Matrix (No Ambiguity)

**Episode:** "The Matrix (1999) with Keanu Reeves"

**TMDB Results:**
- The Matrix (1999) - Score: 160 (year + title)
- No other candidates

**Result:** Correct match (only one candidate)

### Example 3: Ocean's Eleven (Multiple Versions)

**Episode:** "Ocean's Eleven starring George Clooney"

**Description:** "The 2001 heist film directed by Steven Soderbergh..."

**TMDB Results:**
1. Ocean's Eleven (1960) - Rat Pack version
2. Ocean's Eleven (2001) - George Clooney version

**Scoring:**
- 1960 version: -50 (wrong year) + 0 (no person match) = -50
- 2001 version: +100 (year) + 75 (Clooney) + 75 (Soderbergh) = 250 ✅

**Result:** Correct match (2001 version)

## Edge Cases Handled

### No Year in Description
Falls back to title-based matching (original behavior)

### Multiple Films Same Title and Year
Person name validation disambiguates (e.g., different language versions)

### Credits Unavailable
Gracefully degrades to year + title matching

### Year in Title Takes Precedence
Episode titled "Crazy Stupid Love (2011)" would use title year, even if description says different year
