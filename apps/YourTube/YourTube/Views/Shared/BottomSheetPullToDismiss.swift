import SwiftUI

#if os(iOS)
import UIKit

private struct BottomSheetPullToDismissVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isBottomSheetPullToDismissVisible: Bool {
        get { self[BottomSheetPullToDismissVisibleKey.self] }
        set { self[BottomSheetPullToDismissVisibleKey.self] = newValue }
    }
}

/// YourTube close affordance on the shared MinAppKit pull-to-dismiss engine
/// (edge-swipe + overscroll, including the flat drag-proxy corner clip).
private struct YourTubePullToDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.pullToDismissEngine(buttonAlignment: .bottom) { isActive in
            Image(systemName: DesignSystem.Icon.close)
                .font(.body.weight(.semibold))
                .foregroundStyle(isActive ? Color.white : Color.secondary)
                .frame(width: DesignSystem.Controls.controlHeight, height: DesignSystem.Controls.controlHeight)
                .background {
                    let cs = MinAffordanceStyle.shared.circleShape
                    if isActive {
                        cs.fill(Color.red.opacity(0.9))
                    } else {
                        cs.fill(.thinMaterial)
                    }
                }
                .clipShape(MinAffordanceStyle.shared.circleShape)
                .overlay {
                    if MinAffordanceStyle.shared.borderEnabled {
                        MinAffordanceStyle.shared.circleShape
                            .stroke(Color.white.opacity(isActive ? 0.35 : 0.2), lineWidth: 0.8)
                    }
                }
                .scaleEffect(isActive ? 1.04 : 1)
                .opacity(isActive ? 1 : 0.9)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 14)
        }
        .environment(\.isBottomSheetPullToDismissVisible, true)
    }
}
#endif

extension View {
    @ViewBuilder
    func bottomSheetPullToDismiss() -> some View {
        #if os(iOS)
        modifier(YourTubePullToDismissModifier())
        #else
        self
        #endif
    }
}
