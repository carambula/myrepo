# Font Setup Instructions - Quick Reference

## TL;DR - What You Need To Do

Since I'm running in a cloud environment, I can't access your local Mac filesystem where the Nuform Redux app and the Swift apps are located. **You'll need to run the automated script from your Mac terminal.**

## Step 1: Run the Automated Script (On Your Mac)

Open Terminal on your Mac and run:

```bash
cd /Users/carambula/Documents/GitHub/myrepo

./packages/design-system/scripts/copy-rotina-fonts.sh /path/to/nuform-redux-app
```

**Replace `/path/to/nuform-redux-app`** with the actual path to your Nuform Redux application.

### Finding Nuform Redux

If you're not sure where Nuform Redux is located, try:

```bash
# Search in common locations
find ~/Documents ~/Desktop ~/Projects -type d -name "*uform*" 2>/dev/null
```

Or use Spotlight:
```bash
mdfind -name "nuform" | grep -i app
```

### What the Script Does

The script will automatically:
1. ✅ Find Rotina fonts in Nuform Redux
2. ✅ Copy to design system: `packages/design-system/src/assets/fonts/rotina/`
3. ✅ Copy to WatchedIt: `apps/WatchedIt/WatchedIt/Fonts/Rotina/`
4. ✅ Copy to PodLink: `apps/PodLink/PodLink/Fonts/Rotina/`
5. ✅ Copy to YourTube: `apps/YourTube/YourTube/Fonts/Rotina/`
6. ✅ Copy to Cyclismo: `apps/Cyclismo/Cyclismo/Fonts/Rotina/`
7. ✅ Verify all files copied correctly

## Step 2: Integrate into Each Swift App

After the script completes, you'll need to integrate the fonts into each iOS app. The script will print instructions, but here's the summary:

### For Each App (WatchedIt, PodLink, YourTube, Cyclismo):

1. **Open the app in Xcode**

2. **Add fonts to project:**
   - Locate `apps/[AppName]/[AppName]/Fonts/Rotina/` in Finder
   - Drag the entire `Rotina` folder into Xcode
   - ✅ Check "Copy items if needed"
   - ✅ Check your app target
   - Click "Finish"

3. **Update Info.plist:**
   - Open Info.plist
   - Add key: "Fonts provided by application" (or `UIAppFonts`)
   - Copy the font list from: `packages/design-system/scripts/Info.plist-fonts-snippet.xml`
   - Paste the 16 Rotina font file names

4. **Add ThemeManager code:**
   - Open your app's `ThemeManager.swift`
   - Add the code from: `packages/design-system/scripts/SWIFT_INTEGRATION.md`
   - This includes:
     - `RotinaWeight` enum
     - `FontTier` enum
     - `FontOverrideSettings` struct
     - Font helper methods

5. **Create FontOverrideSettingsView:**
   - Create new file: `FontOverrideSettingsView.swift`
   - Copy the SwiftUI view code from the integration guide
   - Add to your project

6. **Link to Settings:**
   - Add a NavigationLink in your SettingsView:
     ```swift
     NavigationLink {
         FontOverrideSettingsView(themeManager: themeManager)
     } label: {
         Label("Fonts", systemImage: "textformat")
     }
     ```

7. **Test:**
   - Build and run
   - Go to Settings > Fonts
   - Enable custom fonts
   - Verify fonts appear correctly

## Step 3: Verify Everything Works

### Quick Test

Add this to your app's launch code to verify fonts loaded:

```swift
func verifyFontsLoaded() {
    if UIFont.fontNames(forFamilyName: "Rotina").isEmpty {
        print("⚠️ WARNING: Rotina fonts not found!")
    } else {
        print("✅ Rotina fonts loaded successfully")
        UIFont.fontNames(forFamilyName: "Rotina").forEach { 
            print("  - \($0)") 
        }
    }
}
```

## All Resources at a Glance

### Scripts & Tools
- **Font copy script**: `packages/design-system/scripts/copy-rotina-fonts.sh`
- **Swift integration guide**: `packages/design-system/scripts/SWIFT_INTEGRATION.md`
- **Info.plist snippet**: `packages/design-system/scripts/Info.plist-fonts-snippet.xml`
- **Scripts README**: `packages/design-system/scripts/README.md`

### Documentation
- **Font override API**: `packages/design-system/docs/font-override.md`
- **Integration guide**: `packages/design-system/docs/font-override-integration.md`
- **Main README**: `packages/design-system/README.md`

### Examples
- **Interactive demo**: `packages/design-system/examples/font-override-example.html`

## Timeline Estimate

- **Running the script**: 1 minute
- **Per app integration**: 15-30 minutes
- **Total for all 4 apps**: 1-2 hours

## Common Issues

### "Permission denied" when running script
```bash
chmod +x ./packages/design-system/scripts/copy-rotina-fonts.sh
```

### Can't find Nuform Redux
Search your Mac:
```bash
find ~ -type d -name "*uform*" 2>/dev/null | grep -v Library
```

### Fonts don't appear in iOS app
1. Check Info.plist has all font files listed
2. Check Build Phases > Copy Bundle Resources includes fonts
3. Clean build (Shift+Cmd+K) and rebuild
4. Check font file names match exactly (case-sensitive)

## Questions?

- Check the [Swift Integration Guide](./scripts/SWIFT_INTEGRATION.md) for detailed steps
- Review the [Font Override Documentation](./docs/font-override.md) for API details
- Look at the troubleshooting sections in each guide

## What I've Created for You

Since I can't access your local filesystem, I've created:

✅ Complete font override system in the design system package  
✅ Automated script to copy fonts from Nuform Redux  
✅ Comprehensive Swift/iOS integration guide  
✅ Info.plist configuration snippet  
✅ SwiftUI settings view code  
✅ ThemeManager integration code  
✅ Interactive HTML example  
✅ Full documentation and guides  

**Now you just need to run the script on your Mac to copy the actual font files!**

---

## Quick Command Reference

```bash
# Navigate to repo
cd /Users/carambula/Documents/GitHub/myrepo

# Run font copy script (replace path to Nuform Redux)
./packages/design-system/scripts/copy-rotina-fonts.sh /path/to/nuform-redux

# Open integration guide
open packages/design-system/scripts/SWIFT_INTEGRATION.md

# Open scripts README  
open packages/design-system/scripts/README.md

# View PR
open https://github.com/carambula/myrepo/pull/11
```

**Good luck! The script will guide you through the rest.** 🎨✨
