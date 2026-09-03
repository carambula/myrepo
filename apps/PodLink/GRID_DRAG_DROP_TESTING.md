# Grid Drag and Drop Testing Guide

## Quick Test (5 minutes)

### Setup
1. Build and run PodLink on iOS Simulator or device
2. Complete onboarding if needed
3. Follow at least 3-4 podcasts via search
4. Navigate to main screen
5. Ensure you're in **grid view** (tap the grid/list toggle if needed)

### Basic Test
1. **Long-press** on any podcast artwork for ~1 second
2. **Observe** - The artwork should lift up with iOS drag animation
3. **Drag** the artwork to a different position in the grid
4. **Observe** - Other podcasts should smoothly animate to make space
5. **Release** - The podcast should drop into the new position
6. **Kill the app** - Force quit completely
7. **Reopen the app** - Verify the new order is preserved

✅ **Pass Criteria**: Podcasts reorder smoothly and persist after app restart

---

## Comprehensive Test Suite

### Test 1: First to Last Position
**Goal**: Verify dragging from first position to last position

1. Note the first podcast in the grid
2. Long-press and drag the first podcast to the last position
3. Release
4. **Verify**: 
   - All other podcasts shifted left/up with smooth animation
   - First podcast is now last
   - Order persists after app restart

### Test 2: Last to First Position
**Goal**: Verify dragging from last position to first position

1. Note the last podcast in the grid
2. Long-press and drag the last podcast to the first position
3. Release
4. **Verify**:
   - All other podcasts shifted right/down with smooth animation
   - Last podcast is now first
   - Order persists after app restart

### Test 3: Middle Reordering
**Goal**: Verify dragging between middle positions

1. Long-press on the 2nd podcast
2. Drag it to the 4th position
3. Release
4. **Verify**:
   - 3rd and 4th podcasts shifted left
   - 2nd podcast moved to 4th position
   - Smooth spring animation
   - Order persists after app restart

### Test 4: Rapid Reordering
**Goal**: Test multiple quick reorders

1. Drag podcast A to a new position
2. Immediately drag podcast B to another position
3. Immediately drag podcast C to another position
4. **Verify**:
   - All animations complete smoothly without glitches
   - Final order is correct
   - No duplicate podcasts or missing podcasts
   - Order persists after app restart

### Test 5: Animation Smoothness
**Goal**: Verify visual quality of animations

1. Long-press and drag a podcast slowly across the grid
2. Observe neighboring podcasts as they shift
3. **Verify**:
   - Spring animation has natural bounce (dampingFraction: 0.7)
   - Transitions are smooth, not jumpy
   - Response time feels instant (response: 0.3)
   - No visual artifacts or overlapping

### Test 6: Different Artwork Sizes
**Goal**: Test with all poster size settings

For each size setting:
- Settings → Poster Size → plus10
- Settings → Poster Size → plus20
- Settings → Poster Size → plus40
- Settings → Poster Size → plus60 (default)

For each:
1. Return to main screen
2. Perform basic drag and drop
3. **Verify**: Drag and drop works correctly regardless of size

### Test 7: Show Titles Toggle
**Goal**: Test with titles visible/hidden

**With titles hidden** (compact poster style):
1. Ensure "Show Podcast Titles" is OFF
2. Perform drag and drop
3. **Verify**: Works correctly

**With titles visible**:
1. Enable "Show Podcast Titles"
2. Perform drag and drop
3. **Verify**: Works correctly, titles remain aligned

### Test 8: List View (Should Not Have Drag)
**Goal**: Verify drag and drop is grid-only

1. Switch to list view (tap grid/list toggle)
2. Try to long-press and drag a podcast
3. **Verify**: 
   - List items do NOT drag (intentional)
   - Tapping still opens podcast detail sheet

### Test 9: Large Collections
**Goal**: Test with many podcasts

1. Follow 10+ podcasts
2. Drag a podcast from top to bottom of long scroll
3. **Verify**:
   - Scrolling works during drag (if needed)
   - Animation remains smooth
   - No performance issues

### Test 10: Latest Episodes Integrity
**Goal**: Verify episodes stay with correct podcasts

**Setup**:
1. Note which podcast has an unplayed episode (blue dot)
2. Reorder that podcast to a different position

**Verify**:
- The unplayed indicator (blue dot) moves with the podcast
- Opening the podcast shows the correct latest episode
- Episode data is not mixed up with other podcasts

### Test 11: Persistence Across Sessions
**Goal**: Verify order persists correctly

1. Reorder 3+ podcasts
2. Force quit the app
3. Reopen the app
4. **Verify**: Order is preserved exactly

5. Reorder again
6. Force quit again
7. Reopen again
8. **Verify**: New order is preserved

### Test 12: Pull to Refresh
**Goal**: Verify reorder survives data refresh

1. Reorder podcasts
2. Pull down to refresh feeds
3. Wait for refresh to complete
4. **Verify**: 
   - Podcast order is unchanged
   - Latest episodes update correctly
   - No podcasts are duplicated or missing

---

## Edge Cases

### Edge Case 1: Single Podcast
**Setup**: Follow only 1 podcast

**Test**: Try to drag it
**Expected**: Nothing happens (no other positions to move to)

### Edge Case 2: Two Podcasts
**Setup**: Follow exactly 2 podcasts

**Test**: Drag first to second position, then second to first
**Expected**: Order swaps correctly each time

### Edge Case 3: Empty State
**Setup**: Unfollow all podcasts

**Test**: Verify empty state shows "Find Podcasts" button
**Expected**: No crashes, empty state displays correctly

### Edge Case 4: During Feed Fetch
**Setup**: Trigger feed refresh while podcasts are loading

**Test**: Try to drag and drop during refresh
**Expected**: Drag and drop still works, no conflicts

---

## Visual Regression Tests

### Visual Test 1: Drag Lift Animation
1. Long-press on artwork
2. **Observe**: Artwork lifts with iOS standard shadow and scale
3. **Verify**: Matches iOS system drag gesture appearance

### Visual Test 2: Space Creation
1. Drag a podcast slowly between two others
2. **Observe**: The gap opens smoothly with spring animation
3. **Verify**: Other podcasts shift proportionally, not abruptly

### Visual Test 3: Drop Animation
1. Release a dragged podcast
2. **Observe**: Artwork settles into position
3. **Verify**: Smooth transition, no jarring snaps

---

## Accessibility Tests

### VoiceOver Test
1. Enable VoiceOver
2. Navigate to a podcast in the grid
3. Use VoiceOver drag gesture
4. **Verify**: 
   - VoiceOver announces drag and drop actions
   - Reordering works with VoiceOver gestures
   - Feedback is clear and accurate

### Accessibility Hints
1. With VoiceOver on, focus a podcast
2. Listen to accessibility hints
3. **Verify**: Hints indicate drag and drop capability

---

## Performance Tests

### Performance Test 1: Animation Frame Rate
1. Use Instruments or Xcode performance monitor
2. Perform drag and drop operations
3. **Verify**: Frame rate stays at 60fps (or 120fps on ProMotion displays)

### Performance Test 2: Memory Usage
1. Monitor memory during drag operations
2. Perform 10+ drag and drop operations
3. **Verify**: No memory leaks, memory usage stable

### Performance Test 3: UserDefaults Write Speed
1. Monitor console during reorder operations
2. **Verify**: Saves complete within milliseconds, no blocking

---

## Cross-Device Testing

### Devices to Test
- **iPhone SE** (small screen, compact grid)
- **iPhone 15** (standard size)
- **iPhone 15 Pro Max** (large screen, more columns)
- **iPad** (if supporting iPad in future)

### Orientation Tests
1. **Portrait**: Test drag and drop in portrait mode
2. **Landscape**: Test drag and drop in landscape mode
3. **Verify**: Works correctly in both orientations

---

## Integration Tests

### Integration Test 1: Search → Follow → Reorder
1. Search for a new podcast
2. Follow it
3. Immediately drag it to first position
4. **Verify**: Works correctly, new podcast appears in correct position

### Integration Test 2: Unfollow → Reorder
1. Unfollow a podcast from the middle of the grid
2. Reorder remaining podcasts
3. **Verify**: No gaps, no crashes, smooth operation

### Integration Test 3: Theme Change During Drag
1. Start dragging a podcast
2. While holding, use another device/simulator to change theme
3. **Verify**: No visual artifacts or crashes

---

## Regression Tests

### Regression Test 1: Tap Interaction Still Works
1. Verify tap interactions (bounce, ripple, etc.) still work
2. **Verify**: Tapping (not dragging) still opens podcast detail

### Regression Test 2: Latest Episodes Still Load
1. Reorder podcasts
2. Wait for latest episodes to load
3. **Verify**: Correct episodes appear under correct podcasts

### Regression Test 3: Playback Integration
1. Start playing an episode
2. Reorder podcasts while playing
3. **Verify**: Playback continues uninterrupted

---

## Bug Report Template

If you find issues, report using this template:

```
**Issue**: [Brief description]
**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Behavior**: 
**Actual Behavior**: 
**Device**: [iPhone model]
**iOS Version**: [e.g., iOS 17.0]
**PodLink Version**: [commit hash or version]
**Screenshots/Video**: [if applicable]
**Console Logs**: [any errors or warnings]
```

---

## Success Criteria Summary

✅ **Must Pass All**:
1. Drag and drop reorders podcasts smoothly
2. Order persists after app restart
3. Animations are smooth (spring with response 0.3, damping 0.7)
4. Latest episodes stay associated with correct podcasts
5. Works with all artwork sizes
6. Works with titles shown/hidden
7. Does NOT work in list view (intentional)
8. No crashes or visual glitches
9. Performance remains excellent (60fps+)
10. VoiceOver support works correctly

---

## Automated Test Scenarios (Future)

Consider adding XCTest UI tests for:
- Drag gesture simulation
- Order persistence verification
- Array reordering logic unit tests
- UserDefaults save/load tests
