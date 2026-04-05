import SwiftUI
import MinAppKit

protocol AppTheme: MinTheme {
    var id: String { get }
    var onAccent: Color { get }
    var background: Color { get }
    var surface: Color { get }
    var text: Color { get }
    var secondaryText: Color { get }
    var divider: Color { get }
    var isDark: Bool { get }
}

extension AppTheme {
    var secondaryAccent: Color? { nil }
    var headlineFont: Font { .system(size: 22, weight: .bold) }
    var bodyFont: Font { .system(size: 17) }
    var backgroundTint: Color? { background }
    var darkModeBackground: Color? { isDark ? background : nil }
    var lightModeBackground: Color? { isDark ? nil : background }
    var supportsLightMode: Bool { !isDark }
    var darkModeHeadlineColor: Color? { isDark ? text : nil }
    var lightModeHeadlineColor: Color? { isDark ? nil : text }
    var headlineColor: Color { text }
}

struct BuiltInTheme: AppTheme, Identifiable, Hashable {
    let id: String
    let name: String
    let accent: Color
    let onAccent: Color
    let background: Color
    let surface: Color
    let text: Color
    let secondaryText: Color
    let divider: Color
    let isDark: Bool
}

enum BuiltInThemes {
    static let midnight = BuiltInTheme(
        id: "midnight",
        name: "Midnight",
        accent: Color(red: 0.34, green: 0.47, blue: 1.0),
        onAccent: .white,
        background: Color(red: 0.07, green: 0.08, blue: 0.10),
        surface: Color(red: 0.13, green: 0.14, blue: 0.17),
        text: .white,
        secondaryText: Color.white.opacity(0.65),
        divider: Color.white.opacity(0.2),
        isDark: true
    )

    static let sunrise = BuiltInTheme(
        id: "sunrise",
        name: "Sunrise",
        accent: Color(red: 1.0, green: 0.37, blue: 0.25),
        onAccent: .white,
        background: Color(red: 0.98, green: 0.97, blue: 0.94),
        surface: Color.white,
        text: Color(red: 0.14, green: 0.16, blue: 0.2),
        secondaryText: Color(red: 0.14, green: 0.16, blue: 0.2).opacity(0.6),
        divider: Color.black.opacity(0.12),
        isDark: false
    )

    static let all: [BuiltInTheme] = [midnight, sunrise]
}
