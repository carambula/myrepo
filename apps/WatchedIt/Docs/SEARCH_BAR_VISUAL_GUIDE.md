# Search Bar Appearance - Visual Guide

## Quick Comparison Table

| Feature | Classic | Solid | Elevated |
|---------|---------|-------|----------|
| **Background** | Ultra thin glass | Solid card color | Thick glass |
| **Border Width** | 0.5pt | 1.5pt | 0.5pt |
| **Border Opacity** | 60% light | 100% accent | 80% light |
| **Shadow Radius** | None | 8pt | 12pt |
| **Shadow Offset** | 0pt | 4pt | 6pt |
| **Bottom Padding** | 8pt | 12pt | 16pt |
| **Icon Color** | Secondary text | Accent color | Secondary text |
| **Close Button** | Glass circle | Solid accent circle | Glass circle |
| **Visual Weight** | Light | Bold | Medium-Heavy |
| **Best With** | All themes | Bold accent themes | Dark mode themes |

## Detailed Visual Breakdown

### 1. Classic Style
**Philosophy:** Subtle integration with minimal visual interruption

**Visual Properties:**
```
Search Field:
├── Background: .ultraThinMaterial
├── Border: borderLight @ 60% opacity, 0.5pt
├── Shadow: None
├── Height: 44pt
└── Padding: 12pt horizontal, 8pt bottom

Icons:
├── Search icon: textSecondary
├── Clear icon: textSecondary
└── Size: 16pt (small)

Close Button:
├── Style: Glass icon button
├── Background: .ultraThinMaterial
├── Shadow: Medium (10pt radius)
└── Size: 44pt circle
```

**When to Use:**
- You prefer minimal visual clutter
- You want the search bar to blend with the toolbar
- You're using light, subtle themes
- You prioritize content over chrome

### 2. Solid Style
**Philosophy:** Bold statement with strong theme integration

**Visual Properties:**
```
Search Field:
├── Background: cardBackground (solid color)
├── Border: accent @ 100% opacity, 1.5pt
├── Shadow: accent @ 20% opacity, 8pt radius, 4pt Y
├── Height: 44pt
└── Padding: 12pt horizontal, 12pt bottom

Icons:
├── Search icon: accent
├── Clear icon: accent
└── Size: 16pt (small)

Close Button:
├── Style: Solid circle
├── Background: accent
├── Shadow: accent @ 30% opacity, 8pt radius
└── Size: 44pt circle
```

**When to Use:**
- You want the search bar to stand out
- You're using themes with vibrant accent colors
- You prefer bold, modern design
- You want stronger visual hierarchy

### 3. Elevated Style
**Philosophy:** Pronounced depth with floating appearance

**Visual Properties:**
```
Search Field:
├── Background: .thickMaterial
├── Border: borderLight @ 80% opacity, 0.5pt
├── Shadow: black @ 40% opacity, 12pt radius, 6pt Y
├── Height: 44pt
└── Padding: 12pt horizontal, 16pt bottom

Icons:
├── Search icon: textSecondary
├── Clear icon: textSecondary
└── Size: 16pt (small)

Close Button:
├── Style: Glass icon button
├── Background: .ultraThinMaterial
├── Shadow: Large (12pt radius)
└── Size: 44pt circle
```

**When to Use:**
- You want a floating, elevated feel
- You prefer dark mode
- You like pronounced shadows and depth
- You want clear spatial separation from toolbar

## Visual States Comparison

### Empty State (No search text)
```
CLASSIC:  ╭─────🔍 Search movies──────────────────╮ [×]
          Translucent · Thin border · Flush

SOLID:    ╔═════🔍 Search movies══════════════════╗ [●]
          Solid · Accent border · Shadow · Spaced

ELEVATED: ╔═════🔍 Search movies══════════════════╗ [×]
          Frosted · Thick border · Large shadow · Very spaced
```

### Active State (With search text)
```
CLASSIC:  ╭─────🔍 Lynne Ramsay────────── ⊗ ───╮ [×]
          Text visible · Clear button appears

SOLID:    ╔═════🔍 Lynne Ramsay════════════ ⊗ ═══╗ [●]
          Accent highlights · Bold presence

ELEVATED: ╔═════🔍 Lynne Ramsay════════════ ⊗ ═══╗ [×]
          Deep shadow · Floating above toolbar
```

## Theme Compatibility

### With Batman Theme (Yellow accent, Navy background)
- **Classic**: ✅ Excellent - Subtle yellow hint in border
- **Solid**: ⭐ Outstanding - Bold yellow border pops against navy
- **Elevated**: ✅ Excellent - Strong depth perception in dark mode

### With Matrix Theme (Green accent, Monospace)
- **Classic**: ✅ Excellent - Clean, minimal
- **Solid**: ⭐ Outstanding - Green border creates strong tech aesthetic
- **Elevated**: ✅ Good - Shadow might compete with green accent

### With McQueen Theme (Blue/Orange dual accent)
- **Classic**: ✅ Excellent - Doesn't compete with dual accents
- **Solid**: ✅ Excellent - Showcases primary accent strongly
- **Elevated**: ⭐ Outstanding - Depth works beautifully with dual colors

### With Sepia Theme (Warm tones)
- **Classic**: ⭐ Outstanding - Matches vintage aesthetic
- **Solid**: ✅ Good - Warm border creates cohesive look
- **Elevated**: ✅ Excellent - Depth adds dimension to flat tones

## Accessibility Considerations

### Visual Contrast
- **Classic**: Medium contrast, relies on material blur
- **Solid**: High contrast, strong border definition
- **Elevated**: Medium-high contrast, shadow provides depth cues

### Focus Indicators
All three styles support keyboard focus equally:
- Focus ring appears when navigating with keyboard
- Clear visual indication of active search field
- Close button has distinct tap target (44pt minimum)

### Reduced Motion
All three styles respect iOS reduced motion settings:
- Animations are simplified or removed
- Transitions use fade instead of scale/slide
- Shadow effects remain static

## Performance Notes

### Rendering Cost (Lowest to Highest)
1. **Classic** - Ultra thin material is optimized by system
2. **Solid** - Solid color is cheapest to render, but shadow adds cost
3. **Elevated** - Thick material + large shadow has highest GPU cost

### Recommendations
- Classic: Best for older devices or battery conservation
- Solid: Good balance of visual impact and performance
- Elevated: Best for newer devices with high refresh rate displays

## User Preference Data (Expected)

Based on similar design patterns in other apps:
- **Classic**: ~45% of users (prefer familiarity and subtlety)
- **Solid**: ~35% of users (prefer bold, modern design)
- **Elevated**: ~20% of users (prefer depth and spatial design)

## Testing Checklist

When testing the search bar appearances:

### Visual Testing
- [ ] Search bar appears correctly in light mode
- [ ] Search bar appears correctly in dark mode
- [ ] Border colors match theme accent
- [ ] Shadow is visible and appropriate
- [ ] Spacing looks balanced above toolbar
- [ ] Close button matches search bar style

### Interaction Testing
- [ ] Search field is tappable
- [ ] Keyboard appears when tapping field
- [ ] Clear button appears with text
- [ ] Clear button clears text
- [ ] Close button dismisses search
- [ ] Animations are smooth

### Theme Testing
- [ ] Test with default theme
- [ ] Test with Batman theme
- [ ] Test with Matrix theme
- [ ] Test with McQueen theme
- [ ] Test with Sepia theme
- [ ] Test with custom themes

### Persistence Testing
- [ ] Selected appearance persists across app launches
- [ ] Default is Classic for new users
- [ ] Changing appearance updates immediately
- [ ] No crashes when switching between styles

## Implementation Code Snippets

### Switching Between Styles (User Action)
```swift
// In SearchBarAppearanceView
searchBarAppearanceRaw = appearance.rawValue
```

### Applying Style (View Rendering)
```swift
// In MovieListView
private var searchBarAppearance: SearchBarAppearance {
    SearchBarAppearance(rawValue: searchBarAppearanceRaw) ?? .classic
}

@ViewBuilder
private var searchFieldBackground: some View {
    switch searchBarAppearance {
    case .classic: Rectangle().fill(.ultraThinMaterial)
    case .solid: DesignSystem.Color.cardBackground
    case .elevated: Rectangle().fill(.thickMaterial)
    }
}
```

## Feedback and Iteration

Based on user feedback, we may adjust:
- Shadow intensities
- Border thicknesses
- Padding amounts
- Add new style variants
- Per-theme default preferences

Current implementation allows easy tuning of these values without structural changes.
