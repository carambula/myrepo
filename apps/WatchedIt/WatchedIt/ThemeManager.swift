//
//  ThemeManager.swift
//  WatchedIt
//
//  Theme Management System
//

import SwiftUI
import Combine
import UIKit
import CloudKit

// MARK: - Theme Protocol (delegates to MinTheme from MinAppKit)

public typealias Theme = MinTheme

// MARK: - Theme Implementations

public struct WatchedItTheme: Theme {
    public let name = "Watched It"
    public let accent = SwiftUI.Color(red: 0.0, green: 0.48, blue: 1.0) // System Blue
    public let secondaryAccent: SwiftUI.Color? = nil
    public let headlineFont = Font.system(size: 22, weight: .bold, design: .default)
    public let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    public let backgroundTint: SwiftUI.Color? = nil
    public let darkModeBackground: SwiftUI.Color? = nil
    public let lightModeBackground: SwiftUI.Color? = nil
    public let supportsLightMode = true
    public let darkModeHeadlineColor: SwiftUI.Color? = nil
    public let lightModeHeadlineColor: SwiftUI.Color? = nil
    public let headlineColor = SwiftUI.Color.primary
}

public struct MatrixTheme: Theme {
    public let name = "Matrix"
    public let accent = SwiftUI.Color(red: 0.0, green: 1.0, blue: 0.0) // Bright Green
    public let secondaryAccent: SwiftUI.Color? = nil
    public let headlineFont = Font.system(size: 22, weight: .bold, design: .monospaced)
    public let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    public let backgroundTint: SwiftUI.Color? = nil
    public let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.02, green: 0.08, blue: 0.02)
    public let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.92, green: 1.0, blue: 0.92)
    public let supportsLightMode = true
    public let darkModeHeadlineColor: SwiftUI.Color?
    public let lightModeHeadlineColor: SwiftUI.Color?
    public let headlineColor: SwiftUI.Color
    
    public init() {
        darkModeHeadlineColor = accent
        lightModeHeadlineColor = SwiftUI.Color(red: 0.0, green: 0.45, blue: 0.0)
        headlineColor = darkModeHeadlineColor ?? accent
    }
}

public struct McQueenTheme: Theme {
    public let name = "McQueen"
    public let accent = SwiftUI.Color(red: 0.4, green: 0.8, blue: 1.0) // Baby Blue
    public let secondaryAccent: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
    // SF Pro Expanded - using rounded design as closest available alternative
    // Note: .expanded design is not available in SwiftUI Font.Design
    // Using .rounded which provides a similar expanded appearance
    public let headlineFont = Font.system(size: 22, weight: .bold, design: .rounded)
    public let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    public let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.4, green: 0.8, blue: 1.0) // Baby Blue tint
    public let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.15, blue: 0.22)
    public let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.91, green: 0.97, blue: 1.0)
    public let supportsLightMode = true
    public let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.6, blue: 0.0)
    public let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.85, green: 0.45, blue: 0.0)
    // Headlines should stay in the orange family for McQueen theme.
    public let headlineColor = SwiftUI.Color(red: 1.0, green: 0.6, blue: 0.0)
}

public struct SepiaTheme: Theme {
    public let name = "Sepia"
    public let accent = SwiftUI.Color(red: 0.6, green: 0.5, blue: 0.4) // Sepia brown
    public let secondaryAccent: SwiftUI.Color? = nil
    public var headlineFont: Font { ThemeFontResolver.newYorkFont(size: 22, headline: true, fallback: nil) }
    public var bodyFont: Font { ThemeFontResolver.newYorkFont(size: 17, headline: false, fallback: nil) }
    public let backgroundTint: SwiftUI.Color? = nil
    public let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.16, green: 0.13, blue: 0.1)
    public let lightModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.98, green: 0.95, blue: 0.88)
    public let supportsLightMode = true
    public let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.68, green: 0.58, blue: 0.46)
    public let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.5, green: 0.4, blue: 0.3)
    public let headlineColor = SwiftUI.Color(red: 0.5, green: 0.4, blue: 0.3)
}

public struct BatmanTheme: Theme {
    public let name = "I'm Batman"
    public let accent = SwiftUI.Color(red: 1.0, green: 0.85, blue: 0.0) // Batman yellow
    public let secondaryAccent: SwiftUI.Color? = nil
    public let headlineFont = Font.system(size: 22, weight: .bold, design: .default).width(.condensed)
    public let bodyFont = Font.system(size: 17, weight: .regular, design: .default)
    public let backgroundTint: SwiftUI.Color? = SwiftUI.Color(red: 0.05, green: 0.08, blue: 0.15) // Dark navy blue
    public let darkModeBackground: SwiftUI.Color? = SwiftUI.Color(red: 0.03, green: 0.06, blue: 0.12)
    public let lightModeBackground: SwiftUI.Color? = nil
    public let supportsLightMode = false
    public let darkModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 1.0, green: 0.85, blue: 0.0)
    public let lightModeHeadlineColor: SwiftUI.Color? = SwiftUI.Color(red: 0.4, green: 0.3, blue: 0.0)
    public let headlineColor = SwiftUI.Color(red: 1.0, green: 0.85, blue: 0.0)
}

// MARK: - Custom Theme Persistence (types from MinAppKit)

public struct BundledThemePresetDefinition: Codable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    public var builtInThemeName: String?
    public var headlineFontStyle: String
    public var bodyFontStyle: String
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case builtInThemeName
        case headlineFontStyle
        case bodyFontStyle
        case accent
        case secondaryAccent
        case darkModeHeadlineColor
        case lightModeHeadlineColor
        case legacyHeadlineColor = "headlineColor"
        case backgroundTint
        case darkModeBackground
        case lightModeBackground
        case supportsLightMode
        case createdAt
        case lastUpdated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        builtInThemeName = try container.decodeIfPresent(String.self, forKey: .builtInThemeName)
        // Missing style keys should inherit from the built-in base theme instead of forcing system default.
        headlineFontStyle = try container.decodeIfPresent(String.self, forKey: .headlineFontStyle) ?? "inherit"
        bodyFontStyle = try container.decodeIfPresent(String.self, forKey: .bodyFontStyle) ?? "inherit"
        accent = try container.decode(ThemeColorData.self, forKey: .accent)
        secondaryAccent = try container.decode(ThemeColorData.self, forKey: .secondaryAccent)
        let legacyHeadlineColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .legacyHeadlineColor)
        darkModeHeadlineColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .darkModeHeadlineColor) ?? legacyHeadlineColor ?? ThemeColorData(red: 1.0, green: 1.0, blue: 1.0)
        lightModeHeadlineColor = try container.decodeIfPresent(ThemeColorData.self, forKey: .lightModeHeadlineColor) ?? legacyHeadlineColor ?? ThemeColorData(red: 0.0, green: 0.0, blue: 0.0)
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
        try container.encodeIfPresent(builtInThemeName, forKey: .builtInThemeName)
        try container.encode(headlineFontStyle, forKey: .headlineFontStyle)
        try container.encode(bodyFontStyle, forKey: .bodyFontStyle)
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

public struct BundledThemePreset: Theme, Identifiable {
    public let definition: BundledThemePresetDefinition
    public let baseTheme: Theme?

    public var id: UUID { definition.id }
    public var name: String { definition.name }
    public var accent: SwiftUI.Color { definition.accent.color }
    public var secondaryAccent: SwiftUI.Color? { definition.secondaryAccent.color }
    public var headlineFont: Font { ThemeFontResolver.font(for: definition.headlineFontStyle, size: 22, headline: true, fallback: baseTheme?.headlineFont) }
    public var bodyFont: Font { ThemeFontResolver.font(for: definition.bodyFontStyle, size: 17, headline: false, fallback: baseTheme?.bodyFont) }
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

// ThemeFontResolver and ThemeAdaptedPalette provided by MinAppKit

public enum ThemePreferences {
    public static let selectedThemeKey = "selectedTheme"
    public static let customThemesStorageKey = "customThemes"
    public static let lastUpdatedKey = "themePreferencesLastUpdated"

    public static func customThemesData() -> Data {
        UserDefaults.standard.data(forKey: customThemesStorageKey) ?? Data()
    }

    public static func selectedThemeName() -> String {
        UserDefaults.standard.string(forKey: selectedThemeKey) ?? "Watched It"
    }

    public static func setSelectedThemeName(_ name: String) {
        UserDefaults.standard.set(name, forKey: selectedThemeKey)
    }

    public static func decodeThemes(from data: Data) -> [CustomThemeDefinition] {
        guard !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([CustomThemeDefinition].self, from: data)) ?? []
    }

    public static func encodeThemes(_ themes: [CustomThemeDefinition]) -> Data {
        (try? JSONEncoder().encode(themes)) ?? Data()
    }

    public static func lastUpdated() -> Date {
        UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date ?? Date.distantPast
    }

    public static func updateLastUpdated(_ date: Date = Date()) {
        UserDefaults.standard.set(date, forKey: lastUpdatedKey)
    }
}

// MARK: - Theme Manager

@MainActor
public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    private static let bundledThemePresetsResource = "theme_presets"
    
    @Published public var currentTheme: Theme {
        didSet {
            ThemePreferences.setSelectedThemeName(currentTheme.name)
            ThemePreferences.updateLastUpdated()
            scheduleThemesPushToCloudKit()
        }
    }

    @Published public private(set) var customThemeDefinitions: [CustomThemeDefinition] = []
    @Published public private(set) var bundledThemeDefinitions: [BundledThemePresetDefinition] = []

    private let builtInThemes: [Theme] = [
        WatchedItTheme(),
        MatrixTheme(),
        McQueenTheme(),
        SepiaTheme(),
        BatmanTheme()
    ]

    private var hasRestoredThemesThisSession = false
    private var hasPushedThemesThisSession = false
    private var pendingPushTask: Task<Void, Never>?
    
    // MARK: - Font Override Properties
    @AppStorage("fontOverrideEnabled") public var fontOverrideEnabled: Bool = false
    
    private var fontOverrideSettingsData: Data? {
        get { UserDefaults.standard.data(forKey: "fontOverrideSettings") }
        set { UserDefaults.standard.set(newValue, forKey: "fontOverrideSettings") }
    }
    
    public var fontOverrideSettings: FontOverrideSettings {
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

    public init() {
        bundledThemeDefinitions = ThemeManager.loadBundledThemeDefinitions()
        customThemeDefinitions = ThemePreferences.decodeThemes(from: ThemePreferences.customThemesData())
        self.currentTheme = WatchedItTheme()
        let savedThemeName = ThemePreferences.selectedThemeName()
        self.currentTheme = allThemesSnapshot().first { $0.name == savedThemeName } ?? WatchedItTheme()
    }
    
    public func getTheme(named name: String) -> Theme? {
        return allThemesSnapshot().first { $0.name == name }
    }
    
    public func getAllThemes() -> [Theme] {
        return allThemesSnapshot()
    }
    
    public func setTheme(_ theme: Theme) {
        currentTheme = theme
    }

    public func makeAdaptedPalette(from highlight: SwiftUI.Color) -> ThemeAdaptedPalette {
        .from(highlight: highlight)
    }

    public func createOrUpdateCustomTheme(
        existingID: UUID?,
        name: String,
        fontStyle: ThemeFontStyle,
        accent: SwiftUI.Color,
        secondaryAccent: SwiftUI.Color,
        darkModeHeadlineColor: SwiftUI.Color,
        lightModeHeadlineColor: SwiftUI.Color,
        darkModeBackground: SwiftUI.Color,
        lightModeBackground: SwiftUI.Color,
        supportsLightMode: Bool
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let builtInConflict = builtInThemes.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
        let bundledConflict = bundledThemeDefinitions.contains { ($0.name).caseInsensitiveCompare(trimmedName) == .orderedSame }
        if (builtInConflict || bundledConflict) && existingID == nil {
            return false
        }

        let now = Date()
        let derivedBackgroundTint = UIColor(darkModeBackground).lightened(by: 0.03).asColor()
        let definition: CustomThemeDefinition
        if let existingID,
           let existing = customThemeDefinitions.first(where: { $0.id == existingID }) {
            definition = CustomThemeDefinition(
                id: existing.id,
                name: trimmedName,
                fontStyle: fontStyle,
                accent: .from(accent),
                secondaryAccent: .from(secondaryAccent),
                darkModeHeadlineColor: .from(darkModeHeadlineColor),
                lightModeHeadlineColor: .from(lightModeHeadlineColor),
                backgroundTint: .from(derivedBackgroundTint),
                darkModeBackground: .from(darkModeBackground),
                lightModeBackground: .from(lightModeBackground),
                supportsLightMode: supportsLightMode,
                createdAt: existing.createdAt,
                lastUpdated: now
            )
            customThemeDefinitions.removeAll { $0.id == existingID }
        } else if let existingByName = customThemeDefinitions.first(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            definition = CustomThemeDefinition(
                id: existingByName.id,
                name: trimmedName,
                fontStyle: fontStyle,
                accent: .from(accent),
                secondaryAccent: .from(secondaryAccent),
                darkModeHeadlineColor: .from(darkModeHeadlineColor),
                lightModeHeadlineColor: .from(lightModeHeadlineColor),
                backgroundTint: .from(derivedBackgroundTint),
                darkModeBackground: .from(darkModeBackground),
                lightModeBackground: .from(lightModeBackground),
                supportsLightMode: supportsLightMode,
                createdAt: existingByName.createdAt,
                lastUpdated: now
            )
            customThemeDefinitions.removeAll { $0.id == existingByName.id }
        } else {
            definition = CustomThemeDefinition(
                name: trimmedName,
                fontStyle: fontStyle,
                accent: .from(accent),
                secondaryAccent: .from(secondaryAccent),
                darkModeHeadlineColor: .from(darkModeHeadlineColor),
                lightModeHeadlineColor: .from(lightModeHeadlineColor),
                backgroundTint: .from(derivedBackgroundTint),
                darkModeBackground: .from(darkModeBackground),
                lightModeBackground: .from(lightModeBackground),
                supportsLightMode: supportsLightMode,
                createdAt: now,
                lastUpdated: now
            )
        }

        customThemeDefinitions.append(definition)
        customThemeDefinitions.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistCustomThemesAndTimestamp()
        currentTheme = CustomTheme(definition: definition)
        return true
    }

    public func deleteCustomTheme(id: UUID) {
        guard let index = customThemeDefinitions.firstIndex(where: { $0.id == id }) else { return }
        let removed = customThemeDefinitions.remove(at: index)
        persistCustomThemesAndTimestamp()
        if currentTheme.name.caseInsensitiveCompare(removed.name) == .orderedSame {
            currentTheme = WatchedItTheme()
        }
    }

    public func restoreThemesFromCloudKitIfNeeded() async {
        if !customThemeDefinitions.isEmpty {
            return
        }
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await CloudKitManager.shared.fetchUserThemePreferencesPayload() else {
                return
            }
            applyThemePayload(payload)
            hasRestoredThemesThisSession = true
        } catch {
            print("⚠️ Failed to fetch theme preferences from iCloud: \(error)")
        }
    }

    public func syncThemesFromCloudKitIfNewer() async {
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await CloudKitManager.shared.fetchUserThemePreferencesPayload() else {
                return
            }
            guard payload.lastUpdated > ThemePreferences.lastUpdated() else { return }
            applyThemePayload(payload)
        } catch {
            print("⚠️ Failed to sync theme preferences from iCloud: \(error)")
        }
    }

    public func pushLocalThemesToCloudKitIfNeeded() async {
        guard !hasPushedThemesThisSession else {
            return
        }
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else { return }

        let themesData = ThemePreferences.encodeThemes(customThemeDefinitions)
        var lastUpdated = ThemePreferences.lastUpdated()
        if lastUpdated == Date.distantPast {
            lastUpdated = Date()
            ThemePreferences.updateLastUpdated(lastUpdated)
        }

        let payload = CloudKitManager.UserThemePreferencesPayload(
            customThemesData: themesData,
            selectedThemeName: currentTheme.name,
            lastUpdated: lastUpdated
        )
        hasPushedThemesThisSession = true
        await CloudKitManager.shared.saveUserThemePreferencesPayload(payload)
    }

    private func scheduleThemesPushToCloudKit() {
        pendingPushTask?.cancel()
        pendingPushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await self?.pushLocalThemesToCloudKitIfNeeded()
        }
    }

    private func persistCustomThemesAndTimestamp() {
        let data = ThemePreferences.encodeThemes(customThemeDefinitions)
        UserDefaults.standard.set(data, forKey: ThemePreferences.customThemesStorageKey)
        ThemePreferences.updateLastUpdated()
        hasPushedThemesThisSession = false
        scheduleThemesPushToCloudKit()
    }

    private func applyThemePayload(_ payload: CloudKitManager.UserThemePreferencesPayload) {
        let decoded = ThemePreferences.decodeThemes(from: payload.customThemesData)
        customThemeDefinitions = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        UserDefaults.standard.set(payload.customThemesData, forKey: ThemePreferences.customThemesStorageKey)
        ThemePreferences.setSelectedThemeName(payload.selectedThemeName)
        ThemePreferences.updateLastUpdated(payload.lastUpdated)
        if let matchedTheme = getTheme(named: payload.selectedThemeName) {
            currentTheme = matchedTheme
        } else {
            currentTheme = WatchedItTheme()
        }
        hasPushedThemesThisSession = true
    }

    public func currentThemeFontStyle() -> ThemeFontStyle {
        return currentThemeHeadlineFontStyle()
    }

    public func currentThemeHeadlineFontStyle() -> ThemeFontStyle {
        if let customTheme = currentTheme as? CustomTheme {
            return customTheme.definition.fontStyle
        }
        if let bundledTheme = currentTheme as? BundledThemePreset,
           let mapped = ThemeFontStyle.fromBundledStyleString(bundledTheme.definition.headlineFontStyle) {
            return mapped
        }
        switch currentTheme.name {
        case "Matrix":
            return .monospaced
        case "Sepia":
            return .serif
        case "McQueen":
            return .rounded
        case "I'm Batman":
            return .condensed
        default:
            return .system
        }
    }

    public func currentThemeBodyFontStyle() -> ThemeFontStyle {
        if let customTheme = currentTheme as? CustomTheme {
            return customTheme.definition.fontStyle
        }
        if let bundledTheme = currentTheme as? BundledThemePreset,
           let mapped = ThemeFontStyle.fromBundledStyleString(bundledTheme.definition.bodyFontStyle) {
            return mapped
        }
        return .system
    }

    private func allThemesSnapshot() -> [Theme] {
        let bundledThemes = bundledThemesSnapshot()
        let customThemes = customThemeDefinitions.map { CustomTheme(definition: $0) as Theme }
        return bundledThemes + customThemes
    }

    private func bundledThemesSnapshot() -> [Theme] {
        let builtInsByName = Dictionary(uniqueKeysWithValues: builtInThemes.map { ($0.name.lowercased(), $0) })
        var overridesByBuiltInName: [String: BundledThemePresetDefinition] = [:]
        var usedPresetIDs = Set<UUID>()

        for definition in bundledThemeDefinitions {
            guard let targetName = definition.builtInThemeName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !targetName.isEmpty else { continue }
            overridesByBuiltInName[targetName.lowercased()] = definition
        }

        var resolvedThemes: [Theme] = []
        for builtIn in builtInThemes {
            let key = builtIn.name.lowercased()
            if let override = overridesByBuiltInName[key] {
                resolvedThemes.append(BundledThemePreset(definition: override, baseTheme: builtIn))
                usedPresetIDs.insert(override.id)
            } else {
                resolvedThemes.append(builtIn)
            }
        }

        let additionalBundledThemes = bundledThemeDefinitions
            .filter { !usedPresetIDs.contains($0.id) }
            .map { definition -> Theme in
                let baseName = definition.builtInThemeName?.lowercased() ?? definition.name.lowercased()
                let baseTheme = builtInsByName[baseName]
                return BundledThemePreset(definition: definition, baseTheme: baseTheme)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return resolvedThemes + additionalBundledThemes
    }

    private static func loadBundledThemeDefinitions() -> [BundledThemePresetDefinition] {
        guard let url = Bundle.main.url(forResource: bundledThemePresetsResource, withExtension: "json") else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([BundledThemePresetDefinition].self, from: data)
        } catch {
            print("⚠️ Failed to load bundled theme presets: \(error)")
            return []
        }
    }
}

private extension ThemeFontStyle {
    static func fromBundledStyleString(_ raw: String) -> ThemeFontStyle? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "system-default":
            return .system
        case "system-rounded":
            return .rounded
        case "system-monospaced":
            return .monospaced
        case "new-york":
            return .serif
        case "system-condensed":
            return .condensed
        case "inherit", "":
            return nil
        default:
            return nil
        }
    }
}

// UIColor theme extensions provided by MinAppKit


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
    // Get custom font for a specific tier
    public func customFont(_ tier: FontTier, size: CGFloat) -> Font {
        if fontOverrideEnabled {
            let weight = fontOverrideSettings.weight(for: tier)
            return .custom(weight.rawValue, size: size)
        }
        // Fallback to system font with appropriate weight
        return .system(size: size, weight: fontOverrideSettings.weight(for: tier).weight)
    }
    
    // Get custom UIFont for a specific tier
    public func customUIFont(_ tier: FontTier, size: CGFloat) -> UIFont {
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
