import SwiftUI

#if os(iOS)
import UIKit
#endif

// MARK: - Layout (mini player lives in a higher window; lift affordance + pad scroll)

enum SheetPullToDismissLayout {
    static let pullToDismissButtonReserve: CGFloat = 56
    static let miniPlayerOverlapReserve: CGFloat = 118

    static func scrollContentBottomInset(playbackService: PlaybackService) -> CGFloat {
        let mini: CGFloat = {
            guard playbackService.state.currentEpisode != nil,
                  !playbackService.isEpisodePlayerUIVisible else { return 0 }
            return miniPlayerOverlapReserve
        }()
        return pullToDismissButtonReserve + mini
    }

    static func closeButtonExtraBottomInset(playbackService: PlaybackService) -> CGFloat {
        guard playbackService.state.currentEpisode != nil,
              !playbackService.isEpisodePlayerUIVisible else { return 0 }
        return miniPlayerOverlapReserve
    }
}

// MARK: - Environment

private struct BottomSheetPullToDismissVisibleKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isBottomSheetPullToDismissVisible: Bool {
        get { self[BottomSheetPullToDismissVisibleKey.self] }
        set { self[BottomSheetPullToDismissVisibleKey.self] = newValue }
    }
}

// MARK: - View extensions

extension View {
    @ViewBuilder
    func bottomSheetPullToDismiss() -> some View {
        #if os(iOS)
        self.modifier(PodLinkPullToDismissModifier())
            .environment(\.isBottomSheetPullToDismissVisible, true)
        #else
        self
        #endif
    }

    func sheetPullToDismissScrollBottomInset(playbackService: PlaybackService) -> some View {
        let inset = SheetPullToDismissLayout.scrollContentBottomInset(playbackService: playbackService)
        return contentMargins(.bottom, inset, for: .scrollContent)
    }
}

// MARK: - PodLink-specific modifier (uses shared engine + frostedSurface close button)

#if os(iOS)
private struct PodLinkPullToDismissModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(PlaybackService.self) private var playbackService

    private let closeButtonSize: CGFloat = 56

    func body(content: Content) -> some View {
        content.pullToDismissEngine(
            buttonAlignment: .bottomLeading
        ) { isActive in
            Button(action: {}) {
                Image(systemName: DesignSystem.Icon.close)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isActive ? themeManager.currentTheme.accentColor : DesignSystem.Colors.textPrimary)
                    .frame(width: closeButtonSize, height: closeButtonSize)
                    .contentShape(Rectangle())
                    .frostedSurface(MinAffordanceStyle.shared.insettableCircleShape)
                    .scaleEffect(isActive ? 1.04 : 1.0)
                    .opacity(isActive ? 1.0 : 0.85)
            }
            .buttonStyle(.plain)
            .padding(.leading, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.bottom, 20 + SheetPullToDismissLayout.closeButtonExtraBottomInset(playbackService: playbackService))
        }
    }
}
#endif
