# PodLink

iOS podcast client (SwiftUI, iOS 17+). Open `PodLink.xcodeproj` in Xcode to build and run.

## Repo layout

- **`PodLink/`** — App sources (views, services, models, design system, `Resources/` JSON).
- **`PodLinkTests` / `PodLinkUITests`** — Xcode test targets.
- **`Package.swift`** — Optional Swift package layout (same sources under `PodLink/`) if you use SPM elsewhere.
- **`project.yml`** — [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec; run `xcodegen generate` from the repo root only if you want to regenerate an `.xcodeproj` from YAML instead of editing the checked-in project.
- **`PRD.md`** — Product notes from the original prototype.

## Signing & CloudKit

The app target uses bundle ID `Carambula-Projects.PodLink`. Entitlements reference:

- iCloud container: `iCloud.Carambula-Projects.PodLink`
- App group: `group.Carambula-Projects.PodLink`

Create matching identifiers and capabilities in the Apple Developer portal if you use CloudKit or the app group in production.

iCloud is optional. Sign in to Min Cloud (`services/min-cloud`) for server-side feed refresh, notifications, and library sync. Local RSS remains the backup when the service is offline.

## Migration note

Application code was merged from the earlier `myrepo` PodLink tree. The canonical app in this repo is the Xcode project above; `project.yml` / `Package.swift` are kept for tooling parity with that history.
