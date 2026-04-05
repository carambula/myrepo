//
//  DesignSystem.swift
//  YourTube
//
//  Centralized Design System with Semantic Tokenization
//

import SwiftUI
@_exported import MinAppKit

// MARK: - YourTube-Specific Preferences

enum VideoDetailPresentationMode: String, CaseIterable {
    case fullYouTubePage
    case videoOnlyWithAppUI
    case thumbnailAndPlayButton

    var title: String {
        switch self {
        case .fullYouTubePage:
            return "Full YouTube video page"
        case .videoOnlyWithAppUI:
            return "Video only with app UI"
        case .thumbnailAndPlayButton:
            return "Thumbnail and play button"
        }
    }
}

// MARK: - Design System

enum DesignSystem {

    // MARK: - Color Tokens

    enum Color {
        static var accent: SwiftUI.Color {
            ThemeManager.shared.currentTheme.accent
        }

        static var onAccent: SwiftUI.Color {
            ThemeManager.shared.currentTheme.onAccent
        }

        static let primary = SwiftUI.Color.primary
        static let secondary = SwiftUI.Color.secondary

        static var background: SwiftUI.Color {
            ThemeManager.shared.currentTheme.background
        }

        static var surface: SwiftUI.Color {
            ThemeManager.shared.currentTheme.surface
        }

        static var surfaceElevated: SwiftUI.Color {
            surface
        }

        static var cardBackground: SwiftUI.Color {
            surface
        }

        static let success = SwiftUI.Color.green
        static let error = SwiftUI.Color.red
        static let warning = SwiftUI.Color.orange
        static var info: SwiftUI.Color { accent }

        static var border: SwiftUI.Color {
            ThemeManager.shared.currentTheme.divider
        }

        static var borderLight: SwiftUI.Color {
            border.opacity(0.6)
        }

        static let overlay = SwiftUI.Color.black.opacity(0.3)
        static let overlayLight = SwiftUI.Color.black.opacity(0.1)

        static var textPrimary: SwiftUI.Color {
            ThemeManager.shared.currentTheme.text
        }

        static var textSecondary: SwiftUI.Color {
            ThemeManager.shared.currentTheme.secondaryText
        }

        static let textTertiary = SwiftUI.Color(.tertiaryLabel)

        static var headline: SwiftUI.Color {
            textPrimary
        }

        static var interactive: SwiftUI.Color { accent }
        static var interactivePressed: SwiftUI.Color { accent.opacity(0.8) }
        static let interactiveDisabled = SwiftUI.Color(.systemGray4)
    }

    // MARK: - Typography Tokens

    enum Typography {
        static let displayLarge = Font.system(size: 34, weight: .bold, design: .rounded)
        static let displayMedium = Font.system(size: 28, weight: .bold, design: .rounded)
        static let displaySmall = Font.system(size: 24, weight: .bold, design: .rounded)

        static let headlineLarge = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headlineMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
        static let headlineSmall = Font.system(size: 18, weight: .semibold, design: .default)

        static let titleLarge = Font.system(size: 20, weight: .semibold, design: .default)
        static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)
        static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)

        static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)
        static let bodySmall = Font.system(size: 15, weight: .regular, design: .default)

        static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)
        static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)
        static let labelSmall = Font.system(size: 13, weight: .medium, design: .default)

        static let captionLarge = Font.system(size: 13, weight: .regular, design: .default)
        static let captionMedium = Font.system(size: 12, weight: .regular, design: .default)
        static let captionSmall = Font.system(size: 11, weight: .regular, design: .default)

        static let overline = Font.system(size: 10, weight: .medium, design: .default)

        static let glassIcon: Font = .body.weight(.semibold)
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

        static let checkmark = "checkmark"
        static let checkmarkCircle = "checkmark.circle.fill"
        static let error = "exclamationmark.triangle.fill"
        static let warning = "exclamationmark.circle.fill"
        static let info = "info.circle.fill"

        static let list = "list.bullet"
        static let grid = "square.grid.2x2"
        static let account = "person.crop.circle"
        static let settings = "gearshape"

        static let play = "play.fill"
        static let pause = "pause.fill"
        static let edit = "pencil"
        static let delete = "trash"
        static let share = "square.and.arrow.up"
        static let refresh = "arrow.clockwise"
        static let sort = "arrow.up.arrow.down"
        static let link = "link"
        static let externalLink = "arrow.up.right.square"
        static let person = "person.fill"
        static let calendar = "calendar"
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

    // MARK: - Controls

    enum Controls {
        static let controlHeight: CGFloat = 48
        static let iconButtonSize: CGFloat = 56
        static let detailsActionSize: CGFloat = 60
        static let dragHandleWidth: CGFloat = 36
        static let dragHandleHeight: CGFloat = 5
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
    func foregroundHeadline() -> some View { self.foregroundColor(DesignSystem.Color.headline) }

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

// MARK: - YourTube-Specific View Modifiers

extension View {
    func viewControlIconStyle() -> some View {
        font(.body.weight(.semibold))
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
    }

    func themeBackground(using theme: AppTheme) -> some View {
        self.background(theme.background.ignoresSafeArea())
    }

    func yourTubeSettingsSurface(using theme: AppTheme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(theme.background.ignoresSafeArea())
            .listStyle(.insetGrouped)
            .listRowBackground(DesignSystem.Color.surface)
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
            .listStyle(.insetGrouped)
            .listRowSeparatorTint(DesignSystem.Color.border)
            .listRowBackground(DesignSystem.Color.surface)
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
        self.listRowBackground(DesignSystem.Color.surface)
    }
}

// MARK: - Design System Button Style

struct DesignSystemButtonStyle: ButtonStyle {
    var variant: Variant = .primary
    var size: Size = .medium

    enum Variant {
        case primary
        case secondary
        case ghost
        case destructive
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
            case .small: return DesignSystem.Typography.labelSmall
            case .medium: return DesignSystem.Typography.labelMedium
            case .large: return DesignSystem.Typography.labelLarge
            }
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(foregroundColor)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .frame(minHeight: DesignSystem.Controls.controlHeight)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DesignSystem.Animation.springQuick, value: configuration.isPressed)
    }

    private var foregroundColor: SwiftUI.Color {
        switch variant {
        case .primary: return DesignSystem.Color.onAccent
        case .secondary: return DesignSystem.Color.textPrimary
        case .ghost: return DesignSystem.Color.accent
        case .destructive: return .white
        }
    }

    private var backgroundColor: SwiftUI.Color {
        switch variant {
        case .primary: return DesignSystem.Color.accent
        case .secondary: return DesignSystem.Color.surface
        case .ghost: return .clear
        case .destructive: return .red
        }
    }
}

// MARK: - Circular Glass Icon Button Style

struct CircularGlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = DesignSystem.Controls.iconButtonSize

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(DesignSystem.Color.textPrimary)
            .frame(width: size, height: size)
            .background(.thinMaterial.opacity(configuration.isPressed ? 0.65 : 1))
            .overlay(
                Circle()
                    .stroke(DesignSystem.Color.border.opacity(0.4), lineWidth: 1)
            )
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(DesignSystem.Animation.springQuick, value: configuration.isPressed)
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
