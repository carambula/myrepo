# Generated native artifacts

Run from the design-system repo root:

```bash
npm run build:native
```

Source: `src/tokens/spacing.js`, `src/tokens/mainLoading.js`, `src/tokens/minTitles.js`  
Script: `scripts/build-native-tokens.js`

| Output | Use |
|--------|-----|
| **`MinAppLayout.swift`** | **SwiftUI screen wrapper — applies mov min page margins. Use on every screen.** |
| **`MinAppHeader.swift`** | **SwiftUI header bar with page margins** |
| **`MinDismissButton.swift`** | **SwiftUI floating button at page offsets** |
| **`MinAppLayout.kt`** | **Compose screen scaffold — applies page margins. Use on every screen.** |
| **`MinAppHeader.kt`** | **Compose header bar with page margins** |
| **`MinDismissButton.kt`** | **Compose floating button at page offsets** |
| `MinPageMargins.swift` | Raw **pt** constants (regular + mobile pairs) |
| `MinPageInsets.swift` | Size-class helpers — `uiEdgeInsets(traitCollection:)`, `horizontalPadding(sizeClass:)` |
| `MinPageMargins.kt` | Android constants (dp) |
| `MinTitleTypography.swift` | iOS title constants + SwiftUI views (`MinMainContentTitleView`, `MinHomeScreenTitleView`, `MinHeaderTitleView`) |
| `MinTitleTypography.kt` | Android title constants (Compose) |
| `title_typography.json` | Title metrics JSON |
| `MinMainAppLoading.swift` | iOS main bootstrap loader constants + `MinMainAppLoadingView` |
| `MinMainAppLoading.kt` | Android main loader constants |
| `main_app_loading.json` | Message + spinner/gap/font sizes |
| `spacing.json` | Numeric spacing tree for any pipeline |
| `android/values/min_page_margins.xml` | All margin tokens (explicit `_mobile` names) |
| `android/values/min_page_content_insets.xml` | `min_page_padding_start/end/top/bottom` — **phone = mobile tokens** |
| `android/values-sw600dp/min_page_content_insets.xml` | Same resource names — **sw600dp+ = regular tokens** |
| `android/values/min_title_typography.xml` | Android `@dimen` for title text sizes and margins |
| `android/values/min_main_loading.xml` | String + dimens for main loading row |
| `android/values/min_app_layout.xml` | Template XML layout with page-margin padding |

## Layout components (the actual fix for inconsistent margins)

These are **drop-in screen wrappers** that enforce the mov min page grid. Add them to the app target and wrap every screen — no per-screen padding math.

### iOS (SwiftUI)

| File | What it does |
|------|-------------|
| **`MinAppLayout.swift`** | Screen wrapper — applies page margins to content. **Use this on every screen.** |
| `MinAppHeader.swift` | Header bar with the same page-margin padding |
| `MinDismissButton.swift` | Floating close button at page-margin offsets |

```swift
// Every screen in every app:
MinAppLayout(header: { MinAppHeaderView("YourTube") }) {
    VideoQueueList(videos)
}

// Without a header:
MinAppLayout {
    List { … }
}
```

Detail screen:

```swift
MinAppLayout {
    MinMainContentTitleView(movie.title)
    Text(movie.year).foregroundStyle(.secondary)
}
```

Home screen:

```swift
MinAppLayout {
    MinHomeScreenTitleView("WatchedIt")
    // buttons, content…
}
```

Requires all Swift files from this folder in the same Xcode target.

### Android (Jetpack Compose)

| File | What it does |
|------|-------------|
| **`MinAppLayout.kt`** | Screen scaffold — applies page margins to content. **Use on every screen.** |
| `MinAppHeader.kt` | Header bar with page-margin padding |
| `MinDismissButton.kt` | Floating close button at page-margin offsets |

```kotlin
// Every screen in every app:
MinAppLayout(header = { MinAppHeader("YourTube") }) {
    LazyColumn { … }
}
```

Requires `MinPageMargins.kt` + `MinTitleTypography.kt` in `com.minapps.ds.tokens`.

### Android (XML layouts)

`android/values/min_app_layout.xml` — a template `LinearLayout` with header and content slots using `@dimen/min_page_padding_*`. Copy the pattern or include the layout directly.

See **[Native tokens](../docs/native-tokens.md)** and **[Main app loading — native](../docs/main-app-loading-native.md)**.
