# Min Apps

Monorepo for the min apps suite and their shared design system.

## Apps

| App | Path | Description |
|-----|------|-------------|
| **mov min** | `apps/WatchedIt` | WatchedIt — movie tracking (Swift / Xcode) |
| **pod min** | `apps/PodLink` | podlink — podcast app (Swift / Xcode) |
| **vid min** | `apps/YourTube` | yourtube — video app (Swift / Xcode) |
| **cyc min** | `apps/Cyclismo` | Cyclismo guide — cycling guide (Swift / Xcode + backend) |
| **spin min** | `apps/SpinMin` | SpinMin — tire pressure calculator (Swift / Xcode) |
| **fit min** | `apps/fit min` | Interval timers (Swift / Xcode) |

## Packages

| Package | Path | Description |
|---------|------|-------------|
| `@min-apps/design-system` | `packages/design-system` | Shared tokens, themes, components, layouts, and utilities |
| `@min-apps/design-studio` | `packages/design-studio` | Web tool for browsing tokens, previewing themes, and managing the design system |
| `@min-apps/agent-kit` | `packages/agent-kit` | MCP / HTTP agent gateway, scoped tokens, and undo journal |
| **Min Cloud** | `services/min-cloud` | Railway web service for mov min + pod min (catalog, notifications, accounts, admin) and the shared ideas/feedback loop for all min apps |

## Feedback / ideas

Bugs and ideas from **Account → Ideas & bugs** (all min apps) go through Min Cloud → redacted GitHub issues → Cursor triage/build. Setup, secrets, and Cursor automations: [docs/FEEDBACK.md](docs/FEEDBACK.md).

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
open apps/SpinMin/SpinMin.xcodeproj
```

## Structure

```
min-apps/
├── apps/
│   ├── WatchedIt/              # mov min — WatchedIt (Swift)
│   ├── PodLink/                # pod min — podlink (Swift)
│   ├── YourTube/               # vid min — yourtube (Swift)
│   ├── Cyclismo/               # cyc min — Cyclismo guide (Swift + backend)
│   └── SpinMin/                # spin min — SpinMin tire pressure calculator (Swift)
├── services/
│   └── min-cloud/              # Shared Railway API + web for mov min and pod min
├── packages/
│   ├── design-system/          # @min-apps/design-system
│   │   ├── src/                # Tokens, components, layouts (JS)
│   │   ├── native/             # Generated Swift/Kotlin/XML for iOS & Android
│   │   ├── swift/              # MinAppKit Swift package (spacing, corner radius, opacity)
│   │   ├── scripts/            # build-native-tokens.js
│   │   └── docs/               # Documentation
│   ├── design-studio/          # @min-apps/design-studio (npm run studio)
│   └── agent-kit/              # @min-apps/agent-kit (MCP / HTTP agent gateway)
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

## Agent access

Every min app is agent-ready. An agent can connect with **read** and/or **write** scopes, see your library (movies watched or saved, podcasts listened to, timers, and so on), and make changes that stay undoable for 7 days.

1. In any app: **Account → Agents → Create connection** (or `node packages/agent-kit/src/cli.js init`).
2. Copy the token into your agent’s MCP config. See [`packages/agent-kit/README.md`](./packages/agent-kit/README.md).
3. Call tools such as `list_movies`, `set_movie_saved`, `list_listening_history`, `follow_podcast`, `create_timer`, or `start_timer`.
4. Undo accidents with `undo` or **Account → Agents → Undo last agent write**.

On-device, the same actions are also App Intents (Siri / Shortcuts / Apple Intelligence).

## License

MIT
