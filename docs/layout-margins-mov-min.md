# Screen layout and margins (mov min canonical grid)

**WatchedIt (mov min)** defines the canonical **page grid** for the min apps suite. **PodLink, YourTube (vid min), and Cyclismo** must align scrollable content, headers, home actions, search fields, filters, segmented controls, and other **chrome** to the **same** horizontal and vertical insets — not ad‑hoc `16px`, `1rem`, or per-app padding.

**Vid min note:** Video apps often ship with **tighter** list gutters or **full-bleed** thumbnail grids from platform defaults. Replace those with this grid so queues, subscriptions, and search **line up with mov min**.

## Native apps (iOS + Android)

The design system generates **drop-in layout components** that enforce the mov min page grid.

### iOS (SwiftUI) — `MinAppLayout`

```swift
// Every screen in every app:
MinAppLayout(header: { MinAppHeaderView("YourTube") }) {
    VideoQueueList(videos)
}
```

`MinAppLayout` reads `@Environment(\.horizontalSizeClass)` and applies compact (phone) or regular margins. Add all files from [`native/`](../native/) to the Xcode target.

### Android (Compose) — `MinAppLayout`

```kotlin
MinAppLayout(header = { MinAppHeader("YourTube") }) {
    LazyColumn { items(videos) { VideoRow(it) } }
}
```

`MinAppLayout` reads `LocalConfiguration.current.screenWidthDp` and selects compact (< 600dp) or regular.

### Android (XML)

Use `@dimen/min_page_padding_start/end/top/bottom` on every screen root. Copy `values/` and `values-sw600dp/` from [`native/android/`](../native/android/).

**Do not add horizontal padding on children.** The layout wrapper handles it.

See **[Native tokens](./native-tokens.md)**.

## Rules

1. **Single source of truth**  
   **Author** in [`src/tokens/spacing.js`](../src/tokens/spacing.js); **run** `npm run build:native`; **consume** [`native/`](../native/) in Swift/Kotlin/XML. For web/JS, use **`spacing.page.*`** from `@min-apps/design-system/tokens`. In plain CSS, use **`global.css`** variables:
   - `--min-page-margin-top` / `--min-page-margin-bottom`
   - `--min-page-margin-left` / `--min-page-margin-right`  
   Values are identical to the tokens; keep them in sync if you change the tokens.

2. **Layout components apply the grid**  
   - **Web**: `AppLayout`, `HomeLayout`, `AppHeader` from `@min-apps/design-system`.  
   - **iOS**: `MinAppLayout`, `MinAppHeaderView` from [`native/`](../native/).  
   - **Android**: `MinAppLayout`, `MinAppHeader` from [`native/`](../native/).  
   Prefer these over hand-rolled containers. They apply `spacing.page.*` / `MinPageMargins` automatically.

3. **Do not double the horizontal inset**  
   If the screen root is already **`AppLayout`** (or any container that applies `spacing.page` on `main`), **do not** add another `padding-left` / `padding-right` on inner wrappers for “content width.” Use **vertical** spacing only between blocks (e.g. `spacing[2]` under a sticky search row).  
   If the root has **no** page padding, either wrap with **`AppLayout`**, add **`min-page-padding`** / **`min-page-padding-x`** from `global.css`, or use **`ContentContainer`** with default padding.

4. **Sticky search, filters, and toolbars**  
   Rows that stick to the top (search `Input`, filter chips, scope toggles) must sit in the **same** horizontal column as list content: **no extra** left/right padding beyond what the parent already applied. Background and `z-index` may span the padded area; the controls align to the **inner** edges of the page grid.

5. **Fixed and overlay controls**  
   Floating actions (e.g. **DismissButton**), corner buttons, and similar **viewport-fixed** elements should inset from the safe edges with **`spacing.page.marginLeft` / `marginBottom`** (and `*Mobile` in a `max-width: 767px` query) so they line up with the **mov min** content margin, not arbitrary `spacing[4]`.

6. **Main bootstrap loading**  
   Continues to follow **[Main app loading](./main-app-loading.md)** (classes + **`Loading…`**). Horizontal inset for `.min-content-status--main` uses the same **`--min-page-margin-*`** variables.

7. **Max-width columns**  
   Centered caps (e.g. home content **600px**) stay as documented in the [visual specification](./visual-specification.md). Horizontal **inset to the viewport** is still **`spacing.page`**; max-width only limits line length inside that inset.

## Checklist (per screen)

- [ ] Root uses **`AppLayout`** (web) / **`MinAppLayout`** (iOS SwiftUI) / **`MinAppLayout`** (Android Compose) / `@dimen/min_page_padding_*` (Android XML) — not a one-off padding mix.
- [ ] No **double** horizontal padding inside `AppLayout` `main`.
- [ ] Sticky search / filters / inputs align with list or primary content (same left/right edge).
- [ ] Fixed overlays use **`spacing.page`** (or `--min-page-margin-*`) for viewport offsets.
- [ ] Values match **mov min** (desktop / mobile breakpoints at **767px**, same as existing layout components).

## See also

- [Visual specification — Page layout](./visual-specification.md#page-layout-specifications)
- [Best practices — Spacing](./best-practices.md#spacing-and-layout)
- [Tokens — spacing.page](./tokens.md)
