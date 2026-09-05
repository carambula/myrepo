import SwiftUI
import Foundation

/// Codable definition for user-created custom themes.
/// Supports legacy migration from single `headlineColor` to split
/// `darkModeHeadlineColor`/`lightModeHeadlineColor`.
public struct CustomThemeDefinition: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var fontStyle: ThemeFontStyle
    public var accent: ThemeColorData
    public var secondaryAccent: ThemeColorData
    public var darkModeHeadlineColor: ThemeColorData
    public var lightModeHeadlineColor: ThemeColorData
    public var backgroundTint: ThemeColorData
    public var darkModeBackground: ThemeColorData
    public var lightModeBackground: ThemeColorData
    public var supportsLightMode: Bool
    public var createdAt: Date
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        name: String,
        fontStyle: ThemeFontStyle = .system,
        accent: ThemeColorData,
        secondaryAccent: ThemeColorData,
        darkModeHeadlineColor: ThemeColorData,
        lightModeHeadlineColor: ThemeColorData,
        backgroundTint: ThemeColorData,
        darkModeBackground: ThemeColorData,
        lightModeBackground: ThemeColorData,
        supportsLightMode: Bool,
        createdAt: Date = Date(),
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fontStyle = fontStyle
        self.accent = accent
        self.secondaryAccent = secondaryAccent
        self.darkModeHeadlineColor = darkModeHeadlineColor
        self.lightModeHeadlineColor = lightModeHeadlineColor
        self.backgroundTint = backgroundTint
        self.darkModeBackground = darkModeBackground
        self.lightModeBackground = lightModeBackground
        self.supportsLightMode = supportsLightMode
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }

    enum CodingKeys: String, CodingKey {
        case id, name, fontStyle, accent, secondaryAccent
        case darkModeHeadlineColor, lightModeHeadlineColor
        case legacyHeadlineColor = "headlineColor"
        case backgroundTint, darkModeBackground, lightModeBackground
        case supportsLightMode, createdAt, lastUpdated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        fontStyle = try container.decodeIfPresent(ThemeFontStyle.self, forKey: .fontStyle) ?? .system
        accent = try container.decode(ThemeColorData.self, forKey: .accent)
        secondaryAccent = try container.decode(ThemeColorData.self, forKey: .secondaryAccent)
        let legacy = try container.decodeIfPresent(ThemeColorData.self, forKey: .legacyHeadlineColor)
        darkModeHeadlineColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .darkModeHeadlineColor) ?? legacy ?? ThemeColorData(red: 1, green: 1, blue: 1)
        lightModeHeadlineColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .lightModeHeadlineColor) ?? legacy ?? ThemeColorData(red: 0, green: 0, blue: 0)
        backgroundTint = try container.decode(ThemeColorData.self, forKey: .backgroundTint)
        darkModeBackground = try container.decode(ThemeColorData.self, forKey: .darkModeBackground)
        lightModeBackground = try container.decode(ThemeColorData.self, forKey: .lightModeBackground)
        supportsLightMode = try container.decode(Bool.self, forKey: .supportsLightMode)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(fontStyle, forKey: .fontStyle)
        try container.encode(accent, forKey: .accent)
        try container.encode(secondaryAccent, forKey: .secondaryAccent)
        try container.encode(darkModeHeadlineColor, forKey: .darkModeHeadlineColor)
        try container.encode(lightModeHeadlineColor, forKey: .lightModeHeadlineColor)
        try container.encode(darkModeHeadlineColor, forKey: .legacyHeadlineColor)
        try container.encode(backgroundTint, forKey: .backgroundTint)
        try container.encode(darkModeBackground, forKey: .darkModeBackground)
        try container.encode(lightModeBackground, forKey: .lightModeBackground)
        try container.encode(supportsLightMode, forKey: .supportsLightMode)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}

/// Wraps a `CustomThemeDefinition` to conform to `MinTheme`.
public struct CustomTheme: MinTheme, Identifiable {
    public let definition: CustomThemeDefinition

    public init(definition: CustomThemeDefinition) {
        self.definition = definition
    }

    public var id: UUID { definition.id }
    public var name: String { definition.name }
    public var accent: SwiftUI.Color { definition.accent.color }
    public var secondaryAccent: SwiftUI.Color? { definition.secondaryAccent.color }
    public var headlineFont: Font { definition.fontStyle.headlineFont(size: 22, weight: .bold) }
    public var bodyFont: Font { definition.fontStyle.bodyFont(size: 17) }
    public var backgroundTint: SwiftUI.Color? {
        darkModeBackgroundTint ?? lightModeBackgroundTint ?? definition.backgroundTint.color
    }
    public var darkModeBackground: SwiftUI.Color? { definition.darkModeBackground.color }
    public var lightModeBackground: SwiftUI.Color? { definition.lightModeBackground.color }
    public var supportsLightMode: Bool { definition.supportsLightMode }
    public var darkModeHeadlineColor: SwiftUI.Color? { definition.darkModeHeadlineColor.color }
    public var lightModeHeadlineColor: SwiftUI.Color? { definition.lightModeHeadlineColor.color }
    public var headlineColor: SwiftUI.Color { definition.darkModeHeadlineColor.color }
}
