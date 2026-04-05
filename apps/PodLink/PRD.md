# PodLink — Podcast App PRD

## Product Vision

PodLink is an iOS podcast app that makes it dead simple to follow, unlock, and listen to podcasts — and then instantly discover and link out to every piece of connected media discussed in each episode. When a host mentions a movie, a sporting event replay, a YouTube clip, an app, a book, or a song, PodLink identifies it and surfaces a tap-to-open link. It uses on-device Apple Intelligence (Core ML / Foundation Models) to analyze transcripts and show notes, extracting entities and matching them to real media.

PodLink inherits its design system, navigation patterns, theming engine, iCloud sync, and interaction behaviors from the sibling apps **WatchedIt** (movie tracker) and **Cyclismo Guide** (cycling race guide).

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Project Structure](#2-project-structure)
3. [Design System (Shared Pattern)](#3-design-system)
4. [Theme Engine (Shared Pattern)](#4-theme-engine)
5. [Data Models](#5-data-models)
6. [Core Services](#6-core-services)
7. [Views & Navigation](#7-views--navigation)
8. [Audio & Video Playback](#8-audio--video-playback)
9. [Media Linking Engine](#9-media-linking-engine)
10. [AI / On-Device Intelligence](#10-ai--on-device-intelligence)
11. [iCloud Sync](#11-icloud-sync)
12. [Onboarding](#12-onboarding)
13. [Account & Settings](#13-account--settings)
14. [Build Phases](#14-build-phases)
15. [API & External Services](#15-api--external-services)
16. [File-by-File Implementation Guide](#16-file-by-file-implementation-guide)

---

## 1. Architecture Overview

### Platform
- **iOS 17+** (required for Apple Intelligence APIs, `@Observable`, modern SwiftUI)
- **Swift 6** with strict concurrency
- **SwiftUI** only — no UIKit except for scroll introspection (same pattern as WatchedIt's `BottomSheetPullToDismiss.swift`)

### Pattern: MVVM + Services
```
View → ViewModel (@Observable) → Service → Data Store / Network
```

All data flows through `@Observable` classes. Views bind to published state. Services are injected via the environment. No Combine — use Swift concurrency (`async/await`, `AsyncSequence`).

### Dependency Management
- **Zero third-party dependencies** for core features. Use only Apple frameworks:
  - `AVFoundation` / `AVKit` — audio and video playback
  - `MediaPlayer` — Now Playing info, remote commands
  - `BackgroundTasks` — background refresh
  - `NaturalLanguage` — entity extraction from transcripts
  - `CoreML` — on-device model inference
  - `CloudKit` — iCloud sync
  - `SwiftData` — local persistence (or raw `CloudKit` containers matching WatchedIt pattern)
  - `WebKit` — in-app web views for linked media
  - `StoreKit 2` — if premium features are added later

### Shared Patterns from WatchedIt & Cyclismo

| Pattern | WatchedIt File | PodLink Equivalent |
|---------|---------------|-------------------|
| Design tokens | `DesignSystem.swift` | `DesignSystem.swift` (identical structure) |
| Theme engine | `ThemeManager.swift` | `ThemeManager.swift` (identical structure) |
| Theme builder | `ThemesView.swift`, `ThemeBuilderView.swift` | Same |
| Bottom sheets | `MovieDetailView.swift` | `EpisodeDetailView.swift` |
| Pull-to-dismiss | `BottomSheetPullToDismiss.swift` | Same file, reused |
| Glass toolbar | `MovieListView.swift` toolbar code | `PodcastListView.swift` toolbar |
| Search bar styles | `SearchScreenView.swift` | Same patterns |
| Toolbar behaviors | Toolbar behavior settings | Same |
| Tap interactions | `TapInteractionBehaviors.swift` | Same file, reused |
| Account sheet | `AccountSheetView.swift` | Same structure |
| iCloud sync | `@AppStorage` + CloudKit | Same approach |
| Onboarding | `NewUserExperienceView.swift` | `OnboardingView.swift` |
| Poster grid | `MovieListView.swift` grid | `PodcastGridView.swift` |
| Collection headers | `CollectionsHomeView.swift` | `CategoriesHomeView.swift` |

---

## 2. Project Structure

```
PodLink/
├── PodLinkApp.swift                    # App entry point, scene setup
├── ContentView.swift                   # Root view with tab/navigation state
│
├── DesignSystem/
│   ├── DesignSystem.swift              # Typography, colors, spacing, radius tokens
│   ├── ThemeManager.swift              # Theme protocol, built-in themes, custom themes
│   ├── ThemesView.swift                # Theme browser & preview
│   ├── ThemeBuilderView.swift          # Custom theme creator/editor
│   └── GlassComponents.swift          # Glass material modifiers, button styles
│
├── Models/
│   ├── Podcast.swift                   # Podcast show model
│   ├── Episode.swift                   # Episode model (audio URL, show notes, transcript)
│   ├── MediaLink.swift                 # Linked media entity (movie, app, video, etc.)
│   ├── PlaybackState.swift             # Current playback position, queue
│   ├── UserSubscription.swift          # User's followed podcasts + auth state
│   └── Category.swift                  # Genre/category taxonomy
│
├── Services/
│   ├── PodcastSearchService.swift      # Apple Podcasts Search API / iTunes API
│   ├── RSSFeedService.swift            # RSS/Atom feed parser for episodes
│   ├── PlaybackService.swift           # AVPlayer wrapper, Now Playing, PiP
│   ├── MediaLinkingService.swift       # Entity extraction → media resolution
│   ├── TranscriptService.swift         # Fetch/generate transcripts
│   ├── AIEntityExtractor.swift         # On-device NLP + Core ML inference
│   ├── YouTubeService.swift            # YouTube oEmbed + search for clips
│   ├── AppStoreService.swift           # App Store lookup for mentioned apps
│   ├── TMDBService.swift               # Movie/TV lookups (same as WatchedIt)
│   ├── SpotifyService.swift            # Song/album lookups
│   ├── SyncService.swift               # iCloud sync orchestration
│   ├── CacheService.swift              # Unified disk + memory cache
│   ├── ImageService.swift              # Async image loading + caching
│   └── AuthService.swift               # Podcast platform auth (Patreon, etc.)
│
├── ViewModels/
│   ├── PodcastListViewModel.swift      # Main list state, filtering, search
│   ├── EpisodeDetailViewModel.swift    # Episode detail + media links
│   ├── PlayerViewModel.swift           # Playback controls, queue management
│   ├── SearchViewModel.swift           # Podcast discovery search
│   └── OnboardingViewModel.swift       # Onboarding flow state
│
├── Views/
│   ├── Main/
│   │   ├── PodcastListView.swift       # Main grid/list of followed podcasts
│   │   ├── PodcastRowView.swift        # Single podcast row in list
│   │   ├── CategoriesHomeView.swift    # Category-based browsing
│   │   └── CollectionHeaderView.swift  # Section headers (tap to filter)
│   │
│   ├── Detail/
│   │   ├── PodcastDetailView.swift     # Podcast show detail (bottom sheet)
│   │   ├── EpisodeDetailView.swift     # Episode detail with media links
│   │   ├── EpisodeRowView.swift        # Episode list item
│   │   └── MediaLinkCardView.swift     # Linked media card (movie, video, app)
│   │
│   ├── Player/
│   │   ├── MiniPlayerView.swift        # Persistent mini player bar
│   │   ├── FullPlayerView.swift        # Full-screen player (bottom sheet)
│   │   ├── VideoPlayerView.swift       # Video playback with PiP support
│   │   ├── QueueView.swift             # Up next / queue management
│   │   └── SleepTimerView.swift        # Sleep timer controls
│   │
│   ├── Search/
│   │   ├── SearchScreenView.swift      # Search overlay/sheet
│   │   ├── SearchResultsView.swift     # Search results grid
│   │   └── FilterBarView.swift         # Filter tokens (genre, recency, etc.)
│   │
│   ├── Account/
│   │   ├── AccountSheetView.swift      # Settings hub (bottom sheet)
│   │   ├── AppearanceSettingsView.swift # Toolbar behavior, tap interactions, etc.
│   │   ├── PlaybackSettingsView.swift   # Playback speed, skip intervals, auto-play
│   │   ├── NotificationSettingsView.swift # New episode alerts
│   │   └── ConnectedAccountsView.swift # Patreon, YouTube, Spotify links
│   │
│   ├── Onboarding/
│   │   ├── OnboardingView.swift        # Welcome flow
│   │   ├── PodcastPickerView.swift     # Select initial podcasts to follow
│   │   └── FeatureHighlightView.swift  # Highlight media linking feature
│   │
│   └── Shared/
│       ├── BottomSheetPullToDismiss.swift  # Pull-to-dismiss modifier (from WatchedIt)
│       ├── TapInteractionBehaviors.swift   # Bounce, ripple, shimmer, glow (from WatchedIt)
│       ├── ToolbarBehaviorManager.swift    # Static, minimize, corners, show/hide
│       ├── SearchBarStyles.swift           # Classic, solid, elevated, glass
│       └── AsyncCachedImage.swift          # Async image with disk cache
│
├── Extensions/
│   ├── Color+Theme.swift               # Color convenience extensions
│   ├── View+Glass.swift                # Glass material view modifiers
│   ├── Date+Formatting.swift           # Relative date formatting
│   ├── String+Parsing.swift            # HTML stripping, entity cleaning
│   └── URL+Schemes.swift              # Deep link / universal link handling
│
└── Resources/
    ├── Assets.xcassets                  # App icon, accent color
    ├── DefaultPodcasts.json            # Curated starter podcast list
    └── MediaPatterns.json              # Regex/NLP patterns for entity extraction
```

---

## 3. Design System

Port the `DesignSystem.swift` structure from WatchedIt exactly. It provides:

### Typography
```swift
struct Typography {
    static func displayLarge() -> Font   // 34pt, theme headline font
    static func displayMedium() -> Font  // 28pt
    static func headlineLarge() -> Font  // 22pt
    static func headlineMedium() -> Font // 20pt
    static func headlineSmall() -> Font  // 17pt
    static func bodyLarge() -> Font      // 17pt, system default
    static func bodyMedium() -> Font     // 15pt
    static func bodySmall() -> Font      // 13pt
    static func caption() -> Font        // 11pt
}
```

When a theme specifies a custom headline font (e.g., Batman theme uses condensed bold sans-serif), all `display*` and `headline*` functions return that font. Body and caption always use the system font.

### Colors
```swift
struct Colors {
    static var accent: Color          // From active theme
    static var background: Color      // Adaptive light/dark
    static var surface: Color         // Card/sheet backgrounds
    static var textPrimary: Color
    static var textSecondary: Color
    static var divider: Color
    static var error: Color
}
```

### Spacing
```swift
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
```

### Radius
```swift
struct Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let capsule: CGFloat = 100
}
```

### Toolbar Spacing
Default `36px` between toolbar icons (matching WatchedIt's updated default).

---

## 4. Theme Engine

Port `ThemeManager.swift` from WatchedIt. Structure:

```swift
protocol AppTheme {
    var id: String { get }
    var name: String { get }
    var accentColor: Color { get }
    var backgroundTint: Color { get }
    var headlineFont: Font? { get }          // nil = system default
    var headlineFontDesign: Font.Design { get }
    var headlineFontWeight: Font.Weight { get }
    var headlineColor: Color? { get }        // nil = use textPrimary
    var isDark: Bool { get }
}

@Observable
class ThemeManager {
    static let shared = ThemeManager()
    var currentTheme: AppTheme
    var themes: [AppTheme]           // Built-in + custom
    var customThemes: [CustomTheme]  // User-created, synced via iCloud
}
```

### Built-in Themes
1. **Default** — System blue accent, no custom font
2. **Midnight** — Deep purple accent, dark mode optimized
3. **Coral** — Warm coral/orange accent
4. **Forest** — Deep green accent
5. **Ocean** — Teal/cyan accent
6. **Sunset** — Orange-to-pink accent gradient
7. **I'm Batman** — Yellow accent, dark navy backgrounds, condensed bold sans-serif headlines (ported from WatchedIt)

### Custom Theme Builder
Same `ThemeBuilderView` pattern — user picks accent color, background tint, headline font from a list of options. Saved to iCloud.

---

## 5. Data Models

### Podcast
```swift
struct Podcast: Identifiable, Codable, Hashable {
    let id: String                      // Unique identifier (iTunes ID or feed URL hash)
    let title: String
    let author: String
    let description: String
    let feedURL: URL
    let artworkURL: URL?
    let artworkURL600: URL?             // High-res artwork
    let categories: [String]
    let language: String
    let isExplicit: Bool
    let websiteURL: URL?
    let itunesID: String?

    // User state (synced via iCloud)
    var isFollowed: Bool = false
    var notificationsEnabled: Bool = false
    var autoDownload: Bool = false
    var preferVideo: Bool = false        // Opt into video streaming when available
    var customPlaybackSpeed: Float?      // Per-podcast speed override
}
```

### Episode
```swift
struct Episode: Identifiable, Codable, Hashable {
    let id: String                      // GUID from RSS
    let podcastID: String               // Parent podcast
    let title: String
    let description: String             // HTML show notes
    let publishDate: Date
    let duration: TimeInterval
    let audioURL: URL
    let videoURL: URL?                  // If podcast supports video
    let artworkURL: URL?                // Episode-specific artwork
    let episodeNumber: Int?
    let seasonNumber: Int?
    let transcript: String?             // Plain text transcript
    let transcriptURL: URL?             // URL to transcript file
    let chapters: [Chapter]?            // Podcast chapters (if supported)

    // User state
    var playbackPosition: TimeInterval = 0
    var isPlayed: Bool = false
    var isBookmarked: Bool = false
    var isDownloaded: Bool = false
    var downloadedFileURL: URL?

    // Extracted media links (populated by AI/NLP)
    var mediaLinks: [MediaLink] = []
}
```

### Chapter
```swift
struct Chapter: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let startTime: TimeInterval
    let endTime: TimeInterval?
    let imageURL: URL?
    let linkURL: URL?
}
```

### MediaLink
```swift
struct MediaLink: Identifiable, Codable, Hashable {
    let id: String
    let type: MediaLinkType
    let title: String
    let subtitle: String?               // e.g., "2011 film" or "Season 3, Episode 5"
    let imageURL: URL?
    let destinationURL: URL             // Deep link or web URL
    let appSchemeURL: URL?              // Direct app open (e.g., netflix://)
    let confidence: Float               // AI confidence score (0-1)
    let timestamp: TimeInterval?        // When it was mentioned in the episode
    let sourceText: String?             // The text that triggered this link

    enum MediaLinkType: String, Codable {
        case movie
        case tvShow
        case sportingEvent
        case sportingReplay
        case youtubeVideo
        case youtubeChannel
        case app
        case book
        case song
        case album
        case podcast                    // Cross-podcast reference
        case website
        case product
        case person
    }
}
```

### PlaybackState
```swift
@Observable
class PlaybackState {
    var currentEpisode: Episode?
    var isPlaying: Bool = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var queue: [Episode] = []
    var isVideoMode: Bool = false
    var isPiPActive: Bool = false
    var sleepTimerEnd: Date?
}
```

### UserSubscription
```swift
struct UserSubscription: Identifiable, Codable {
    let id: String
    let podcastID: String
    let platform: SubscriptionPlatform?
    var isAuthenticated: Bool = false
    var accessToken: String?             // Stored in Keychain, not synced

    enum SubscriptionPlatform: String, Codable {
        case patreon
        case applePodcasts
        case spotify
        case memberful
        case supercast
        case glow
        case custom                      // Direct RSS with auth
    }
}
```

---

## 6. Core Services

### 6.1 PodcastSearchService
```swift
actor PodcastSearchService {
    // Uses iTunes Search API: https://itunes.apple.com/search?term=X&media=podcast
    func search(query: String, limit: Int = 25) async throws -> [Podcast]
    func lookup(itunesID: String) async throws -> Podcast?
    func topPodcasts(genre: String?, limit: Int) async throws -> [Podcast]
}
```

### 6.2 RSSFeedService
```swift
actor RSSFeedService {
    // Parses RSS 2.0 / Atom feeds with podcast namespace extensions
    func fetchEpisodes(feedURL: URL) async throws -> [Episode]
    func fetchPodcastMetadata(feedURL: URL) async throws -> Podcast

    // Handles:
    // - <enclosure> for audio/video URLs
    // - <itunes:image> for artwork
    // - <podcast:transcript> for transcript URLs
    // - <podcast:chapters> for chapter markers
    // - YouTube RSS feeds (same pattern as Cyclismo's PodcastEpisodeFeedService)
    // - Authentication headers for paid feeds
}
```

Key implementation detail from Cyclismo: YouTube feeds use `https://www.youtube.com/feeds/videos.xml?channel_id=X` format. Parse `<media:group>` for video thumbnails and `<yt:videoId>` for video URLs.

### 6.3 PlaybackService
```swift
@Observable
class PlaybackService {
    static let shared = PlaybackService()

    let state: PlaybackState

    // Core playback
    func play(episode: Episode, startAt: TimeInterval?) async
    func pause()
    func resume()
    func seek(to time: TimeInterval)
    func skipForward(seconds: TimeInterval = 30)
    func skipBackward(seconds: TimeInterval = 15)
    func setRate(_ rate: Float)

    // Queue management
    func addToQueue(_ episode: Episode)
    func removeFromQueue(_ episode: Episode)
    func playNext(_ episode: Episode)
    func clearQueue()

    // Video
    func enableVideoPlayback()           // Switch to video stream if available
    func disableVideoPlayback()          // Audio-only mode
    func enablePiP()
    func disablePiP()

    // Background audio
    func configureAudioSession()          // AVAudioSession.sharedInstance()
    func updateNowPlayingInfo()           // MPNowPlayingInfoCenter
    func configureRemoteCommands()        // MPRemoteCommandCenter

    // Sleep timer
    func setSleepTimer(minutes: Int)
    func cancelSleepTimer()

    // Persistence
    func savePlaybackPosition() async     // Debounced, every 10 seconds
}
```

**Implementation requirements:**
- Use `AVPlayer` for audio, `AVPlayerViewController` for video with PiP
- Configure `AVAudioSession` category `.playback` with `.mixWithOthers` option
- Set `UIBackgroundModes` to `audio` in Info.plist
- Register remote commands: play, pause, skipForward, skipBackward, changePlaybackPosition
- Update `MPNowPlayingInfoCenter` with artwork, title, duration, elapsed time, rate
- PiP via `AVPictureInPictureController` for custom player or `AVPlayerViewController.allowsPictureInPicturePlayback`

### 6.4 MediaLinkingService
```swift
actor MediaLinkingService {
    // Orchestrates entity extraction → media resolution
    func extractMediaLinks(from episode: Episode) async -> [MediaLink]

    // Pipeline:
    // 1. Parse show notes HTML for explicit links
    // 2. Parse episode title for media references
    // 3. If transcript available, run NLP entity extraction
    // 4. For each entity, resolve to a concrete media link:
    //    - Movies/TV → TMDBService
    //    - YouTube → YouTubeService
    //    - Apps → AppStoreService
    //    - Music → SpotifyService / Apple Music
    //    - Sports → match known leagues/events
    //    - Books → Google Books API or Open Library
    // 5. Deduplicate and rank by confidence
    // 6. Cache results
}
```

### 6.5 TranscriptService
```swift
actor TranscriptService {
    // Fetch transcripts from multiple sources
    func getTranscript(for episode: Episode) async -> String?

    // Sources (in priority order):
    // 1. <podcast:transcript> tag in RSS (SRT, VTT, or plain text)
    // 2. YouTube auto-generated captions (via timedtext API)
    // 3. Apple's on-device speech recognition (Speech framework)
    //    - Only if user opts in
    //    - Runs in background
    //    - Cached locally
}
```

### 6.6 AIEntityExtractor
```swift
actor AIEntityExtractor {
    // Uses Apple's NaturalLanguage framework + Core ML
    func extractEntities(from text: String) async -> [ExtractedEntity]

    struct ExtractedEntity {
        let text: String
        let type: EntityType       // .movie, .person, .app, .song, etc.
        let confidence: Float
        let range: Range<String.Index>
    }

    // Implementation approach:
    // 1. NLTagger with .nameType, .organizationName, .placeName schemes
    // 2. Custom NLP patterns (regex + context) for:
    //    - Movie titles: "we're talking about [Title] (year)"
    //    - Apps: "download [App] from the App Store"
    //    - YouTube: "check out our YouTube", "linked in description"
    //    - Songs: "playing [Song] by [Artist]"
    // 3. Core ML model for higher accuracy entity classification
    //    - Can use CreateML to train on podcast transcript data
    //    - Or leverage Apple Intelligence foundation models (iOS 18.4+)

    // For Apple Intelligence integration (iOS 18.4+):
    // Use the Foundation Models framework to run on-device LLM inference
    // Prompt: "Extract all media references from this podcast transcript segment.
    //          Return JSON with title, type, year (if mentioned), confidence."
}
```

### 6.7 YouTubeService
```swift
actor YouTubeService {
    // YouTube integration (same pattern as Cyclismo)
    func searchVideos(query: String, limit: Int) async throws -> [MediaLink]
    func getChannelArtwork(channelID: String) async throws -> URL?
    func getVideoThumbnail(videoID: String) -> URL

    // Uses:
    // - YouTube oEmbed API (no auth needed): https://www.youtube.com/oembed?url=...&format=json
    // - YouTube Data API v3 (if API key available) for search
    // - Fallback: construct thumbnail URLs directly: https://img.youtube.com/vi/{id}/maxresdefault.jpg
}
```

### 6.8 SyncService (iCloud)
```swift
actor SyncService {
    // Mirrors WatchedIt's iCloud sync pattern
    // Uses NSUbiquitousKeyValueStore for preferences
    // Uses CloudKit for larger data (subscriptions, playback positions)

    func syncSubscriptions() async
    func syncPlaybackPositions() async
    func syncThemePreferences() async
    func syncSettings() async
}
```

Preferences that sync via `@AppStorage` with `UserDefaults` + `NSUbiquitousKeyValueStore`:
- Theme selection
- Search bar appearance style
- Toolbar behavior
- Tap interaction style
- Glass component style
- Playback speed
- Skip intervals
- Auto-play next
- Video streaming preference

Heavier data via CloudKit:
- Followed podcasts list
- Episode playback positions
- Bookmarked episodes
- Downloaded episodes metadata
- Custom themes
- Queue state

---

## 7. Views & Navigation

### 7.1 App Structure
```
PodLinkApp
└── ContentView
    ├── PodcastListView (main view, always visible)
    │   ├── Glass toolbar (bottom)
    │   │   ├── Filter buttons (genre, recency, etc.)
    │   │   ├── Search button
    │   │   └── Account button
    │   ├── Podcast grid/list
    │   └── MiniPlayerView (above toolbar, when playing)
    │
    ├── .sheet → PodcastDetailView
    │   └── Episode list → .sheet → EpisodeDetailView
    │       └── Media links section
    │
    ├── .sheet → FullPlayerView
    │   ├── Now playing controls
    │   ├── Chapter list
    │   ├── Media links (for current episode)
    │   ├── Queue
    │   └── Sleep timer
    │
    ├── .sheet → SearchScreenView
    │   ├── Search input (glass bar)
    │   ├── Filter tokens
    │   └── Results grid
    │
    └── .sheet → AccountSheetView
        ├── Themes
        ├── Appearance (toolbar, search bar, tap interactions, glass style)
        ├── Playback settings
        ├── Connected accounts
        └── Notifications
```

### 7.2 PodcastListView (Main View)

The primary view — shows followed podcasts with latest episodes. Matches WatchedIt's `MovieListView` pattern.

**Layout modes** (user preference):
1. **Grid** — Podcast artwork in a grid (like WatchedIt's poster grid). Configurable poster size (+10% to +60%).
2. **List** — Artwork thumbnail + podcast name + latest episode title + date
3. **Episodes** — Chronological feed of all new episodes across all followed podcasts

**Toolbar** (glass effect, bottom of screen):
- Filter buttons: Genre, Recency (Today/This Week/This Month), Has New, Has Unplayed
- Search button (opens search sheet)
- Account button (opens account sheet)

**Toolbar behaviors** (from WatchedIt):
1. Static — always visible
2. Minimize to pill on scroll down
3. Minimize to corners on scroll down
4. Simple show/hide on scroll

### 7.3 PodcastDetailView (Bottom Sheet)

Opens as a bottom sheet (`.sheet` presentation). Shows:

1. **Header** — Large artwork, podcast title, author, follow/unfollow button
2. **Action bar** — Play latest, Notifications toggle, Settings, Share
3. **Episode list** — Scrollable list of all episodes
   - Each row: episode artwork (if different), title, date, duration, play button
   - Played indicator, bookmark icon, download icon
4. **Description** — Expandable podcast description
5. **Sources & Links** — Website, social media links

Uses `.bottomSheetPullToDismiss()` modifier. Supports all detail layout styles from WatchedIt (Classic, Compact, Split, Poster Focus, Cinematic).

### 7.4 EpisodeDetailView (Bottom Sheet)

Opens from an episode row. Shows:

1. **Header** — Episode artwork or podcast artwork, title, date, duration
2. **Play controls** — Large play button, progress bar, speed control
3. **Show notes** — Rendered HTML with tappable links
4. **Media links section** — Cards for each identified media reference:
   - Movie card: poster, title, year, "Open in TMDB" / "Stream on Netflix"
   - YouTube card: thumbnail, title, "Watch on YouTube"
   - App card: icon, name, "Open in App Store"
   - Music card: album art, song, artist, "Listen on Spotify/Apple Music"
5. **Chapters** — If available, chapter list with timestamps
6. **Transcript** — Expandable transcript with highlighted media mentions

### 7.5 Player Views

**MiniPlayerView** — Persistent bar above the toolbar:
- Podcast artwork (small), episode title, play/pause button, close button
- Tap to expand to FullPlayerView
- Swipe left to skip forward, right to skip backward

**FullPlayerView** — Full-screen bottom sheet:
- Large artwork (or video player if video mode)
- Episode title, podcast name
- Progress scrubber with elapsed/remaining time
- Play/pause, skip forward (30s), skip backward (15s)
- Speed control (0.5x, 0.75x, 1x, 1.25x, 1.5x, 1.75x, 2x, 2.5x, 3x)
- AirPlay button
- Sleep timer button
- Queue button
- Share button
- **Media links carousel** — Horizontal scroll of identified media for current episode
- **Chapter navigation** — Jump between chapters

**VideoPlayerView** — For video podcasts:
- Inline video player using `AVPlayerViewController`
- PiP support via `allowsPictureInPicturePlayback = true`
- Toggle between video and audio-only mode
- Supports background playback when user leaves the app

### 7.6 Search

**SearchScreenView** — Same glass search bar patterns as WatchedIt:
- Four search bar appearance styles (Classic, Solid, Elevated, Glass)
- Debounced search (300ms) with background filtering
- Search scope: My Library (followed podcasts) or Discover (iTunes Search API)
- Filter tokens: Genre, Has Video, Is Paid, Recently Updated

When searching "My Library", filter across:
- Podcast titles
- Episode titles
- Show notes content
- Media link titles (search "Marvel" to find episodes that discuss Marvel movies)

### 7.7 Onboarding

**OnboardingView** — Welcome flow:
1. **Welcome screen** — App intro with key feature highlight (media linking)
2. **Podcast picker** — Curated grid of popular podcasts to follow
   - Categories: Comedy, News, Sports, Tech, True Crime, Culture, Business
   - Pre-populated from `DefaultPodcasts.json`
3. **Connected accounts** — Optional: link Patreon, premium podcast platforms
4. **Permissions** — Notifications for new episodes, background refresh
5. **Theme picker** — Choose initial theme (same as WatchedIt)

---

## 8. Audio & Video Playback

### Audio Session Configuration
```swift
func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .spokenAudio, options: [])
    try session.setActive(true)
}
```

### Now Playing Integration
```swift
func updateNowPlayingInfo() {
    var info = [String: Any]()
    info[MPMediaItemPropertyTitle] = episode.title
    info[MPMediaItemPropertyArtist] = podcast.title
    info[MPMediaItemPropertyPlaybackDuration] = episode.duration
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
    info[MPNowPlayingInfoPropertyPlaybackRate] = playbackRate
    // Load and set artwork
    info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: size) { _ in image }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
}
```

### Remote Command Center
```swift
func configureRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { _ in self.resume(); return .success }
    center.pauseCommand.addTarget { _ in self.pause(); return .success }
    center.skipForwardCommand.preferredIntervals = [30]
    center.skipForwardCommand.addTarget { _ in self.skipForward(); return .success }
    center.skipBackwardCommand.preferredIntervals = [15]
    center.skipBackwardCommand.addTarget { _ in self.skipBackward(); return .success }
    center.changePlaybackPositionCommand.addTarget { event in
        let e = event as! MPChangePlaybackPositionCommandEvent
        self.seek(to: e.positionTime)
        return .success
    }
}
```

### Picture in Picture
```swift
// For video playback
let pipController = AVPictureInPictureController(playerLayer: playerLayer)
pipController.canStartPictureInPictureAutomaticallyFromInline = true
```

### Info.plist Requirements
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>fetch</string>
</array>
```

---

## 9. Media Linking Engine

The core differentiator. Pipeline for extracting and resolving media references:

### Step 1: Parse Show Notes
```swift
func parseShowNotes(_ html: String) -> [RawMediaReference] {
    // Extract explicit links (<a href="...">) and their anchor text
    // Match known domains:
    //   - youtube.com, youtu.be → YouTube video
    //   - netflix.com, hulu.com, etc. → Streaming link
    //   - apps.apple.com → App Store
    //   - spotify.com, music.apple.com → Music
    //   - imdb.com, tmdb.org → Movie/TV
    //   - amazon.com/dp/ → Product/Book
    // Extract plain text mentions near link clusters
}
```

### Step 2: Parse Episode Title
```swift
func parseTitle(_ title: String) -> [RawMediaReference] {
    // Common patterns:
    // "Ep 42: We Rewatched 'Jaws' (1975)"
    // "Interview with Steven Spielberg"
    // "'Crazy Stupid Love' with Ryan Gosling"
    // "Best Apps of 2026"
    // "Super Bowl LIX Recap"
    // Extract quoted titles, years, person names
}
```

### Step 3: NLP Entity Extraction (from transcript)
```swift
func extractFromTranscript(_ text: String) -> [RawMediaReference] {
    // Use NLTagger for named entity recognition
    // Custom rules for media-specific patterns
    // Apple Intelligence Foundation Models for complex extraction
    // Return entities with confidence scores and timestamps
}
```

### Step 4: Resolution
```swift
func resolve(_ ref: RawMediaReference) async -> MediaLink? {
    switch ref.likelyType {
    case .movie, .tvShow:
        return await TMDBService.search(title: ref.text, year: ref.year)
    case .youtubeVideo:
        return await YouTubeService.resolve(ref.url ?? ref.text)
    case .app:
        return await AppStoreService.search(name: ref.text)
    case .song, .album:
        return await SpotifyService.search(ref.text)
    case .book:
        return await BookService.search(ref.text)
    case .sportingEvent:
        return await SportsService.resolve(ref.text, date: ref.date)
    default:
        return MediaLink(type: .website, title: ref.text, destinationURL: ref.url)
    }
}
```

### Step 5: Deduplication & Ranking
- Remove duplicates by normalized title
- Merge confidence scores from multiple extraction passes
- Rank by: explicit link > title mention > high-confidence NLP > low-confidence NLP
- Filter out below threshold (configurable, default 0.5)

---

## 10. AI / On-Device Intelligence

### Apple Intelligence Integration (iOS 18.4+)

Use the Foundation Models framework for on-device LLM inference:

```swift
import FoundationModels

actor SmartExtractor {
    func extractMediaReferences(from transcript: String) async throws -> [MediaLink] {
        let session = LanguageModelSession()

        let prompt = """
        Analyze this podcast transcript segment. Extract all references to:
        - Movies or TV shows (include year if mentioned)
        - YouTube videos or channels
        - Mobile apps or websites
        - Songs, albums, or artists
        - Sporting events or replays
        - Books
        - Products

        Return as JSON array: [{"title": "...", "type": "movie|tvShow|youtube|app|song|book|sport|product", "year": null, "confidence": 0.9}]

        Transcript:
        \(transcript.prefix(4000))
        """

        let response = try await session.respond(to: prompt)
        return parseResponse(response.content)
    }
}
```

### Fallback for Older Devices
For devices without Apple Intelligence:
1. `NLTagger` with `.nameType` scheme for named entity recognition
2. Custom regex patterns in `MediaPatterns.json`
3. Keyword matching against known media databases
4. Show notes link parsing (always works, no AI needed)

### Privacy
- All AI processing happens on-device
- No transcript data leaves the phone
- User can disable AI features in settings
- Clear indicator when AI is processing

---

## 11. iCloud Sync

### Strategy (matches WatchedIt pattern)

**Light data — `@AppStorage` + `NSUbiquitousKeyValueStore`:**
```swift
@AppStorage("selectedTheme") var selectedTheme: String = "default"
@AppStorage("searchBarAppearance") var searchBarAppearance: String = "glass"
@AppStorage("toolbarBehavior") var toolbarBehavior: String = "static"
@AppStorage("tapInteraction") var tapInteraction: String = "bounce"
@AppStorage("glassComponentStyle") var glassComponentStyle: String = "premium"
@AppStorage("playbackSpeed") var playbackSpeed: Float = 1.0
@AppStorage("skipForwardInterval") var skipForwardInterval: Int = 30
@AppStorage("skipBackwardInterval") var skipBackwardInterval: Int = 15
@AppStorage("autoPlayNext") var autoPlayNext: Bool = true
@AppStorage("preferVideoPlayback") var preferVideoPlayback: Bool = false
@AppStorage("layoutMode") var layoutMode: String = "grid"
@AppStorage("posterSize") var posterSize: String = "plus60"
```

**Heavy data — CloudKit private database:**
```swift
// CKContainer.default().privateCloudDatabase
// Record types:
// - "Subscription" (podcastID, feedURL, settings)
// - "PlaybackPosition" (episodeID, position, lastUpdated)
// - "Bookmark" (episodeID, timestamp)
// - "CustomTheme" (name, accentColor, backgroundTint, font)
// - "QueueItem" (episodeID, position, addedDate)
```

---

## 12. Onboarding

### Flow (matches WatchedIt's `NewUserExperienceView` pattern)

```
Screen 1: Welcome
  "PodLink"
  "Your podcasts. Connected to everything."
  [Get Started]

Screen 2: Pick Podcasts
  Grid of popular podcast artwork
  Categories: Comedy, News, Sports, Tech, True Crime, Culture
  Tap to follow (multi-select)
  [Continue] (minimum 1 selection)

Screen 3: Premium Podcasts (Optional)
  "Have premium podcast subscriptions?"
  [Connect Patreon] [Connect Supercast] [Skip]

Screen 4: Notifications
  "Get notified when new episodes drop?"
  [Enable Notifications] [Not Now]

Screen 5: Choose Your Look
  Theme grid (same as WatchedIt ThemesView)
  [Done]
```

---

## 13. Account & Settings

### AccountSheetView Structure
```
Account
├── Appearance
│   ├── Themes → ThemesView
│   ├── Create Theme → ThemeBuilderView
│   ├── Search Bar Appearance (Classic/Solid/Elevated/Glass)
│   ├── Toolbar & Button Style (Standard/Enhanced/Premium)
│   ├── Toolbar Behavior (Static/Minimize/Corners/Show-Hide)
│   ├── Tap Interactions (Bounce/Ripple/Shimmer/Glow)
│   ├── Layout Mode (Grid/List/Episodes Feed)
│   ├── Podcast Detail Layout (Classic/Compact/Split/Poster Focus/Cinematic)
│   └── Artwork Size (+10% to +60%)
│
├── Playback
│   ├── Default Speed (0.5x - 3x slider)
│   ├── Skip Forward Interval (10/15/30/45/60s)
│   ├── Skip Backward Interval (5/10/15/30s)
│   ├── Auto-Play Next Episode (toggle)
│   ├── Stream Video When Available (toggle)
│   ├── Background Video Playback (toggle)
│   ├── Continuous Play (toggle)
│   └── Trim Silence (toggle)
│
├── Connected Accounts
│   ├── Patreon (connect/disconnect)
│   ├── Supercast
│   ├── Supporting Cast
│   └── Custom RSS (add authenticated feed)
│
├── Downloads
│   ├── Auto-Download New Episodes (toggle, per-podcast)
│   ├── Download on Wi-Fi Only (toggle)
│   ├── Auto-Delete Played (toggle)
│   ├── Storage Used (display + clear)
│   └── Download Quality (Standard/High)
│
├── Notifications
│   ├── New Episodes (toggle)
│   ├── Download Complete (toggle)
│   └── Per-Podcast Overrides
│
├── Media Linking
│   ├── Auto-Extract Media Links (toggle)
│   ├── Use AI for Transcript Analysis (toggle)
│   ├── Link Types to Show (checkboxes for each MediaLinkType)
│   └── Minimum Confidence Threshold (slider)
│
└── About
    ├── Version
    ├── Privacy Policy
    ├── Send Feedback
    └── Rate on App Store
```

---

## 14. Build Phases

### Phase 1: Core Playback App
**Goal:** Functional podcast player with follow, search, play, background audio.

Files to implement:
1. `PodLinkApp.swift` — App entry, audio session
2. `ContentView.swift` — Root navigation
3. `DesignSystem.swift` — Full design token system
4. `ThemeManager.swift` — Theme engine with built-in themes
5. `Podcast.swift`, `Episode.swift` — Core models
6. `PodcastSearchService.swift` — iTunes Search API
7. `RSSFeedService.swift` — RSS feed parsing
8. `PlaybackService.swift` — AVPlayer, Now Playing, remote commands, background audio
9. `PodcastListView.swift` — Main view with grid/list
10. `PodcastDetailView.swift` — Show detail (bottom sheet)
11. `EpisodeDetailView.swift` — Episode detail
12. `MiniPlayerView.swift` — Persistent mini player
13. `FullPlayerView.swift` — Full player sheet
14. `SearchScreenView.swift` — Podcast search
15. `AccountSheetView.swift` — Settings
16. `BottomSheetPullToDismiss.swift` — Pull to dismiss
17. `GlassComponents.swift` — Glass toolbar and buttons

### Phase 2: Media Linking
**Goal:** Extract and display connected media from episodes.

Files to implement:
1. `MediaLink.swift` — Media link model
2. `MediaLinkingService.swift` — Extraction pipeline
3. `MediaLinkCardView.swift` — Media link UI cards
4. `TMDBService.swift` — Movie/TV lookups
5. `YouTubeService.swift` — YouTube lookups
6. `AppStoreService.swift` — App lookups
7. `TranscriptService.swift` — Transcript fetching
8. `String+Parsing.swift` — HTML/text parsing utilities

### Phase 3: AI & Intelligence
**Goal:** On-device NLP for smart media extraction.

Files to implement:
1. `AIEntityExtractor.swift` — NLP + Core ML
2. `MediaPatterns.json` — Pattern rules
3. Media linking settings UI

### Phase 4: Video & PiP
**Goal:** Video podcast support with PiP.

Files to implement:
1. `VideoPlayerView.swift` — Video player with PiP
2. `PlaybackSettingsView.swift` — Video preferences
3. PiP controller integration

### Phase 5: Premium & Auth
**Goal:** Paid podcast support.

Files to implement:
1. `AuthService.swift` — Platform authentication
2. `ConnectedAccountsView.swift` — Account linking UI
3. `UserSubscription.swift` — Subscription model

### Phase 6: Polish & Sync
**Goal:** iCloud sync, onboarding, themes, interactions.

Files to implement:
1. `SyncService.swift` — CloudKit sync
2. `OnboardingView.swift` — Welcome flow
3. `ThemesView.swift` — Theme browser
4. `ThemeBuilderView.swift` — Custom themes
5. `TapInteractionBehaviors.swift` — Tap effects
6. `ToolbarBehaviorManager.swift` — Toolbar scroll behaviors
7. `SearchBarStyles.swift` — Search bar appearances

---

## 15. API & External Services

| Service | API | Auth Required | Cost |
|---------|-----|--------------|------|
| Podcast Search | iTunes Search API | No | Free |
| RSS Feeds | Direct HTTP | No (or podcast auth) | Free |
| Movie/TV Lookup | TMDB API v3 | API key | Free tier |
| YouTube | oEmbed API | No | Free |
| YouTube Search | Data API v3 | API key | Free tier (10K/day) |
| App Store Lookup | iTunes Lookup API | No | Free |
| Spotify | Web API | Client ID/Secret | Free tier |
| Apple Music | MusicKit | Apple Developer | Free |
| iCloud Sync | CloudKit | Apple Developer | Free tier |
| AI/NLP | On-device (Apple) | None | Free |

### API Keys Needed
- **TMDB API Key** — for movie/TV lookups (same as WatchedIt)
- **YouTube Data API Key** — for video search (optional, oEmbed works without)
- **Spotify Client ID** — for music lookups (optional)

---

## 16. File-by-File Implementation Guide

This section provides the exact implementation order optimized for Claude to build incrementally. Each file includes its dependencies so Claude knows what must exist first.

### Wave 1: Foundation (no dependencies between files)

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 1 | `PodLink/Models/Category.swift` | Genre/category enum | None |
| 2 | `PodLink/Models/PlaybackState.swift` | Playback state observable | None |
| 3 | `PodLink/Models/MediaLink.swift` | Media link model + types | None |
| 4 | `PodLink/Extensions/Date+Formatting.swift` | Date helpers | None |
| 5 | `PodLink/Extensions/String+Parsing.swift` | HTML strip, entity clean | None |
| 6 | `PodLink/Extensions/Color+Theme.swift` | Color helpers | None |
| 7 | `PodLink/Resources/Assets.xcassets` | App icon, colors | None |

### Wave 2: Design System + Models

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 8 | `PodLink/DesignSystem/DesignSystem.swift` | Typography, colors, spacing tokens | Color+Theme |
| 9 | `PodLink/DesignSystem/ThemeManager.swift` | Theme protocol, built-ins, custom | DesignSystem |
| 10 | `PodLink/Models/Podcast.swift` | Podcast show model | Category |
| 11 | `PodLink/Models/Episode.swift` | Episode model | Podcast, MediaLink |
| 12 | `PodLink/Models/UserSubscription.swift` | Subscription/auth model | Podcast |

### Wave 3: Services

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 13 | `PodLink/Services/CacheService.swift` | Memory + disk cache | None |
| 14 | `PodLink/Services/ImageService.swift` | Async image loading | CacheService |
| 15 | `PodLink/Services/PodcastSearchService.swift` | iTunes Search API | Podcast |
| 16 | `PodLink/Services/RSSFeedService.swift` | RSS/Atom parser | Episode, Podcast |
| 17 | `PodLink/Services/PlaybackService.swift` | AVPlayer, Now Playing | PlaybackState, Episode |
| 18 | `PodLink/Services/TMDBService.swift` | Movie/TV lookup | MediaLink |
| 19 | `PodLink/Services/YouTubeService.swift` | YouTube oEmbed/search | MediaLink |
| 20 | `PodLink/Services/AppStoreService.swift` | App Store lookup | MediaLink |
| 21 | `PodLink/Services/TranscriptService.swift` | Transcript fetch | Episode |
| 22 | `PodLink/Services/AIEntityExtractor.swift` | NLP entity extraction | MediaLink |
| 23 | `PodLink/Services/MediaLinkingService.swift` | Orchestrator | All above services |
| 24 | `PodLink/Services/SyncService.swift` | iCloud sync | Podcast, Episode |

### Wave 4: Shared Views

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 25 | `PodLink/Views/Shared/AsyncCachedImage.swift` | Image view with cache | ImageService |
| 26 | `PodLink/Views/Shared/BottomSheetPullToDismiss.swift` | Pull-to-dismiss | None |
| 27 | `PodLink/Views/Shared/TapInteractionBehaviors.swift` | Tap effects | DesignSystem |
| 28 | `PodLink/Views/Shared/ToolbarBehaviorManager.swift` | Toolbar scroll | DesignSystem |
| 29 | `PodLink/Views/Shared/SearchBarStyles.swift` | Search bar appearances | DesignSystem, ThemeManager |
| 30 | `PodLink/DesignSystem/GlassComponents.swift` | Glass material modifiers | DesignSystem, ThemeManager |

### Wave 5: View Models

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 31 | `PodLink/ViewModels/PodcastListViewModel.swift` | Main list state | Podcast, Episode, services |
| 32 | `PodLink/ViewModels/EpisodeDetailViewModel.swift` | Episode detail state | Episode, MediaLinkingService |
| 33 | `PodLink/ViewModels/PlayerViewModel.swift` | Player controls | PlaybackService |
| 34 | `PodLink/ViewModels/SearchViewModel.swift` | Search state | PodcastSearchService |
| 35 | `PodLink/ViewModels/OnboardingViewModel.swift` | Onboarding state | PodcastSearchService |

### Wave 6: Feature Views

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 36 | `PodLink/Views/Main/PodcastRowView.swift` | Podcast list row | Podcast, DesignSystem |
| 37 | `PodLink/Views/Main/PodcastListView.swift` | Main grid/list | PodcastRowView, toolbar |
| 38 | `PodLink/Views/Main/CategoriesHomeView.swift` | Category browser | Category, Podcast |
| 39 | `PodLink/Views/Detail/EpisodeRowView.swift` | Episode list item | Episode |
| 40 | `PodLink/Views/Detail/MediaLinkCardView.swift` | Media link card | MediaLink, DesignSystem |
| 41 | `PodLink/Views/Detail/PodcastDetailView.swift` | Show detail sheet | EpisodeRowView, Podcast |
| 42 | `PodLink/Views/Detail/EpisodeDetailView.swift` | Episode detail sheet | MediaLinkCardView |
| 43 | `PodLink/Views/Player/MiniPlayerView.swift` | Mini player bar | PlayerViewModel |
| 44 | `PodLink/Views/Player/FullPlayerView.swift` | Full player sheet | PlayerViewModel |
| 45 | `PodLink/Views/Player/VideoPlayerView.swift` | Video with PiP | PlaybackService |
| 46 | `PodLink/Views/Player/QueueView.swift` | Queue management | PlayerViewModel |
| 47 | `PodLink/Views/Player/SleepTimerView.swift` | Sleep timer | PlayerViewModel |
| 48 | `PodLink/Views/Search/SearchScreenView.swift` | Search overlay | SearchViewModel |
| 49 | `PodLink/Views/Search/SearchResultsView.swift` | Search results | PodcastRowView |
| 50 | `PodLink/Views/Search/FilterBarView.swift` | Filter tokens | Category |

### Wave 7: Settings & Onboarding

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 51 | `PodLink/DesignSystem/ThemesView.swift` | Theme browser | ThemeManager |
| 52 | `PodLink/DesignSystem/ThemeBuilderView.swift` | Theme creator | ThemeManager |
| 53 | `PodLink/Views/Account/AccountSheetView.swift` | Settings hub | All settings views |
| 54 | `PodLink/Views/Account/AppearanceSettingsView.swift` | Visual settings | DesignSystem |
| 55 | `PodLink/Views/Account/PlaybackSettingsView.swift` | Playback prefs | PlaybackService |
| 56 | `PodLink/Views/Account/ConnectedAccountsView.swift` | Auth links | AuthService |
| 57 | `PodLink/Views/Account/NotificationSettingsView.swift` | Notification prefs | None |
| 58 | `PodLink/Views/Onboarding/OnboardingView.swift` | Welcome flow | OnboardingViewModel |
| 59 | `PodLink/Views/Onboarding/PodcastPickerView.swift` | Podcast selector | PodcastSearchService |
| 60 | `PodLink/Views/Onboarding/FeatureHighlightView.swift` | Feature intro | DesignSystem |

### Wave 8: App Shell

| # | File | Purpose | Dependencies |
|---|------|---------|-------------|
| 61 | `PodLink/ContentView.swift` | Root navigation | All views |
| 62 | `PodLink/PodLinkApp.swift` | App entry | ContentView, services |

---

## Appendix A: RSS Feed Parsing Reference

Standard podcast RSS namespaces to support:
```xml
xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
xmlns:podcast="https://podcastindex.org/namespace/1.0"
xmlns:media="http://search.yahoo.com/mrss/"
xmlns:yt="http://www.youtube.com/xml/schemas/2015"
```

Key elements:
- `<enclosure url="..." type="audio/mpeg" length="..." />` — audio file
- `<itunes:image href="..." />` — artwork
- `<itunes:duration>` — episode length
- `<itunes:episode>` / `<itunes:season>` — numbering
- `<podcast:transcript url="..." type="text/plain" />` — transcript
- `<podcast:chapters url="..." type="application/json+chapters" />` — chapters
- `<media:content url="..." type="video/mp4" />` — video enclosure
- `<yt:videoId>` — YouTube video ID (in YouTube RSS feeds)

## Appendix B: iTunes Search API Reference

```
GET https://itunes.apple.com/search
  ?term={query}
  &media=podcast
  &entity=podcast        // or podcastEpisode
  &limit=25
  &country=US

Response fields:
  - collectionId → itunesID
  - collectionName → title
  - artistName → author
  - feedUrl → feedURL
  - artworkUrl600 → artworkURL600
  - primaryGenreName → category
  - trackCount → episodeCount
```

## Appendix C: Playback Speed Presets

```swift
let speedPresets: [(label: String, rate: Float)] = [
    ("0.5×", 0.5),
    ("0.75×", 0.75),
    ("1×", 1.0),
    ("1.25×", 1.25),
    ("1.5×", 1.5),
    ("1.75×", 1.75),
    ("2×", 2.0),
    ("2.5×", 2.5),
    ("3×", 3.0)
]
```

## Appendix D: Deep Link Schemes for Media Apps

```swift
let appSchemes: [String: String] = [
    "netflix": "nflx://",
    "hulu": "hulu://",
    "disney+": "disneyplus://",
    "hbo": "hbomax://",
    "amazon": "aiv://",
    "apple_tv": "videos://",
    "peacock": "peacock://",
    "spotify": "spotify://",
    "apple_music": "music://",
    "youtube": "youtube://",
    "twitch": "twitch://",
    "espn": "sportscenter://"
]
```
