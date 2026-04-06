import Foundation
import Observation
import SwiftUI
import UIKit

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

    // MARK: - Font Override Properties

    @ObservationIgnored
    @AppStorage("fontOverrideEnabled") var fontOverrideEnabled: Bool = false

    @ObservationIgnored
    private var fontOverrideSettingsData: Data? {
        get { UserDefaults.standard.data(forKey: "fontOverrideSettings") }
        set { UserDefaults.standard.set(newValue, forKey: "fontOverrideSettings") }
    }

    @ObservationIgnored
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

public enum RotinaWeight: String, Codable, CaseIterable {
    case extraThin = "Rotina-ExtraThin"
    case thin = "Rotina-Thin"
    case extraLight = "Rotina-ExtraLight"
    case light = "Rotina-Light"
    case regular = "Rotina-Regular"
    case medium = "Rotina-Medium"
    case bold = "Rotina-Bold"
    case extraBold = "Rotina-ExtraBold"

    public var weight: Font.Weight {
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

    public var uiWeight: UIFont.Weight {
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

    public var displayName: String {
        rawValue.replacingOccurrences(of: "Rotina-", with: "")
    }
}

public enum FontTier: String, CaseIterable, Codable {
    case display
    case heading
    case body
    case ui
    case caption

    public var defaultRotinaWeight: RotinaWeight {
        switch self {
        case .display: return .bold
        case .heading: return .medium
        case .body: return .regular
        case .ui: return .medium
        case .caption: return .regular
        }
    }

    public var displayName: String {
        switch self {
        case .display: return "Display"
        case .heading: return "Heading"
        case .body: return "Body"
        case .ui: return "UI"
        case .caption: return "Caption"
        }
    }

    public var description: String {
        switch self {
        case .display: return "Large headings (H1, H2)"
        case .heading: return "Section headings (H3-H6)"
        case .body: return "Paragraphs and body text"
        case .ui: return "Buttons, labels, and controls"
        case .caption: return "Small text and captions"
        }
    }
}

public struct FontOverrideSettings: Codable, Equatable {
    public var enabled: Bool = false
    public var displayWeight: RotinaWeight = .bold
    public var headingWeight: RotinaWeight = .medium
    public var bodyWeight: RotinaWeight = .regular
    public var uiWeight: RotinaWeight = .medium
    public var captionWeight: RotinaWeight = .regular

    public init(
        enabled: Bool = false,
        displayWeight: RotinaWeight = .bold,
        headingWeight: RotinaWeight = .medium,
        bodyWeight: RotinaWeight = .regular,
        uiWeight: RotinaWeight = .medium,
        captionWeight: RotinaWeight = .regular
    ) {
        self.enabled = enabled
        self.displayWeight = displayWeight
        self.headingWeight = headingWeight
        self.bodyWeight = bodyWeight
        self.uiWeight = uiWeight
        self.captionWeight = captionWeight
    }

    public func weight(for tier: FontTier) -> RotinaWeight {
        switch tier {
        case .display: return displayWeight
        case .heading: return headingWeight
        case .body: return bodyWeight
        case .ui: return uiWeight
        case .caption: return captionWeight
        }
    }

    public mutating func setWeight(_ weight: RotinaWeight, for tier: FontTier) {
        switch tier {
        case .display: displayWeight = weight
        case .heading: headingWeight = weight
        case .body: bodyWeight = weight
        case .ui: uiWeight = weight
        case .caption: captionWeight = weight
        }
    }
}

// MARK: - Font Override Methods

extension ThemeManager {
    public func customFont(_ tier: FontTier, size: CGFloat) -> Font {
        if fontOverrideEnabled {
            let weight = fontOverrideSettings.weight(for: tier)
            return .custom(weight.rawValue, size: size)
        }
        return .system(size: size, weight: fontOverrideSettings.weight(for: tier).weight)
    }

    public func customUIFont(_ tier: FontTier, size: CGFloat) -> UIFont {
        if fontOverrideEnabled {
            let weight = fontOverrideSettings.weight(for: tier)
            if let font = UIFont(name: weight.rawValue, size: size) {
                return font
            }
        }
        return UIFont.systemFont(ofSize: size, weight: fontOverrideSettings.weight(for: tier).uiWeight)
    }

    public func verifyRotinaFontsLoaded() {
        let rotinaFonts = UIFont.fontNames(forFamilyName: "Rotina")
        if rotinaFonts.isEmpty {
            print("⚠️ WARNING: Rotina fonts not found!")
        } else {
            print("✅ Rotina fonts loaded successfully:")
            rotinaFonts.forEach { print("  - \($0)") }
        }
    }
}
