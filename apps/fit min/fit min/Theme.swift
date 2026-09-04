import Foundation
import MinAppKit
import Observation
import SwiftUI

struct FitTheme: Identifiable {
    let id: String
    let name: String
    let accent: Color
    let highlight: Color
    let indexColor: Color = Color(red: 1.0, green: 0.251, blue: 0.141)
    let onAccent: Color
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let divider: Color
    let isDark: Bool
    let fontDesign: Font.Design
}

extension FitTheme: MinTheme {
    var secondaryAccent: Color? { highlight }
    var headlineFont: Font { .system(size: 22, weight: .bold, design: fontDesign) }
    var bodyFont: Font { .system(size: 17) }
    var backgroundTint: Color? { background }
    var darkModeBackground: Color? { isDark ? background : nil }
    var lightModeBackground: Color? { isDark ? nil : background }
    var supportsLightMode: Bool { !isDark }
    var darkModeHeadlineColor: Color? { isDark ? text : nil }
    var lightModeHeadlineColor: Color? { isDark ? nil : text }
    var headlineColor: Color { text }
}

enum FitThemes {
    static let track = FitTheme(
        id: "track",
        name: "Track",
        accent: Color(red: 0.94, green: 0.18, blue: 0.12),
        highlight: Color(red: 1.0, green: 0.62, blue: 0.22),
        onAccent: .white,
        background: Color(red: 0.11, green: 0.08, blue: 0.07),
        surface: Color(red: 0.18, green: 0.12, blue: 0.10),
        surfaceElevated: Color(red: 0.23, green: 0.15, blue: 0.12),
        text: .white,
        secondaryText: Color.white.opacity(0.72),
        tertiaryText: Color.white.opacity(0.42),
        divider: Color.white.opacity(0.18),
        isDark: true,
        fontDesign: .rounded
    )

    static let iron = FitTheme(
        id: "iron",
        name: "Iron",
        accent: Color(red: 0.70, green: 0.78, blue: 0.88),
        highlight: Color(red: 0.95, green: 0.96, blue: 1.0),
        onAccent: Color(red: 0.08, green: 0.09, blue: 0.10),
        background: Color(red: 0.06, green: 0.07, blue: 0.08),
        surface: Color(red: 0.12, green: 0.13, blue: 0.15),
        surfaceElevated: Color(red: 0.17, green: 0.18, blue: 0.20),
        text: .white,
        secondaryText: Color.white.opacity(0.70),
        tertiaryText: Color.white.opacity(0.40),
        divider: Color.white.opacity(0.16),
        isDark: true,
        fontDesign: .default
    )

    static let pool = FitTheme(
        id: "pool",
        name: "Pool",
        accent: Color(red: 0.0, green: 0.48, blue: 0.92),
        highlight: Color(red: 0.0, green: 0.78, blue: 0.95),
        onAccent: .white,
        background: Color(red: 0.93, green: 0.98, blue: 1.0),
        surface: .white,
        surfaceElevated: Color(red: 0.85, green: 0.94, blue: 0.99),
        text: Color(red: 0.05, green: 0.13, blue: 0.20),
        secondaryText: Color(red: 0.05, green: 0.13, blue: 0.20).opacity(0.66),
        tertiaryText: Color(red: 0.05, green: 0.13, blue: 0.20).opacity(0.42),
        divider: Color(red: 0.05, green: 0.13, blue: 0.20).opacity(0.12),
        isDark: false,
        fontDesign: .rounded
    )

    static let court = FitTheme(
        id: "court",
        name: "Court",
        accent: Color(red: 0.14, green: 0.50, blue: 0.27),
        highlight: Color(red: 0.89, green: 0.74, blue: 0.24),
        onAccent: .white,
        background: Color(red: 0.95, green: 0.94, blue: 0.88),
        surface: Color(red: 1.0, green: 0.99, blue: 0.94),
        surfaceElevated: Color(red: 0.90, green: 0.91, blue: 0.82),
        text: Color(red: 0.12, green: 0.16, blue: 0.12),
        secondaryText: Color(red: 0.12, green: 0.16, blue: 0.12).opacity(0.66),
        tertiaryText: Color(red: 0.12, green: 0.16, blue: 0.12).opacity(0.42),
        divider: Color(red: 0.12, green: 0.16, blue: 0.12).opacity(0.14),
        isDark: false,
        fontDesign: .serif
    )

    static let trail = FitTheme(
        id: "trail",
        name: "Trail",
        accent: Color(red: 0.93, green: 0.47, blue: 0.18),
        highlight: Color(red: 0.55, green: 0.74, blue: 0.32),
        onAccent: .white,
        background: Color(red: 0.10, green: 0.12, blue: 0.08),
        surface: Color(red: 0.16, green: 0.18, blue: 0.12),
        surfaceElevated: Color(red: 0.22, green: 0.24, blue: 0.16),
        text: Color(red: 0.97, green: 0.94, blue: 0.86),
        secondaryText: Color(red: 0.97, green: 0.94, blue: 0.86).opacity(0.70),
        tertiaryText: Color(red: 0.97, green: 0.94, blue: 0.86).opacity(0.40),
        divider: Color(red: 0.97, green: 0.94, blue: 0.86).opacity(0.16),
        isDark: true,
        fontDesign: .rounded
    )

    static let recovery = FitTheme(
        id: "recovery",
        name: "Recovery",
        accent: Color(red: 0.57, green: 0.45, blue: 0.92),
        highlight: Color(red: 0.86, green: 0.59, blue: 0.86),
        onAccent: .white,
        background: Color(red: 0.97, green: 0.95, blue: 1.0),
        surface: .white,
        surfaceElevated: Color(red: 0.91, green: 0.88, blue: 0.98),
        text: Color(red: 0.17, green: 0.13, blue: 0.22),
        secondaryText: Color(red: 0.17, green: 0.13, blue: 0.22).opacity(0.64),
        tertiaryText: Color(red: 0.17, green: 0.13, blue: 0.22).opacity(0.40),
        divider: Color(red: 0.17, green: 0.13, blue: 0.22).opacity(0.12),
        isDark: false,
        fontDesign: .rounded
    )

    static let all = [track, iron, pool, court, trail, recovery]
}

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let selectedThemeKey = "fitMin.selectedThemeID"
    private let store = NSUbiquitousKeyValueStore.default

    private(set) var availableThemes: [FitTheme] = FitThemes.all
    var selectedThemeID: String {
        didSet {
            UserDefaults.standard.set(selectedThemeID, forKey: selectedThemeKey)
            store.set(selectedThemeID, forKey: selectedThemeKey)
            store.synchronize()
        }
    }

    var currentTheme: FitTheme {
        availableThemes.first(where: { $0.id == selectedThemeID }) ?? FitThemes.track
    }

    private init() {
        let localThemeID = UserDefaults.standard.string(forKey: selectedThemeKey)
        let cloudThemeID = store.string(forKey: selectedThemeKey)
        selectedThemeID = localThemeID ?? cloudThemeID ?? FitThemes.track.id
        syncFromCloud()
    }

    func select(themeID: String) {
        selectedThemeID = themeID
    }

    func syncFromCloud() {
        guard let cloudTheme = store.string(forKey: selectedThemeKey), !cloudTheme.isEmpty else { return }
        selectedThemeID = cloudTheme
    }
}
