import SwiftUI
import UIKit

// MARK: - SwiftUI root (lives above system sheets via overlay window)

private struct MiniPlayerOverlayRoot: View {
    @Bindable var themeManager: ThemeManager
    @Bindable var playbackService: PlaybackService
    @Bindable var downloadManager: DownloadManager
    @Bindable var networkStatusService: NetworkStatusService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue

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
    private var presentNowPlayingFromOverlay: Binding<Bool> {
        Binding(
            get: {
                ownsFloatingMini
                    && playbackService.isNowPlayingSheetPresented
                    && playbackService.state.currentEpisode != nil
            },
            set: { presented in
                if !presented { playbackService.isNowPlayingSheetPresented = false }
            }
        )
    }

    var body: some View {
        Group {
            if showMiniPlayer {
                MiniPlayerView(showNowPlayingSheet: $playbackService.isNowPlayingSheetPresented)
                    .environment(themeManager)
                    .environment(playbackService)
                    .environment(networkStatusService)
                    // Hug the card/capsule — UIKit leading/trailing (or ≤320 center)
                    // constraints propose width; avoid a maxHeight infinity strip.
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(hideMiniForForeignPlayer ? 0 : 1)
                    .animation(nil, value: hideMiniForForeignPlayer)
                    .allowsHitTesting(!playbackService.isEpisodePlayerUIVisible)
                    .transition(.offset(y: UIScreen.main.bounds.height))
            }
        }
        .animation(.spring(response: SheetHeroMotion.openDuration), value: playbackService.state.currentEpisode != nil)
        .animation(.spring(response: SheetHeroMotion.openDuration), value: playbackService.isSearchUIVisible)
        .animation(.spring(response: SheetHeroMotion.openDuration), value: miniPlayerDockMode)
        .sheetFromHero(
            isPresented: presentNowPlayingFromOverlay,
            onDismiss: { overlayOwnsPresentedPlayer = false }
        ) {
            if let episode = playbackService.state.currentEpisode {
                EpisodePlayerSheet(
                    episode: episode,
                    onOpenPodcast: { podcast in
                        playbackService.isNowPlayingSheetPresented = false
                        playbackService.pendingPodcastPresentation = podcast
                    },
                    sheetHeroSourceID: SheetHeroID.miniPlayer(episode.id)
                )
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .environment(networkStatusService)
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: playbackService.isNowPlayingSheetPresented) { _, presented in
            if presented, ownsFloatingMini {
                overlayOwnsPresentedPlayer = true
            }
        }
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
            let hit = super.hitTest(point, with: event)
            // Don't let the clear full-screen container steal taps outside the sheet.
            if hit === self || hit === rootViewController?.view {
                return nil
            }
            return hit
        }

        guard let root = rootViewController?.view,
              let host = miniPlayerHostView,
              host.superview != nil,
              !host.isHidden,
              host.alpha > 0.01
        else {
            return nil
        }
        let hostFrameInRoot = host.superview!.convert(host.frame, to: root)
        // Host is sized to the mini card; ignore collapsed / empty hosts.
        guard hostFrameInRoot.width > 8, hostFrameInRoot.height > 8 else { return nil }

        let pointInRoot = root.convert(point, from: self)
        guard hostFrameInRoot.contains(pointInRoot) else { return nil }

        let local = convert(point, to: host)
        // SwiftUI materials/buttons often resolve hitTest to the hosting root.
        // The host hugs the card, so delivering those taps is correct — do not
        // discard `hit === host` or microplayer taps fall through to the grid.
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

    private init() {}

    func configure(
        windowScene: UIWindowScene,
        themeManager: ThemeManager,
        playbackService: PlaybackService,
        downloadManager: DownloadManager,
        networkStatusService: NetworkStatusService,
        miniPlayerFloatSnapAtTop: Bool,
        isMicroplayerMode: Bool
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
            host.clipsToBounds = false
            applyHostConstraints(
                hostView: host,
                container: container,
                floatSnapAtTop: miniPlayerFloatSnapAtTop,
                isMicroplayerMode: isMicroplayerMode
            )
            overlayWindow?.isHidden = false
            return
        }

        overlayWindow?.isHidden = true
        overlayWindow = nil
        hostingController = nil
        NSLayoutConstraint.deactivate(hostVerticalConstraints)
        hostVerticalConstraints.removeAll()

        let window = MiniPlayerOverlayWindow(windowScene: windowScene)
        let container = UIViewController()
        container.view.backgroundColor = .clear
        let rootContainer = container.view!

        let host = UIHostingController(rootView: root)
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        host.view.clipsToBounds = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.setContentHuggingPriority(.required, for: .vertical)
        host.view.setContentCompressionResistancePriority(.required, for: .vertical)
        if #available(iOS 16.0, *) {
            host.sizingOptions = [.intrinsicContentSize]
        }

        container.addChild(host)
        rootContainer.addSubview(host.view)
        applyHostConstraints(
            hostView: host.view,
            container: rootContainer,
            floatSnapAtTop: miniPlayerFloatSnapAtTop,
            isMicroplayerMode: isMicroplayerMode
        )
        host.didMove(toParent: container)

        window.rootViewController = container
        window.miniPlayerHostView = host.view
        window.isHidden = false

        overlayWindow = window
        hostingController = host
    }

    private func applyHostConstraints(
        hostView: UIView,
        container: UIView,
        floatSnapAtTop: Bool,
        isMicroplayerMode: Bool
    ) {
        NSLayoutConstraint.deactivate(hostVerticalConstraints)
        hostVerticalConstraints.removeAll()

        let safe = container.safeAreaLayoutGuide
        /// Restrict interactive strip to the minimum practical area so overlay touches don't
        /// block unrelated controls (e.g. top search button) outside the visible mini player.
        let maxStripHeight: CGFloat = isMicroplayerMode ? 72 : 280

        hostVerticalConstraints = [hostView.heightAnchor.constraint(lessThanOrEqualToConstant: maxStripHeight)]
        if isMicroplayerMode {
            hostVerticalConstraints.append(contentsOf: [
                hostView.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
                hostView.leadingAnchor.constraint(greaterThanOrEqualTo: safe.leadingAnchor),
                hostView.trailingAnchor.constraint(lessThanOrEqualTo: safe.trailingAnchor),
                hostView.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            ])
        } else {
            hostVerticalConstraints.append(contentsOf: [
                hostView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
                hostView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            ])
        }
        if floatSnapAtTop {
            hostVerticalConstraints.append(hostView.topAnchor.constraint(equalTo: safe.topAnchor))
        } else {
            hostVerticalConstraints.append(hostView.bottomAnchor.constraint(equalTo: safe.bottomAnchor))
        }
        NSLayoutConstraint.activate(hostVerticalConstraints)
    }
}

// MARK: - Attach once the main SwiftUI hierarchy has a window

struct MiniPlayerOverlaySceneAnchor: UIViewRepresentable {
    var themeManager: ThemeManager
    var playbackService: PlaybackService
    var downloadManager: DownloadManager
    var networkStatusService: NetworkStatusService
    /// Drives overlay strip pin (UIKit); must mirror `miniPlayerFloatVerticalSnap` AppStorage.
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
