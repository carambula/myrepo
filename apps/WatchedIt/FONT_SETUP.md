# WatchedIt Font Setup

## ✅ Status Checklist

- ✅ Font files copied to `WatchedIt/Fonts/Rotina/` (16 woff2 files)
- ✅ Info.plist updated with `UIAppFonts` array
- ✅ ThemeManager updated with font override support
- ✅ FontOverrideSettingsView created
- ✅ Settings link added to MovieListView
- ⚠️ **NEED TO DO**: Add fonts to Xcode project

## 🎯 Final Step: Add Fonts to Xcode Project

The font files are on disk, but Xcode doesn't know about them yet. Here's how to add them:

### Step-by-Step Instructions:

1. **Open** `WatchedIt.xcodeproj` in Xcode

2. **In the Project Navigator** (left sidebar), find the `WatchedIt` folder

3. **Right-click** on `WatchedIt` folder → **"Add Files to 'WatchedIt'..."**

4. **Navigate to** `WatchedIt/Fonts/Rotina/`

5. **Select ALL 16 .woff2 files**:
   - Rotina-ExtraThin.woff2
   - Rotina-Thin.woff2
   - Rotina-ExtraLight.woff2
   - Rotina-Light.woff2
   - Rotina-Regular.woff2
   - Rotina-Medium.woff2
   - Rotina-Bold.woff2
   - Rotina-ExtraBold.woff2
   - Rotina-ExtraThinItalic.woff2
   - Rotina-ThinItalic.woff2
   - Rotina-ExtraLightItalic.woff2
   - Rotina-LightItalic.woff2
   - Rotina-Italic.woff2
   - Rotina-MediumItalic.woff2
   - Rotina-BoldItalic.woff2
   - Rotina-ExtraBoldItalic.woff2

6. **IMPORTANT - In the dialog:**
   - ❌ **UN-check** "Copy items if needed" (files are already in the right place)
   - ✅ **Select** "Create groups" (not "Create folder references")
   - ✅ **Check** "WatchedIt" under "Add to targets"

7. **Click "Add"**

8. **Verify** in Xcode:
   - You should now see `Fonts/Rotina/` in the Project Navigator
   - Select the WatchedIt target
   - Go to "Build Phases" tab
   - Expand "Copy Bundle Resources"
   - All 16 Rotina-*.woff2 files should be listed

9. **Build and Run** (Cmd+R)

10. **Go to Settings** → **Appearance** → **Fonts**

11. **Enable Custom Fonts** and select weights!

## 🧪 Testing

After adding fonts to Xcode:

1. Build and run the app
2. Tap the "Test Font Loading" button in Font Settings
3. Check Xcode console - you should see:
   ```
   ✅ Rotina fonts loaded successfully
     - Rotina-ExtraThin
     - Rotina-Thin
     - (etc...)
   ```

If you see "⚠️ WARNING: Rotina fonts not found!", then fonts weren't added to Xcode project correctly.

## 🎨 Using Custom Fonts

Once enabled, you can:
- Choose different Rotina weights for each typography tier
- Preview fonts in real-time
- Reset to defaults
- Toggle on/off at any time

Settings are saved and persist across app launches!

## 📍 Where to Find Font Settings

In the app:
**Settings (gear icon)** → **Appearance section** → **Fonts**

---

**Need help? See:** `/packages/design-system/scripts/SWIFT_INTEGRATION.md`
