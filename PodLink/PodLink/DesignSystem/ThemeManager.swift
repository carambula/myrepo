import SwiftUI
import Observation

// MARK: - Theme Protocol

protocol AppTheme: Identifiable {
    var id: String { get }
    var name: String { get }
    var accentColor: Color { get }
    var backgroundTint: Color { get }
    var headlineFontDesign: Font.Design { get }
    var headlineFontWeight: Font.Weight { get }
    var headlineColor: Color? { get }
    var isDark: Bool { get }
}

// MARK: - Built-in Themes

struct DefaultTheme: AppTheme {
    let id = "default"
    let name = "Default"
    let accentColor = Color.blue
    let backgroundTint = Color.clear
    let headlineFontDesign: Font.Design = .default
    let headlineFontWeight: Font.Weight = .bold
    let headlineColor: Color? = nil
    let isDark = false
}

struct MidnightTheme: AppTheme {
    let id = "midnight"
    let name = "Midnight"
    let accentColor = Color(red: 0.6, green: 0.4, blue: 1.0)
    let backgroundTint = Color(red: 0.05, green: 0.02, blue: 0.15)
    let headlineFontDesign: Font.Design = .default
    let headlineFontWeight: Font.Weight = .bold
    let headlineColor: Color? = Color(red: 0.7, green: 0.5, blue: 1.0)
    let isDark = true
}

struct CoralTheme: AppTheme {
    let id = "coral"
    let name = "Coral"
    let accentColor = Color(red: 1.0, green: 0.4, blue: 0.3)
    let backgroundTint = Color(red: 0.15, green: 0.05, blue: 0.03)
    let headlineFontDesign: Font.Design = .rounded
    let headlineFontWeight: Font.Weight = .bold
    let headlineColor: Color? = nil
    let isDark = false
}

struct ForestTheme: AppTheme {
    let id = "forest"
    let name = "Forest"
    let accentColor = Color(red: 0.2, green: 0.7, blue: 0.4)
    let backgroundTint = Color(red: 0.02, green: 0.1, blue: 0.04)
    let headlineFontDesign: Font.Design = .serif
    let headlineFontWeight: Font.Weight = .semibold
    let headlineColor: Color? = nil
    let isDark = true
}

struct OceanTheme: AppTheme {
    let id = "ocean"
    let name = "Ocean"
    let accentColor = Color(red: 0.0, green: 0.75, blue: 0.85)
    let backgroundTint = Color(red: 0.02, green: 0.08, blue: 0.12)
    let headlineFontDesign: Font.Design = .default
    let headlineFontWeight: Font.Weight = .bold
    let headlineColor: Color? = Color(red: 0.0, green: 0.85, blue: 0.95)
    let isDark = true
}

struct SunsetTheme: AppTheme {
    let id = "sunset"
    let name = "Sunset"
    let accentColor = Color(red: 1.0, green: 0.55, blue: 0.2)
    let backgroundTint = Color(red: 0.12, green: 0.05, blue: 0.02)
    let headlineFontDesign: Font.Design = .rounded
    let headlineFontWeight: Font.Weight = .heavy
    let headlineColor: Color? = Color(red: 1.0, green: 0.6, blue: 0.25)
    let isDark = false
}

struct BatmanTheme: AppTheme {
    let id = "batman"
    let name = "I'm Batman"
    let accentColor = Color(red: 1.0, green: 0.85, blue: 0.0)
    let backgroundTint = Color(red: 0.05, green: 0.08, blue: 0.15)
    var headlineFontDesign: Font.Design { .default }
    let headlineFontWeight: Font.Weight = .bold
    let headlineColor: Color? = Color(red: 1.0, green: 0.85, blue: 0.0)
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

    var backgroundTint: Color {
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

    var headlineColor: Color? {
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
        NSUbiquitousKeyValueStore.default.set(theme.id, forKey: selectedThemeKey)
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
            NSUbiquitousKeyValueStore.default.set(data, forKey: "customThemes")
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
