# Collection Filter Header in Search Results

## Summary

Added a prominent filter header at the top of search results when searching from a collection, making it clear which collection is being searched.

## The Problem

When users tapped on a collection header (e.g., "Latest Podcast Episodes", "Top Rated on Netflix") to open a filtered search, the search results appeared with no indication of what collection was being searched. Users could be confused about why they were seeing certain results or forget what filter was active.

## The Solution

### Visual Filter Badge

When opening search from a collection, a filter badge now appears at the top of the search results showing:

- **Collection icon**: Stack icon (`rectangle.stack.fill`) in accent color
- **Collection title**: The name of the collection being searched
- **Dismiss button**: X button to close the search and return to home
- **Styled badge**: 
  - Tinted background (accent color at 12% opacity)
  - Accent border (accent color at 25% opacity)
  - Rounded corners (medium radius)
  - Proper padding and spacing

### Positioning

The filter badge is positioned:
- Below the drag handle (capsule indicator)
- Above any active search tokens (filters)
- Full width with proper horizontal padding
- Automatically adjusts spacing when search tokens are present

### Theme Integration

The badge adapts to the active theme:
- **Batman theme**: Yellow accent → yellow icon and yellow-tinted badge
- **Matrix theme**: Green accent → green icon and green-tinted badge
- All other themes use their respective accent colors

## Technical Implementation

### Files Modified

**`WatchedIt/Views/Search/SearchScreenView.swift`**

1. **Pass context to SearchResultsContent**:
   - Added `context: SearchPresentationContext` parameter
   - Added `onDismiss: () -> Void` callback for dismissing search

2. **Added collection filter detection**:
   ```swift
   private var isScopedToCollection: Bool {
       context.restrictedMovieIDs != nil && context.title != "All Movies"
   }
   ```

3. **Added filter header view**:
   - `collectionFilterHeader` - displays the collection badge
   - Shows collection icon, title, and dismiss button
   - Styled with accent color and proper spacing

4. **Updated topSearchHeader**:
   - Shows collection filter badge when scoped
   - Adjusts spacing for search tokens when badge is present
   - Only shows empty space when no collection filter AND no tokens

### How It Works

1. **Collection header tapped** → `presentScopedSearch(title:section:)` called
2. **SearchPresentationContext created** with:
   - `title`: Collection name (e.g., "Latest Podcast Episodes")
   - `restrictedMovieIDs`: Set of movie IDs in that collection
3. **SearchScreenView presented** with context
4. **SearchResultsContent receives context** and renders filter badge
5. **Badge shows collection name** with dismiss button
6. **User can dismiss** by tapping X button → closes search modal

### Behavior

- **Collection searches**: Show filter badge with collection name
- **Global searches**: No filter badge (title is "All Movies")
- **Search tokens**: Show below collection badge when present
- **Empty state**: Proper spacing maintained with or without badge

## User Experience

### Before
```
┌─────────────────────────────┐
│         [drag handle]        │
│                              │
│  [search tokens if any]      │
│                              │
│  🎬 Movie Title              │
│  🎬 Movie Title              │
│  🎬 Movie Title              │
└─────────────────────────────┘
```
*No indication of collection filter*

### After
```
┌─────────────────────────────┐
│         [drag handle]        │
│                              │
│  ┌───────────────────────┐  │
│  │ 📚 Latest Episodes  ✕ │  │  ← Collection badge
│  └───────────────────────┘  │
│                              │
│  [search tokens if any]      │
│                              │
│  🎬 Movie Title              │
│  🎬 Movie Title              │
│  🎬 Movie Title              │
└─────────────────────────────┘
```
*Clear indication of collection filter with dismiss option*

## Examples of Collection Titles

Based on actual collection sections in the app:

- "Latest Podcast Episodes"
- "Movies You Haven't Seen"
- "Movies to Rewatch"
- "Top Rated on Netflix"
- "Recently Added"
- "Criterion Collection"
- And any other collection section

## Testing

To test this feature:

1. **Navigate to Collections Home**
2. **Tap on any collection header** (e.g., "Latest Podcast Episodes")
3. **Verify**:
   - Filter badge appears at top
   - Shows correct collection name
   - Badge uses accent color from current theme
   - X button dismisses the search
   - Search tokens appear below badge (if any filters applied)
   - Spacing is correct with/without search tokens

4. **Test with different themes**:
   - Batman theme → Yellow badge
   - Matrix theme → Green badge
   - Other themes → Their accent colors

5. **Test dismissal**:
   - Tap X button → Search closes, returns to home

## Git Status

- **Branch**: `cursor/default-poster-image-quality-796b`
- **Commit**: Add collection filter header to search results
- **Files changed**: 1 (SearchScreenView.swift)
- **Lines changed**: +58 insertions, -2 deletions
