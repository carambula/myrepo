import SwiftUI

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
                    .shadow(color: .black.opacity(0.15), radius: style == .premium ? 8 : 4, y: 2)
            }
    }
}

extension View {
    func glassToolbar(style: GlassComponentStyle = .premium) -> some View {
        modifier(GlassToolbarModifier(style: style))
    }
}
