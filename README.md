# Min Apps

Monorepo for the min apps suite and their shared design system.

## Apps

| App | Path | Description |
|-----|------|-------------|
| **mov min** | `apps/WatchedIt` | WatchedIt — movie tracking (Swift / Xcode) |
| **pod min** | `apps/PodLink` | podlink — podcast app (Swift / Xcode) |
| **vid min** | `apps/YourTube` | yourtube — video app (Swift / Xcode) |
| **cyc min** | `apps/Cyclismo` | Cyclismo guide — cycling guide (Swift / Xcode + backend) |

## Packages

| Package | Path | Description |
|---------|------|-------------|
| `@min-apps/design-system` | `packages/design-system` | Shared tokens, themes, components, layouts, and utilities |
| `@min-apps/design-studio` | `packages/design-studio` | Web tool for browsing tokens, previewing themes, and managing the design system |

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) >= 18 (for the design system and native token generation)
- [Xcode](https://developer.apple.com/xcode/) (for the native apps)

### Install design system dependencies

```bash
npm install
```

### Launch the Design Studio

Browse tokens, preview themes, and see how changes affect all 4 apps:

```bash
npm run studio
```

Opens at [http://localhost:3100](http://localhost:3100).

### Build native tokens

Regenerates Swift, Kotlin, and Android XML files from the design system tokens:

```bash
npm run build
```

The generated files land in `packages/design-system/native/`. Each app can reference them via Xcode project/file references or by copying them into its target.

### Open an app in Xcode

```bash
open apps/WatchedIt/WatchedIt.xcodeproj
open apps/PodLink/PodLink.xcodeproj
open apps/YourTube/YourTube.xcodeproj
open "apps/Cyclismo/Cyclismo Guide.xcodeproj"
```

## Structure

```
min-apps/
├── apps/
│   ├── WatchedIt/              # mov min — WatchedIt (Swift)
│   ├── PodLink/                # pod min — podlink (Swift)
│   ├── YourTube/               # vid min — yourtube (Swift)
│   └── Cyclismo/               # cyc min — Cyclismo guide (Swift + backend)
├── packages/
│   ├── design-system/          # @min-apps/design-system
│   │   ├── src/                # Tokens, components, layouts (JS)
│   │   ├── native/             # Generated Swift/Kotlin/XML for iOS & Android
│   │   ├── scripts/            # build-native-tokens.js
│   │   └── docs/               # Documentation
│   └── design-studio/          # @min-apps/design-studio (npm run studio)
├── package.json                # Root workspace config (npm)
└── turbo.json                  # Turborepo task pipeline
```

## How the apps use the design system

The apps are native Swift/Xcode projects. They consume the design system's **generated native artifacts** from `packages/design-system/native/`:

- **iOS**: `MinPageMargins.swift`, `MinPageInsets.swift`, `MinMainAppLoading.swift`, `MinTitleTypography.swift`, etc.
- **Android**: XML dimens in `native/android/values/`
- **JSON**: `spacing.json`, `main_app_loading.json`, `title_typography.json` for tooling

After editing tokens in `packages/design-system/src/tokens/`, run `npm run build` to regenerate these files.

## Design System

See the design system [README](./packages/design-system/README.md) for full documentation on tokens, components, theming, notifications, onboarding, deep linking, and storage.

## License

MIT
