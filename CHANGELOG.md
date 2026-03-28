# Changelog

All notable changes to the min apps design system will be documented in this file.

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
