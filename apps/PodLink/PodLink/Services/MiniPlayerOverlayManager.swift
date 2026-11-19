import SwiftUI
import UIKit

// MARK: - SwiftUI root (lives above system sheets via overlay window)

/// Stable item for overlay now-playing so the sheet is never an empty `if let`.
private struct OverlayNowPlayingItem: Identifiable {
    let episode: Episode
    var id: String { episode.id }
}

private struct MiniPlayerCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
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

    /// True while this overlay window presented now-playing (including the
    /// dismiss zoom). The mini stays at rest so the thumb can land on it.
    @State private var overlayOwnsPresentedPlayer = false

    /// Hide only when a player from another window would sit under this overlay.
    /// Instant, not sprung — a fade here fights the zoom.
    private var hideMiniForForeignPlayer: Bool {
        playbackService.isEpisodePlayerUIVisible && !overlayOwnsPresentedPlayer
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
                if newValue == nil { playbackService.isNowPlayingSheetPresented = false }
            }
        )
    }

    var body: some View {
        ZStack(alignment: overlayAlignment) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            if showMiniPlayer {
                MiniPlayerView(showNowPlayingSheet: $playbackService.isNowPlayingSheetPresented)
                    .environment(themeManager)
                    .environment(playbackService)
                    .environment(networkStatusService)
                    .environment(\.sheetHeroNamespace, overlayHero)
                    .fixedSize(horizontal: miniPlayerSize == MiniPlayerSize.microplayer.rawValue, vertical: true)
                    .opacity(hideMiniForForeignPlayer ? 0 : 1)
                    .animation(nil, value: hideMiniForForeignPlayer)
                    .allowsHitTesting(!playbackService.isEpisodePlayerUIVisible)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: MiniPlayerCardFrameKey.self,
                                value: proxy.frame(in: .global)
                            )
                        }
                    }
                    .transition(.offset(y: UIScreen.main.bounds.height))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onPreferenceChange(MiniPlayerCardFrameKey.self) { frame in
            MiniPlayerOverlayManager.shared.cardFrameInWindow = frame
        }
        .onChange(of: showMiniPlayer) { _, show in
            if !show { MiniPlayerOverlayManager.shared.cardFrameInWindow = .zero }
        }
        .animation(.spring(response: SheetHeroMotion.openDuration), value: playbackService.state.currentEpisode != nil)
        .animation(.spring(response: SheetHeroMotion.openDuration), value: playbackService.isSearchUIVisible)
        .animation(.spring(response: SheetHeroMotion.openDuration), value: miniPlayerDockMode)
        .sheetFromHero(
            item: overlayNowPlayingItem,
            sourceID: { SheetHeroID.miniPlayer($0.episode.id) },
            namespace: overlayHero,
            onDismiss: { overlayOwnsPresentedPlayer = false }
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
                overlayOwnsPresentedPlayer = true
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

        let card = MiniPlayerOverlayManager.shared.cardFrameInWindow
        guard card.width > 8, card.height > 8, card.contains(point) else {
            return nil
        }

        guard let host = miniPlayerHostView else { return nil }
        let local = convert(point, to: host)
        return host.hitTest(local, with: event) ?? host
    }
}

// MARK: - Manager

@MainActor
final class MiniPlayerOverlayManager {
    static let shared = MiniPlayerOverlayManager()

    private var overlayWindow: MiniPlayerOverlayWindow?
    private var hostingController: UIHostingController<MiniPlayerOverlayRoot>?
    private var hostVerticalConstraints: [NSLayoutConstraint] = []
    /// Mini-player card in screen coordinates, for passthrough hit testing.
    var cardFrameInWindow: CGRect = .zero

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
           let host = hostingController?.view,
           let container = host.superview {
            hostingController?.rootView = root
            existing.miniPlayerHostView = host
            host.backgroundColor = .clear
            host.isOpaque = false
            host.clipsToBounds = false
            applyHostConstraints(hostView: host, container: container)
            overlayWindow?.isHidden = false
            return
        }

        overlayWindow?.isHidden = true
        overlayWindow = nil
        hostingController = nil
        NSLayoutConstraint.deactivate(hostVerticalConstraints)
        hostVerticalConstraints.removeAll()

        let window = MiniPlayerOverlayWindow(windowScene: windowScene)
        window.isOpaque = false
        window.backgroundColor = .clear
        let container = UIViewController()
        container.view.backgroundColor = .clear
        container.view.isOpaque = false
        // Present sheets in this full-screen container, not the 72pt host
        // strip — otherwise UIKit draws a full-size platter from the tiny
        // presenting bounds, then zoom tears it down.
        container.definesPresentationContext = true
        let rootContainer = container.view!

        let host = UIHostingController(rootView: root)
        // Full-screen host so `.sheet` zoom presents from the window, not a
        // 72pt strip. Hits outside the card still pass through.
        host.definesPresentationContext = true
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.clipsToBounds = false
        host.view.translatesAutoresizingMaskIntoConstraints = false

        container.addChild(host)
        rootContainer.addSubview(host.view)
        applyHostConstraints(hostView: host.view, container: rootContainer)
        host.didMove(toParent: container)

        window.rootViewController = container
        window.miniPlayerHostView = host.view
        window.isHidden = false

        overlayWindow = window
        hostingController = host
    }

    private func applyHostConstraints(hostView: UIView, container: UIView) {
        NSLayoutConstraint.deactivate(hostVerticalConstraints)
        hostVerticalConstraints = [
            hostView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostView.topAnchor.constraint(equalTo: container.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ]
        NSLayoutConstraint.activate(hostVerticalConstraints)
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
