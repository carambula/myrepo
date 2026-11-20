import SwiftUI
import UIKit

// MARK: - SwiftUI root (lives above system sheets via overlay window)

/// Stable item for overlay now-playing so the sheet is never an empty `if let`.
private struct OverlayNowPlayingItem: Identifiable {
    let episode: Episode
    var id: String { episode.id }
}

/// Reports the mini-player card in the overlay *window* coordinate space.
/// SwiftUI `.global` in a secondary window does not match `UIWindow.hitTest`.
private struct MiniPlayerHitTargetProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.isOpaque = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.reportFrame()
    }

    static func dismantleUIView(_ uiView: ProbeView, coordinator: ()) {
        (uiView.window as? MiniPlayerOverlayWindow)?.cardFrame = .zero
    }

    final class ProbeView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            reportFrame()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportFrame()
        }

        func reportFrame() {
            guard let overlay = window as? MiniPlayerOverlayWindow else { return }
            guard bounds.width > 8, bounds.height > 8 else {
                overlay.cardFrame = .zero
                return
            }
            overlay.cardFrame = convert(bounds, to: overlay)
        }
    }
}

private struct MiniPlayerOverlayRoot: View {
    @Bindable var themeManager: ThemeManager
    @Bindable var playbackService: PlaybackService
    @Bindable var downloadManager: DownloadManager
    @Bindable var networkStatusService: NetworkStatusService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue
    @AppStorage("miniPlayerFloatVerticalSnap") private var miniPlayerFloatVerticalSnap = MiniPlayerFloatVerticalSnap.bottom.rawValue
    @Namespace private var overlayHero

    private var overlayAlignment: Alignment {
        miniPlayerFloatVerticalSnap == MiniPlayerFloatVerticalSnap.top.rawValue ? .top : .bottom
    }

    /// Floating / microplayer chrome ownership for this overlay window.
    private var ownsFloatingMini: Bool {
        hasCompletedOnboarding
            && (miniPlayerDockMode != MiniPlayerDockMode.docked.rawValue
                || miniPlayerSize == MiniPlayerSize.microplayer.rawValue)
    }

    /// Keep the mini mounted while now-playing is up so zoom can return here.
    private var showMiniPlayer: Bool {
        ownsFloatingMini
            && playbackService.state.currentEpisode != nil
            && !playbackService.isSearchUIVisible
    }

    /// Hide only when a player from another window would sit under this overlay.
    /// Never hide while this overlay spawned now-playing — including dismiss
    /// zoom — so art returns into the still-visible micro / floating chrome.
    /// Instant, not sprung — a fade here fights the zoom.
    private var hideMiniForForeignPlayer: Bool {
        if playbackService.nowPlayingPresentedFromFloatingOverlay {
            return false
        }
        if ownsFloatingMini && playbackService.isNowPlayingSheetPresented {
            return false
        }
        return playbackService.isEpisodePlayerUIVisible
    }

    /// Mark ownership on the tap that opens the sheet (before `onAppear`),
    /// so the mini never flashes hidden for one frame.
    private var showNowPlayingFromOverlay: Binding<Bool> {
        Binding(
            get: { playbackService.isNowPlayingSheetPresented },
            set: { newValue in
                if newValue {
                    playbackService.nowPlayingPresentedFromFloatingOverlay = true
                }
                playbackService.isNowPlayingSheetPresented = newValue
            }
        )
    }

    /// Present now-playing from this window so the mini thumb and player share
    /// one zoom namespace (floating mini is not in the main `ContentView` window).
    private var overlayNowPlayingItem: Binding<OverlayNowPlayingItem?> {
        Binding(
            get: {
                guard ownsFloatingMini,
                      playbackService.isNowPlayingSheetPresented,
                      let episode = playbackService.state.currentEpisode else { return nil }
                return OverlayNowPlayingItem(episode: episode)
            },
            set: { newValue in
                if newValue == nil {
                    playbackService.isNowPlayingSheetPresented = false
                }
            }
        )
    }

    var body: some View {
        ZStack(alignment: overlayAlignment) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            if showMiniPlayer {
                MiniPlayerView(showNowPlayingSheet: showNowPlayingFromOverlay)
                    .environment(themeManager)
                    .environment(playbackService)
                    .environment(networkStatusService)
                    .environment(\.sheetHeroNamespace, overlayHero)
                    .fixedSize(horizontal: miniPlayerSize == MiniPlayerSize.microplayer.rawValue, vertical: true)
                    .opacity(hideMiniForForeignPlayer ? 0 : 1)
                    .animation(nil, value: hideMiniForForeignPlayer)
                    // Stay non-interactive under the sheet, but never unmount /
                    // opacity-hide when this overlay owns the presentation.
                    .allowsHitTesting(
                        !playbackService.isEpisodePlayerUIVisible
                            && !playbackService.nowPlayingPresentedFromFloatingOverlay
                    )
                    .background {
                        MiniPlayerHitTargetProbe()
                    }
                    .transition(.offset(y: UIScreen.main.bounds.height))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: showMiniPlayer) { _, show in
            if !show { MiniPlayerOverlayManager.shared.clearCardFrame() }
        }
        .animation(.spring(response: SheetHeroMotion.openDuration), value: playbackService.state.currentEpisode != nil)
        .animation(.spring(response: SheetHeroMotion.openDuration), value: playbackService.isSearchUIVisible)
        .animation(.spring(response: SheetHeroMotion.openDuration), value: miniPlayerDockMode)
        .sheetFromHero(
            item: overlayNowPlayingItem,
            sourceID: { SheetHeroID.miniPlayer($0.episode.id) },
            namespace: overlayHero,
            onDismiss: {
                // Wait a turn so `EpisodePlayerSheet.onDisappear` can pop its
                // session first — clearing ownership in the same frame as the
                // pop would flash the mini hidden under a foreign-player hide.
                DispatchQueue.main.async {
                    playbackService.nowPlayingPresentedFromFloatingOverlay = false
                }
            }
        ) { item in
            EpisodePlayerSheet(
                episode: item.episode,
                onOpenPodcast: { podcast in
                    playbackService.isNowPlayingSheetPresented = false
                    playbackService.pendingPodcastPresentation = podcast
                }
            )
            .environment(themeManager)
            .environment(playbackService)
            .environment(downloadManager)
            .environment(networkStatusService)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: playbackService.isNowPlayingSheetPresented) { _, presented in
            if presented, ownsFloatingMini {
                playbackService.nowPlayingPresentedFromFloatingOverlay = true
            }
        }
        .environment(themeManager)
        .environment(playbackService)
        .environment(downloadManager)
        .environment(networkStatusService)
        .sheetHeroOverlayContainer()
    }
}

// MARK: - Overlay window above the main window (covers modal sheets)

private final class MiniPlayerOverlayWindow: UIWindow {
    weak var miniPlayerHostView: UIView?
    var cardFrame: CGRect = .zero

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Now-playing (and any other modal) presented from this window must
        // receive normal hits; the mini-only passthrough would eat the sheet.
        if rootViewController?.presentedViewController != nil {
            return super.hitTest(point, with: event)
        }

        let card = cardFrame.insetBy(dx: -8, dy: -8)
        guard card.width > 8, card.height > 8, card.contains(point) else {
            return nil
        }

        guard let host = miniPlayerHostView else { return nil }
        let local = convert(point, to: host)
        // Materials often resolve to the full-screen hosting root. The card
        // frame already gated this tap, so deliver it to the host.
        return host.hitTest(local, with: event) ?? host
    }
}

// MARK: - Manager

@MainActor
final class MiniPlayerOverlayManager {
    static let shared = MiniPlayerOverlayManager()

    private var overlayWindow: MiniPlayerOverlayWindow?
    private var hostingController: UIHostingController<MiniPlayerOverlayRoot>?

    func clearCardFrame() {
        overlayWindow?.cardFrame = .zero
    }

    private init() {}

    func configure(
        windowScene: UIWindowScene,
        themeManager: ThemeManager,
        playbackService: PlaybackService,
        downloadManager: DownloadManager,
        networkStatusService: NetworkStatusService,
        miniPlayerFloatSnapAtTop _: Bool,
        isMicroplayerMode _: Bool
    ) {
        let root = MiniPlayerOverlayRoot(
            themeManager: themeManager,
            playbackService: playbackService,
            downloadManager: downloadManager,
            networkStatusService: networkStatusService
        )

        if let existing = overlayWindow, existing.windowScene === windowScene,
           let host = hostingController {
            host.rootView = root
            existing.miniPlayerHostView = host.view
            host.view.backgroundColor = .clear
            host.view.isOpaque = false
            host.view.clipsToBounds = false
            overlayWindow?.isHidden = false
            return
        }

        overlayWindow?.isHidden = true
        overlayWindow = nil
        hostingController = nil

        let window = MiniPlayerOverlayWindow(windowScene: windowScene)
        window.isOpaque = false
        window.backgroundColor = .clear

        let host = UIHostingController(rootView: root)
        // Root of the overlay window so `.sheet` zoom presents from the
        // window, not a 72pt strip. Hits outside the card still pass through.
        host.definesPresentationContext = true
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.clipsToBounds = false

        window.rootViewController = host
        window.miniPlayerHostView = host.view
        window.isHidden = false

        overlayWindow = window
        hostingController = host
    }
}

// MARK: - Attach once the main SwiftUI hierarchy has a window

struct MiniPlayerOverlaySceneAnchor: UIViewRepresentable {
    var themeManager: ThemeManager
    var playbackService: PlaybackService
    var downloadManager: DownloadManager
    var networkStatusService: NetworkStatusService
    /// Reconfigures the overlay when snap / microplayer settings change.
    var miniPlayerFloatSnapAtTop: Bool
    var isMicroplayerMode: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            themeManager: themeManager,
            playbackService: playbackService,
            downloadManager: downloadManager,
            networkStatusService: networkStatusService,
            miniPlayerFloatSnapAtTop: miniPlayerFloatSnapAtTop,
            isMicroplayerMode: isMicroplayerMode
        )
    }

    func makeUIView(context: Context) -> SceneAnchorView {
        let view = SceneAnchorView()
        view.isUserInteractionEnabled = false
        context.coordinator.bind(to: view)
        return view
    }

    func updateUIView(_ uiView: SceneAnchorView, context: Context) {
        context.coordinator.themeManager = themeManager
        context.coordinator.playbackService = playbackService
        context.coordinator.downloadManager = downloadManager
        context.coordinator.networkStatusService = networkStatusService
        context.coordinator.miniPlayerFloatSnapAtTop = miniPlayerFloatSnapAtTop
        context.coordinator.isMicroplayerMode = isMicroplayerMode
        context.coordinator.refreshOverlayIfPossible(from: uiView)
    }

    final class Coordinator {
        var themeManager: ThemeManager
        var playbackService: PlaybackService
        var downloadManager: DownloadManager
        var networkStatusService: NetworkStatusService
        var miniPlayerFloatSnapAtTop: Bool
        var isMicroplayerMode: Bool

        init(
            themeManager: ThemeManager,
            playbackService: PlaybackService,
            downloadManager: DownloadManager,
            networkStatusService: NetworkStatusService,
            miniPlayerFloatSnapAtTop: Bool,
            isMicroplayerMode: Bool
        ) {
            self.themeManager = themeManager
            self.playbackService = playbackService
            self.downloadManager = downloadManager
            self.networkStatusService = networkStatusService
            self.miniPlayerFloatSnapAtTop = miniPlayerFloatSnapAtTop
            self.isMicroplayerMode = isMicroplayerMode
        }

        func bind(to view: SceneAnchorView) {
            view.onMoveToWindow = { [weak self, weak view] in
                guard let self, let view else { return }
                refreshOverlayIfPossible(from: view)
            }
        }

        func refreshOverlayIfPossible(from view: UIView) {
            guard let scene = view.window?.windowScene else { return }
            MiniPlayerOverlayManager.shared.configure(
                windowScene: scene,
                themeManager: themeManager,
                playbackService: playbackService,
                downloadManager: downloadManager,
                networkStatusService: networkStatusService,
                miniPlayerFloatSnapAtTop: miniPlayerFloatSnapAtTop,
                isMicroplayerMode: isMicroplayerMode
            )
        }
    }
}

final class SceneAnchorView: UIView {
    var onMoveToWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onMoveToWindow?()
        }
    }
}
