import SwiftUI

// MARK: - Tap Interaction Style

enum TapInteractionStyle: String, CaseIterable {
    case bounce
    case ripple
    case shimmer
    case glowPulse

    var displayName: String {
        switch self {
        case .bounce: return "Bounce"
        case .ripple: return "Ripple"
        case .shimmer: return "Shimmer"
        case .glowPulse: return "Glow Pulse"
        }
    }

    var description: String {
        switch self {
        case .bounce: return "Recess and rebound with shake"
        case .ripple: return "Metal-style expanding ripple"
        case .shimmer: return "Sparkle and shimmer effect"
        case .glowPulse: return "Glowing outline pulse"
        }
    }
}

// MARK: - Bounce Interaction

struct BounceInteractionModifier: ViewModifier {
    @State private var isPressed = false
    @State private var shakeOffset: CGFloat = 0
    let intensity: CGFloat
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? (1.0 - 0.08 * intensity) : 1.0)
            .offset(x: shakeOffset)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)
            .animation(.spring(response: 0.15, dampingFraction: 0.3), value: shakeOffset)
            .onTapGesture {
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    shakeOffset = 4 * intensity
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        shakeOffset = -3 * intensity
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            shakeOffset = 0
                            action()
                        }
                    }
                }
            }
    }
}

// MARK: - Glow Pulse Interaction

struct GlowPulseInteractionModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager
    @State private var isGlowing = false
    let intensity: CGFloat
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .strokeBorder(themeManager.currentTheme.accentColor, lineWidth: isGlowing ? 2 * intensity : 0)
                    .blur(radius: isGlowing ? 4 * intensity : 0)
                    .opacity(isGlowing ? 1 : 0)
            }
            .scaleEffect(isGlowing ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isGlowing)
            .onTapGesture {
                isGlowing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isGlowing = false
                    action()
                }
            }
    }
}

// MARK: - View Extension

extension View {
    func tapInteraction(style: TapInteractionStyle, intensity: CGFloat = 1.0, action: @escaping () -> Void) -> some View {
        switch style {
        case .bounce:
            return AnyView(modifier(BounceInteractionModifier(intensity: intensity, action: action)))
        case .ripple, .shimmer:
            return AnyView(modifier(BounceInteractionModifier(intensity: intensity, action: action)))
        case .glowPulse:
            return AnyView(modifier(GlowPulseInteractionModifier(intensity: intensity, action: action)))
        }
    }
}
