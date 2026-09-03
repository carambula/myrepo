# Main app loading (bootstrap)

**WatchedIt (mov min)** defines the canonical main bootstrap loader for the suite. **PodLink, YourTube, and Cyclismo guide must match it on every platform** — no per-app spinners, centering, or alternate wording.

### iOS, Android, React Native

**CSS and `MainAppLoading.js` (DOM) do not apply on native.** Use:

- **React Native / Expo:** `import { MainAppLoading } from '@min-apps/design-system/react-native'`
- **Swift / SwiftUI / Kotlin:** generated files under **`native/`** (`npm run build:native`)

Full instructions: **[Main app loading — native](./main-app-loading-native.md)**.

---

## Web requirements

- Same **three** classes on one root element: `min-content-status`, `min-content-status--loading`, `min-content-status--main`.
- Same **label** text: **`Loading…`** (ellipsis character `…`, not three ASCII periods).
- Same **structure**: spinner `span` first, then label `span`, with `role="status"` and `aria-live="polite"`.
- Import **`global.css`** so the 14px spinner and `--main` layout apply.
- **No** full-viewport flex wrapper with `justify-content: center` / `align-items: center` around this block.

## Reference implementation (copy into any min app)

### React / JSX (recommended)

Use **`MainAppLoading`** so markup, classes, and copy stay identical to mov min (especially important for **vid min / YourTube**, which often used centered loaders):

```jsx
import '@min-apps/design-system/src/styles/global.css';
import { MainAppLoading } from '@min-apps/design-system/components';

if (loading) {
  return <MainAppLoading />;
}
```

Optional: `import { MainAppLoading } from '@min-apps/design-system'` (same export).

### React / JSX (manual class string)

```jsx
import '@min-apps/design-system/src/styles/global.css';
import { MAIN_APP_LOADING_CLASSNAME } from '@min-apps/design-system/components';

if (loading) {
  return (
    <div
      className={MAIN_APP_LOADING_CLASSNAME}
      role="status"
      aria-live="polite"
    >
      <span className="min-content-status__spinner" aria-hidden="true" />
      <span className="min-content-status__label">Loading…</span>
    </div>
  );
}
```

Equivalent without the constant:

```jsx
<div
  className="min-content-status min-content-status--loading min-content-status--main"
  role="status"
  aria-live="polite"
>
  <span className="min-content-status__spinner" aria-hidden="true" />
  <span className="min-content-status__label">Loading…</span>
</div>
```

### Object-tree components (`LoadingState`)

```javascript
import { LoadingState } from '@min-apps/design-system/components';

LoadingState({ main: true }); // message defaults from tokens — same as mov min
```

## See also

- [Main app loading — native](./main-app-loading-native.md)
- [Visual specification — Loading and empty states](./visual-specification.md#loading-and-empty-null-states)
