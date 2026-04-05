# Testing Guide - Search Bar Appearance Feature

## How to Test

### 1. Build and Run
```bash
# In Xcode
1. Open WatchedIt.xcodeproj
2. Select your device or simulator
3. Product → Build (⌘B)
4. Product → Run (⌘R)
```

### 2. Access the Feature
1. Launch the app
2. Tap the **Account** button (person icon, top-right)
3. Under **Appearance** section, tap **Search Bar Appearance**

### 3. Test Each Style

#### Test Classic Style (Default)
1. Select **Classic** from the list
2. Dismiss the settings
3. Tap the **Search** button (magnifying glass, bottom-right)
4. **Expected Result:**
   - Search bar appears with ultra-thin glass effect
   - Subtle border around the search field
   - No shadow
   - Close button has glass appearance
   - Search icon is gray (secondary text color)

#### Test Solid Style
1. Go back to Account → Search Bar Appearance
2. Select **Solid**
3. Dismiss settings and open search
4. **Expected Result:**
   - Search bar has solid background (matches card color)
   - Bold accent-colored border (your theme's accent color)
   - Visible shadow beneath search field
   - Close button is a solid circle filled with accent color
   - Search icon matches accent color
   - More spacing between search bar and toolbar

#### Test Elevated Style
1. Go back to Account → Search Bar Appearance
2. Select **Elevated**
3. Dismiss settings and open search
4. **Expected Result:**
   - Search bar has thick frosted glass effect
   - More pronounced border
   - Large shadow creating floating appearance
   - Close button has glass appearance
   - Search icon is gray
   - Maximum spacing between search bar and toolbar

### 4. Test with Different Themes

Test each search bar style with all available themes:

#### With "I'm Batman" Theme (Yellow/Navy)
1. Go to Account → Themes → I'm Batman
2. Test all three search bar styles
3. **Expected:**
   - Classic: Subtle yellow tint in border
   - Solid: Bold yellow border and yellow close button
   - Elevated: Large shadow against navy background

#### With "Matrix" Theme (Green)
1. Switch to Matrix theme
2. Test all three styles
3. **Expected:**
   - Classic: Subtle green hints
   - Solid: Bright green border and button
   - Elevated: Deep shadows with green accents

#### With Other Themes
Repeat for:
- Default "Watched It" (Blue)
- "McQueen" (Blue/Orange)
- "Sepia" (Warm tones)
- Any custom themes

### 5. Test Interaction

For each style, verify:

#### Search Functionality
- [ ] Tap search field to show keyboard
- [ ] Type search text
- [ ] Clear button (×) appears when typing
- [ ] Tap clear button to remove text
- [ ] Search results update in real-time
- [ ] Close button dismisses search

#### Visual States
- [ ] Empty state (no text) looks correct
- [ ] Active state (with text) looks correct
- [ ] Keyboard appearance doesn't break layout
- [ ] Animations are smooth when opening/closing search

### 6. Test Persistence

1. Select **Solid** appearance
2. Force quit the app (swipe up from app switcher)
3. Relaunch the app
4. Open search
5. **Expected:** Search bar still uses Solid appearance

### 7. Test in Different Modes

#### Light Mode
1. Set device to light mode (Settings → Display & Brightness → Light)
2. Open app and test each search bar style
3. **Expected:** All styles should look appropriate in light mode

#### Dark Mode
1. Set device to dark mode
2. Test each style again
3. **Expected:**
   - Materials should show appropriate blur
   - Shadows should be visible
   - Borders should have good contrast

#### Dynamic Type (Accessibility)
1. Enable larger text (Settings → Accessibility → Display & Text Size → Larger Text)
2. Test search bar with larger font
3. **Expected:** Text scales appropriately, layout doesn't break

### 8. Performance Testing

#### Smooth Scrolling
1. Open search with each style
2. Scroll through movie list
3. **Expected:** No lag or stuttering, especially with Elevated style

#### Animation Performance
1. Rapidly toggle search on/off
2. Switch between styles quickly
3. **Expected:** Animations remain smooth, no flickering

### 9. Edge Cases

#### Long Search Text
1. Type a very long search query
2. **Expected:** Text truncates or scrolls appropriately

#### Theme Switching While Search is Open
1. Open search
2. Open Account → Themes
3. Switch theme while search is visible
4. **Expected:** Search bar updates colors immediately

#### Appearance Switching While Search is Open
1. Open search
2. Go to Search Bar Appearance
3. Switch between styles
4. **Expected:** Changes apply immediately when returning to main view

## Known Limitations

1. **iOS Version:** Requires iOS 17+ for material effects
2. **Performance:** Elevated style has highest GPU cost (may impact older devices)
3. **Themes:** Some custom themes may need manual testing for optimal appearance

## Reporting Issues

If you find any bugs or visual issues:

1. **Screenshot:** Take a screenshot showing the issue
2. **Details:** Note which style, theme, iOS version, and device
3. **Steps:** Document exact steps to reproduce
4. **Expected vs Actual:** Describe what you expected vs what happened

### Example Bug Report
```
Style: Solid
Theme: I'm Batman
Device: iPhone 15 Pro, iOS 17.2
Issue: Border color doesn't match accent color
Steps:
1. Select I'm Batman theme
2. Select Solid search bar appearance
3. Open search
Expected: Yellow border
Actual: White border
```

## Success Criteria

All tests pass when:
- ✅ All three styles render correctly
- ✅ Styles work with all themes
- ✅ Interactions are smooth and responsive
- ✅ Selected style persists after app restart
- ✅ No crashes or visual glitches
- ✅ Performance remains smooth
- ✅ Accessibility features work properly

## Quick Checklist

Use this checklist for rapid testing:

### Visual
- [ ] Classic style: thin glass, subtle
- [ ] Solid style: bold border, accent color
- [ ] Elevated style: thick glass, large shadow

### Functional
- [ ] Search works in all styles
- [ ] Close button works
- [ ] Clear button works
- [ ] Selection persists

### Themes
- [ ] Tested with Batman theme
- [ ] Tested with Matrix theme
- [ ] Tested with default theme

### Modes
- [ ] Light mode works
- [ ] Dark mode works
- [ ] No performance issues

---

**Happy Testing!** 🎬

If everything works as expected, the feature is ready for use!
