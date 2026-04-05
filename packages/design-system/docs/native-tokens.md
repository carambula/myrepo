# Native apps: consuming design tokens

The min apps ship as **native** (iOS / Android). This design-system repository also contains **web** tokens (`spacing.js`, `global.css`). **Those files do not run inside native binaries.** If margins differ between WatchedIt, podlink, yourtube, and Cyclismo, the cause is almost always **inconsistent native code** (hard-coded `16.dp` everywhere, missing `MinPageInsets`, or layouts that ignore `@dimen/min_page_padding_*`).

## Same margins in all four native apps

The design system generates **drop-in layout components** for both platforms. Add them to the app target and wrap every screen — no per-screen padding math, no hard-coded `16`.

### iOS (SwiftUI) — wrap every screen in `MinAppLayout`

Add these files to every Xcode target:

- [`MinPageMargins.swift`](../native/MinPageMargins.swift) — raw constants
- [`MinPageInsets.swift`](../native/MinPageInsets.swift) — size-class helpers
- **[`MinAppLayout.swift`](../native/MinAppLayout.swift)** — **screen wrapper, applies page margins**
- [`MinAppHeader.swift`](../native/MinAppHeader.swift) — header bar with page margins
- [`MinDismissButton.swift`](../native/MinDismissButton.swift) — floating button at page offsets
- [`MinTitleTypography.swift`](../native/MinTitleTypography.swift) — screen titles
- [`MinMainAppLoading.swift`](../native/MinMainAppLoading.swift) — bootstrap loader

```swift
// Every screen in every app — YourTube, WatchedIt, PodLink, Cyclismo:
MinAppLayout(header: { MinAppHeaderView("YourTube") }) {
    VideoQueueList(videos)
}

// Without header:
MinAppLayout {
    List { … }
}

// Detail screen with hero title:
MinAppLayout {
    MinMainContentTitleView(movie.title)
    Text(movie.year).foregroundStyle(.secondary)
    // …
}
```

`MinAppLayout` reads `@Environment(\.horizontalSizeClass)` and applies compact (phone) or regular (tablet) margins automatically. **Do not add `.padding(.horizontal)` on children.**

For `UICollectionView` / `UITableView` screens not using SwiftUI, use `MinPageMargins.uiEdgeInsets(traitCollection:)` as `contentInset` / `sectionInset`.

### Android (Jetpack Compose) — wrap every screen in `MinAppLayout`

Add these files to the module:

- [`MinPageMargins.kt`](../native/MinPageMargins.kt) — raw dp constants (`com.minapps.ds.tokens`)
- **[`MinAppLayout.kt`](../native/MinAppLayout.kt)** — **screen scaffold, applies page margins** (`com.minapps.ds.ui`)
- [`MinAppHeader.kt`](../native/MinAppHeader.kt) — header bar with page margins
- [`MinDismissButton.kt`](../native/MinDismissButton.kt) — floating button at page offsets
- [`MinTitleTypography.kt`](../native/MinTitleTypography.kt) — screen title constants
- [`MinMainAppLoading.kt`](../native/MinMainAppLoading.kt) — bootstrap loader

```kotlin
// Every screen in every app:
MinAppLayout(header = { MinAppHeader("YourTube") }) {
    LazyColumn { items(videos) { VideoRow(it) } }
}

// Without header:
MinAppLayout {
    Column { … }
}
```

`MinAppLayout` reads `LocalConfiguration.current.screenWidthDp` and selects compact (< 600dp) or regular margins. **Do not add horizontal padding on children.**

### Android (XML layouts)

Copy `android/values/` and `android/values-sw600dp/` into the module `res/` tree. Use `@dimen/min_page_padding_start/end/top/bottom` on every root `FrameLayout` / `ConstraintLayout`. A template layout is at [`android/values/min_app_layout.xml`](../native/android/values/min_app_layout.xml).

**Remove** duplicate padding: if the root applies these insets, `RecyclerView`, search bars, and list rows must not add a second horizontal inset.

## Source of truth

1. **Author** spacing in [`src/tokens/spacing.js`](../src/tokens/spacing.js).
2. **Generate** platform outputs:
   ```bash
   npm run build:native
   ```
3. **Commit** everything under [`native/`](../native/).
4. **Integrate** in each app (submodule, copy step, or internal package).

Generated artifacts are documented in [`native/README.md`](../native/README.md).

## Screen titles (mov min)

Each app's **home title**, **detail/show hero title**, and **header title** must be exactly the same size and position as WatchedIt. The source is [`src/tokens/minTitles.js`](../src/tokens/minTitles.js); `npm run build:native` compiles it into:

| Output | iOS use |
|--------|---------|
| [`MinTitleTypography.swift`](../native/MinTitleTypography.swift) | Constants **+ drop-in SwiftUI views**: `MinMainContentTitleView`, `MinHomeScreenTitleView`, `MinHeaderTitleView` |
| [`title_typography.json`](../native/title_typography.json) | Machine-readable tree for CI / UIKit hand-wiring |

### Detail / show / player title (mov min canonical)

48pt system bold, -1.2pt tracking, 16pt bottom spacing. Leading edge on the same vertical line as lists and `MinMainAppLoadingView`.

```swift
// Parent already applies page horizontal padding — do NOT add a second inset.
ScrollView {
    MinMainContentTitleView(movie.title)
    // subtitle, metadata, etc.
}
.padding(.horizontal, MinPageMargins.horizontalPadding(horizontalSizeClass: hsc))
```

Pass `bottomSpacing:` to override the default 16pt (e.g. `8` when a subtitle sits directly under the title).

### Home screen app name

36pt bold (regular) / 30pt bold (compact), centered. `MinHomeScreenTitleView` reads `@Environment(\.horizontalSizeClass)` automatically.

```swift
VStack {
    Image("Logo")
    MinHomeScreenTitleView("WatchedIt")
    Text("Track your movies").foregroundStyle(.secondary)
}
```

### Navigation / header title

20pt semibold, single line, truncating tail.

```swift
HStack {
    Button(action: goBack) { Image(systemName: "chevron.left") }
    MinHeaderTitleView(movie.title)
    Spacer()
}
```

### UIKit

If a screen is still UIKit, use the raw constants from `MinMainContentTitle` / `MinHomeScreenTitle` / `MinHeaderTitle` with `UIFont.systemFont(ofSize:weight:)` and `NSAttributedString` tracking. The numbers are in the same file.

## Per-app checklist (iOS / SwiftUI)

- [ ] Add **all** Swift files from `native/` to the Xcode target: `MinPageMargins`, `MinPageInsets`, **`MinAppLayout`**, `MinAppHeader`, `MinDismissButton`, `MinTitleTypography`, `MinMainAppLoading`.
- [ ] **Every screen**: wrap in **`MinAppLayout { … }`** — not a bare `VStack` / `ScrollView` with ad-hoc `.padding(16)`.
- [ ] **Header**: `MinAppLayout(header: { MinAppHeaderView("AppName") }) { … }` — not a custom `HStack` with hard-coded padding.
- [ ] **Detail/show title**: `MinMainContentTitleView(title)` inside `MinAppLayout` — no extra horizontal padding.
- [ ] **Home title**: `MinHomeScreenTitleView("AppName")` — replaces custom centered `Text`.
- [ ] **Floating buttons**: `MinDismissButtonView(isVisible: scrolled) { dismiss() }` — positioned from page margins automatically.
- [ ] **Loading**: `MinMainAppLoadingView()` — already uses responsive page margins.
- [ ] **Remove** all hard-coded `.padding(.horizontal, 16)` or `.padding(.horizontal, 12)` from screen roots. `MinAppLayout` handles it.
- [ ] `UICollectionView` / `UITableView` (UIKit): use `MinPageMargins.uiEdgeInsets(traitCollection:)` as `contentInset` — no extra horizontal inset if the root already applies margins.

## Per-app checklist (Android / Compose)

- [ ] Copy all `native/android/values/` and `native/android/values-sw600dp/` XML files into the module `res/` tree.
- [ ] Add **`MinAppLayout.kt`**, `MinAppHeader.kt`, `MinDismissButton.kt`, `MinPageMargins.kt`, `MinTitleTypography.kt`, `MinMainAppLoading.kt` to the project (update `package` to match).
- [ ] **Every screen**: wrap in **`MinAppLayout { … }`** — not a bare `Column` / `Box` with hard-coded `padding(16.dp)`.
- [ ] **Header**: `MinAppLayout(header = { MinAppHeader("AppName") }) { … }`.
- [ ] **Floating buttons**: `MinDismissButton(visible = scrolled, onClick = { dismiss() })`.
- [ ] **Remove** all hard-coded `Modifier.padding(horizontal = 16.dp)` from screen roots. `MinAppLayout` handles it.
- [ ] `RecyclerView` (XML): `paddingStart`/`paddingEnd` = `@dimen/min_page_padding_start`/`end` — no extra horizontal inset if parent already applies margins.

## Vid min / yourtube

Video apps often use tighter gutters in prototypes. **Override those** with `MinPageMargins` / `@dimen/min_page_margin_*` so queues and search align with mov min. See [YourTube integration guide](../integration-tools/app-specific/yourtube-integration.md).

## Related

- [Layout and margins (mov min)](./layout-margins-mov-min.md)
- [Tokens reference](./tokens.md)
