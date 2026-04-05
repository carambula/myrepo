# Toolbar Behavior Testing Guide

## Quick Start

1. **Build and run the app** in Xcode
2. Navigate to **Account → Appearance → Toolbar Behavior**
3. Try each of the 4 behavior modes

## Testing Each Mode

### 1. Always Visible (Default)

**What to expect:**
- Toolbar stays at the bottom at all times
- No changes when scrolling

**Test steps:**
1. Select "Always Visible"
2. Return to main screen
3. Scroll up and down
4. ✅ Toolbar should never move

---

### 2. Minimize on Scroll

**What to expect:**
- Scroll down → Toolbar shrinks to small pill in center
- Scroll up → Toolbar expands
- Tap pill → Toolbar expands

**Test steps - Main Screen:**
1. Select "Minimize on Scroll"
2. Return to main screen
3. Scroll down slowly
4. ✅ Toolbar should shrink to a 100px centered pill
5. Scroll up
6. ✅ Toolbar should expand back
7. Scroll down again
8. Tap the minimized pill
9. ✅ Toolbar should expand immediately

**Test steps - Search:**
1. Open search (tap search button)
2. Type a query (e.g., "Matrix")
3. Scroll down in results
4. ✅ Search bar should shrink to pill, keyboard should hide
5. Tap the pill
6. ✅ Search bar expands, input focuses, keyboard appears

---

### 3. Minimize to Corners

**What to expect:**
- Scroll down → Filter button (left) + Search/Close button (right)
- Each button is a 48px circle in the corners
- Tap any corner button → Toolbar expands

**Test steps - Main Screen:**
1. Select "Minimize to Corners"
2. Return to main screen
3. Scroll down slowly
4. ✅ Filter icon should appear in lower left
5. ✅ Search icon should appear in lower right
6. Tap the filter icon
7. ✅ Full toolbar should expand
8. Scroll down again
9. Tap the search icon
10. ✅ Search should open

**Test steps - Search:**
1. Open search
2. Scroll down in results
3. ✅ Filter icon (left) + Close icon (right)
4. Tap filter icon
5. ✅ Toolbar expands
6. Scroll down again
7. Tap close icon
8. ✅ Search dismisses

---

### 4. Show/Hide

**What to expect:**
- Scroll down → Toolbar slides out completely
- Scroll up → Toolbar slides back in
- No UI elements when hidden

**Test steps - Main Screen:**
1. Select "Show/Hide"
2. Return to main screen
3. Scroll down
4. ✅ Toolbar should slide down and disappear
5. Scroll up
6. ✅ Toolbar should slide back up

**Test steps - Search:**
1. Open search
2. Scroll down in results
3. ✅ Search controls should disappear
4. Scroll up
5. ✅ Search controls should reappear

---

## Edge Cases to Test

### Switch Between Modes
1. Set to "Minimize on Scroll"
2. Scroll down (toolbar minimized)
3. Open settings
4. Change to "Always Visible"
5. ✅ Toolbar should be fully visible

### Rapid Scrolling
1. Set to any dynamic mode
2. Scroll down very quickly
3. Scroll up very quickly
4. ✅ Animations should be smooth, no jitter

### Pull to Refresh
1. Set to "Show/Hide"
2. Pull down to refresh
3. ✅ Refresh should work normally
4. ✅ Toolbar should not interfere

### Theme Integration
1. Set to "Minimize to Corners"
2. Change theme (e.g., to "I'm Batman")
3. Scroll down to see corner buttons
4. ✅ Corner button icons should be yellow (theme accent)

### Search Keyboard
1. Set to "Minimize on Scroll"
2. Open search
3. Tap search field (keyboard visible)
4. Scroll down
5. ✅ Keyboard should hide
6. ✅ Toolbar should minimize
7. Tap pill
8. ✅ Keyboard should reappear

### Orientation Change
1. Set to "Minimize on Scroll"
2. Scroll down (minimized)
3. Rotate device
4. ✅ Toolbar should stay minimized
5. ✅ Pill should stay centered

---

## Visual Verification

### Minimized Pill
- **Size**: 100px wide × 24px tall
- **Shape**: Rounded rectangle (16px corners)
- **Material**: Ultra thin glass
- **Position**: Centered horizontally
- **Border**: Subtle white stroke

### Corner Buttons
- **Size**: 48px × 48px circles
- **Material**: Ultra thin glass
- **Position**: Lower left + lower right
- **Shadow**: Subtle drop shadow
- **Icon color**: Theme accent color

### Animations
- **Transition**: Smooth spring animation
- **Duration**: ~0.4 seconds
- **Feel**: Bouncy but controlled
- **No lag**: Should be 60fps

---

## Performance Check

### Large Lists
1. Filter to show 500+ movies
2. Set to "Minimize on Scroll"
3. Scroll rapidly through entire list
4. ✅ No frame drops
5. ✅ Smooth toolbar transitions

### Quick Mode Switching
1. Rapidly switch between all 4 modes
2. ✅ No crashes
3. ✅ Settings update correctly
4. ✅ Toolbar adapts immediately

---

## Known Issues to Watch For

❌ **If toolbar doesn't minimize:**
- Check that you selected a dynamic mode (not Always Visible)
- Try scrolling faster or further (50pt threshold)

❌ **If animations are choppy:**
- This shouldn't happen, report as bug if it does

❌ **If keyboard doesn't hide in search:**
- Only happens in Minimize on Scroll mode
- Only when scrolling down past threshold

---

## Success Criteria

✅ All 4 modes work as described
✅ Smooth animations with no lag
✅ Tap interactions work correctly
✅ Search keyboard auto-hides/shows properly
✅ Corner buttons match theme accent
✅ No crashes or state issues
✅ Settings persist across app restarts

---

## Report Issues

If you find any bugs or unexpected behavior:
1. Note which mode was selected
2. Note exact steps to reproduce
3. Check console for any error messages
4. Screenshot or screen recording helpful
