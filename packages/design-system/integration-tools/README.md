# Design System Integration Tools

This directory contains automated tools and guides for integrating the min-apps design system into each of the four min apps.

## Apps Covered

1. **WatchedIt** (mov min) - Movie tracking app
2. **podlink** (pod min) - Podcast app
3. **yourtube** (vid min) - Video app
4. **Cyclismo guide** (cyc min) - Cycling guide app

**Main bootstrap loading** matches **WatchedIt (mov min)** on **web and native**: [Main app loading](../docs/main-app-loading.md) (DOM/CSS), [Main app loading — native](../docs/main-app-loading-native.md) (React Native, Swift, Kotlin, `native/`). Other loading/empty rules: [Visual specification](../docs/visual-specification.md#loading-and-empty-null-states).

**Page grid and margins** (content, sticky search, filters, fixed buttons) also match **mov min** across all apps: [Layout and margins (mov min)](../docs/layout-margins-mov-min.md).

## Quick Start

### Option 1: Automated Integration Script

Run the integration script in your app directory:

```bash
cd /path/to/your-app
node /path/to/design-system/integration-tools/scripts/integrate.js
```

The script will:
- Install the design system package
- Set up global styles
- Initialize theming
- Create example component migrations
- Generate an integration checklist specific to your app

### Option 2: Manual Integration

Follow the app-specific guide in `app-specific/` directory:

- `app-specific/watchedit-integration.md`
- `app-specific/podlink-integration.md`
- `app-specific/yourtube-integration.md`
- `app-specific/cyclismo-integration.md`

### Option 3: Step-by-Step

1. Copy the integration checklist template
2. Install dependencies
3. Follow the migration steps
4. Use the code transformation utilities

## Directory Structure

```
integration-tools/
├── README.md                    # This file
├── scripts/
│   ├── integrate.js            # Main integration script
│   ├── setup-package.js        # Package installation helper
│   ├── migrate-spacing.js      # Spacing migration utility
│   ├── migrate-colors.js       # Color migration utility
│   ├── migrate-components.js   # Component migration utility
│   └── verify-integration.js   # Integration verification
├── templates/
│   ├── app-init.js             # App initialization template
│   ├── theme-setup.js          # Theme setup template
│   ├── home-layout.jsx         # Home screen example
│   ├── list-view.jsx           # List view example
│   └── detail-view.jsx         # Detail view example
└── app-specific/
    ├── watchedit-integration.md
    ├── podlink-integration.md
    ├── yourtube-integration.md
    └── cyclismo-integration.md
```

## Tools Included

### 1. Integration Script (`scripts/integrate.js`)
Automates the basic setup process:
- Checks if design system is installed
- Adds global style imports
- Creates theme initialization
- Generates boilerplate code

### 2. Migration Utilities
Scripts that help migrate existing code:

- **migrate-spacing.js** - Replaces hard-coded spacing values with design tokens
- **migrate-colors.js** - Replaces color values with CSS variables
- **migrate-components.js** - Suggests component replacements

### 3. Templates
Pre-built templates for common patterns:
- App initialization
- Theme setup
- Layout components
- Common views

### 4. App-Specific Guides
Detailed integration guides tailored to each app's specific needs and structure.

## Integration Workflow

1. **Preparation**
   - Back up your app (create git branch)
   - Review your current component structure
   - Identify hard-coded spacing and colors

2. **Installation**
   - Run integration script OR
   - Manually install design system package

3. **Global Setup**
   - Import global styles
   - Initialize theming
   - Test theme switching

4. **Component Migration**
   - Replace spacing values
   - Replace colors
   - Replace components
   - Update layouts

5. **Testing**
   - Visual testing across breakpoints
   - Theme switching
   - Accessibility checks
   - Cross-browser testing

6. **Cleanup**
   - Remove old custom components
   - Update documentation
   - Create pull request

## Usage Examples

### Run Integration Script
```bash
cd your-app
node ../design-system/integration-tools/scripts/integrate.js
```

### Migrate Spacing
```bash
node ../design-system/integration-tools/scripts/migrate-spacing.js ./src
```

### Verify Integration
```bash
node ../design-system/integration-tools/scripts/verify-integration.js
```

## Need Help?

1. Check the app-specific guide for your app
2. Review the main [Integration Checklist](../docs/integration-checklist.md)
3. Look at the [Migration Guide](../docs/migration.md)
4. Refer to the [examples](../examples/)

## Success Criteria

Your integration is complete when:
- ✅ Logo positioned at exact 32px from top (desktop)
- ✅ Buttons use consistent spacing (24px × 12px padding)
- ✅ List items have uniform spacing
- ✅ Theme switching works throughout
- ✅ All spacing uses design tokens
- ✅ All colors use CSS variables
- ✅ Visual consistency with other min apps
