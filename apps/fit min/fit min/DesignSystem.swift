import SwiftUI
import UIKit
@_exported import MinAppKit

struct DesignSystem {
    enum Spacing {
        static let xs: CGFloat = MinSpacing.xs
        static let sm: CGFloat = MinSpacing.sm
        static let md: CGFloat = MinSpacing.md
        static let lg: CGFloat = MinSpacing.lg
        static let xl: CGFloat = MinSpacing.xl
        static let xxl: CGFloat = MinSpacing.xxl
        static let screenHorizontalPadding: CGFloat = MinSpacing.screenHorizontalPadding
        static let bottomSafeArea: CGFloat = 34
    }

    enum TopControls {
        static let buttonSize: CGFloat = Controls.iconButtonSize
        static let horizontalPadding: CGFloat = Spacing.sm
        static let verticalPadding: CGFloat = Spacing.sm
    }

    enum TitleType {
        static let horizontalPadding: CGFloat = Spacing.screenHorizontalPadding
        static let markOffsetY: CGFloat = 0
        static let scrollTopPadding: CGFloat = Spacing.xxl
        static let contentTopSpacing: CGFloat = Spacing.xl
        static let maxWidth: CGFloat = 220
        static let maxHeight: CGFloat = 38
        static let blurDistance: CGFloat = 80
        static let maxBlurRadius: CGFloat = 12
        static let maxOpacityReduction: CGFloat = 0.5
    }

    enum Typography {
        static func displayLarge() -> Font { themed(size: 56, weight: .bold) }
        static func displayMedium() -> Font { themed(size: 34, weight: .bold) }
        static func headlineLarge() -> Font { themed(size: 24, weight: .semibold) }
        static func headlineMedium() -> Font { themed(size: 20, weight: .semibold) }
        static func bodyLarge() -> Font { .system(size: 17) }
        static func bodyMedium() -> Font { .system(size: 15) }
        static func caption() -> Font { .system(size: 12) }

        private static func themed(size: CGFloat, weight: Font.Weight) -> Font {
            let theme = ThemeManager.shared.currentTheme
            return .system(size: size, weight: weight, design: theme.fontDesign)
        }
    }

    enum Colors {
        static var accent: Color { ThemeManager.shared.currentTheme.accent }
        static var highlight: Color { ThemeManager.shared.currentTheme.highlight }
        static var index: Color { ThemeManager.shared.currentTheme.indexColor }
        static var background: Color { ThemeManager.shared.currentTheme.background }
        static var surface: Color { ThemeManager.shared.currentTheme.surface }
        static var surfaceElevated: Color { ThemeManager.shared.currentTheme.surfaceElevated }
        static var textPrimary: Color { ThemeManager.shared.currentTheme.text }
        static var textSecondary: Color { ThemeManager.shared.currentTheme.secondaryText }
        static var textTertiary: Color { ThemeManager.shared.currentTheme.tertiaryText }
        static var divider: Color { ThemeManager.shared.currentTheme.divider }
        static var error: Color { .red }
        static var headlineColor: Color { ThemeManager.shared.currentTheme.headlineColor }
    }

    enum Icon {
        static let account = "person.crop.circle"
        static let add = "plus"
        static let back = "backward.fill"
        static let check = "checkmark"
        static let close = "xmark"
        static let delete = "trash"
        static let edit = "pencil"
        static let forward = "forward.fill"
        static let clock = "timer"
        static let pause = "pause.circle.fill"
        static let play = "play.circle.fill"
        static let playSmall = "play.fill"
        static let themes = "paintbrush"
        static let fonts = "textformat"
        static let sound = "speaker.wave.2"
        static let soundOff = "speaker.slash"
    }

    enum Controls {
        static let iconButtonSize: CGFloat = 56
        static let prominentButtonSize: CGFloat = 64
    }
}

extension View {
    func themeBackground() -> some View {
        background(DesignSystem.Colors.background.ignoresSafeArea())
    }

    func designSystemGroupedListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(DesignSystem.Colors.background)
    }

    func designSystemGroupedListRow() -> some View {
        listRowBackground(DesignSystem.Colors.surface)
    }

    func viewControlIconStyle(size: CGFloat = 18) -> some View {
        font(.system(size: size, weight: .semibold))
            .foregroundStyle(DesignSystem.Colors.textPrimary)
    }
}

struct CircularGlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = DesignSystem.TopControls.buttonSize
    var foregroundColor: Color = DesignSystem.Colors.textPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .background {
                MinAffordanceStyle.shared.circleShape
                    .fill(.thinMaterial)
                    .overlay {
                        if MinAffordanceStyle.shared.borderEnabled {
                            MinAffordanceStyle.shared.circleShape
                                .stroke(DesignSystem.Colors.divider.opacity(0.7), lineWidth: 0.8)
                        }
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct DesignSystemButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case destructive
        case ghost
    }

    var variant: Variant = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.bodyMedium().weight(.semibold))
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .foregroundStyle(foreground)
            .background {
                MinAffordanceStyle.shared.capsuleShape
                    .fill(background)
                    .overlay {
                        if MinAffordanceStyle.shared.borderEnabled {
                            MinAffordanceStyle.shared.capsuleShape
                                .stroke(DesignSystem.Colors.divider.opacity(0.8), lineWidth: 0.8)
                        }
                    }
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return ThemeManager.shared.currentTheme.onAccent
        case .destructive: return DesignSystem.Colors.error
        case .secondary, .ghost: return DesignSystem.Colors.textPrimary
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return DesignSystem.Colors.accent
        case .secondary: return DesignSystem.Colors.surfaceElevated
        case .destructive: return DesignSystem.Colors.error.opacity(0.14)
        case .ghost: return .clear
        }
    }
}
