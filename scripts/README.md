# Font Integration Scripts

This directory contains automated scripts and guides to help integrate the Rotina font family into all min apps.

## Quick Start

### 1. Copy Fonts from Nuform Redux

Run this script from your Mac (not in the cloud environment):

```bash
cd /path/to/your/myrepo
./packages/design-system/scripts/copy-rotina-fonts.sh /path/to/nuform-redux-app
```

This will:
- ✅ Find Rotina fonts in the Nuform Redux app
- ✅ Copy them to the design system package
- ✅ Copy them to all four Swift apps (WatchedIt, PodLink, YourTube, Cyclismo)
- ✅ Create the necessary directory structure
- ✅ Verify font file counts

### 2. Integrate into iOS Apps

Follow the comprehensive guide:

```bash
open packages/design-system/scripts/SWIFT_INTEGRATION.md
```

Or read it here: [SWIFT_INTEGRATION.md](./SWIFT_INTEGRATION.md)

## Files in This Directory

### 📜 Scripts

#### `copy-rotina-fonts.sh`
Automated bash script to copy Rotina fonts from Nuform Redux to all apps.

**Usage:**
```bash
./copy-rotina-fonts.sh <path-to-nuform-redux-app>
```

**Example:**
```bash
./copy-rotina-fonts.sh /Users/carambula/Documents/GitHub/nuform-redux
```

**What it does:**
1. Searches for Rotina fonts in the Nuform Redux app
2. Validates font files exist
3. Creates font directories in each app
4. Copies WOFF2 and WOFF files
5. Reports success and provides next steps

**Targets:**
- `packages/design-system/src/assets/fonts/rotina/`
- `apps/WatchedIt/WatchedIt/Fonts/Rotina/`
- `apps/PodLink/PodLink/Fonts/Rotina/`
- `apps/YourTube/YourTube/Fonts/Rotina/`
- `apps/Cyclismo/Cyclismo/Fonts/Rotina/`

### 📚 Guides

#### `SWIFT_INTEGRATION.md`
Complete step-by-step guide for integrating Rotina fonts into iOS Swift apps.

**Covers:**
- ✅ Copying font files
- ✅ Adding fonts to Xcode projects
- ✅ Configuring Info.plist
- ✅ Implementing ThemeManager font support
- ✅ Creating FontOverrideSettingsView
- ✅ Adding to app settings
- ✅ Testing and verification
- ✅ Troubleshooting common issues

**Includes code examples for:**
- `RotinaWeight` enum
- `FontTier` enum
- `FontOverrideSettings` struct
- ThemeManager integration
- SwiftUI settings view
- Font verification helpers

### 📄 Reference Files

#### `Info.plist-fonts-snippet.xml`
Ready-to-paste XML snippet for iOS app Info.plist files.

**Usage:**
1. Open your app's Info.plist in Xcode
2. Right-click and select "Open As" > "Source Code"
3. Copy the contents of this file
4. Paste into your Info.plist
5. Save and rebuild

**Contains:**
- `UIAppFonts` key with all 16 Rotina font file names
- Helpful comments explaining iOS version compatibility
- Alternative key name for older iOS versions

## Workflow

### Complete Integration Workflow

```
┌─────────────────────────────────────────┐
│ 1. Run copy-rotina-fonts.sh           │
│    (copies fonts from Nuform Redux)     │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 2. For each Swift app:                  │
│    - Open in Xcode                      │
│    - Add Fonts/Rotina folder            │
│    - Update Info.plist                  │
│    - Add ThemeManager code              │
│    - Create FontOverrideSettingsView    │
│    - Link to settings                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 3. Test in each app:                    │
│    - Verify fonts load                  │
│    - Test settings UI                   │
│    - Check all font tiers               │
│    - Test on device                     │
└─────────────────────────────────────────┘
```

## Troubleshooting

### Script Issues

**Problem: Script can't find Nuform Redux fonts**

Solution:
1. Verify the path to Nuform Redux is correct
2. Check that Rotina fonts exist in the app
3. Try searching manually:
   ```bash
   find /path/to/nuform-redux -name "Rotina*.woff*"
   ```

**Problem: Permission denied**

Solution:
```bash
chmod +x ./copy-rotina-fonts.sh
```

### iOS Integration Issues

See the troubleshooting section in `SWIFT_INTEGRATION.md` for:
- Fonts don't appear in app
- Font names don't match
- Build errors
- File size concerns

## Additional Resources

### Documentation
- [Font Override System Documentation](../docs/font-override.md)
- [Font Override Integration Guide](../docs/font-override-integration.md)
- [Design System README](../README.md)

### Examples
- [Interactive HTML Example](../examples/font-override-example.html)

### Rotina Font Files

**Expected files (32 total):**
- 16 WOFF2 files: Rotina-{Weight}.woff2, Rotina-{Weight}Italic.woff2
- 16 WOFF files: Rotina-{Weight}.woff, Rotina-{Weight}Italic.woff

**Weights:**
- ExtraThin (200)
- Thin (250)
- Light (300)
- Regular (400)
- Medium (500)
- SemiBold (600)
- Bold (700)
- ExtraBold (800)

## Platform-Specific Notes

### iOS (Swift Apps)
- Use WOFF2 files (iOS 10+) for smaller size
- Or convert to TTF/OTF for broader compatibility
- Must register fonts in Info.plist
- Must add to "Copy Bundle Resources" build phase

### Web (React Apps)
- Use WOFF2 with WOFF fallback
- Import rotina.css to load @font-face declarations
- Fonts lazy-load when feature is enabled
- Uses CSS custom properties for tier-based application

## Need Help?

1. Check the [Swift Integration Guide](./SWIFT_INTEGRATION.md)
2. Review the [Font Override Documentation](../docs/font-override.md)
3. Look at code examples in the guides
4. Check the troubleshooting sections

## License

Rotina is a commercial typeface by Nuform Type and Sharp Type. Ensure you have appropriate licensing for use in your applications.
