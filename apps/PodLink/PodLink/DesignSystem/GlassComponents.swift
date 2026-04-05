import SwiftUI
import UIKit

// MARK: - Glass Component Style

enum GlassComponentStyle: String, CaseIterable {
    case standard
    case enhanced
    case premium

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .enhanced: return "Enhanced"
        case .premium: return "Premium"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Clean glass with subtle border"
        case .enhanced: return "Glass with gradient highlights"
        case .premium: return "Full glass with distortion effects"
        }
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    let style: GlassComponentStyle
    let isCircular: Bool

    init(style: GlassComponentStyle = .premium, isCircular: Bool = true) {
        self.style = style
        self.isCircular = isCircular
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(isCircular ? 10 : 12)
            .background {
                Group {
                    switch style {
                    case .standard:
                        standardGlass
                    case .enhanced:
                        enhancedGlass
                    case .premium:
                        premiumGlass
                    }
                }
            }
            .clipShape(isCircular ? AnyShape(Circle()) : AnyShape(Capsule()))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }

    private var standardGlass: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 100)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        }
    }

    private var enhancedGlass: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 100)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1), .clear, .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
    }

    private var premiumGlass: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)

            LinearGradient(
                colors: [.white.opacity(0.15), .white.opacity(0.05), .clear, .white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 100)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1), .clear, .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )

            RoundedRectangle(cornerRadius: 100)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.25)
                .padding(0.5)
        }
    }
}

// MARK: - Glass Toolbar Modifier

struct GlassToolbarModifier: ViewModifier {
    let style: GlassComponentStyle

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background {
                Capsule()
                    .fill(.clear)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay {
                        if style == .enhanced || style == .premium {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1), .clear, .white.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        } else {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        }
                    }
                    .shadow(color: .black.opacity(0.10), radius: style == .premium ? 4 : 2, y: 1)
            }
    }
}

extension View {
    func glassToolbar(style: GlassComponentStyle = .premium) -> some View {
        modifier(GlassToolbarModifier(style: style))
    }
}

// MARK: - Liquid glass (WatchedIt MovieDetailView parity)

/// Background-near control surfaces with circular or rounded-rect shapes and press feedback.
struct LiquidGlassButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    var role: ButtonRole?
    var isCompact: Bool = false

    private var baseFillColor: Color {
        adjustedBackgroundColor(delta: colorScheme == .dark ? 0.06 : -0.06)
    }

    private var destructiveFillColor: Color {
        baseFillColor.opacity(0.82).overlaying(DesignSystem.Colors.error.opacity(0.18))
    }

    private func adjustedBackgroundColor(delta: CGFloat) -> Color {
        let uiColor = UIColor(DesignSystem.Colors.background)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        if uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return Color(
                UIColor(
                    hue: hue,
                    saturation: saturation,
                    brightness: min(max(brightness + delta, 0), 1),
                    alpha: alpha
                )
            )
        }

        var white: CGFloat = 0
        if uiColor.getWhite(&white, alpha: &alpha) {
            return Color(
                UIColor(
                    white: min(max(white + delta, 0), 1),
                    alpha: alpha
                )
            )
        }

        return DesignSystem.Colors.surface
    }

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isCompact {
                configuration.label
            } else {
                configuration.label
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }
        }
        .background {
            if isCompact {
                Circle()
                    .fill(role == .destructive ? destructiveFillColor : baseFillColor)
                    .overlay {
                        Circle()
                            .stroke(
                                role == .destructive
                                    ? DesignSystem.Colors.error.opacity(0.35)
                                    : DesignSystem.Colors.borderLight.opacity(0.9),
                                lineWidth: 0.8
                            )
                    }
            } else {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .fill(role == .destructive ? destructiveFillColor : baseFillColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                            .stroke(
                                role == .destructive
                                    ? DesignSystem.Colors.error.opacity(0.35)
                                    : DesignSystem.Colors.borderLight.opacity(0.9),
                                lineWidth: 0.8
                            )
                    }
            }
        }
        .foregroundStyle(role == .destructive ? DesignSystem.Colors.error : DesignSystem.Colors.textPrimary)
        .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
        .brightness(configuration.isPressed ? -0.06 : 0)
        .animation(DesignSystem.Animation.standard, value: configuration.isPressed)
    }
}

private extension Color {
    func overlaying(_ overlay: Color) -> Color {
        let base = UIColor(self)
        let top = UIColor(overlay)

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0
        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        guard base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
              top.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) else {
            return self
        }

        let outAlpha = a2 + a1 * (1 - a2)
        guard outAlpha > 0 else { return .clear }

        let outRed = (r2 * a2 + r1 * a1 * (1 - a2)) / outAlpha
        let outGreen = (g2 * a2 + g1 * a1 * (1 - a2)) / outAlpha
        let outBlue = (b2 * a2 + b1 * a1 * (1 - a2)) / outAlpha

        return Color(
            UIColor(
                red: outRed,
                green: outGreen,
                blue: outBlue,
                alpha: outAlpha
            )
        )
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

// MARK: - Frosted Surface

/// Shared frosted-glass background used by the micro player, floating circular
/// controls, and any other surface that needs the thin-material blur treatment.
/// Parameterised by shape so it works as both `Circle` and `Capsule`.
struct FrostedSurfaceModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.thinMaterial)
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
    }
}

extension View {
    func frostedSurface<S: InsettableShape>(_ shape: S) -> some View {
        modifier(FrostedSurfaceModifier(shape: shape))
    }
}

// MARK: - Frosted Icon Button Style

/// Circular thin-material button with press feedback.
/// Use for floating controls (grid/list toggle, account, search, etc.).
struct FrostedIconButtonStyle: ButtonStyle {
    var size: CGFloat = 56
    var foreground: Color = DesignSystem.Colors.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .frostedSurface(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(DesignSystem.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Legacy alias
@available(*, deprecated, renamed: "FrostedIconButtonStyle")
typealias WatchedItFloatingIconButtonStyle = FrostedIconButtonStyle
