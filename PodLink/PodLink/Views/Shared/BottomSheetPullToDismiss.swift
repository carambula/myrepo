import SwiftUI
import UIKit

// MARK: - Pull-to-Dismiss Modifier

struct BottomSheetPullToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    @State private var overscrollDistance: CGFloat = 0
    @State private var isAtBottom = false
    @State private var showCloseButton = false
    @State private var isCloseButtonActive = false
    @State private var isContentScrollable = true

    private let showThreshold: CGFloat = 50
    private let activateThreshold: CGFloat = 90

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if showCloseButton {
                closeButton
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onPreferenceChange(ScrollMetricsKey.self) { metrics in
            guard let metrics else { return }
            isContentScrollable = metrics.contentHeight > metrics.visibleHeight
            isAtBottom = !isContentScrollable || metrics.isAtBottom
            overscrollDistance = metrics.overscrollDistance

            withAnimation(DesignSystem.Animation.quick) {
                if isAtBottom && overscrollDistance > showThreshold {
                    showCloseButton = true
                    isCloseButtonActive = overscrollDistance > activateThreshold
                } else {
                    showCloseButton = false
                    isCloseButtonActive = false
                }
            }
        }
        .onChange(of: isCloseButtonActive) { _, isActive in
            if isActive {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
        .onChange(of: overscrollDistance) { oldValue, newValue in
            if isCloseButtonActive && newValue < oldValue && newValue < activateThreshold {
                dismiss()
            }
        }
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isCloseButtonActive ? themeManager.currentTheme.accentColor : .secondary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.1), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                }
                .scaleEffect(isCloseButtonActive ? 1.04 : 1.0)
                .opacity(isCloseButtonActive ? 1.0 : 0.5)
        }
        .padding(.bottom, 20)
        .animation(DesignSystem.Animation.quick, value: isCloseButtonActive)
    }
}

// MARK: - Scroll Metrics Preference

struct ScrollMetrics: Equatable {
    let contentHeight: CGFloat
    let visibleHeight: CGFloat
    let isAtBottom: Bool
    let overscrollDistance: CGFloat
}

struct ScrollMetricsKey: PreferenceKey {
    static var defaultValue: ScrollMetrics?
    static func reduce(value: inout ScrollMetrics?, nextValue: () -> ScrollMetrics?) {
        value = nextValue() ?? value
    }
}

// MARK: - View Extension

extension View {
    func bottomSheetPullToDismiss() -> some View {
        modifier(BottomSheetPullToDismissModifier())
    }
}
