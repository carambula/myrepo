# Search Bar Appearance Options

## Overview

The WatchedIt app now supports three distinct search bar appearance styles that can be selected from the Account panel. Each style is designed to complement the glass effect toolbar while providing different visual aesthetics.

## Available Styles

### 1. Classic (Default)
**Visual Characteristics:**
- Ultra thin material background (`.ultraThinMaterial`)
- Subtle border (light opacity: 0.6)
- No shadow
- Standard padding (8pt bottom)
- Close button: Glass icon button
- Icon color: Secondary text color

**Best for:** Users who prefer the original, subtle integration with the toolbar.

### 2. Solid
**Visual Characteristics:**
- Solid card background color
- Accent-colored border (1.5pt thickness)
- Accent-colored shadow (8pt radius, 4pt offset, 20% opacity)
- Medium padding (12pt bottom)
- Close button: Solid accent-colored circle with shadow
- Icon color: Accent color

**Best for:** Users who want strong visual distinction and bold accent integration.

### 3. Elevated
**Visual Characteristics:**
- Thick material background (`.thickMaterial`)
- Prominent border (light opacity: 0.8)
- Large shadow (12pt radius, 6pt offset, 40% opacity)
- Large padding (16pt bottom)
- Close button: Glass icon button
- Icon color: Secondary text color

**Best for:** Users who prefer pronounced depth and a floating appearance.

## How to Change Appearance

1. Open the app
2. Tap the Account button (person icon, top-right)
3. Navigate to **Appearance** section
4. Tap **Search Bar Appearance**
5. Select your preferred style from the three options
6. The change applies immediately

## Technical Implementation

### Storage
- Preference is stored using `@AppStorage` with key: `"searchBarAppearance"`
- Persists across app launches
- Defaults to "Classic" style

### Components Modified
- `MovieListView.swift`:
  - Added `SearchBarAppearance` enum with three cases
  - Modified `searchBarView` to support all three styles
  - Added visual preview components
  - Created `SearchBarAppearanceView` settings screen

### Code Structure
```swift
enum SearchBarAppearance: String, CaseIterable {
    case classic = "Classic"
    case solid = "Solid"
    case elevated = "Elevated"
}
```

## Visual Comparison

### Classic
```
┌─────────────────────────────────┐
│ ╭─────────────────────────────╮ │
│ │ 🔍 Search movies...         │ │
│ ╰─────────────────────────────╯ │
│         Ultra Thin Glass        │
│      Subtle, Integrated         │
└─────────────────────────────────┘
```

### Solid
```
┌─────────────────────────────────┐
│                                 │
│ ╔═════════════════════════════╗ │
│ ║ 🔍 Search movies...         ║ │
│ ╚═════════════════════════════╝ │
│      Solid Background           │
│    Accent Border & Shadow       │
│                                 │
└─────────────────────────────────┘
```

### Elevated
```
┌─────────────────────────────────┐
│                                 │
│                                 │
│ ╔═════════════════════════════╗ │
│ ║ 🔍 Search movies...         ║ │
│ ╚═════════════════════════════╝ │
│      Thick Glass Material       │
│    Pronounced Shadow & Depth    │
│                                 │
│                                 │
└─────────────────────────────────┘
```

## Design Philosophy

Each style balances three key factors:

1. **Visual Hierarchy**: How distinct the search bar appears from the toolbar
2. **Theme Integration**: How well it integrates with the current theme's accent color
3. **Spatial Depth**: The perceived elevation and floating effect

The **Classic** style emphasizes subtlety and continuity with the toolbar.
The **Solid** style emphasizes boldness and theme accent integration.
The **Elevated** style emphasizes depth and spatial separation.

## Future Enhancements

Potential future additions could include:
- Animation transitions when switching styles
- Per-theme default appearance preferences
- Additional style variations (e.g., "Minimal", "Frosted", "Neon")
- Custom color options for the solid style
