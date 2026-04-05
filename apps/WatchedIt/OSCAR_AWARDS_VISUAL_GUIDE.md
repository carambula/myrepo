# Oscar Awards Visual Guide

## UI Components

### 1. Oscar Awards Section on Movie Details

```
┌─────────────────────────────────────────────┐
│                                             │
│  Cast Section                               │
│  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐          │
│  │ 👤  │ │ 👤  │ │ 👤  │ │ 👤  │          │
│  └─────┘ └─────┘ └─────┘ └─────┘          │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ 🏆 Academy Awards                     │ │ ← New Section
│  │                                       │ │
│  │ ┌───────────────────────────────────┐ │ │
│  │ │                                   │ │ │
│  │ │   🏆   11                         │ │ │
│  │ │        Oscar Wins                 │ │ │
│  │ │                                   │ │ │
│  │ └───────────────────────────────────┘ │ │
│  │                                       │ │
│  │ ┌───────────────────────────────────┐ │ │
│  │ │                                   │ │ │
│  │ │   ⭐   3                          │ │ │
│  │ │        Oscar Nominations          │ │ │
│  │ │                                   │ │ │
│  │ └───────────────────────────────────┘ │ │
│  └───────────────────────────────────────┘ │
│                                             │
│  Sources & Lists Section                   │
│                                             │
└─────────────────────────────────────────────┘
```

### 2. Win Card Details

```
┌─────────────────────────────────────┐
│                                     │
│   ┌────┐                            │
│   │ 🏆 │  11                        │
│   └────┘  Oscar Wins                │
│                                     │
└─────────────────────────────────────┘

Components:
- Circle background: Accent color at 15% opacity
- Trophy icon: Accent color (yellow, green, blue)
- Number: Headline font, text primary color
- Label: Body small font, text secondary color
- Border: Accent color at 20% opacity
- Corner radius: Medium (8pt)
```

### 3. Nomination Card Details

```
┌─────────────────────────────────────┐
│                                     │
│   ┌────┐                            │
│   │ ⭐ │  3                         │
│   └────┘  Oscar Nominations         │
│                                     │
└─────────────────────────────────────┘

Components:
- Circle background: Text secondary at 15% opacity
- Star icon: Text secondary color
- Number: Headline font, text primary color
- Label: Body small font, text secondary color
- Border: Border light at 50% opacity
- Corner radius: Medium (8pt)
```

## Theme Variations

### Batman Theme (Dark Navy + Yellow)

```
┌─────────────────────────────────────┐
│ 🏆 Academy Awards      [Yellow icon]│
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🏆  11           [Yellow trophy]│ │
│ │    Oscar Wins                   │ │
│ └─────────────────────────────────┘ │
│      [Yellow border]                │
└─────────────────────────────────────┘

Colors:
- Background: Dark navy (#0D141A)
- Accent: Yellow (#FFD700)
- Text: White/light gray
```

### Matrix Theme (Dark + Green)

```
┌─────────────────────────────────────┐
│ 🏆 Academy Awards      [Green icon] │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🏆  11           [Green trophy] │ │
│ │    Oscar Wins                   │ │
│ └─────────────────────────────────┘ │
│      [Green border]                 │
└─────────────────────────────────────┘

Colors:
- Background: Dark
- Accent: Neon green (#00FF00)
- Text: White/light gray
```

### Default Theme (Light + Blue)

```
┌─────────────────────────────────────┐
│ 🏆 Academy Awards       [Blue icon] │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🏆  11            [Blue trophy] │ │
│ │    Oscar Wins                   │ │
│ └─────────────────────────────────┘ │
│      [Blue border]                  │
└─────────────────────────────────────┘

Colors:
- Background: White/light gray
- Accent: Blue (#007AFF)
- Text: Dark gray/black
```

## Search Examples

### 1. Search: "oscar"

```
┌─────────────────────────────────────┐
│ 🔍 oscar                        ✕   │
└─────────────────────────────────────┘

Results:
┌─────────────────────────────────────┐
│ 🎬 The Lord of the Rings: ROTK      │
│    2003 • 11 Oscar Wins             │
├─────────────────────────────────────┤
│ 🎬 Titanic                          │
│    1997 • 11 Oscar Wins             │
├─────────────────────────────────────┤
│ 🎬 The Shawshank Redemption         │
│    1994 • 7 Oscar Nominations       │
└─────────────────────────────────────┘
```

### 2. Search: "11"

```
┌─────────────────────────────────────┐
│ 🔍 11                           ✕   │
└─────────────────────────────────────┘

Results:
┌─────────────────────────────────────┐
│ 🎬 The Lord of the Rings: ROTK      │
│    2003 • 11 Oscar Wins             │
├─────────────────────────────────────┤
│ 🎬 Titanic                          │
│    1997 • 11 Oscar Wins             │
├─────────────────────────────────────┤
│ 🎬 Ocean's Eleven                   │
│    2001 • (Year matches)            │
└─────────────────────────────────────┘
```

### 3. Search: "win"

```
┌─────────────────────────────────────┐
│ 🔍 win                          ✕   │
└─────────────────────────────────────┘

Results: (Only movies with Oscar wins)
┌─────────────────────────────────────┐
│ 🎬 Parasite                         │
│    2019 • 4 Oscar Wins              │
├─────────────────────────────────────┤
│ 🎬 Everything Everywhere All at Once│
│    2022 • 7 Oscar Wins              │
└─────────────────────────────────────┘
```

## Icon Guide

### Trophy Icon (Wins)
```
  🏆
```
- SF Symbol: `trophy.fill`
- Color: Accent color
- Size: 20pt for cards, 14pt for headers

### Star Icon (Nominations)
```
  ⭐
```
- SF Symbol: `star.fill`
- Color: Text secondary
- Size: 20pt for cards

### Circle Backgrounds
```
┌────────┐
│   🏆   │  ← 48×48 circle
└────────┘
```
- Diameter: 48pt
- Fill: Accent/secondary at 15% opacity

## Spacing Guidelines

### Section Spacing
```
Cast Section
    ↓
   16pt spacing (DesignSystem.Spacing.lg)
    ↓
Oscar Awards Section
    ↓
   16pt spacing (DesignSystem.Spacing.lg)
    ↓
Streaming Services Section
```

### Card Spacing
```
┌─────────────────────────┐
│ 🏆 Academy Awards       │
│                         │ ← 16pt spacing
│ ┌─────────────────────┐ │
│ │ Win Card            │ │
│ └─────────────────────┘ │
│                         │ ← 12pt spacing
│ ┌─────────────────────┐ │
│ │ Nomination Card     │ │
│ └─────────────────────┘ │
└─────────────────────────┘
```

### Internal Card Spacing
```
┌─────────────────────────┐
│ 12pt padding            │
│ ┌────┐                  │
│ │ 🏆 │  11              │ ← 12pt spacing between icon and text
│ └────┘  Oscar Wins      │
│ 12pt padding            │
└─────────────────────────┘
```

## Responsive Behavior

### Portrait (iPhone)
```
┌──────────────────────┐
│                      │
│ ┌──────────────────┐ │
│ │ 🏆  11           │ │ Full width
│ │    Oscar Wins    │ │
│ └──────────────────┘ │
│                      │
│ ┌──────────────────┐ │
│ │ ⭐  3            │ │ Full width
│ │    Nominations   │ │
│ └──────────────────┘ │
│                      │
└──────────────────────┘
```

### Landscape (iPad)
```
┌──────────────────────────────────────┐
│                                      │
│ ┌──────────────────┐  Cards adapt   │
│ │ 🏆  11           │  to available   │
│ │    Oscar Wins    │  width          │
│ └──────────────────┘                 │
│                                      │
│ ┌──────────────────┐                 │
│ │ ⭐  3            │                 │
│ │    Nominations   │                 │
│ └──────────────────┘                 │
│                                      │
└──────────────────────────────────────┘
```

## States

### 1. Movie with Wins Only
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🏆  4                       │ │
│ │    Oscar Wins               │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### 2. Movie with Nominations Only
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ⭐  7                       │ │
│ │    Oscar Nominations        │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### 3. Movie with Both
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🏆  11                      │ │
│ │    Oscar Wins               │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ⭐  3                       │ │
│ │    Oscar Nominations        │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### 4. Movie with No Awards
```
(Oscar Awards section not displayed)

Cast Section
    ↓
Streaming Services Section
```

## Dark Mode

### Light Mode
```
┌─────────────────────────────────┐
│ Background: White/Light Gray    │
│ Text: Black/Dark Gray           │
│ Borders: Light gray             │
│ Icons: Accent color             │
└─────────────────────────────────┘
```

### Dark Mode
```
┌─────────────────────────────────┐
│ Background: Black/Dark Gray     │
│ Text: White/Light Gray          │
│ Borders: Dark gray              │
│ Icons: Accent color (brighter)  │
└─────────────────────────────────┘
```

## Accessibility

### VoiceOver Labels
```
🏆 Academy Awards
  → "Academy Awards section"

🏆 11 Oscar Wins
  → "Eleven Oscar wins"

⭐ 3 Oscar Nominations
  → "Three Oscar nominations"
```

### Dynamic Type Support
- All text scales with system font size
- Cards maintain readable spacing
- Icons scale proportionally

## Animation (Future Enhancement)

### Potential Animations
```
1. Trophy Shine:
   ✨🏆✨ → Subtle sparkle on wins card

2. Star Pulse:
   ⭐→⭐ → Gentle pulse on nominations card

3. Reveal Animation:
   Cards slide up + fade in when scrolling
```

## Example Movies

### The Lord of the Rings: The Return of the King (2003)
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🏆  11                      │ │
│ │    Oscar Wins               │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### The Shawshank Redemption (1994)
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ⭐  7                       │ │
│ │    Oscar Nominations        │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

### Parasite (2019)
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards               │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🏆  4                       │ │
│ │    Oscar Wins               │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ⭐  2                       │ │
│ │    Oscar Nominations        │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

## Code-to-Visual Mapping

### SwiftUI View Structure
```swift
VStack(alignment: .leading, spacing: 16) {
    // Header
    HStack(spacing: 8) {
        Image(systemName: "trophy.fill")
        Text("Academy Awards")
    }
    
    VStack(alignment: .leading, spacing: 12) {
        // Win Card
        if awards.totalWins > 0 {
            WinCardView(count: awards.totalWins)
        }
        
        // Nomination Card
        if awards.totalNominations > 0 {
            NominationCardView(count: awards.totalNominations)
        }
    }
}
```

Maps to:
```
┌─────────────────────────────────┐
│ 🏆 Academy Awards      ← Header │
│            ↑ 8pt spacing        │
│            ↓ 16pt spacing       │
│ ┌─────────────────────────────┐ │
│ │ Win Card                    │ │
│ └─────────────────────────────┘ │
│            ↓ 12pt spacing       │
│ ┌─────────────────────────────┐ │
│ │ Nomination Card             │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

## Summary

The Oscar awards UI is designed to be:
- ✅ **Clear**: Easy to understand wins vs nominations
- ✅ **Themed**: Adapts to all app themes
- ✅ **Responsive**: Works on all device sizes
- ✅ **Accessible**: VoiceOver compatible
- ✅ **Beautiful**: Matches app design system
- ✅ **Performant**: No layout jank or delays

---

**Note:** This visual guide represents the implemented design. Actual rendering may vary slightly based on device, iOS version, and theme settings.
