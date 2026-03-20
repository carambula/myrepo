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
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background {
                switch style {
                case .classic:
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                        }
                case .solid:
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .overlay {
                            Capsule()
                                .strokeBorder(themeManager.currentTheme.accentColor, lineWidth: 1.5)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                case .elevated:
                    Capsule()
                        .fill(.thickMaterial)
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
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
                                    lineWidth: 0.75
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
