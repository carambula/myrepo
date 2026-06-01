import SwiftUI
import Observation
import MinAppKit

// MARK: - Theme Protocol (extends MinTheme from MinAppKit)

protocol AppTheme: MinTheme, Identifiable {
    var id: String { get }
    var accentColor: Color { get }
    var headlineFontDesign: Font.Design { get }
    var headlineFontWeight: Font.Weight { get }
    var headlineColorOverride: Color? { get }
    var isDark: Bool { get }
}

extension AppTheme {
    var accent: Color { accentColor }
    var secondaryAccent: Color? { nil }
    var headlineFont: Font { .system(size: 22, weight: headlineFontWeight, design: headlineFontDesign) }
    var bodyFont: Font { .system(size: 17, weight: .regular, design: headlineFontDesign) }
    var headlineColor: Color { headlineColorOverride ?? .primary }
    var darkModeBackground: Color? { nil }
    var lightModeBackground: Color? { nil }
    var supportsLightMode: Bool { !isDark }
    var darkModeHeadlineColor: Color? { headlineColorOverride }
    var lightModeHeadlineColor: Color? { headlineColorOverride }
}

// MARK: - Built-in Themes

struct DefaultTheme: AppTheme {
    let id = "default"
    let name = "Default"
    let accentColor = Color.blue
    let backgroundTint: Color? = Color.clear
    let headlineFontDesign: Font.Design = .default
    let headlineFontWeight: Font.Weight = .bold
    let headlineColorOverride: Color? = nil
    let isDark = false
}

struct MidnightTheme: AppTheme {
    let id = "midnight"
    let name = "Midnight"
    let accentColor = Color(red: 0.6, green: 0.4, blue: 1.0)
    let backgroundTint: Color? = Color(red: 0.05, green: 0.02, blue: 0.15)
    let headlineFontDesign: Font.Design = .default
    let headlineFontWeight: Font.Weight = .bold
    let headlineColorOverride: Color? = Color(red: 0.7, green: 0.5, blue: 1.0)
    let isDark = true
}

struct CoralTheme: AppTheme {
    let id = "coral"
    let name = "Coral"
    let accentColor = Color(red: 1.0, green: 0.4, blue: 0.3)
    let backgroundTint: Color? = Color(red: 0.15, green: 0.05, blue: 0.03)
    let headlineFontDesign: Font.Design = .rounded
    let headlineFontWeight: Font.Weight = .bold
    let headlineColorOverride: Color? = nil
    let isDark = false
}

struct ForestTheme: AppTheme {
    let id = "forest"
    let name = "Forest"
    let accentColor = Color(red: 0.2, green: 0.7, blue: 0.4)
    let backgroundTint: Color? = Color(red: 0.02, green: 0.1, blue: 0.04)
    let headlineFontDesign: Font.Design = .serif
    let headlineFontWeight: Font.Weight = .semibold
    let headlineColorOverride: Color? = nil
    let isDark = true
}

struct OceanTheme: AppTheme {
    let id = "ocean"
    let name = "Ocean"
    let accentColor = Color(red: 0.0, green: 0.75, blue: 0.85)
    let backgroundTint: Color? = Color(red: 0.02, green: 0.08, blue: 0.12)
    let headlineFontDesign: Font.Design = .default
    let headlineFontWeight: Font.Weight = .bold
    let headlineColorOverride: Color? = Color(red: 0.0, green: 0.85, blue: 0.95)
    let isDark = true
}

struct SunsetTheme: AppTheme {
    let id = "sunset"
    let name = "Sunset"
    let accentColor = Color(red: 1.0, green: 0.55, blue: 0.2)
    let backgroundTint: Color? = Color(red: 0.12, green: 0.05, blue: 0.02)
    let headlineFontDesign: Font.Design = .rounded
    let headlineFontWeight: Font.Weight = .heavy
    let headlineColorOverride: Color? = Color(red: 1.0, green: 0.6, blue: 0.25)
    let isDark = false
}

struct BatmanTheme: AppTheme {
    let id = "batman"
    let name = "I'm Batman"
    let accentColor = Color(red: 1.0, green: 0.85, blue: 0.0)
    let backgroundTint: Color? = Color(red: 0.05, green: 0.08, blue: 0.15)
    var headlineFontDesign: Font.Design { .default }
    let headlineFontWeight: Font.Weight = .bold
    let headlineColorOverride: Color? = Color(red: 1.0, green: 0.85, blue: 0.0)
    let isDark = true
}

// MARK: - Custom Theme

struct CustomTheme: AppTheme, Codable {
    let id: String
    var name: String
    var accentRed: Double
    var accentGreen: Double
    var accentBlue: Double
    var tintRed: Double
    var tintGreen: Double
    var tintBlue: Double
    var fontDesignRaw: String
    var fontWeightRaw: String
    var useAccentForHeadlines: Bool
    var isDark: Bool

    var accentColor: Color {
        Color(red: accentRed, green: accentGreen, blue: accentBlue)
    }

    var backgroundTint: Color? {
        Color(red: tintRed, green: tintGreen, blue: tintBlue)
    }

    var headlineFontDesign: Font.Design {
        switch fontDesignRaw {
        case "rounded": return .rounded
        case "serif": return .serif
        case "monospaced": return .monospaced
        default: return .default
        }
    }

    var headlineFontWeight: Font.Weight {
        switch fontWeightRaw {
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "heavy": return .heavy
        case "black": return .black
        default: return .bold
        }
    }

    var headlineColorOverride: Color? {
        useAccentForHeadlines ? accentColor : nil
    }

    init(
        id: String = UUID().uuidString,
        name: String = "Custom",
        accentColor: Color = .blue,
        backgroundTint: Color = .clear,
        fontDesign: String = "default",
        fontWeight: String = "bold",
        useAccentForHeadlines: Bool = false,
        isDark: Bool = false
    ) {
        self.id = id
        self.name = name

        let accent = UIColor(accentColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        accent.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.accentRed = Double(r)
        self.accentGreen = Double(g)
        self.accentBlue = Double(b)

        let tint = UIColor(backgroundTint)
        tint.getRed(&r, green: &g, blue: &b, alpha: nil)
        self.tintRed = Double(r)
        self.tintGreen = Double(g)
        self.tintBlue = Double(b)

        self.fontDesignRaw = fontDesign
        self.fontWeightRaw = fontWeight
        self.useAccentForHeadlines = useAccentForHeadlines
        self.isDark = isDark
    }
}

// MARK: - Theme Manager

@Observable
class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: any AppTheme
    var customThemes: [CustomTheme] = []

    var allThemes: [any AppTheme] {
        var themes: [any AppTheme] = builtInThemes
        themes.append(contentsOf: customThemes)
        return themes
    }

    let builtInThemes: [any AppTheme] = [
        DefaultTheme(),
        MidnightTheme(),
        CoralTheme(),
        ForestTheme(),
        OceanTheme(),
        SunsetTheme(),
        BatmanTheme()
    ]

    @ObservationIgnored
    private let selectedThemeKey = "selectedTheme"
    
    // MARK: - Font Override Properties
    @ObservationIgnored
    @AppStorage("fontOverrideEnabled") var fontOverrideEnabled: Bool = false

    /// Bumped each time a new batch of Rotina weights finishes registering off the main thread. Views
    /// that resolve custom fonts observe this so they re-render once the real fonts become available.
    private(set) var fontRegistrationGeneration = 0
    
    @ObservationIgnored
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
        }
    }

    init() {
        let savedID = UserDefaults.standard.string(forKey: "selectedTheme") ?? "default"
        let builtIns: [any AppTheme] = [
            DefaultTheme(), MidnightTheme(), CoralTheme(),
            ForestTheme(), OceanTheme(), SunsetTheme(), BatmanTheme()
        ]
        self.currentTheme = builtIns.first { $0.id == savedID } ?? DefaultTheme()
        loadCustomThemes()
    }

    func selectTheme(_ theme: any AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.id, forKey: selectedThemeKey)
        CloudKeyValueWriter.setString(theme.id, forKey: selectedThemeKey)
    }

    func addCustomTheme(_ theme: CustomTheme) {
        customThemes.append(theme)
        saveCustomThemes()
    }

    func removeCustomTheme(_ theme: CustomTheme) {
        customThemes.removeAll { $0.id == theme.id }
        if currentTheme.id == theme.id {
            selectTheme(DefaultTheme())
        }
        saveCustomThemes()
    }

    private func saveCustomThemes() {
        if let data = try? JSONEncoder().encode(customThemes) {
            UserDefaults.standard.set(data, forKey: "customThemes")
            CloudKeyValueWriter.setData(data, forKey: "customThemes")
        }
    }

    private func loadCustomThemes() {
        if let data = UserDefaults.standard.data(forKey: "customThemes"),
           let themes = try? JSONDecoder().decode([CustomTheme].self, from: data) {
            customThemes = themes
            let savedID = UserDefaults.standard.string(forKey: selectedThemeKey)
            if let match = customThemes.first(where: { $0.id == savedID }) {
                currentTheme = match
            }
        }
    }
}

// MARK: - Font Override Support

import SwiftUI
import UIKit

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
    case display    // H1, H2 - largest headings
    case heading    // H3-H6 - section headings
    case body       // Paragraphs, body text
    case ui         // Buttons, labels, controls
    case caption    // Small text, metadata
    
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
    /// Registers exactly the Rotina weights referenced by the current override settings, off the main
    /// thread, each at most once. Call only when the custom fonts are about to be displayed (the Font
    /// Settings preview) or when the override is toggled on — never on the launch path.
    func ensureCustomFontsRegistered() {
        guard fontOverrideEnabled else { return }
        let settings = fontOverrideSettings
        let names = [
            settings.displayWeight, settings.headingWeight, settings.bodyWeight,
            settings.uiWeight, settings.captionWeight
        ].map(\.rawValue)
        RotinaFontRegistrar.ensureRegistered(fontNames: names) { [weak self] in
            self?.fontRegistrationGeneration += 1
        }
    }

    // Get custom font for a specific tier
    public func customFont(_ tier: FontTier, size: CGFloat) -> Font {
        if fontOverrideEnabled {
            ensureCustomFontsRegistered()
            _ = fontRegistrationGeneration // Establish observation so views refresh once fonts load.
            let weight = fontOverrideSettings.weight(for: tier)
            return .custom(weight.rawValue, size: size)
        }
        // Fallback to system font with appropriate weight
        return .system(size: size, weight: fontOverrideSettings.weight(for: tier).weight)
    }
    
    // Get custom UIFont for a specific tier
    public func customUIFont(_ tier: FontTier, size: CGFloat) -> UIFont {
        if fontOverrideEnabled {
            ensureCustomFontsRegistered()
            _ = fontRegistrationGeneration // Establish observation so views refresh once fonts load.
            let weight = fontOverrideSettings.weight(for: tier)
            if let font = UIFont(name: weight.rawValue, size: size) {
                return font
            }
        }
        // Fallback to system font
        return UIFont.systemFont(ofSize: size, weight: fontOverrideSettings.weight(for: tier).uiWeight)
    }
    
    // Verify fonts are loaded (useful for debugging)
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
