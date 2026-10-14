# Min Apps handoff notes

Snapshot for the next person or agent. Written **5 October 2026** from `master` at `ed2b004` (`github.com/carambula/myrepo`). This is a working map, not a product spec. Prefer the code and open PRs when they disagree with this file.

Owner: Aaron Carambula (GitHub `carambula`).

---

## How this repo works

This is the **min apps** monorepo: a family of native Swift/Xcode apps that share a design system, a Railway backend, and an agent protocol. The apps are meant to feel like one product line (same spacing, chrome, account/ideas, deep links) while each catalog stays local-first.

### Apps

| Short name | Path | What it is |
|---|---|---|
| **mov min** | `apps/WatchedIt` | Movie tracker. iOS + tvOS. Bundled SwiftData catalog + user status. Closet Picks, theaters, discs, Play menu. |
| **pod min** | `apps/PodLink` | Podcast client. Followed shows, playback, transcripts, Rewatchables archive, mov-min deep links. |
| **vid min** | `apps/YourTube` | YouTube client (`vidmin://watch?v=`). Closet Picks episodes deep-link here. |
| **cyc min** | `apps/Cyclismo` | Cycling race guide. |
| **spin min** | `apps/SpinMin` | Tire pressure / bike gear. This is the only app GitHub Actions builds today. |
| **fit min** | `apps/fit min` | Interval timers. Smaller surface; still wired for Ideas and agents. |

Deep-link schemes: `movmin://`, `podmin://`, `vidmin://`, `cycmin://`, `spinmin://`. Apps query each other via `LSApplicationQueriesSchemes`. Bias is: open another min app when it can handle the content.

### Shared packages

| Path | Role |
|---|---|
| `packages/design-system` | JS tokens + generated native artifacts (`native/`) + **MinAppKit** Swift package (spacing, Ideas & bugs, rage shake). |
| `packages/design-studio` | Token / theme browser. `npm run studio` → http://localhost:3100 |
| `packages/agent-kit` | MCP + loopback HTTP gateway. Tokens `minagt_…`. Writes undoable 7 days. |
| `services/min-cloud` | Railway API + admin + web hub for mov/pod (catalog, jobs, accounts, social, notifications, feedback, agent HTTP). |
| `src/onboarding` | Shared web onboarding helpers (legacy web surface). |

Root `package.json` is npm workspaces + Turborepo for the **JS packages only**. Native apps are Xcode projects. Do not point Railway Railpack at the root `package.json` — it has no `start` script. Root `Dockerfile` / `railway.toml` copy `services/min-cloud` into the image.

### Data model (especially mov min)

Three layers. Do not mix them.

1. **Catalog** — movies, sources, streaming, physical media, Closet Picks, theater stays. Bundled in the app (`bootstrap_database.store`). Min Cloud overlays newer catalog / availability when reachable. Catalog is **not** CloudKit.
2. **User status** — Saved, Rewatched, Listened, **I own disc** (`isOwnedDisc`). Local SwiftData, optional iCloud (`UserMovieDataZone`), and Min Cloud library when signed in. Want-to-buy is **Saved and not owned**. There is no `isWantedDisc`.
3. **Live overlay** — theatrical runs, ticket links, now-playing. From Min Cloud `GET /v1/mov/now-playing`, with a local TMDB fallback. Not stored on `MovieData`.

Rules live in `apps/WatchedIt/Docs/DATA_CONTRACT.md` and `PODCAST_INGEST_PARITY_RULE.md`. iOS and tvOS share `WatchedItCore`. Podcast title cleaning / TMDB match must stay aligned across web admin (`bootstrap_web/server.js`), Min Cloud ingest, and `PodcastEpisodeIntakeService.swift`.

### Min Cloud

- Live: https://min-cloud-production.up.railway.app
- Admin: `/admin` (needs `ADMIN_TOKEN`)
- Health: `/health`
- Agent HTTP (VM-reachable): `GET /tools`, `POST /invoke` with `Authorization: Bearer minagt_…`
- Project: https://railway.com/project/eb333f4f-f09f-4ed8-9cfc-eaf4a66f09cf

Local:

```bash
cd services/min-cloud
cp .env.example .env
docker compose up postgres -d
npm install && npm run migrate && npm run seed && npm test && npm run dev
```

Scheduled jobs (when `ENABLE_JOBS=true`): podcast feeds ~30 min, streaming ~6 hours. Admin jobs cover Closet Picks rematch/YouTube attach, theater refresh, disc enrichment, Delta in-flight ingest.

Clients read `UserDefaults` / settings key `mincloud.baseURL` (default production). Apps still work offline.

### Agents

Every min app is agent-ready (read/write + undo). On-device: **Account → Agents**. Remote: Min Cloud `/tools` + `/invoke`, or local `packages/agent-kit` `serve` on `127.0.0.1:4732`. Skill for VM agents: `.cursor/skills/min-apps-agent/SKILL.md`.

Same actions are also App Intents (Siri / Shortcuts).

### Feedback / ideas loop

Users submit from **Account → Ideas & bugs** or by shaking the phone. Min Cloud stores the report, opens a **redacted** GitHub issue, and can ping Cursor to triage → you pick an option → a build agent opens a PR with `Feedback-Id: <uuid>` → merge marks it shipped.

Code is on `master` (`services/min-cloud` feedback routes, MinAppKit Ideas UI, `.github/workflows/feedback-comment.yml` + `feedback-shipped.yml`). **Ops still need finishing** — labels, Railway secrets, GitHub Action secrets, Cursor automations. Checklist: `docs/FEEDBACK.md`. Probe issues `#75` / `#79` are test noise; `#76` is a real pod bug.

### Design rules agents must follow

Always-on Cursor rules in `.cursor/rules/`:

- **Spacing** — `xl` / 24pt screen content margins; `lg` / 16pt floating chrome (toolbars, FABs, account button). Pod/vid 2-column grids: exactly two `.flexible()` columns, `lg` gutters, `xl` outer padding. Canonical: `packages/design-system/swift/Sources/MinAppKit/Tokens/MinSpacing.swift`.
- **Metadata separators** — three ASCII spaces (`"   "`), never `·` / `•` / `|`.

Older docs sometimes say 12pt phone margins. Trust `MinSpacing` and the Cursor rules.

### How to run an app

```bash
npm install                  # design system / studio
npm run build                # regenerate native tokens
open apps/WatchedIt/WatchedIt.xcodeproj
open apps/PodLink/PodLink.xcodeproj
open apps/YourTube/YourTube.xcodeproj
open "apps/Cyclismo/Cyclismo Guide.xcodeproj"
open apps/SpinMin/SpinMin.xcodeproj
```

Xcode 16+, iOS 17+. Cloud agents cannot sign or run the iOS apps here; verify Swift/TS tests and Min Cloud instead, then note what still needs a device.

CI (`.github/workflows/ci.yml`) only builds **SpinMin** on macOS. Do not assume a green CI means mov/pod compiled.

---

## What we have been doing

Recent work (roughly September–October 2026) is concentrated on **mov min + pod min + Min Cloud**, driven by Cursor cloud agents from this repo. Themes, newest first:

### 1. Play: stream, tickets, discs (mov min)

Play used to be “open Netflix.” It is now a **provider menu** that also covers theaters and physical media.

- Current streamers (Netflix, Criterion Channel, etc.) stay on the preferred list; Criterion Channel is kept even when TMDB ranking would hide it.
- **Get tickets** and **Buy disc** are Play submenus, not separate sheets on the detail page. Duplicate “In Theaters” blocks were removed.
- Theater stays + AMC/Fandango/Atom ticket URLs come from Min Cloud (`mov.theaters.refresh`). Client falls back to search URLs.
- **I own disc** is a first-class user status. Want = Saved and unowned. Buy-disc UI is also where you mark owned.
- Search filters for theater / disc were merged into **Streaming**.
- Latest merge: **Delta in-flight** as a default-on streamer, plus the Letterboxd in-flight list on the featured page (`#115`, 1 Oct 2026).

### 2. Criterion Closet Picks (mov min catalog)

Closet Picks is a real WatchedIt source, not a one-off scrape.

- Ingest + rematch to Criterion TMDB titles, with admin progress (`mov.closet.rematch`).
- Newest-drop-first sort; Latest carousel clusters on the newest guest episode (can show more than one recent episode per show).
- Guests are source-style rows on movie detail, all guests linked (not just the first), Watch & Shop permalinks, Criterion C badge.
- YouTube attach job writes `vidmin://watch?v=` / YouTube links.
- Guest names + podcast notes are in movie search.

### 3. Pod min archive and mov → pod deep links

The Rewatchables (and similar) used to be a recent RSS slice. Cloud now serves the **full archive**.

- Full archive in pod min (`#107`).
- Mov min can open an old episode without hitching search (`#108`).
- Fixes: mid-play seek jumping backward; episode dates collapsing to 31 Dec year 1; unfollow leaving shows on the home grid; keep show sheets open after tap; list scroll performance.
- **Not finished:** opening the archive on launch is too expensive, and some deep links still present the show instead of the episode. See open PRs below.

### 4. Min Cloud as the shared backend

Stood up and then hardened:

- Railway GitHub deploys from repo root (`Dockerfile` copies `services/min-cloud`).
- Catalog import/export, snapshots + admin history/revert.
- Incremental `/v1/mov/catalog` and `/v1/pod/catalog`.
- Accounts, library sync (`isSaved` / `isRewatched` / `isListened` / `isOwnedDisc`), anonymous device watch, APNs inbox.
- Admin data-ops for discs (Wikidata) and theater stays.
- Catalog quality: skip BRUNCH / “Available date” junk, unmatched RSS stubs, data-poor movies, Big Picture false matches.
- Mobile-friendly web hub.
- Agent HTTP on the same origin as the user site.

### 5. Shared product chrome

- Ideas & bugs + rage shake in MinAppKit, wired in every app.
- Agent connections + App Intents.
- Status filters on mov min home/search; pod min “downloaded” instead of rewatched.
- Design-system spacing / wordmark / chrome passes (some still in draft PRs).

---

## What is open / what to do next

### Finish first (real user-facing gaps)

1. **Pod min launch stall** — [PR #112](https://github.com/carambula/myrepo/pull/112) (`cursor/podmin-launch-pause-bc74`, draft). After the full-archive work, home / Up Next fetch the entire archive just to find the newest episode. The PR keeps launch on a small recent RSS window and leaves full archive for show detail + deep links. Review, rebase on current `master`, verify launch + Rewatchables Rocky, then merge.
2. **Mov → pod episode presentation** — [PR #109](https://github.com/carambula/myrepo/pull/109) (`cursor/podmin-deeplink-present-bc74`, draft). Tapping Rocky from WatchedIt still opens The Rewatchables without the episode (sheet identity + nested player during animation). Same branch family as the archive work. Pair with #112.
3. **Grid tap dismisses the show** — [issue #76](https://github.com/carambula/myrepo/issues/76) (feedback bug, `app:pod`). “They pop up and pop away before I can do anything.” `#80` already landed “keep sheets open after tapping a show”; this may be a regression or a different path (home grid vs search). Confirm on device before writing another fix. Feedback-Id: `23e5ad87-907e-4534-b053-726993c625e5`.

### Product direction still in motion (no single open PR)

These are the live threads from the last month of agents. Continue in small PRs; do not reopen the large historical branches unless you need a specific commit.

- **Play menu completeness** — stream / tickets / discs should keep feeling like one control. Ticket-link coverage, owned-disc copy, Criterion-as-preferred-streamer.
- **Catalog quality** — Closet Picks rematch, Delta in-flight refresh, physical-media Wikidata, skip junk RSS, podcast ingest parity (web admin ↔ Swift ↔ Min Cloud).
- **Cross-app listen/watch** — mov min sources that are podcasts or YouTube should deep-link into pod min / vid min and land on the right episode/video.
- **Min Cloud ops** — keep Railway deploys green; catalog snapshots before destructive admin; APNs keys if notifications should leave the in-app inbox.
- **Feedback loop go-live** — finish `docs/FEEDBACK.md` checklist (GitHub labels, `FEEDBACK_GITHUB_TOKEN`, Action secrets, Cursor Triage + Iterate automations, `FEEDBACK_CURSOR_API_KEY`). Then close probe issues `#75` and `#79` (they say “ok to delete”).
- **Design consistency** — apply `MinSpacing` / three-space metadata rules wherever chrome or captions still use old 12pt margins or `·`.

### Stale drafts (probably close or rebase-and-decide)

| PR | Notes |
|---|---|
| [#69](https://github.com/carambula/myrepo/pull/69) Ideas & Bugs boards | Early public-vote board. **Superseded** by the GitHub-issue + Cursor loop already on `master`. Close unless you still want the public `/feedback` vote UI. |
| [#43](https://github.com/carambula/myrepo/pull/43) Wordmark padding 24pt | Tiny token tweak from early September. Rebase or drop. |
| [#20](https://github.com/carambula/myrepo/pull/20) RSS HTML entities | May 2026. Still valid for Stratechery-type titles. Rebase onto current `RSSFeedService` or close if already handled. |

Lots of `origin/cursor/…` branches are merged leftovers. Do not treat a remote branch as in-flight unless it has an open PR.

### Suggested order for the next agent

1. Rebase and land **#112** (launch) and **#109** (episode present), or re-implement them on a fresh `cursor/…` branch if they bitrotted.
2. Reproduce **#76** on pod min home grid; fix only if still broken after those PRs.
3. Walk `docs/FEEDBACK.md` secrets/automations so new ideas do not stall at “issue opened, no options.”
4. Only then pick a catalog/Play item (Delta refresh, Closet rematch, ticket links) or a design-token sweep.

---

## Conventions for the next change

- Branch from current `origin/master` (fetch first; this environment’s checkout can be hours behind).
- One concern per PR. Recent successful PRs are small: one Play submenu, one date bug, one ingest source.
- Mov catalog / user-status / ID changes must stay iOS+tvOS compatible (`DATA_CONTRACT.md`).
- Podcast ingest changes land in **all three** surfaces in the same PR.
- Do not put submitter name/email on GitHub issues. Use Min Cloud `GET /internal/feedback/{id}`.
- UI work: 24pt content / 16pt chrome; three spaces in metadata; 2-column flexible grids only.
- After token edits in `packages/design-system/src/tokens/`, run `npm run build` so `native/` Swift/Kotlin/XML update.
- Do not commit secrets. Admin token and agent tokens live in Railway / device keychain.
- Prefer Min Cloud + tests for verification in this VM. Say so if a flow still needs Xcode on a phone.

### Pointers

| Need | Where |
|---|---|
| Repo overview | `README.md` |
| Mov architecture / setup / contract | `apps/WatchedIt/Docs/` |
| Min Cloud API + jobs | `services/min-cloud/README.md` |
| Feedback ops | `docs/FEEDBACK.md` |
| Agent protocol | `packages/agent-kit/README.md` |
| Design tokens | `packages/design-system/README.md`, MinAppKit `MinSpacing.swift` |
| Spacing / metadata rules | `.cursor/rules/` |
| VM movie/podcast tools | `.cursor/skills/min-apps-agent/SKILL.md` |
