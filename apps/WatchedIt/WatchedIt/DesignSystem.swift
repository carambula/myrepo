//
//  DesignSystem.swift
//  WatchedIt
//
//  Centralized Design System with Semantic Tokenization
//

import SwiftUI
@_exported import MinAppKit

// MARK: - Design System

enum DesignSystem {
    
    // MARK: - Color Tokens
    
    enum Color {
        // Accent Color (Primary Brand Color) - Theme-aware
        static var accent: SwiftUI.Color {
            ThemeManager.shared.currentTheme.accent
        }
        
        // Secondary Accent (for themes like McQueen)
        static var secondaryAccent: SwiftUI.Color? {
            ThemeManager.shared.currentTheme.secondaryAccent
        }
        
        // Semantic Colors
        static let primary = SwiftUI.Color.primary
        static let secondary = SwiftUI.Color.secondary
        
        // Background Colors - Theme-aware with tinting
        static var background: SwiftUI.Color {
            #if os(tvOS)
            return ThemeManager.shared.currentTheme.darkModeBackground ?? SwiftUI.Color.black
            #else
            return themedBackgroundColor(
                darkDefault: UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                lightDefault: UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            )
            #endif
        }
        
        static var backgroundSecondary: SwiftUI.Color {
            #if os(tvOS)
            return ThemeManager.shared.currentTheme.darkModeBackground?.opacity(0.92) ?? SwiftUI.Color(white: 0.12)
            #else
            return themedBackgroundColor(
                darkDefault: UIColor.secondarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                lightDefault: UIColor.secondarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            )
            #endif
        }
        
        static var backgroundTertiary: SwiftUI.Color {
            #if os(tvOS)
            return ThemeManager.shared.currentTheme.darkModeBackground?.opacity(0.84) ?? SwiftUI.Color(white: 0.18)
            #else
            return themedBackgroundColor(
                darkDefault: UIColor.tertiarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                lightDefault: UIColor.tertiarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            )
            #endif
        }

        #if !os(tvOS)
        private static func themedBackgroundColor(darkDefault: UIColor, lightDefault: UIColor) -> SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return SwiftUI.Color(
                UIColor { traits in
                    let useDark = traits.userInterfaceStyle == .dark || !theme.supportsLightMode
                    if useDark {
                        return theme.darkModeBackground.map { UIColor($0) } ?? darkDefault
                    }
                    return theme.lightModeBackground.map { UIColor($0) } ?? lightDefault
                }
            )
        }
        #endif
        
        // Surface Colors
        #if os(tvOS)
        static var surface: SwiftUI.Color {
            ThemeManager.shared.currentTheme.darkModeBackground?.opacity(0.9) ?? SwiftUI.Color(white: 0.14)
        }
        static var surfaceElevated: SwiftUI.Color {
            ThemeManager.shared.currentTheme.darkModeBackground?.opacity(0.8) ?? SwiftUI.Color(white: 0.2)
        }
        #else
        static var surface: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            guard theme.darkModeBackground != nil || theme.lightModeBackground != nil else {
                return SwiftUI.Color(.systemGray6)
            }
            return backgroundSecondary
        }
        static var surfaceElevated: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            guard theme.darkModeBackground != nil || theme.lightModeBackground != nil else {
                return SwiftUI.Color(.systemGray5)
            }
            return backgroundTertiary
        }
        #endif

        // Card/Tile Backgrounds
        static var cardBackground: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            if theme.darkModeBackground != nil || theme.lightModeBackground != nil {
                return backgroundSecondary
            }
            #if os(tvOS)
            return SwiftUI.Color(white: 0.16)
            #else
            return SwiftUI.Color(
                UIColor { traits in
                    traits.userInterfaceStyle == .dark ? UIColor.systemGray5 : UIColor.systemGray6
                }
            )
            #endif
        }

        // Grouped list cards should be visibly themed, not system gray.
        static var groupedListCardBackground: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            #if os(tvOS)
            return theme.darkModeBackgroundTint
                ?? theme.backgroundTint
                ?? theme.secondaryAccent
                ?? theme.accent
            #else
            return SwiftUI.Color(
                UIColor { traits in
                    let useDark = traits.userInterfaceStyle == .dark || !theme.supportsLightMode
                    if useDark {
                        if let darkTint = theme.darkModeBackgroundTint {
                            return UIColor(darkTint)
                        }
                    } else if let lightTint = theme.lightModeBackgroundTint {
                        return UIColor(lightTint)
                    }
                    if let legacyTint = theme.backgroundTint {
                        return UIColor(legacyTint)
                    }
                    if let secondary = theme.secondaryAccent {
                        return UIColor(secondary)
                    }
                    return UIColor(theme.accent)
                }
            )
            #endif
        }
        
        // Status Colors
        static let success = SwiftUI.Color.green
        static let error = SwiftUI.Color.red
        static let warning = SwiftUI.Color.orange
        static var info: SwiftUI.Color { accent }
        
        // Border Colors
        #if os(tvOS)
        static var border: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return theme.darkModeListRuleColor ?? SwiftUI.Color.white.opacity(0.25)
        }
        static var borderLight: SwiftUI.Color { border.opacity(0.6) }
        #else
        static var border: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return SwiftUI.Color(
                UIColor { traits in
                    let useDark = traits.userInterfaceStyle == .dark || !theme.supportsLightMode
                    if useDark, let darkRule = theme.darkModeListRuleColor {
                        return UIColor(darkRule)
                    }
                    if !useDark, let lightRule = theme.lightModeListRuleColor {
                        return UIColor(lightRule)
                    }
                    return UIColor.separator.resolvedColor(with: traits)
                }
            )
        }
        static var borderLight: SwiftUI.Color { border.opacity(0.6) }
        #endif
        
        // Overlay Colors
        static let overlay = SwiftUI.Color.black.opacity(0.3)
        static let overlayLight = SwiftUI.Color.black.opacity(0.1)
        
        // Text Colors
        static var textPrimary: SwiftUI.Color {
            #if os(tvOS)
            let theme = ThemeManager.shared.currentTheme
            return theme.darkModeBodyTextColor ?? SwiftUI.Color.primary
            #else
            let theme = ThemeManager.shared.currentTheme
            return SwiftUI.Color(
                UIColor { traits in
                    let useDark = traits.userInterfaceStyle == .dark || !theme.supportsLightMode
                    if useDark, let darkBody = theme.darkModeBodyTextColor {
                        return UIColor(darkBody)
                    }
                    if !useDark, let lightBody = theme.lightModeBodyTextColor {
                        return UIColor(lightBody)
                    }
                    return UIColor.label.resolvedColor(with: traits)
                }
            )
            #endif
        }
        static var textSecondary: SwiftUI.Color { textPrimary.opacity(0.76) }
        static var darkModeHeadline: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return theme.darkModeHeadlineColor ?? theme.headlineColor
        }
        static var lightModeHeadline: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return theme.lightModeHeadlineColor ?? theme.headlineColor
        }
        static var headline: SwiftUI.Color {
            #if os(tvOS)
            return darkModeHeadline
            #else
            let theme = ThemeManager.shared.currentTheme
            return SwiftUI.Color(
                UIColor { traits in
                    let useDark = traits.userInterfaceStyle == .dark || !theme.supportsLightMode
                    if useDark {
                        return UIColor(darkModeHeadline)
                    }
                    return UIColor(lightModeHeadline)
                }
            )
            #endif
        }
        #if os(tvOS)
        static let textTertiary = SwiftUI.Color.secondary.opacity(0.7)
        #else
        static let textTertiary = SwiftUI.Color(.tertiaryLabel)
        #endif
        
        // Interactive Colors
        static var interactive: SwiftUI.Color { accent }
        static var interactivePressed: SwiftUI.Color { accent.opacity(0.8) }
        #if os(tvOS)
        static let interactiveDisabled = SwiftUI.Color(white: 0.4)
        #else
        static let interactiveDisabled = SwiftUI.Color(.systemGray4)
        #endif
    }
    
    // MARK: - Typography Tokens
    
    enum Typography {
        // Display Styles - Theme-aware
        static var displayLarge: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 34, weight: Font.Weight.bold)
        }
        
        static var displayMedium: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 28, weight: Font.Weight.bold)
        }
        
        static var displaySmall: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 24, weight: Font.Weight.bold)
        }
        
        // Headline Styles - Theme-aware
        static var headlineLarge: Font {
            ThemeManager.shared.currentTheme.headlineFont
        }
        
        static var headlineMedium: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 20, weight: Font.Weight.semibold)
        }
        
        static var headlineSmall: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 18, weight: Font.Weight.semibold)
        }
        
        // Title Styles
        static let titleLarge = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)
        static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)
        
        // Body Styles - Theme-aware
        static var bodyLarge: Font {
            ThemeManager.shared.currentTheme.bodyFont
        }
        
        static var bodyMedium: Font {
            ThemeManager.shared.currentThemeBodyFontStyle().bodyFont(size: 16)
        }
        
        static var bodySmall: Font {
            ThemeManager.shared.currentThemeBodyFontStyle().bodyFont(size: 15)
        }
        
        // Label Styles
        static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 13, weight: .medium, design: .default)
        
        // Caption Styles
        static let captionLarge = Font.system(size: 13, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .regular, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)
        
        // Overline Styles
        static let overline = Font.system(size: 10, weight: .medium, design: .default)
        
        // Glass Control Icon Style
        static let glassIcon: Font = .body.weight(.semibold)
        
        // Standalone Icon Styles
        static let iconLarge: Font = .system(size: 24, weight: .medium)
        static let iconMedium: Font = .system(size: 20, weight: .medium)
    }
    
    // MARK: - Spacing Tokens (values from MinAppKit)

    enum Spacing {
        static let xs: CGFloat = MinSpacing.xs
        static let sm: CGFloat = MinSpacing.sm
        static let md: CGFloat = MinSpacing.md
        static let lg: CGFloat = MinSpacing.lg
        static let xl: CGFloat = MinSpacing.xl
        static let xxl: CGFloat = MinSpacing.xxl
        static let xxxl: CGFloat = MinSpacing.xxxl
        static let bottomSafeArea: CGFloat = MinSpacing.bottomSafeArea
        static let screenHorizontalPadding: CGFloat = MinSpacing.screenHorizontalPadding
    }

    // MARK: - Corner Radius Tokens (values from MinAppKit)

    enum CornerRadius {
        static let artTile: CGFloat = MinCornerRadius.artTile
        static let xs: CGFloat = MinCornerRadius.xs
        static let sm: CGFloat = MinCornerRadius.sm
        static let md: CGFloat = MinCornerRadius.md
        static let lg: CGFloat = MinCornerRadius.lg
        static let xl: CGFloat = MinCornerRadius.xl
        static let round: CGFloat = MinCornerRadius.round
    }
    
    // MARK: - Shadow Tokens
    
    enum Shadow {
        static let sm = (color: SwiftUI.Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let md = (color: SwiftUI.Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let lg = (color: SwiftUI.Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let xl = (color: SwiftUI.Color.black.opacity(0.25), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
    }
    
    // MARK: - Iconography Tokens
    
    enum Icon {
        // Navigation Icons
        static let add = "plus"
        static let close = "xmark"
        static let back = "chevron.left"
        static let forward = "chevron.right"
        static let menu = "ellipsis"
        static let search = "magnifyingglass"
        static let filter = "line.3.horizontal.decrease.circle"
        
        // Content Icons
        static let movie = "film"
        static let movies = "film.stack"
        static let poster = "photo"
        static let backdrop = "photo.artframe"
        static let play = "play.fill"
        static let pause = "pause.fill"
        
        // Status Icons
        static let checkmark = "checkmark"
        static let checkmarkCircle = "checkmark.circle.fill"
        static let error = "exclamationmark.triangle.fill"
        static let warning = "exclamationmark.circle.fill"
        static let info = "info.circle.fill"
        
        // Action Icons
        static let bookmark = "bookmark"
        static let bookmarkFill = "bookmark.fill"
        static let bookmarkCircle = "bookmark.circle"
        static let bookmarkCircleFill = "bookmark.circle.fill"
        static let rewatch = "popcorn"
        static let rewatchFill = "popcorn.fill"
        static let rewatchCircle = "popcorn.circle"
        static let rewatchCircleFill = "popcorn.circle.fill"
        static let listen = "microphone"
        static let listenFill = "microphone.fill"
        static let listenCircle = "microphone.circle"
        static let listenCircleFill = "microphone.circle.fill"
        static let edit = "pencil"
        static let delete = "trash"
        static let share = "square.and.arrow.up"
        static let refresh = "arrow.clockwise"
        static let sync = "arrow.triangle.2.circlepath"
        
        // List Icons
        static let list = "list.bullet"
        static let listRectangle = "list.bullet.rectangle"
        static let listNumber = "list.number"
        
        // Source Icons
        static let podcast = "waveform"
        static let link = "link"
        static let source = "square.stack.3d.up.fill"
        
        // Account Icons
        static let account = "person.crop.circle"
        static let settings = "gearshape"
        
        // Data Icons
        static let statistics = "chart.bar.doc.horizontal"
        static let data = "doc.text"
        static let tools = "wrench.and.screwdriver.fill"
        static let issues = "exclamationmark.triangle"
        
        // Rating Icons
        static let rating = "r.square.fill"
        static let star = "star"
        static let starFill = "star.fill"
        
        // Genre Icons
        static let genre = "theatermasks"
        
        // Sort Icons
        static let sort = "arrow.up.arrow.down"
        
        // Status Filter Icons
        static let status = "checkmark"
        
        // Streaming Icons
        static let streaming = "play.circle.fill"
        static let externalLink = "arrow.up.right.square"
        
        // Cast Icons
        static let person = "person.fill"
        static let cast = "person.2.fill"
        
        // Year Icons
        static let calendar = "calendar"
        
        // Import/Export Icons
        static let importIcon = "square.and.arrow.down"
        static let export = "square.and.arrow.up"
        
        // Validation Icons
        static let valid = "checkmark.circle.fill"
        static let invalid = "xmark.circle.fill"
    }
    
    // MARK: - Icon Sizes
    
    enum IconSize {
        static let xs: CGFloat = 12
        static let sm: CGFloat = 16
        static let md: CGFloat = 20
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Animation Tokens
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.35)
        
        static let springQuick = SwiftUI.Animation.spring(response: 0.2, dampingFraction: 0.6)
        static let springStandard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springSlow = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.8)
    }
    
    // MARK: - Opacity Tokens (values from MinAppKit)

    enum Opacity {
        static let disabled: Double = MinOpacity.disabled
        static let pressed: Double = MinOpacity.pressed
        static let hover: Double = MinOpacity.hover
        static let overlay: Double = MinOpacity.overlay
        static let overlayLight: Double = MinOpacity.overlayLight
    }
}

// MARK: - View Extensions for Design System

extension View {
    // Typography Modifiers
    func displayLarge() -> some View {
        self.font(DesignSystem.Typography.displayLarge)
    }
    
    func displayMedium() -> some View {
        self.font(DesignSystem.Typography.displayMedium)
    }
    
    func displaySmall() -> some View {
        self.font(DesignSystem.Typography.displaySmall)
    }
    
    func headlineLarge() -> some View {
        self.font(DesignSystem.Typography.headlineLarge)
    }
    
    func headlineMedium() -> some View {
        self.font(DesignSystem.Typography.headlineMedium)
    }
    
    func headlineSmall() -> some View {
        self.font(DesignSystem.Typography.headlineSmall)
    }
    
    func titleLarge() -> some View {
        self.font(DesignSystem.Typography.titleLarge)
    }
    
    func titleMedium() -> some View {
        self.font(DesignSystem.Typography.titleMedium)
    }
    
    func titleSmall() -> some View {
        self.font(DesignSystem.Typography.titleSmall)
    }
    
    func bodyLarge() -> some View {
        self.font(DesignSystem.Typography.bodyLarge)
    }
    
    func bodyMedium() -> some View {
        self.font(DesignSystem.Typography.bodyMedium)
    }
    
    func bodySmall() -> some View {
        self.font(DesignSystem.Typography.bodySmall)
    }
    
    func labelLarge() -> some View {
        self.font(DesignSystem.Typography.labelLarge)
    }
    
    func labelMedium() -> some View {
        self.font(DesignSystem.Typography.labelMedium)
    }
    
    func labelSmall() -> some View {
        self.font(DesignSystem.Typography.labelSmall)
    }
    
    func captionLarge() -> some View {
        self.font(DesignSystem.Typography.captionLarge)
    }
    
    func captionMedium() -> some View {
        self.font(DesignSystem.Typography.captionMedium)
    }
    
    func captionSmall() -> some View {
        self.font(DesignSystem.Typography.captionSmall)
    }
    
    func overline() -> some View {
        self.font(DesignSystem.Typography.overline)
    }
    
    // Color Modifiers
    func foregroundAccent() -> some View {
        self.foregroundColor(DesignSystem.Color.accent)
    }
    
    func foregroundSuccess() -> some View {
        self.foregroundColor(DesignSystem.Color.success)
    }
    
    func foregroundError() -> some View {
        self.foregroundColor(DesignSystem.Color.error)
    }
    
    func foregroundWarning() -> some View {
        self.foregroundColor(DesignSystem.Color.warning)
    }
    
    // Theme-aware headline color
    func foregroundHeadline() -> some View {
        self.foregroundColor(DesignSystem.Color.headline)
    }
    
    // Background Modifiers
    func backgroundSurface() -> some View {
        self.background(DesignSystem.Color.surface)
    }
    
    func backgroundSurfaceElevated() -> some View {
        self.background(DesignSystem.Color.surfaceElevated)
    }
    
    // Padding Modifiers
    func paddingXS() -> some View {
        self.padding(DesignSystem.Spacing.xs)
    }
    
    func paddingSM() -> some View {
        self.padding(DesignSystem.Spacing.sm)
    }
    
    func paddingMD() -> some View {
        self.padding(DesignSystem.Spacing.md)
    }
    
    func paddingLG() -> some View {
        self.padding(DesignSystem.Spacing.lg)
    }
    
    func paddingXL() -> some View {
        self.padding(DesignSystem.Spacing.xl)
    }
    
    // Corner Radius Modifiers
    func cornerRadiusXS() -> some View {
        self.cornerRadius(DesignSystem.CornerRadius.xs)
    }
    
    func cornerRadiusSM() -> some View {
        self.cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    func cornerRadiusMD() -> some View {
        self.cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    func cornerRadiusLG() -> some View {
        self.cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    func cornerRadiusXL() -> some View {
        self.cornerRadius(DesignSystem.CornerRadius.xl)
    }
    
    func cornerRadiusRound() -> some View {
        self.cornerRadius(DesignSystem.CornerRadius.round)
    }
}

// MARK: - Grouped List Styling

private struct DesignSystemGroupedListModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Color.background)
            .foregroundStyle(DesignSystem.Color.textPrimary)
            .tint(DesignSystem.Color.accent)
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.automatic)
            #endif
            #if os(iOS)
            .listRowSeparatorTint(DesignSystem.Color.border)
            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
            #endif
    }
}

extension View {
    func designSystemGroupedListStyle() -> some View {
        self.modifier(DesignSystemGroupedListModifier())
    }

    func designSystemGroupedListRow() -> some View {
        self
            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
            #if os(iOS)
            .listRowSeparatorTint(DesignSystem.Color.border)
            #endif
    }
}

// MARK: - Settings Screen Styling

extension View {
    func settingsScreenStyle() -> some View {
        self
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.bottomSafeArea)
    }
}

// MARK: - Settings Option Row

/// Reusable selectable row for settings screens.
/// Displays an icon, title, description, and a checkmark when selected.
///
///     SettingsOptionRow(
///         icon: "hand.tap.fill",
///         title: "Bounce",
///         description: "A subtle bounce effect",
///         isSelected: true
///     )
///
struct SettingsOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.iconMedium)
                .foregroundColor(isSelected ? DesignSystem.Color.accent : DesignSystem.Color.textSecondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .headlineSmall()
                    .foregroundColor(DesignSystem.Color.textPrimary)

                Text(description)
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if isSelected {
                Image(systemName: DesignSystem.Icon.checkmarkCircle)
                    .font(DesignSystem.Typography.iconMedium)
                    .foregroundColor(DesignSystem.Color.accent)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(isSelected ? DesignSystem.Color.accent.opacity(0.1) : DesignSystem.Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(
                    isSelected ? DesignSystem.Color.accent.opacity(0.3) : SwiftUI.Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Glass Material Components

/// Standard control sizing, border, and material tokens for the floating toolbar system.
enum GlassControl {
    static let standardHeight: CGFloat = 56
    static let compactHeight: CGFloat = 48

    enum Border {
        static let standard = (color: SwiftUI.Color.white.opacity(0.28), width: CGFloat(0.8))
        static let subtle   = (color: SwiftUI.Color.white.opacity(0.2),  width: CGFloat(0.5))
        static let card     = (color: SwiftUI.Color.white.opacity(0.35), width: CGFloat(0.5))
    }

    static let toolbarMaterial: Material = .thinMaterial
    static let floatingMaterial: Material = .ultraThinMaterial
}

/// Frosted-glass circular icon button — the primary button control throughout the app.
/// Used for search, close, filter, account, and all icon-action surfaces.
///
///     GlassCircleButton(systemImage: DesignSystem.Icon.search, accessibilityLabel: "Search")
///     GlassCircleButton(systemImage: DesignSystem.Icon.close, size: .compact, accessibilityLabel: "Close")
///
struct GlassCircleButton: View {
    let systemImage: String
    var size: Size = .standard
    var foregroundColor: SwiftUI.Color = DesignSystem.Color.textPrimary
    var accessibilityLabel: String

    enum Size {
        case standard
        case compact

        var points: CGFloat {
            switch self {
            case .standard: return GlassControl.standardHeight
            case .compact: return GlassControl.compactHeight
            }
        }
    }

    var body: some View {
        let shape = MinAffordanceStyle.shared.circleShape
        Image(systemName: systemImage)
            .font(DesignSystem.Typography.glassIcon)
            .foregroundStyle(foregroundColor)
            .frame(width: size.points, height: size.points)
            .background(GlassControl.toolbarMaterial)
            .clipShape(shape)
            .overlay { if MinAffordanceStyle.shared.borderEnabled { shape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }
            .accessibilityLabel(accessibilityLabel)
    }
}

/// Frosted-glass capsule bar that groups icon controls.
/// Used for the floating filter toolbar on the main list screen.
///
///     GlassCapsuleToolbar(spacing: 24) {
///         listMenu
///         genreMenu
///         ratingMenu
///     }
///
struct GlassCapsuleToolbar<Content: View>: View {
    var spacing: CGFloat = DesignSystem.Spacing.xl
    var height: CGFloat = GlassControl.standardHeight
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = MinAffordanceStyle.shared.capsuleShape
        HStack(spacing: spacing) {
            content()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .frame(height: height)
        .background(GlassControl.toolbarMaterial)
        .clipShape(shape)
        .overlay { if MinAffordanceStyle.shared.borderEnabled { shape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }
    }
}

/// Frosted-glass capsule search field with a leading search icon.
///
///     GlassSearchField(text: $searchText)
///     GlassSearchField(text: $searchText, height: GlassControl.compactHeight, placeholder: "Find a movie…")
///
struct GlassSearchField: View {
    @Binding var text: String
    var height: CGFloat = GlassControl.standardHeight
    var material: Material = GlassControl.floatingMaterial
    var placeholder: String = "Search movies"

    var body: some View {
        let shape = MinAffordanceStyle.shared.capsuleShape
        HStack(spacing: DesignSystem.Spacing.sm) {
            DesignSystemIcon(DesignSystem.Icon.search, size: DesignSystem.IconSize.sm, color: DesignSystem.Color.textSecondary)
            TextField(placeholder, text: $text)
                .foregroundColor(DesignSystem.Color.textPrimary)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
        .frame(height: height)
        .background(material)
        .clipShape(shape)
        .overlay { if MinAffordanceStyle.shared.borderEnabled { shape.stroke(GlassControl.Border.standard.color, lineWidth: GlassControl.Border.standard.width) } }
    }
}

// MARK: - LiquidGlass Button Style

/// Detail-screen action button with a subtle background offset from the page color.
/// Two modes:
///   - **compact** — circular, used for the 60pt action bar icons (play, rewatch, listen, save).
///   - **standard** — rounded-rectangle, used for other contextual actions.
///
///     Button { … } label: { icon }
///         .buttonStyle(.liquidGlassCompact)
///
///     Button("Open in TMDB") { … }
///         .buttonStyle(.liquidGlass)
///
#if os(iOS)
struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var role: ButtonRole?
    var isCompact: Bool = false

    private var baseFillColor: SwiftUI.Color {
        adjustedBackgroundColor(delta: colorScheme == .dark ? 0.06 : -0.06)
    }

    private var destructiveFillColor: SwiftUI.Color {
        baseFillColor.opacity(0.82).overlaying(DesignSystem.Color.error.opacity(0.18))
    }

    private func adjustedBackgroundColor(delta: CGFloat) -> SwiftUI.Color {
        let uiColor = UIColor(DesignSystem.Color.background)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return SwiftUI.Color(
                UIColor(hue: hue, saturation: saturation,
                        brightness: min(max(brightness + delta, 0), 1), alpha: alpha)
            )
        }
        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return SwiftUI.Color(
                UIColor(white: min(max(white + delta, 0), 1), alpha: alpha)
            )
        }
        return DesignSystem.Color.backgroundSecondary
    }

    func makeBody(configuration: Configuration) -> some View {
        let circleShape = MinAffordanceStyle.shared.circleShape
        let rectShape = MinAffordanceStyle.shared.capsuleShape
        let strokeColor = role == .destructive
            ? DesignSystem.Color.error.opacity(0.35)
            : DesignSystem.Color.borderLight.opacity(0.9)
        configuration.label
            .if(!isCompact) { view in
                view
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .background {
                if isCompact {
                    circleShape.fill(role == .destructive ? destructiveFillColor : baseFillColor)
                } else {
                    rectShape.fill(role == .destructive ? destructiveFillColor : baseFillColor)
                }
            }
            .overlay {
                if MinAffordanceStyle.shared.borderEnabled {
                    if isCompact {
                        circleShape.stroke(strokeColor, lineWidth: GlassControl.Border.standard.width)
                    } else {
                        rectShape.stroke(strokeColor, lineWidth: GlassControl.Border.standard.width)
                    }
                }
            }
            .foregroundColor(role == .destructive ? DesignSystem.Color.error : DesignSystem.Color.textPrimary)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(DesignSystem.Animation.springStandard, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }

    static var liquidGlassCompact: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(isCompact: true)
    }
}

private extension SwiftUI.Color {
    func overlaying(_ overlay: SwiftUI.Color) -> SwiftUI.Color {
        let base = UIColor(self)
        let top = UIColor(overlay)

        var r1: CGFloat = 0; var g1: CGFloat = 0; var b1: CGFloat = 0; var a1: CGFloat = 0
        var r2: CGFloat = 0; var g2: CGFloat = 0; var b2: CGFloat = 0; var a2: CGFloat = 0

        guard base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              top.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return self
        }

        let outAlpha = a2 + a1 * (1 - a2)
        guard outAlpha > 0 else { return .clear }

        return SwiftUI.Color(
            UIColor(
                red: (r2 * a2 + r1 * a1 * (1 - a2)) / outAlpha,
                green: (g2 * a2 + g1 * a1 * (1 - a2)) / outAlpha,
                blue: (b2 * a2 + b1 * a1 * (1 - a2)) / outAlpha,
                alpha: outAlpha
            )
        )
    }
}
#endif

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Design System Card Style

struct DesignSystemCard: ViewModifier {
    var elevation: Elevation = .medium
    
    enum Elevation {
        case none
        case small
        case medium
        case large
        
        var shadow: (color: SwiftUI.Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
            switch self {
            case .none:
                return (color: .clear, radius: 0, x: 0, y: 0)
            case .small:
                return DesignSystem.Shadow.sm
            case .medium:
                return DesignSystem.Shadow.md
            case .large:
                return DesignSystem.Shadow.lg
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Color.surface)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(
                color: elevation.shadow.color,
                radius: elevation.shadow.radius,
                x: elevation.shadow.x,
                y: elevation.shadow.y
            )
    }
}

extension View {
    func designSystemCard(elevation: DesignSystemCard.Elevation = .medium) -> some View {
        self.modifier(DesignSystemCard(elevation: elevation))
    }
}

// MARK: - Empty State View

/// Left-aligned empty state for screens with no content.
/// Replaces `ContentUnavailableView` to keep the app's left-margin alignment consistent.
///
///     EmptyStateView(
///         title: "No Collections Yet",
///         description: "Try enabling lists in Account settings."
///     )
///
struct EmptyStateView: View {
    let title: String
    var description: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .headlineSmall()
                .foregroundColor(DesignSystem.Color.textPrimary)

            if let description {
                Text(description)
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.md + DesignSystem.Spacing.xs + DesignSystem.Spacing.sm)
    }
}

// MARK: - Design System Icon View

struct DesignSystemIcon: View {
    let name: String
    let size: CGFloat
    let color: SwiftUI.Color?
    
    init(_ name: String, size: CGFloat = DesignSystem.IconSize.md, color: SwiftUI.Color? = nil) {
        self.name = name
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Image(systemName: name)
            .font(.system(size: size))
            .foregroundColor(color ?? DesignSystem.Color.textPrimary)
    }
}

