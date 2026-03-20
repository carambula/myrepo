import SwiftUI

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
                return .system(size: 17, weight: theme.headlineFontWeight, design: design)
            }
            return .system(size: 17, weight: .semibold)
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

        static func caption() -> Font {
            .system(size: 11)
        }
    }

    // MARK: - Colors

    struct Colors {
        static var accent: Color {
            ThemeManager.shared.currentTheme.accentColor
        }

        static var background: Color {
            Color(.systemBackground)
        }

        static var surface: Color {
            Color(.secondarySystemBackground)
        }

        static var textPrimary: Color {
            Color(.label)
        }

        static var textSecondary: Color {
            Color(.secondaryLabel)
        }

        static var divider: Color {
            Color(.separator)
        }

        static var error: Color {
            .red
        }

        static var headlineColor: Color {
            ThemeManager.shared.currentTheme.headlineColor ?? textPrimary
        }
    }

    // MARK: - Spacing

    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let toolbarIconSpacing: CGFloat = 36
    }

    // MARK: - Radius

    struct Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let capsule: CGFloat = 100
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
}
