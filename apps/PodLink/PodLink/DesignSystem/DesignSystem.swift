import SwiftUI
import UIKit
@_exported import MinAppKit

struct DesignSystem {

    // MARK: - Typography

    struct Typography {
        static func displayLarge() -> Font {
            let theme = ThemeManager.shared.currentTheme
            if let design = theme.headlineFontDesign as Font.Design? {
                return .system(size: 34, weight: theme.headlineFontWeight, design: design)
            }
            return .system(size: 34, weight: .bold)
        }

        static func displayMedium() -> Font {
            let theme = ThemeManager.shared.currentTheme
            if let design = theme.headlineFontDesign as Font.Design? {
                return .system(size: 28, weight: theme.headlineFontWeight, design: design)
            }
            return .system(size: 28, weight: .bold)
        }

        static func headlineLarge() -> Font {
            let theme = ThemeManager.shared.currentTheme
            if let design = theme.headlineFontDesign as Font.Design? {
                return .system(size: 22, weight: theme.headlineFontWeight, design: design)
            }
            return .system(size: 22, weight: .semibold)
        }

        static func headlineMedium() -> Font {
            let theme = ThemeManager.shared.currentTheme
            if let design = theme.headlineFontDesign as Font.Design? {
                return .system(size: 20, weight: theme.headlineFontWeight, design: design)
            }
            return .system(size: 20, weight: .semibold)
        }

        static func headlineSmall() -> Font {
            let theme = ThemeManager.shared.currentTheme
            if let design = theme.headlineFontDesign as Font.Design? {
                return .system(size: 18, weight: theme.headlineFontWeight, design: design)
            }
            return .system(size: 18, weight: .semibold)
        }

        static func bodyLarge() -> Font {
            .system(size: 17)
        }

        static func bodyMedium() -> Font {
            .system(size: 15)
        }

        static func bodySmall() -> Font {
            .system(size: 13)
        }

        /// Secondary line under a display title (matches Cyclismo `titleMedium`).
        static func titleMedium() -> Font {
            let theme = ThemeManager.shared.currentTheme
            if let design = theme.headlineFontDesign as Font.Design? {
                return .system(size: 18, weight: .medium, design: design)
            }
            return .system(size: 18, weight: .medium)
        }

        /// Emphasized list / link labels (matches Cyclismo `labelMedium`).
        static func labelMedium() -> Font {
            .system(size: 14, weight: .medium)
        }

        /// Dense metadata under titles (matches Cyclismo `captionMedium`).
        static func captionMedium() -> Font {
            .system(size: 12, weight: .regular)
        }

        /// Fine print and timestamps (matches Cyclismo `captionSmall`).
        static func captionSmall() -> Font {
            .system(size: 11, weight: .regular)
        }

        static func caption() -> Font {
            captionSmall()
        }
    }

    // MARK: - Colors

    struct Colors {
        static var accent: Color {
            ThemeManager.shared.currentTheme.accentColor
        }

        static var background: Color {
            dynamicColor { traits in
                themedBackground(for: traits)
            }
        }

        static var backgroundSecondary: Color {
            dynamicColor { traits in
                let base = themedBackground(for: traits)
                let useDark = prefersDarkAppearance(for: traits)
                return useDark
                    ? base.mix(with: .white, ratio: 0.06)
                    : base.mix(with: .black, ratio: 0.04)
            }
        }

        static var backgroundTertiary: Color {
            dynamicColor { traits in
                let base = themedBackground(for: traits)
                let useDark = prefersDarkAppearance(for: traits)
                return useDark
                    ? base.mix(with: .white, ratio: 0.1)
                    : base.mix(with: .black, ratio: 0.08)
            }
        }

        static var surface: Color {
            backgroundSecondary
        }

        static var surfaceElevated: Color {
            backgroundTertiary
        }

        static var cardBackground: Color {
            surface
        }

        static var groupedListCardBackground: Color {
            dynamicColor { traits in
                guard hasThemeBackground else {
                    return UIColor(ThemeManager.shared.currentTheme.accentColor)
                }
                let bg = themedBackground(for: traits)
                let useDark = prefersDarkAppearance(for: traits)
                return useDark
                    ? bg.mix(with: .white, ratio: 0.05)
                    : bg.mix(with: .black, ratio: 0.05)
            }
        }

        static var textPrimary: Color {
            dynamicColor { traits in
                guard hasThemeBackground else {
                    return UIColor.label.resolvedColor(with: traits)
                }
                let background = themedBackground(for: traits)
                let tint = themeTintColor
                let candidate = prefersDarkAppearance(for: traits)
                    ? tint.mix(with: .white, ratio: 0.88)
                    : tint.mix(with: .black, ratio: 0.88)
                return candidate.adjustedForContrast(against: background, minimumRatio: 4.5)
            }
        }

        static var textSecondary: Color {
            textPrimary.opacity(0.76)
        }

        static var textTertiary: Color {
            if hasThemeBackground {
                return textPrimary.opacity(0.58)
            }
            return Color(.tertiaryLabel)
        }

        static var divider: Color {
            dynamicColor { traits in
                guard hasThemeBackground else {
                    return UIColor.separator.resolvedColor(with: traits)
                }
                let background = themedBackground(for: traits)
                let candidate = background
                    .mix(with: themeTintColor, ratio: 0.36)
                    .adjustedForContrast(against: background, minimumRatio: 1.4)
                return candidate
            }
        }

        /// Subtle stroke for liquid-glass controls (matches WatchedIt `borderLight` usage).
        static var borderLight: Color {
            divider.opacity(0.6)
        }

        static var error: Color {
            .red
        }

        static var headlineColor: Color {
            ThemeManager.shared.currentTheme.headlineColorOverride ?? textPrimary
        }

        private static var hasThemeBackground: Bool {
            themeTintColor.normalizedRGBA().alpha > 0.001
        }

        private static var themeTintColor: UIColor {
            UIColor(ThemeManager.shared.currentTheme.backgroundTint ?? .clear)
        }

        private static func prefersDarkAppearance(for traits: UITraitCollection) -> Bool {
            traits.userInterfaceStyle == .dark
        }

        private static let darkModeBase = UIColor(white: 0.11, alpha: 1)

        private static func themedBackground(for traits: UITraitCollection) -> UIColor {
            let useDark = prefersDarkAppearance(for: traits)
            guard hasThemeBackground else {
                return useDark
                    ? darkModeBase
                    : UIColor.systemBackground.resolvedColor(with: traits)
            }
            let tint = themeTintColor
            return useDark
                ? tint.mix(with: darkModeBase, ratio: 0.35)
                : tint.mix(with: .white, ratio: 0.86)
        }

        private static func dynamicColor(_ resolver: @escaping (UITraitCollection) -> UIColor) -> Color {
            Color(UIColor { traits in
                resolver(traits)
            })
        }
    }

    // MARK: - Spacing (delegated to MinAppKit)

    enum Spacing {
        static let xs: CGFloat = MinSpacing.xs
        static let sm: CGFloat = MinSpacing.sm
        static let md: CGFloat = MinSpacing.md
        static let lg: CGFloat = MinSpacing.lg
        static let xl: CGFloat = MinSpacing.xl
        static let xxl: CGFloat = MinSpacing.xxl
        static let toolbarIconSpacing: CGFloat = 36
        static let screenHorizontalPadding: CGFloat = MinSpacing.screenHorizontalPadding
    }

    // MARK: - Controls

    struct Controls {
        static let controlHeight: CGFloat = 48
        static let iconButtonSize: CGFloat = 48
    }

    // MARK: - Corner Radius (values from MinAppKit)

    struct CornerRadius {
        static let artTile: CGFloat = MinCornerRadius.artTile
        static let xs: CGFloat = MinCornerRadius.xs
        static let sm: CGFloat = MinCornerRadius.sm
        static let md: CGFloat = MinCornerRadius.md
        static let lg: CGFloat = MinCornerRadius.lg
        static let xl: CGFloat = MinCornerRadius.xl
        static let round: CGFloat = MinCornerRadius.round
    }

    // MARK: - Shadows

    struct Shadows {
        static let small: CGFloat = 2
        static let medium: CGFloat = 4
        static let large: CGFloat = 8
    }

    // MARK: - Animation

    struct Animation {
        static let quick = SwiftUI.Animation.spring(response: 0.25, dampingFraction: 0.8)
        static let standard = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let slow = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }

    // MARK: - Icons (toolbar patterns — matches WatchedIt)

    struct Icon {
        static let close = "xmark"
        static let checkmark = "checkmark"
        static let add = "plus"
        static let edit = "pencil"
        static let delete = "trash"
    }
}

// MARK: - Settings lists (theme chrome)

struct PodLinkSettingsListModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .tint(themeManager.currentTheme.accentColor)
            .listStyle(.insetGrouped)
            #if os(iOS)
            .listRowSeparatorTint(DesignSystem.Colors.divider)
            .listRowBackground(DesignSystem.Colors.groupedListCardBackground)
            #endif
    }
}

extension View {
    /// Inset grouped list with hidden scroll background so theme tint reads through (WatchedIt-style settings).
    func podLinkSettingsListSurface() -> some View {
        modifier(PodLinkSettingsListModifier())
    }

    /// Theme-aware background surface used by full-screen sheets and lists.
    func themeBackground() -> some View {
        background(DesignSystem.Colors.background)
    }

    /// Standard top-bar control icon treatment (WatchedIt-style plain toolbar icon).
    func viewControlIconStyle() -> some View {
        font(.body.weight(.semibold))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }
}

// MARK: - Design system button style

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

        var font: Font {
            switch self {
            case .small: return DesignSystem.Typography.captionMedium()
            case .medium: return DesignSystem.Typography.labelMedium()
            case .large: return DesignSystem.Typography.headlineSmall()
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = MinAffordanceStyle.shared.capsuleShape
        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundColor(for: variant))
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .background(backgroundColor(for: variant))
            .clipShape(shape)
            .overlay { if MinAffordanceStyle.shared.borderEnabled { shape.stroke(MinAffordanceStyle.borderColor, lineWidth: MinAffordanceStyle.borderLineWidth) } }
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }

    private func foregroundColor(for variant: Variant) -> Color {
        switch variant {
        case .primary, .destructive:
            return .white
        case .secondary:
            return DesignSystem.Colors.accent
        case .tertiary, .ghost:
            return DesignSystem.Colors.textPrimary
        }
    }

    private func backgroundColor(for variant: Variant) -> Color {
        switch variant {
        case .primary:
            return DesignSystem.Colors.accent
        case .secondary:
            return DesignSystem.Colors.accent.opacity(0.14)
        case .tertiary:
            return DesignSystem.Colors.surface
        case .destructive:
            return DesignSystem.Colors.error
        case .ghost:
            return .clear
        }
    }
}

private extension UIColor {
    func normalizedRGBA() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (red, green, blue, alpha)
        }

        var white: CGFloat = 0
        if getWhite(&white, alpha: &alpha) {
            return (white, white, white, alpha)
        }

        return (0, 0, 0, 1)
    }

    func relativeLuminance() -> CGFloat {
        let rgba = normalizedRGBA()
        func channel(_ value: CGFloat) -> CGFloat {
            if value <= 0.03928 {
                return value / 12.92
            }
            return pow((value + 0.055) / 1.055, 2.4)
        }

        let r = channel(rgba.red)
        let g = channel(rgba.green)
        let b = channel(rgba.blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    func contrastRatio(with other: UIColor) -> CGFloat {
        let lhs = relativeLuminance()
        let rhs = other.relativeLuminance()
        let lighter = max(lhs, rhs)
        let darker = min(lhs, rhs)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func adjustedForContrast(against background: UIColor, minimumRatio: CGFloat) -> UIColor {
        if contrastRatio(with: background) >= minimumRatio {
            return self
        }

        let whiteContrast = UIColor.white.contrastRatio(with: background)
        let blackContrast = UIColor.black.contrastRatio(with: background)
        let target = whiteContrast >= blackContrast ? UIColor.white : UIColor.black

        var best = self
        for step in 1...24 {
            let mixed = mix(with: target, ratio: CGFloat(step) / 24.0)
            best = mixed
            if mixed.contrastRatio(with: background) >= minimumRatio {
                return mixed
            }
        }
        return best
    }

    func mix(with other: UIColor, ratio: CGFloat) -> UIColor {
        let clampedRatio = min(max(ratio, 0), 1)
        let lhs = normalizedRGBA()
        let rhs = other.normalizedRGBA()

        return UIColor(
            red: lhs.red * (1 - clampedRatio) + rhs.red * clampedRatio,
            green: lhs.green * (1 - clampedRatio) + rhs.green * clampedRatio,
            blue: lhs.blue * (1 - clampedRatio) + rhs.blue * clampedRatio,
            alpha: lhs.alpha * (1 - clampedRatio) + rhs.alpha * clampedRatio
        )
    }
}
