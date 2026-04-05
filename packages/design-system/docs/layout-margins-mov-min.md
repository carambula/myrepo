# Screen layout and margins (mov min canonical grid)

**WatchedIt (mov min)** defines the canonical **page grid** for the min apps suite. **PodLink, YourTube (vid min), and Cyclismo** must align scrollable content, headers, home actions, search fields, filters, segmented controls, and other **chrome** to the **same** horizontal and vertical insets.

## Spacing scale (quick reference)

| Token | Points | Role |
|-------|--------|------|
| `xs`  | 4      | Tight internal gaps, vertical toolbar padding |
| `sm`  | 8      | Button-to-button gaps, small internal padding |
| `md`  | 12     | Inter-component spacing |
| `lg`  | 16     | **Floating controls edge inset**, grid gutters |
| `xl`  | 24     | **Screen content margins** (`screenHorizontalPadding`) |
| `xxl` | 32     | Large section spacing |

## Two-tier horizontal margin system

The min apps use a **two-tier** horizontal inset model. Every screen has two distinct horizontal zones:

### Tier 1 — Content margin: `xl` (24pt)

All scrollable content, detail views, list rows, onboarding panels, and page-level text use `screenHorizontalPadding` (24pt / `xl`).

```swift
// iOS — screen content
.padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
```

```css
/* CSS */
padding-left: var(--min-page-margin-left);   /* 24px */
padding-right: var(--min-page-margin-right);  /* 24px */
```

### Tier 2 — Floating controls: `lg` (16pt)

Floating toolbars, search bars, account buttons, layout-toggle FABs, and top safe-area controls sit at `lg` (16pt) — **8pt closer to the screen edge** than content. This creates a deliberate visual break where chrome extends past the content margin.

```swift
// Floating bottom toolbar
.padding(.horizontal, DesignSystem.Spacing.lg)

// Top controls (account button bar)
.padding(.horizontal, MinSpacing.lg)

// Overlay FABs (leading/trailing)
.padding(.leading, DesignSystem.Spacing.lg)
.padding(.trailing, DesignSystem.Spacing.lg)
```

Elements that use tier-2 positioning:
- Floating filter/sort capsule toolbars (all apps)
- Glass search bars and search field chrome
- Account / notifications button bar (`safeAreaInset(edge: .top)`)
- Layout-toggle and search FABs (PodLink, YourTube overlays)
- Corner toolbar minimized states (WatchedIt)

### Banned patterns

```swift
// Content that should be xl but uses something else:
.padding(.horizontal, DesignSystem.Spacing.lg)          // too tight for content
.padding(.horizontal, DesignSystem.Spacing.md + DesignSystem.Spacing.xs) // legacy 16pt

// Floating controls that should be lg but uses something else:
.padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding) // too far in
.padding(.horizontal, DesignSystem.Spacing.sm)                       // too far out
```

### Internal component padding (unchanged)

Glass capsule **internal** padding (inside the pill shape), search field **inner** padding, and similar component chrome keep their own values (typically `lg` or `sm`). These are not screen-edge insets.

## 2-column grid (PodLink & YourTube)

Both pod min and vid min use an **identical** 2-column flexible grid on their main screens.

### Column definition

```swift
private let gridColumns = [
    GridItem(.flexible(), spacing: DesignSystem.Spacing.lg),
    GridItem(.flexible(), spacing: DesignSystem.Spacing.lg)
]
```

### Grid container

```swift
LazyVGrid(columns: gridColumns, spacing: DesignSystem.Spacing.lg) {
    ForEach(items) { item in
        gridTile(item)
    }
}
.padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
```

### Grid tile sizing

Grid tiles must **not** use fixed widths. Artwork fills the column via aspect ratio:

```swift
// Correct — fluid tile
AsyncCachedImage(url: imageURL) { image in
    image.resizable().aspectRatio(1, contentMode: .fill)
}
.clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.artTile))
// parent ZStack:
.aspectRatio(1, contentMode: .fit)
```

```swift
// Banned — breaks fluid columns
.frame(width: artworkSize, height: artworkSize)
```

### Grid rules summary

| Property | Value | Token |
|----------|-------|-------|
| Columns | 2 x `.flexible()` | — |
| Horizontal gutter | 16pt | `lg` |
| Vertical row spacing | 16pt | `lg` |
| Outer horizontal margin | 24pt | `screenHorizontalPadding` |
| Tile sizing | fluid, `aspectRatio(1)` | — |

### Banned grid patterns

```swift
GridItem(.adaptive(minimum: 170), spacing: 12)    // breaks column count with wide margins
.frame(width: artworkSize, height: artworkSize)    // prevents fluid fill
GridItem(.flexible(), spacing: DesignSystem.Spacing.xl) // gutter too wide
GridItem(.flexible(), spacing: DesignSystem.Spacing.md) // gutter too tight
```

## Cyclismo calendar view

The calendar day row uses asymmetric margins to maximize race column width:

```swift
.padding(.leading, DesignSystem.Spacing.screenHorizontalPadding)  // xl (24pt)
.padding(.trailing, DesignSystem.Spacing.md)                       // md (12pt)
```

Race entries inside the card have **no** trailing padding — the card background fills to the edge.

## Native apps (iOS + Android)

The design system generates **drop-in layout components** that enforce the mov min page grid.

### iOS (SwiftUI) — `MinAppLayout`

```swift
MinAppLayout(header: { MinAppHeaderView("YourTube") }) {
    VideoQueueList(videos)
}
```

`MinAppLayout` reads `@Environment(\.horizontalSizeClass)` and applies compact (phone) or regular margins.

### Android (Compose) — `MinAppLayout`

```kotlin
MinAppLayout(header = { MinAppHeader("YourTube") }) {
    LazyColumn { items(videos) { VideoRow(it) } }
}
```

`MinAppLayout` reads `LocalConfiguration.current.screenWidthDp` and selects compact (< 600dp) or regular.

### Android (XML)

Use `@dimen/min_page_padding_start/end/top/bottom` on every screen root. Copy `values/` and `values-sw600dp/` from [`native/android/`](../native/android/).

## Rules

1. **Single source of truth** — Author in [`src/tokens/spacing.js`](../src/tokens/spacing.js); run `npm run build:native`; consume [`native/`](../native/) in Swift/Kotlin/XML. For web/JS, use `spacing.page.*` from `@min-apps/design-system/tokens`. In plain CSS, use `global.css` variables (`--min-page-margin-left/right`: 24px, mobile 16px).

2. **Layout components apply the grid** — `AppLayout` (web), `MinAppLayout` (iOS/Android) apply `spacing.page` automatically. Prefer these over hand-rolled containers.

3. **Do not double the horizontal inset** — If the screen root already applies page margins, do not add horizontal padding on inner wrappers.

4. **Two-tier inset for controls** — Floating controls at `lg` (16pt), content at `xl` (24pt). Account buttons must align with floating toolbars (both at `lg`).

5. **Main bootstrap loading** — Follows [Main app loading](./main-app-loading.md). Horizontal inset for `.min-content-status--main` uses `--min-page-margin-*` variables.

## Mobile breakpoints

| Platform | Breakpoint | Regular margins | Mobile margins |
|----------|-----------|----------------|---------------|
| CSS      | <= 767px  | 24px           | 16px          |
| iOS      | compact `horizontalSizeClass` | 24pt | 16pt |
| Android  | < 600dp   | 24dp           | 16dp          |

## Token sources

| Platform | File | Authoritative |
|----------|------|---------------|
| JS/CSS   | `src/tokens/spacing.js` | Yes — edit here first |
| CSS vars | `src/styles/global.css` | Mirrors `spacing.js` |
| Swift    | `swift/Sources/MinAppKit/Tokens/MinSpacing.swift` | Yes (iOS) |
| Swift (generated) | `native/MinPageMargins.swift` | Auto-generated |
| Kotlin (generated) | `native/MinPageMargins.kt` | Auto-generated |
| Android XML | `native/android/values*/min_page_*.xml` | Auto-generated |
| JSON | `native/spacing.json` | Auto-generated |

## Checklist (per screen)

- [ ] Scroll content uses `screenHorizontalPadding` (`xl` / 24pt).
- [ ] Floating toolbars / search bars / account buttons use `lg` (16pt) edge inset.
- [ ] Account button bar aligns with floating toolbar (both at `lg`).
- [ ] Grid uses 2 x `.flexible()` columns with `lg` gutters — not `.adaptive()`.
- [ ] Grid tiles are fluid (no fixed width frames) — artwork uses `aspectRatio(1)`.
- [ ] No double horizontal padding (layout wrapper + inner padding).
- [ ] Mobile breakpoint margins are 16pt (not 12pt).

## See also

- [Visual specification — Page layout](./visual-specification.md#page-layout-specifications)
- [Best practices — Spacing](./best-practices.md#spacing-and-layout)
- [Tokens — spacing.page](./tokens.md)
