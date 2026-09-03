# Testing Guide: Person Search Feature

## Quick Test Steps

1. **Build and run** the app in Xcode
2. **Open any movie** that has cast/crew information (e.g., "The Matrix", "Inception")
3. **Tap the director's name** in the Key Credits section
4. **Verify**:
   - ✅ Movie details sheet dismisses smoothly
   - ✅ Search bar appears at the bottom
   - ✅ Director's name is pre-filled in the search field
   - ✅ **Keyboard does NOT open**
   - ✅ Search results show only movies with that director

5. **Clear the search** (tap X button)
6. **Open another movie** with a good cast list
7. **Tap any actor's card** (the circular photo with name)
8. **Verify**:
   - ✅ Same behavior as director search
   - ✅ Results show movies featuring that actor

## Edge Cases to Test

### Empty/Whitespace Names
- If a credit has only whitespace, tapping should do nothing

### Visual Feedback
- Button should scale down slightly when pressed (0.97x)
- Button should fade slightly when pressed (0.7 opacity)
- Quick animation using `DesignSystem.Animation.quick`

### Search Bar Appearance
- Should slide up from bottom with spring animation
- Should respect your selected Search Bar Appearance (Classic/Solid/Elevated/Glass)
- Should respect your selected Toolbar & Button Style

### Keyboard Behavior
- **Critical**: Keyboard must NOT open when search appears
- Search field should NOT be focused (no blue cursor)
- User can manually tap search field to open keyboard if desired

### Person Search Filter
The search should use special person matching that checks:
- Director field (case-insensitive)
- All cast members (case-insensitive)
- More precise than typing the name manually (which searches all fields)

### Switching Between Search Modes
1. Search for a person (e.g., "Christopher Nolan")
2. Manually type a different query (e.g., "Dark Knight")
3. The person search filter should automatically clear
4. Results should switch to general text search

## Visual Flow Diagram

```
┌─────────────────────────┐
│   Movie Details View    │
│                         │
│   Director: Nolan       │ ◄── Tap here
│   Cast: [Cards...]      │ ◄── Or tap any cast card
└─────────────────────────┘
            │
            │ handleCreditPersonTap()
            │
            ▼
┌─────────────────────────┐
│ startPersonSearchFrom   │
│       Details()         │
│                         │
│ - Store: pendingPerson  │
│ - Dismiss: sheet        │
└─────────────────────────┘
            │
            │ On Dismiss
            │
            ▼
┌─────────────────────────┐
│ applyPendingPersonSearch│
│      FromDetails()      │
│                         │
│ - skipAutofocus = true  │
│ - searchText = person   │
│ - showSearch = true     │
│ - isFieldFocused = false│
└─────────────────────────┘
            │
            │
            ▼
┌─────────────────────────┐
│    Main Movie List      │
│                         │
│  [Search: Christopher   │ ◄── No keyboard!
│   Nolan]                │
│                         │
│  ▪ Inception            │
│  ▪ The Dark Knight      │
│  ▪ Interstellar         │
│  ▪ Dunkirk              │
└─────────────────────────┘
```

## Performance Check

- Search should feel instant (no lag)
- Sheet dismissal should be smooth (no janky animation)
- Search results should filter quickly
- Scrolling the filtered list should be smooth

## Theme Integration Check

Try the feature with different themes:
- **I'm Batman** theme: Search bar should have yellow accents
- **Matrix** theme: Search bar should have green accents
- **Other themes**: Should use their respective accent colors

## What Changed in the Code

**Before**: Tapping a person opened a full-screen search modal
**After**: Tapping a person opens the inline search bar at the bottom

**Benefits**:
- Faster (no modal transition)
- Lighter weight
- Maintains context
- Matches your UI screenshot

## If Something Doesn't Work

1. **Clean build folder**: Product → Clean Build Folder (Shift+Cmd+K)
2. **Rebuild**: Product → Build (Cmd+B)
3. **Check console**: Look for any runtime errors
4. **Verify branch**: Make sure you're on `cursor/movie-details-person-search-d20d`

## Expected Git Status

```bash
git status
# On branch cursor/movie-details-person-search-d20d
# Your branch is up to date with 'origin/cursor/movie-details-person-search-d20d'.
```

All changes have been committed and pushed to this branch.
