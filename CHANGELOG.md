# Changelog

All notable changes to the min apps design system will be documented in this file.

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
