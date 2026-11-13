import SwiftUI

#if os(iOS)
import UIKit

/// SpinMin close affordance on the shared MinAppKit pull-to-dismiss engine
/// (edge-swipe + overscroll, including the flat drag-proxy corner clip).
private struct SpinMinPullToDismissModifier: ViewModifier {
    private let closeButtonSize: CGFloat = 56

    func body(content: Content) -> some View {
        content.pullToDismissEngine(buttonAlignment: .bottomLeading) { isActive in
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isActive ? DesignSystem.Color.accent : DesignSystem.Color.textPrimary)
                    .frame(width: closeButtonSize, height: closeButtonSize)
                    .contentShape(Rectangle())
                    .frostedSurface(MinAffordanceStyle.shared.insettableCircleShape)
                    .scaleEffect(isActive ? 1.04 : 1)
                    .opacity(isActive ? 1 : 0.86)
            }
            .buttonStyle(.plain)
            .padding(.leading, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, 20)
        }
    }
}
#endif

extension View {
    @ViewBuilder
    func bottomSheetPullToDismiss() -> some View {
        #if os(iOS)
        modifier(SpinMinPullToDismissModifier())
        #else
        self
        #endif
    }
}
