import SwiftUI

struct BottomSheetPullToDismiss: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var isGestureActive = false
    @State private var isCloseReady = false

    private let revealThreshold: CGFloat = 44
    private let dismissThreshold: CGFloat = 96

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                closeAffordance
            }
            .overlay(alignment: .bottom) {
                // Restrict activation to drags that begin near the lower viewport edge.
                Color.clear
                    .frame(height: 120)
                    .contentShape(Rectangle())
                    .gesture(closeGesture)
            }
            .animation(DesignSystem.Animation.standard, value: isGestureActive)
            .animation(DesignSystem.Animation.quick, value: isCloseReady)
    }

    private var closeAffordance: some View {
        Group {
            if isGestureActive {
                Image(systemName: DesignSystem.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isCloseReady ? Color.white : Color.secondary)
                    .frame(width: DesignSystem.Controls.controlHeight, height: DesignSystem.Controls.controlHeight)
                    .background {
                        let cs = MinAffordanceStyle.shared.circleShape
                        if isCloseReady {
                            cs.fill(Color.red.opacity(0.9))
                        } else {
                            cs.fill(.thinMaterial)
                        }
                    }
                    .clipShape(MinAffordanceStyle.shared.circleShape)
                    .overlay {
                        if MinAffordanceStyle.shared.borderEnabled {
                            MinAffordanceStyle.shared.circleShape
                                .stroke(Color.white.opacity(isCloseReady ? 0.35 : 0.2), lineWidth: 0.8)
                        }
                    }
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let upwardDistance = max(0, -value.translation.height)
                if upwardDistance > revealThreshold {
                    if !isGestureActive {
                        isGestureActive = true
                    }
                    isCloseReady = upwardDistance > dismissThreshold
                } else if isGestureActive {
                    isCloseReady = false
                }
            }
            .onEnded { _ in
                let shouldDismiss = isCloseReady
                isGestureActive = false
                isCloseReady = false
                if shouldDismiss {
                    dismiss()
                }
            }
    }
}

extension View {
    func bottomSheetPullToDismiss() -> some View {
        modifier(BottomSheetPullToDismiss())
    }
}
