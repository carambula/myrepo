//
//  DesignSystem.swift
//  Cyclismo
//
//  Centralized Design System with Semantic Tokenization.
//

import SwiftUI
@_exported import MinAppKit

// MARK: - Design System

enum DesignSystem {

    // MARK: - Color Tokens

    enum Color {
        static var accent: SwiftUI.Color {
            ThemeManager.shared.currentTheme.accent
        }

        static var secondaryAccent: SwiftUI.Color? {
            ThemeManager.shared.currentTheme.secondaryAccent
        }

        static var duotoneHighlight: SwiftUI.Color {
            ThemeManager.shared.currentTheme.duotoneHighlightColor
        }

        static var duotoneShadow: SwiftUI.Color {
            ThemeManager.shared.currentTheme.duotoneShadowColor
        }

        static let primary = SwiftUI.Color.primary
        static let secondary = SwiftUI.Color.secondary

        static var background: SwiftUI.Color {
            themedBackgroundColor(
                darkDefault: UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                lightDefault: UIColor.systemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            )
        }

        static var backgroundSecondary: SwiftUI.Color {
            themedBackgroundColor(
                darkDefault: UIColor.secondarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                lightDefault: UIColor.secondarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            )
        }

        static var backgroundTertiary: SwiftUI.Color {
            themedBackgroundColor(
                darkDefault: UIColor.tertiarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
                lightDefault: UIColor.tertiarySystemBackground.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            )
        }

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

        static var cardBackground: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            if theme.darkModeBackground != nil || theme.lightModeBackground != nil {
                return backgroundSecondary
            }
            return SwiftUI.Color(
                UIColor { traits in
                    traits.userInterfaceStyle == .dark ? UIColor.secondarySystemBackground : UIColor.systemBackground
                }
            )
        }

        static var groupedListCardBackground: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return SwiftUI.Color(
                UIColor { traits in
                    let useDark = traits.userInterfaceStyle == .dark || !theme.supportsLightMode
                    if useDark, let darkTint = theme.darkModeBackgroundTint {
                        return UIColor(darkTint)
                    }
                    if !useDark, let lightTint = theme.lightModeBackgroundTint {
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
        }

        static let success = SwiftUI.Color.green
        static let error = SwiftUI.Color.red
        static let warning = SwiftUI.Color.orange
        static var info: SwiftUI.Color { accent }

        static let border = SwiftUI.Color(.separator)
        static let borderLight = SwiftUI.Color(.separator).opacity(0.3)

        static let overlay = SwiftUI.Color.black.opacity(0.3)
        static let overlayLight = SwiftUI.Color.black.opacity(0.1)

        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary
        static let textTertiary = SwiftUI.Color(.tertiaryLabel)

        static var darkModeHeadline: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return theme.darkModeHeadlineColor ?? theme.headlineColor
        }

        static var lightModeHeadline: SwiftUI.Color {
            let theme = ThemeManager.shared.currentTheme
            return theme.lightModeHeadlineColor ?? theme.headlineColor
        }

        static var headline: SwiftUI.Color {
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
        }

        static var interactive: SwiftUI.Color { accent }
        static var interactivePressed: SwiftUI.Color { accent.opacity(0.8) }
        static let interactiveDisabled = SwiftUI.Color(.systemGray4)
    }

    // MARK: - Typography Tokens

    enum Typography {
        static var displayLarge: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 34, weight: .bold)
        }

        static var displayMedium: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 28, weight: .bold)
        }

        static var displaySmall: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 24, weight: .bold)
        }

        static var headlineLarge: Font {
            ThemeManager.shared.currentTheme.headlineFont
        }

        static var headlineMedium: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 20, weight: .semibold)
        }

        static var headlineSmall: Font {
            ThemeManager.shared.currentThemeHeadlineFontStyle().headlineFont(size: 18, weight: .semibold)
        }

        static let titleLarge = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)
        static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)

        static var bodyLarge: Font {
            ThemeManager.shared.currentTheme.bodyFont
        }

        static var bodyMedium: Font {
            ThemeManager.shared.currentThemeBodyFontStyle().bodyFont(size: 16)
        }

        static var bodySmall: Font {
            ThemeManager.shared.currentThemeBodyFontStyle().bodyFont(size: 15)
        }

        static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 13, weight: .medium, design: .default)

        static let captionLarge = Font.system(size: 13, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .regular, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)

        static let overline = Font.system(size: 10, weight: .medium, design: .default)
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
        static let add = "plus"
        static let close = "xmark"
        static let back = "chevron.left"
        static let forward = "chevron.right"
        static let menu = "ellipsis"
        static let search = "magnifyingglass"
        static let filter = "line.3.horizontal.decrease.circle"

        static let race = "flag.checkered"
        static let category = "tag"
        static let format = "list.bullet.rectangle"
        static let streamer = "play.rectangle"
        static let calendar = "calendar"
        static let location = "mappin.circle"
        static let link = "link"
        static let externalLink = "arrow.up.right.square"

        static let checkmark = "checkmark"
        static let checkmarkCircle = "checkmark.circle.fill"
        static let error = "exclamationmark.triangle.fill"
        static let warning = "exclamationmark.circle.fill"
        static let info = "info.circle.fill"

        static let person = "person.fill"
        static let personCircle = "person.circle.fill"
        static let team = "person.2.fill"
        static let edit = "pencil"
        static let delete = "trash"
        static let refresh = "arrow.clockwise"
        static let sort = "arrow.up.arrow.down"
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
    func displayLarge() -> some View { self.font(DesignSystem.Typography.displayLarge) }
    func displayMedium() -> some View { self.font(DesignSystem.Typography.displayMedium) }
    func displaySmall() -> some View { self.font(DesignSystem.Typography.displaySmall) }
    func headlineLarge() -> some View { self.font(DesignSystem.Typography.headlineLarge) }
    func headlineMedium() -> some View { self.font(DesignSystem.Typography.headlineMedium) }
    func headlineSmall() -> some View { self.font(DesignSystem.Typography.headlineSmall) }
    func titleLarge() -> some View { self.font(DesignSystem.Typography.titleLarge) }
    func titleMedium() -> some View { self.font(DesignSystem.Typography.titleMedium) }
    func titleSmall() -> some View { self.font(DesignSystem.Typography.titleSmall) }
    func bodyLarge() -> some View { self.font(DesignSystem.Typography.bodyLarge) }
    func bodyMedium() -> some View { self.font(DesignSystem.Typography.bodyMedium) }
    func bodySmall() -> some View { self.font(DesignSystem.Typography.bodySmall) }
    func labelLarge() -> some View { self.font(DesignSystem.Typography.labelLarge) }
    func labelMedium() -> some View { self.font(DesignSystem.Typography.labelMedium) }
    func labelSmall() -> some View { self.font(DesignSystem.Typography.labelSmall) }
    func captionLarge() -> some View { self.font(DesignSystem.Typography.captionLarge) }
    func captionMedium() -> some View { self.font(DesignSystem.Typography.captionMedium) }
    func captionSmall() -> some View { self.font(DesignSystem.Typography.captionSmall) }
    func overline() -> some View { self.font(DesignSystem.Typography.overline) }

    func foregroundAccent() -> some View { self.foregroundColor(DesignSystem.Color.accent) }
    func foregroundSuccess() -> some View { self.foregroundColor(DesignSystem.Color.success) }
    func foregroundError() -> some View { self.foregroundColor(DesignSystem.Color.error) }
    func foregroundWarning() -> some View { self.foregroundColor(DesignSystem.Color.warning) }
    func foregroundHeadline() -> some View {
        self.foregroundColor(DesignSystem.Color.headline)
    }

    func backgroundSurface() -> some View { self.background(DesignSystem.Color.surface) }
    func backgroundSurfaceElevated() -> some View { self.background(DesignSystem.Color.surfaceElevated) }

    func paddingXS() -> some View { self.padding(DesignSystem.Spacing.xs) }
    func paddingSM() -> some View { self.padding(DesignSystem.Spacing.sm) }
    func paddingMD() -> some View { self.padding(DesignSystem.Spacing.md) }
    func paddingLG() -> some View { self.padding(DesignSystem.Spacing.lg) }
    func paddingXL() -> some View { self.padding(DesignSystem.Spacing.xl) }

    func cornerRadiusXS() -> some View { self.cornerRadius(DesignSystem.CornerRadius.xs) }
    func cornerRadiusSM() -> some View { self.cornerRadius(DesignSystem.CornerRadius.sm) }
    func cornerRadiusMD() -> some View { self.cornerRadius(DesignSystem.CornerRadius.md) }
    func cornerRadiusLG() -> some View { self.cornerRadius(DesignSystem.CornerRadius.lg) }
    func cornerRadiusXL() -> some View { self.cornerRadius(DesignSystem.CornerRadius.xl) }
    func cornerRadiusRound() -> some View { self.cornerRadius(DesignSystem.CornerRadius.round) }
}

// MARK: - Design System Button Style

struct DesignSystemButtonStyle: ButtonStyle {
    var variant: Variant = .primary
    var size: Size = .medium

    enum Variant {
        case primary
        case secondary
        case tertiary
        case destructive
        case ghost
    }

    enum Size {
        case small
        case medium
        case large

        var verticalPadding: CGFloat {
            switch self {
            case .small: return DesignSystem.Spacing.sm
            case .medium: return DesignSystem.Spacing.md
            case .large: return DesignSystem.Spacing.lg
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return DesignSystem.Spacing.md
            case .medium: return DesignSystem.Spacing.lg
            case .large: return DesignSystem.Spacing.xl
            }
        }

        var fontSize: Font {
            switch self {
            case .small: return DesignSystem.Typography.labelSmall
            case .medium: return DesignSystem.Typography.labelMedium
            case .large: return DesignSystem.Typography.labelLarge
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.fontSize)
            .foregroundColor(foregroundColor(for: variant))
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundColor(for: variant))
            .cornerRadius(DesignSystem.CornerRadius.md)
            .opacity(configuration.isPressed ? DesignSystem.Opacity.pressed : 1.0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.springQuick, value: configuration.isPressed)
    }

    private func foregroundColor(for variant: Variant) -> SwiftUI.Color {
        switch variant {
        case .primary: return .white
        case .secondary: return DesignSystem.Color.accent
        case .tertiary: return DesignSystem.Color.textPrimary
        case .destructive: return .white
        case .ghost: return DesignSystem.Color.textPrimary
        }
    }

    private func backgroundColor(for variant: Variant) -> SwiftUI.Color {
        switch variant {
        case .primary: return DesignSystem.Color.accent
        case .secondary: return DesignSystem.Color.accent.opacity(0.1)
        case .tertiary: return DesignSystem.Color.surface
        case .destructive: return DesignSystem.Color.error
        case .ghost: return .clear
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
            case .none: return (color: .clear, radius: 0, x: 0, y: 0)
            case .small: return DesignSystem.Shadow.sm
            case .medium: return DesignSystem.Shadow.md
            case .large: return DesignSystem.Shadow.lg
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

// MARK: - Grouped List Styling

private struct DesignSystemGroupedListModifier: ViewModifier {
    @ObservedObject private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Color.background)
            .foregroundStyle(DesignSystem.Color.textPrimary)
            .tint(themeManager.currentTheme.accent)
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(DesignSystem.Color.border)
            .listRowBackground(DesignSystem.Color.groupedListCardBackground)
            .preferredColorScheme(themeManager.currentTheme.supportsLightMode ? nil : .dark)
            #if os(iOS)
            .toolbarBackground(DesignSystem.Color.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
    }
}

extension View {
    func designSystemGroupedListStyle() -> some View {
        self.modifier(DesignSystemGroupedListModifier())
    }

    func designSystemGroupedListRow() -> some View {
        self.listRowBackground(DesignSystem.Color.groupedListCardBackground)
    }

    func viewControlIconStyle() -> some View {
        font(.body.weight(.semibold))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
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
