# Person Search Feature

## Overview

When viewing a movie's details, you can now tap on any actor or director to instantly search for other movies featuring that person.

## User Flow

1. **Open Movie Details**: Tap any movie to view its details
2. **Tap a Person**: 
   - Tap the director's name, OR
   - Tap any cast member card (shows actor photo and character name)
3. **Inline Search Opens**: 
   - The movie details sheet dismisses
   - The search bar appears at the bottom with the person's name pre-filled
   - The keyboard **does not open** automatically (as requested)
   - Results are filtered to show only movies featuring that person

## Implementation Details

### Files Modified
- `WatchedIt/MovieListView.swift`

### Key Changes

1. **Tap Handler in MovieDetailView** (already existed):
   - Director: Line 969 wraps director name in a Button
   - Cast: Lines 991-997 wrap each CastMemberCard in a Button
   - Both call `handleCreditPersonTap()` which invokes `onCreditPersonTapped?()` callback

2. **Callback Flow**:
   ```swift
   // When person is tapped in movie details:
   startPersonSearchFromDetails(personName) {
       pendingPersonSearchQuery = personName
       selectedMovie = nil  // Dismiss the detail sheet
   }
   
   // On sheet dismiss:
   applyPendingPersonSearchFromDetails() {
       skipNextSearchAutofocus = true      // Prevent keyboard
       activePersonSearchQuery = personName
       searchText = personName
       showSearch = true                   // Show inline search
       isSearchFieldFocused = false        // Ensure keyboard stays closed
   }
   ```

3. **Person Search Filter**:
   - Uses specialized `movieMatchesPersonSearch()` function
   - Searches in:
     - Director field (case-insensitive contains)
     - All cast members (case-insensitive contains)
   - More precise than general text search

4. **Keyboard Prevention**:
   - `skipNextSearchAutofocus = true`: Tells the onChange handler not to focus
   - `isSearchFieldFocused = false`: Directly prevents focus
   - The `onChange(of: showSearch)` handler respects this flag

## Why Inline Search Instead of Full-Screen?

The previous implementation used `activeSearchContext` to show a full-screen search view. This was changed to use the inline search bar (`showSearch = true`) because:

1. Better matches the user's screenshot showing the inline search bar
2. Faster and more lightweight - no modal transition
3. Maintains context - user stays on the main movie list
4. More natural flow - search appears from bottom, just like clicking the search button

## Testing Checklist

- [ ] Build and run the app
- [ ] Open any movie with a director
- [ ] Tap the director's name
- [ ] Verify:
  - [ ] Movie details sheet dismisses
  - [ ] Search bar appears at bottom
  - [ ] Person's name is pre-filled in search
  - [ ] Keyboard does NOT open
  - [ ] Results show movies featuring that person
- [ ] Clear search and open another movie
- [ ] Tap any cast member card
- [ ] Verify same behavior as above

## Technical Notes

### State Variables
- `pendingPersonSearchQuery`: Temporary storage for the person name during sheet dismissal
- `activePersonSearchQuery`: Active person search filter (triggers special search logic)
- `showSearch`: Controls visibility of inline search bar
- `skipNextSearchAutofocus`: Prevents keyboard on next search open
- `isSearchFieldFocused`: Actual focus state of search field

### Search Clearing
When the user manually clears the search or types a different query:
- Line 3683-3685: If search text differs from `activePersonSearchQuery`, clear the person search
- This allows switching from person search to general search seamlessly
