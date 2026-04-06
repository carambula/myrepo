# Swift/iOS Integration Guide for Rotina Fonts

This guide explains how to integrate the Rotina font files into your iOS Swift apps (WatchedIt, PodLink, YourTube, Cyclismo Guide).

## Step 1: Copy Font Files

Run the font copy script from your repository root:

```bash
cd /path/to/your/myrepo
./packages/design-system/scripts/copy-rotina-fonts.sh /path/to/nuform-redux-app
```

This will copy the Rotina fonts to:

- `apps/WatchedIt/WatchedIt/Fonts/Rotina/`
- `apps/PodLink/PodLink/Fonts/Rotina/`
- `apps/YourTube/YourTube/Fonts/Rotina/`
- `apps/Cyclismo/Cyclismo/Fonts/Rotina/`

## Step 2: Add Fonts to Xcode Project

For **each app** (WatchedIt, PodLink, YourTube, Cyclismo):

1. **Open the app in Xcode**
2. **Locate the Fonts/Rotina folder** in Finder:
  ```
   apps/[AppName]/[AppName]/Fonts/Rotina/
  ```
3. **Drag the entire Rotina folder** into the Xcode project navigator
  - Drag it into the `[AppName]/Fonts/` group
  - If the `Fonts` group doesn't exist, create it first
4. **In the dialog that appears, ensure:**
  - ✅ "Copy items if needed" is **checked**
  - ✅ "Create groups" is **selected** (not "Create folder references")
  - ✅ Your app target is **checked** under "Add to targets"
  - Click "Finish"
5. **Verify fonts were added:**
  - Select your app target in Xcode
  - Go to "Build Phases" tab
  - Expand "Copy Bundle Resources"
  - You should see all 16 Rotina font files listed (or 32 if both .woff2 and .woff)

## Step 3: Register Fonts in Info.plist

For **each app**:

1. **Open Info.plist** in Xcode (or as source code)
2. **Add the font files** by adding this key:
  - Right-click in Info.plist
  - Select "Add Row"
  - Choose "Fonts provided by application" (or type `UIAppFonts`)
  - Set type to "Array"
3. **Add each font file** as array items:
  ```xml
   <key>UIAppFonts</key>
   <array>
       <string>Rotina-ExtraThin.woff2</string>
       <string>Rotina-Thin.woff2</string>
       <string>Rotina-Light.woff2</string>
       <string>Rotina-Regular.woff2</string>
       <string>Rotina-Medium.woff2</string>
       <string>Rotina-SemiBold.woff2</string>
       <string>Rotina-Bold.woff2</string>
       <string>Rotina-ExtraBold.woff2</string>
       <string>Rotina-ExtraThinItalic.woff2</string>
       <string>Rotina-ThinItalic.woff2</string>
       <string>Rotina-LightItalic.woff2</string>
       <string>Rotina-Italic.woff2</string>
       <string>Rotina-MediumItalic.woff2</string>
       <string>Rotina-SemiBoldItalic.woff2</string>
       <string>Rotina-BoldItalic.woff2</string>
       <string>Rotina-ExtraBoldItalic.woff2</string>
   </array>
  ```
   Or use the snippet file:

## Step 4: Update ThemeManager

Based on the existing `ThemeManager.swift` files, you'll need to add Rotina font support.

### Example for WatchedIt:

```swift
// Add to your ThemeManager.swift

// MARK: - Font Override Support

enum RotinaWeight: String {
    case extraThin = "Rotina-ExtraThin"
    case thin = "Rotina-Thin"
    case light = "Rotina-Light"
    case regular = "Rotina-Regular"
    case medium = "Rotina-Medium"
    case semiBold = "Rotina-SemiBold"
    case bold = "Rotina-Bold"
    case extraBold = "Rotina-ExtraBold"
    
    var weight: Font.Weight {
        switch self {
        case .extraThin: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semiBold: return .semibold
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
    
    var uiWeight: UIFont.Weight {
        switch self {
        case .extraThin: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semiBold: return .semibold
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
}

enum FontTier: String, CaseIterable {
    case display    // H1, H2 - largest headings
    case heading    // H3-H6 - section headings
    case body       // Paragraphs, body text
    case ui         // Buttons, labels, controls
    case caption    // Small text, metadata
    
    var defaultRotinaWeight: RotinaWeight {
        switch self {
        case .display: return .bold
        case .heading: return .semiBold
        case .body: return .regular
        case .ui: return .medium
        case .caption: return .regular
        }
    }
}

struct FontOverrideSettings: Codable {
    var enabled: Bool = false
    var displayWeight: RotinaWeight = .bold
    var headingWeight: RotinaWeight = .semiBold
    var bodyWeight: RotinaWeight = .regular
    var uiWeight: RotinaWeight = .medium
    var captionWeight: RotinaWeight = .regular
    
    func weight(for tier: FontTier) -> RotinaWeight {
        switch tier {
        case .display: return displayWeight
        case .heading: return headingWeight
        case .body: return bodyWeight
        case .ui: return uiWeight
        case .caption: return captionWeight
        }
    }
}

// Add to your existing ThemeManager class:
@AppStorage("fontOverrideEnabled") private var fontOverrideEnabled: Bool = false
@AppStorage("fontOverrideSettings") private var fontOverrideSettingsData: Data?

var fontOverrideSettings: FontOverrideSettings {
    get {
        guard let data = fontOverrideSettingsData,
              let settings = try? JSONDecoder().decode(FontOverrideSettings.self, from: data) else {
            return FontOverrideSettings()
        }
        return settings
    }
    set {
        fontOverrideSettingsData = try? JSONEncoder().encode(newValue)
    }
}

// Helper function to get custom font
func customFont(_ tier: FontTier, size: CGFloat) -> Font {
    if fontOverrideEnabled {
        let weight = fontOverrideSettings.weight(for: tier)
        return .custom(weight.rawValue, size: size)
    }
    // Fallback to system font with appropriate weight
    return .system(size: size, weight: fontOverrideSettings.weight(for: tier).weight)
}

func customUIFont(_ tier: FontTier, size: CGFloat) -> UIFont {
    if fontOverrideEnabled {
        let weight = fontOverrideSettings.weight(for: tier)
        if let font = UIFont(name: weight.rawValue, size: size) {
            return font
        }
    }
    // Fallback to system font
    return UIFont.systemFont(ofSize: size, weight: fontOverrideSettings.weight(for: tier).uiWeight)
}
```

## Step 5: Create Font Override Settings View

Create a new SwiftUI view for font override settings:

```swift
// FontOverrideSettingsView.swift

import SwiftUI

struct FontOverrideSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var settings: FontOverrideSettings
    @State private var enabled: Bool
    
    init(themeManager: ThemeManager) {
        _settings = State(initialValue: themeManager.fontOverrideSettings)
        _enabled = State(initialValue: themeManager.fontOverrideEnabled)
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Custom Fonts", isOn: $enabled)
                    .onChange(of: enabled) { newValue in
                        themeManager.fontOverrideEnabled = newValue
                    }
            } header: {
                Text("Font Override")
            } footer: {
                Text("Use the Rotina font family to customize typography throughout the app.")
            }
            
            if enabled {
                Section("Display (Large Headings)") {
                    Picker("Weight", selection: $settings.displayWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue.replacingOccurrences(of: "Rotina-", with: ""))
                                .tag(weight)
                        }
                    }
                    
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.display, size: 24))
                        .padding(.vertical, 8)
                }
                
                Section("Heading (Section Titles)") {
                    Picker("Weight", selection: $settings.headingWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue.replacingOccurrences(of: "Rotina-", with: ""))
                                .tag(weight)
                        }
                    }
                    
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.heading, size: 18))
                        .padding(.vertical, 8)
                }
                
                Section("Body (Content Text)") {
                    Picker("Weight", selection: $settings.bodyWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue.replacingOccurrences(of: "Rotina-", with: ""))
                                .tag(weight)
                        }
                    }
                    
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.body, size: 16))
                        .padding(.vertical, 8)
                }
                
                Section("UI (Buttons & Labels)") {
                    Picker("Weight", selection: $settings.uiWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue.replacingOccurrences(of: "Rotina-", with: ""))
                                .tag(weight)
                        }
                    }
                    
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.ui, size: 16))
                        .padding(.vertical, 8)
                }
                
                Section("Caption (Small Text)") {
                    Picker("Weight", selection: $settings.captionWeight) {
                        ForEach(RotinaWeight.allCases, id: \.self) { weight in
                            Text(weight.rawValue.replacingOccurrences(of: "Rotina-", with: ""))
                                .tag(weight)
                        }
                    }
                    
                    Text("The quick brown fox jumps over the lazy dog")
                        .font(themeManager.customFont(.caption, size: 12))
                        .padding(.vertical, 8)
                }
                
                Section {
                    Button("Reset to Defaults") {
                        settings = FontOverrideSettings()
                        themeManager.fontOverrideSettings = settings
                    }
                }
            }
        }
        .navigationTitle("Font Settings")
        .onChange(of: settings) { newSettings in
            themeManager.fontOverrideSettings = newSettings
        }
    }
}

extension RotinaWeight: CaseIterable {
    static var allCases: [RotinaWeight] {
        [.extraThin, .thin, .light, .regular, .medium, .semiBold, .bold, .extraBold]
    }
}
```

## Step 6: Add to Settings/Appearance

Add the font override settings to your app's settings view:

```swift
// In your SettingsView or AppearanceView:

NavigationLink {
    FontOverrideSettingsView(themeManager: themeManager)
} label: {
    Label("Fonts", systemImage: "textformat")
}
```

## Step 7: Test the Integration

1. **Build and run** the app
2. **Go to Settings** > Font Settings
3. **Enable custom fonts**
4. **Change font weights** for different tiers
5. **Verify fonts appear** throughout the app
6. **Check the preview text** updates in the settings

## Verification

To verify fonts are properly loaded:

```swift
// Add this to your app launch or a test view:
func verifyFontsLoaded() {
    let fontNames = UIFont.familyNames
    print("Available font families:")
    for family in fontNames {
        print("- \(family)")
        let names = UIFont.fontNames(forFamilyName: family)
        for name in names {
            print("  - \(name)")
        }
    }
    
    // Check specifically for Rotina
    if UIFont.fontNames(forFamilyName: "Rotina").isEmpty {
        print("⚠️ WARNING: Rotina fonts not found!")
    } else {
        print("✅ Rotina fonts loaded successfully")
        UIFont.fontNames(forFamilyName: "Rotina").forEach { print("  - \($0)") }
    }
}
```

## Troubleshooting

### Fonts Don't Appear

1. **Check Info.plist**: Verify all font files are listed
2. **Check Build Phases**: Ensure fonts are in "Copy Bundle Resources"
3. **Check file names**: Font file names must match exactly (case-sensitive)
4. **Clean build**: Product > Clean Build Folder (Shift+Cmd+K)
5. **Check font format**: iOS prefers .ttf or .otf; .woff2 works in iOS 10+

### Font Names Don't Match

1. **Get actual font names**:
  ```swift
   if let font = UIFont(name: "Rotina-Regular", size: 12) {
       print("Font loaded: \(font.fontName)")
   }
  ```
2. **Use Font Book app** on Mac to inspect font names

### File Size Concerns

- Consider using only .woff2 files (smaller)
- Or convert to .ttf if you need iOS 9 support
- Each weight is ~50-100KB in WOFF2 format

## Next Steps

After integration:

- Update existing text styles to use custom fonts
- Create reusable font modifiers
- Test on different devices and iOS versions
- Add font override to onboarding flow

## See Also

- [Font Override Documentation](../docs/font-override.md)
- [Font Override Integration Guide](../docs/font-override-integration.md)
- [Design System Typography Tokens](../docs/tokens.md#typography)

