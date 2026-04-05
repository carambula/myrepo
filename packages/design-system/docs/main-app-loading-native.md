# Main app loading — native (iOS, Android, React Native)

**`global.css` and DOM-only components do not run on native.** The suite still requires the **same** bootstrap UI as WatchedIt (mov min): **leading** row, **small** spinner, exact **`Loading…`** string, **page-margin** horizontal inset — **not** a centered `ActivityIndicator` / `ProgressView` in the middle of the screen.

Source of truth for numbers and copy: **`src/tokens/mainLoading.js`**. Regenerate native artifacts with **`npm run build:native`** (writes `native/`).

## React Native / Expo (vid min, pod min, cyc min, mov min)

The main app bootstrap loader must match across all four apps. In native code, use the generated views.

### SwiftUI

```swift
MinAppLayout {
    MinMainAppLoadingView()
}
```

`MinMainAppLoadingView` already applies horizontal page padding from `MinPageMargins`. Wrapping in `MinAppLayout` is optional but ensures consistency with every other screen.

### Compose

```kotlin
MinAppLayout {
    MinMainAppLoadingRow()
}
```

Or build the row from `MinMainAppLoading` constants in `MinMainAppLoading.kt`.

### UIKit

Build the row manually using `MinMainAppLoading.*` constants, apply `MinPageMargins.uiEdgeInsets(traitCollection:)` to the root container.

Leading-aligned, start-justified — **never** centered.

## Primary title in main content (same package)

The **large title in the main column** (detail/show hero, not the top bar) must match mov min **type and default spacing**, with **leading edge** on the same vertical line as lists and `MainAppLoading` (page margins on the parent — do not add a second horizontal inset).

```swift
// iOS (SwiftUI):
MinAppLayout {
    MinMainContentTitleView(movie.title)
    // rest of detail view — no extra .padding(.horizontal)
}
```

```kotlin
// Android (Compose):
MinAppLayout {
    Text(
        text = movie.title,
        fontSize = MinMainContentTitle.FONT_SIZE.sp,
        fontWeight = FontWeight(MinMainContentTitle.FONT_WEIGHT),
    )
}
```

- iOS constants: **`MinMainContentTitle`**, **`MinHomeScreenTitle`**, **`MinHeaderTitle`** from `MinTitleTypography.swift`.
- Android constants: same names in `MinTitleTypography.kt`.
- Source: **`src/tokens/minTitles.js`**; run **`npm run build:native`** after token edits.

## SwiftUI (iOS)

1. Copy **all** generated Swift files from `native/` into the app target (or SPM package). The layout component `MinAppLayout.swift` depends on `MinPageMargins.swift` + `MinPageInsets.swift`.
2. Use **`MinMainAppLoadingView()`** inside **`MinAppLayout`** as the bootstrap screen.
3. Outer chrome must be **leading**-aligned, not a centered `VStack { Spacer(); ProgressView(); Spacer() }`.

## Android (Jetpack Compose / XML)

1. Copy `native/android/values/` and `native/android/values-sw600dp/` XML files into `res/`.
2. Add `MinAppLayout.kt`, `MinMainAppLoading.kt`, and `MinPageMargins.kt` to the project.
3. Wrap the loading state in **`MinAppLayout`**, use `MinMainAppLoading` constants for the row.

## Machine-readable spec

- **`native/main_app_loading.json`** — message + numeric tokens for any pipeline.
- **`@min-apps/design-system/native/main-app-loading.json`** (package export).

## See also

- [Main app loading (web + overview)](./main-app-loading.md)
- [Visual specification — Loading states](./visual-specification.md#loading-and-empty-null-states)
- `native/README.md`
