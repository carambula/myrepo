import Foundation
import Observation

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let selectedThemeKey = "selectedThemeID"
    private let store = NSUbiquitousKeyValueStore.default

    private(set) var availableThemes: [BuiltInTheme] = BuiltInThemes.all
    var selectedThemeID: String {
        didSet {
            UserDefaults.standard.set(selectedThemeID, forKey: selectedThemeKey)
            store.set(selectedThemeID, forKey: selectedThemeKey)
            store.synchronize()
        }
    }

    var currentTheme: BuiltInTheme {
        availableThemes.first(where: { $0.id == selectedThemeID }) ?? BuiltInThemes.midnight
    }

    private init() {
        let localThemeID = UserDefaults.standard.string(forKey: selectedThemeKey)
        let cloudThemeID = store.string(forKey: selectedThemeKey)
        selectedThemeID = localThemeID ?? cloudThemeID ?? BuiltInThemes.midnight.id
        syncFromCloud()
    }

    func select(themeID: String) {
        selectedThemeID = themeID
    }

    func syncFromCloud() {
        guard let cloudTheme = store.string(forKey: selectedThemeKey), !cloudTheme.isEmpty else {
            return
        }
        selectedThemeID = cloudTheme
    }
}

// MARK: - Font Override Support

import SwiftUI
import UIKit

enum RotinaWeight: String, Codable, CaseIterable {
    case extraThin = "Rotina-ExtraThin"
    case thin = "Rotina-Thin"
    case extraLight = "Rotina-ExtraLight"
    case light = "Rotina-Light"
    case regular = "Rotina-Regular"
    case medium = "Rotina-Medium"
    case bold = "Rotina-Bold"
    case extraBold = "Rotina-ExtraBold"
    
    var weight: Font.Weight {
        switch self {
        case .extraThin: return .ultraLight
        case .thin: return .thin
        case .extraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
    
    var uiWeight: UIFont.Weight {
        switch self {
        case .extraThin: return .ultraLight
        case .thin: return .thin
        case .extraLight: return .ultraLight
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .extraBold: return .heavy
        }
    }
    
    var displayName: String {
        rawValue.replacingOccurrences(of: "Rotina-", with: "")
    }
}

enum FontTier: String, CaseIterable, Codable {
    case display    // H1, H2 - largest headings
    case heading    // H3-H6 - section headings
    case body       // Paragraphs, body text
    case ui         // Buttons, labels, controls
    case caption    // Small text, metadata
    
    var defaultRotinaWeight: RotinaWeight {
        switch self {
        case .display: return .bold
        case .heading: return .medium
        case .body: return .regular
        case .ui: return .medium
        case .caption: return .regular
        }
    }
    
    var displayName: String {
        switch self {
        case .display: return "Display"
        case .heading: return "Heading"
        case .body: return "Body"
        case .ui: return "UI"
        case .caption: return "Caption"
        }
    }
    
    var description: String {
        switch self {
        case .display: return "Large headings (H1, H2)"
        case .heading: return "Section headings (H3-H6)"
        case .body: return "Paragraphs and body text"
        case .ui: return "Buttons, labels, and controls"
        case .caption: return "Small text and captions"
        }
    }
}

struct FontOverrideSettings: Codable {
    var enabled: Bool = false
    var displayWeight: RotinaWeight = .bold
    var headingWeight: RotinaWeight = .medium
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
    
    mutating func setWeight(_ weight: RotinaWeight, for tier: FontTier) {
        switch tier {
        case .display: displayWeight = weight
        case .heading: headingWeight = weight
        case .body: bodyWeight = weight
        case .ui: uiWeight = weight
        case .caption: captionWeight = weight
        }
    }
}

// Add these to your ThemeManager class:
extension ThemeManager {
    
    @AppStorage("fontOverrideEnabled") var fontOverrideEnabled: Bool = false
    
    private var fontOverrideSettingsData: Data? {
        get { UserDefaults.standard.data(forKey: "fontOverrideSettings") }
        set { UserDefaults.standard.set(newValue, forKey: "fontOverrideSettings") }
    }
    
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
            objectWillChange.send()
        }
    }
    
    // Get custom font for a specific tier
    func customFont(_ tier: FontTier, size: CGFloat) -> Font {
        if fontOverrideEnabled {
            let weight = fontOverrideSettings.weight(for: tier)
            return .custom(weight.rawValue, size: size)
        }
        // Fallback to system font with appropriate weight
        return .system(size: size, weight: fontOverrideSettings.weight(for: tier).weight)
    }
    
    // Get custom UIFont for a specific tier
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
    
    // Verify fonts are loaded (useful for debugging)
    func verifyRotinaFontsLoaded() {
        let rotinaFonts = UIFont.fontNames(forFamilyName: "Rotina")
        if rotinaFonts.isEmpty {
            print("⚠️ WARNING: Rotina fonts not found!")
        } else {
            print("✅ Rotina fonts loaded successfully:")
            rotinaFonts.forEach { print("  - \($0)") }
        }
    }
}
