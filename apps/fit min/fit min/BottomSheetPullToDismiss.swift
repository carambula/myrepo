import SwiftUI

#if os(iOS)
private struct BottomSheetPullToDismissVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isBottomSheetPullToDismissVisible: Bool {
        get { self[BottomSheetPullToDismissVisibleKey.self] }
        set { self[BottomSheetPullToDismissVisibleKey.self] = newValue }
    }
}
#endif

extension View {
    @ViewBuilder
    func bottomSheetPullToDismiss() -> some View {
        #if os(iOS)
        modifier(FitMinPullToDismissModifier())
            .environment(\.isBottomSheetPullToDismissVisible, true)
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct FitMinPullToDismissModifier: ViewModifier {
    private let closeButtonSize: CGFloat = 56

    func body(content: Content) -> some View {
        content.pullToDismissEngine(buttonAlignment: .bottomLeading) { isActive in
            Button(action: {}) {
                Image(systemName: DesignSystem.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isActive ? DesignSystem.Colors.highlight : DesignSystem.Colors.textPrimary)
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
