# Changelog

All notable changes to the min apps design system will be documented in this file.

## [1.3.0] - 2026-04-02

### Added

#### Font Override System
- Custom font override system allowing users to personalize typography across all min apps
- Complete Rotina font family integration (8 weights: ExtraThin through ExtraBold)
- Per-tier font customization system with 6 configurable tiers:
  - **Display**: Large headings (H1, H2)
  - **Heading**: Section headings (H3-H6)
  - **Body**: Paragraphs and body text
  - **UI**: Buttons, labels, and controls
  - **Caption**: Small text and metadata
  - **Mono**: Code and monospace (not customizable)
- `FontOverrideSettings` React component with complete UI for font customization:
  - Enable/disable toggle
  - Dropdown selectors for each tier
  - Live font preview for each weight
  - Reset to defaults functionality
  - Helpful instructions for users
- Programmatic API for font override management:
  - `enableFontOverride()` - Enable with default or custom configuration
  - `disableFontOverride()` - Disable and restore system fonts
  - `updateFontOverride()` - Update specific tiers
  - `getFontOverrideConfig()` - Get current configuration
  - `isFontOverrideEnabled()` - Check enabled status
  - `initFontOverride()` - Auto-initialize on page load
- CSS custom properties for font tiers:
  - `--font-display`, `--font-weight-display`
  - `--font-heading`, `--font-weight-heading`
  - `--font-body`, `--font-weight-body`
  - `--font-ui`, `--font-weight-ui`
  - `--font-caption`, `--font-weight-caption`
- Automatic font loading with `font-display: swap` for optimal performance
- LocalStorage persistence for user preferences
- Complete @font-face declarations for all Rotina weights (Roman and Italic)
- Comprehensive documentation:
  - `/docs/font-override.md` - Complete API and usage guide
  - `/docs/font-override-integration.md` - App-specific integration guides for all four min apps
- Example implementations:
  - `/examples/font-override-example.html` - Interactive demo with live controls
  - App-specific recommendations for WatchedIt, PodLink, YourTube, and Cyclismo Guide
- Font asset structure at `/src/assets/fonts/rotina/` with README for font file placement
- Integration with theme system - font override auto-initializes with `initTheme()`
- Fallback support to system fonts when disabled or fonts unavailable

#### Font Override Features
- **User control**: Toggle custom fonts on/off at any time
- **Granular customization**: Select different Rotina weights for each typography tier
- **Consistent defaults**: Sensible default weight mappings for each tier
- **Performance optimized**: Fonts only load when feature is enabled
- **Accessible**: Maintains readability and WCAG contrast standards
- **Responsive**: Works seamlessly across all devices and screen sizes

## [1.2.0] - 2026-04-02

### Added

#### Deep Linking System
- Comprehensive deep linking system with bias towards opening content in min apps
- URL scheme definitions and parsers for all supported external services:
  - **Movies/TV**: TMDB, IMDb
  - **Podcasts**: Apple Podcasts, Spotify, Overcast, Pocket Casts
  - **Videos**: YouTube (videos, channels, playlists)
  - **Cycling**: ProCyclingStats, CyclingNews
- Content type mapping system for accurate routing between services
- User preference management for choosing preferred apps per content type
- Link opening utilities that respect user preferences and attempt deep links first
- Automatic fallback to web when min app is not installed
- React hooks for deep linking:
  - `useOpenLink` - Open links with deep linking support
  - `useDeepLinkPreferences` - Access and manage user preferences
  - `useLinkPreview` - Preview link behavior before opening
  - `useUrlParser` - Parse URLs to extract content information
  - `useShareableLink` - Create shareable universal links
  - `usePreferredApp` - Get user's preferred app for content type
  - `useDeepLinkAnalytics` - Track deep link usage
- React components for easy integration:
  - `DeepLink` - Automatic deep linking for any URL
  - `LinkPreview` - Show preview of link behavior
  - `SmartLink` - Link with hover preview
  - `ContentButton` - Open specific content by ID
  - `ShareButton` - Share content via deep link
  - `AppPreferenceSelector` - UI for selecting preferred app
  - `DeepLinkPreferencesPanel` - Complete preference management UI
  - `DeepLinkProvider` - Context provider for configuration
- Platform integration support (iOS, Android, Web)
- Content ID extraction and mapping utilities
- Shareable universal link generation
- Comprehensive documentation in `/docs/deep-linking.md`
- Integration examples for all four apps in `/examples/deep-linking/`:
  - WatchedIt integration examples
  - Podlink integration examples
  - Yourtube integration examples
  - Cyclismo Guide integration examples

#### Deep Linking Features
- **Bias towards min apps**: Always attempts to open in a min app first
- **User preference support**: Respects user's chosen apps for different content types
- **Graceful fallbacks**: Falls back to web when app isn't installed
- **Consistent API**: Same API across all platforms and apps
- **URL parsing**: Automatically detects content type from URLs
- **Content mapping**: Maps between different ID systems (TMDB, IMDb, etc.)
- **Batch operations**: Open multiple links efficiently
- **Preview mode**: Preview what will happen before opening
- **Analytics tracking**: Built-in usage tracking
- **Preference persistence**: User preferences saved to localStorage
- **Import/Export**: Backup and sync preferences

#### Deep Linking by App

**WatchedIt**
- Deep links from TMDB and IMDb URLs
- Movie, TV show, and person page deep linking
- Share movies with universal links
- Parse movie links in user-generated content

**Podlink**
- Deep links from Apple Podcasts, Spotify, Overcast, Pocket Casts
- Podcast and episode deep linking
- Smart queue building from multiple sources
- RSS feed import with deep linking

**Yourtube**
- Deep links from YouTube URLs (youtube.com and youtu.be)
- Video, channel, and playlist deep linking
- Distraction-free mode integration
- Comment parsing for video links

**Cyclismo Guide**
- Deep links from ProCyclingStats and CyclingNews
- Race, rider, team, and stage deep linking
- Live race tracking with deep links
- Grand Tour stage tracking

### Changed
- Updated package exports to include deep linking module
- Updated README with deep linking system usage
- Updated main index to export deep linking utilities
- Enhanced overall link handling across all apps

## [1.1.0] - 2026-04-02

### Added

#### Notification System
- Complete notification preferences system for all min apps
- Data structures and type definitions for app-specific notification types
- UI components for managing notification settings:
  - `NotificationToggle` - Toggle switch for enabling/disabling notifications
  - `TimePickerInput` - Time selection input with validation
  - `NumberInput` - Numeric input with range validation
  - `NotificationSettingsGroup` - Collapsible settings group
  - `NotificationSettingsPage` - Main settings page with app routing
- App-specific notification settings components:
  - `CyclismoNotificationSettings` - Cyclismo guide notifications
  - `PodlinkNotificationSettings` - Podlink podcast notifications
  - `WatcheditNotificationSettings` - WatchedIt movie notifications
  - `YourtubeNotificationSettings` - Yourtube video notifications
- Preference management utilities:
  - Load/save notification preferences to localStorage
  - Validation with error reporting
  - Import/export for backup and sync
- Background job scheduling utilities:
  - Notification payload creators for each app
  - Schedule configuration helpers
  - Platform integration guides (iOS, Android, Web)
- App-specific configurations with implementation examples:
  - Cyclismo: Morning races, recap, stream start notifications
  - Podlink: Morning queue summary, priority podcasts with Apple Intelligence
  - WatchedIt: New episode notifications
  - Yourtube: Morning queue summary, priority channels
- Helper utilities:
  - Priority podcast/channel managers
  - Episode/video tracking
  - Apple Intelligence integration helpers
- Comprehensive documentation in `/docs/notifications.md`
- Interactive HTML example for notification settings

#### Notification Features by App

**Cyclismo Guide**
- Morning race notifications with race times and streamers
- Post-race recap with podcasts and replays
- Stream start notifications (5-60 minutes before)
- Option to only notify for saved races

**Podlink**
- Daily morning queue summaries
- Apple Intelligence-powered summaries
- Priority podcast notifications with custom check intervals
- Priority podcast management

**WatchedIt**
- Daily new episode checks
- Configurable check time

**Yourtube**
- Daily morning queue summaries
- Apple Intelligence-powered summaries
- Priority channel notifications with custom check intervals
- Priority channel management

### Changed
- Updated package exports to include notifications module
- Updated README with notification system usage
- Updated main index to export notification utilities

## [1.0.0] - 2026-03-28

### Added

#### Design Tokens
- Complete color system with gray scale, primary, secondary, accent, and semantic colors
- Comprehensive spacing system with semantic values for pages, logos, buttons, and lists
- Typography system with font families, sizes, weights, and predefined text styles
- Shadow tokens for elevation and depth
- Border tokens for radii, widths, and styles
- Breakpoints for responsive design
- Transition tokens for consistent animations
- Z-index tokens for layering

#### Theming System
- Light theme configuration
- Dark theme configuration
- Theme provider utilities with automatic persistence
- CSS custom property generation
- System theme detection
- React hook for theme management (`useTheme`)
- Theme toggle component

#### Components
- `Button` - Standardized button with variants (primary, secondary, outline, ghost, text)
- `ListItem` - List item with image, title, subtitle, and actions
- `AppHeader` - Application header with logo and actions
- `Card` - Container with elevation and padding options
- `Input` - Text input with label and error states
- `ThemeToggle` - Toggle button for switching themes

#### Layout Components
- `AppLayout` - Standard page layout with header and footer
- `HomeLayout` - Home page layout with centered logo
- `ContentContainer` - Max-width container with responsive padding
- `List` - Container for list items with spacing options
- `Grid` - Responsive grid layout
- `Stack` - Vertical/horizontal stack with spacing

#### Documentation
- Getting started guide
- Migration guide for existing apps
- Complete design tokens reference
- Component API documentation
- Theming guide
- Best practices guide

#### Examples
- Basic HTML example with theme switching
- App-specific theme configurations for:
  - WatchedIt (movie app)
  - podlink (podcast app)
  - yourtube (video app)
  - Cyclismo guide (cycling app)

### Features

#### Consistency Across Apps
- Unified spacing for page margins, logo positioning, buttons, and lists
- Standardized component patterns
- Interchangeable themes
- Common visual language

#### Accessibility
- WCAG 2.1 AA compliant color contrast
- Keyboard navigation support
- Focus indicators
- Screen reader friendly markup

#### Developer Experience
- Modular imports
- TypeScript-ready structure
- Comprehensive documentation
- Easy migration path

### Notes

This is the initial release of the unified design system for the min apps suite. All four apps (WatchedIt, podlink, yourtube, Cyclismo guide) can now share the same design tokens, components, and themes for a consistent user experience.
