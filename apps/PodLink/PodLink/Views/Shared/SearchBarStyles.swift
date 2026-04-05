import SwiftUI

enum SearchBarAppearance: String, CaseIterable {
    case classic
    case solid
    case elevated
    case glass

    var displayName: String {
        switch self {
        case .classic: return "Classic"
        case .solid: return "Solid"
        case .elevated: return "Elevated"
        case .glass: return "Glass"
        }
    }

    var description: String {
        switch self {
        case .classic: return "Minimal, integrated look"
        case .solid: return "Bold accent-colored border"
        case .elevated: return "Floating with large shadow"
        case .glass: return "Toolbar-matched glass effect"
        }
    }
}

struct SearchBarStyleModifier: ViewModifier {
    let style: SearchBarAppearance
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.md)
            .frame(height: DesignSystem.Controls.controlHeight)
            .background {
                switch style {
                case .classic:
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                        }
                case .solid:
                    Capsule()
                        .fill(DesignSystem.Colors.surface)
                        .overlay {
                            Capsule()
                                .strokeBorder(themeManager.currentTheme.accentColor.opacity(0.85), lineWidth: 1.2)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                case .elevated:
                    Capsule()
                        .fill(.thickMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.7)
                        }
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 3)
                case .glass:
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05), .clear, .white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(Capsule())
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1), .clear, .white.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
            }
    }
}

extension View {
    func searchBarStyle(_ style: SearchBarAppearance) -> some View {
        modifier(SearchBarStyleModifier(style: style))
    }
}
