import SwiftUI
import UIKit

// MARK: - SwiftUI root (lives above system sheets via overlay window)

private struct MiniPlayerOverlayRoot: View {
    @Bindable var themeManager: ThemeManager
    @Bindable var playbackService: PlaybackService
    @Bindable var networkStatusService: NetworkStatusService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("miniPlayerDockMode") private var miniPlayerDockMode = MiniPlayerDockMode.floating.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue

    /// Floating mini player only; docked mode is laid out inside the main `NavigationStack`.
    private var showMiniPlayer: Bool {
        hasCompletedOnboarding
            && (miniPlayerDockMode != MiniPlayerDockMode.docked.rawValue
                || miniPlayerSize == MiniPlayerSize.microplayer.rawValue)
            && playbackService.state.currentEpisode != nil
            && !playbackService.isEpisodePlayerUIVisible
            && !playbackService.isSearchUIVisible
    }

    var body: some View {
        Group {
            if showMiniPlayer {
                MiniPlayerView(showNowPlayingSheet: $playbackService.isNowPlayingSheetPresented)
                    .environment(themeManager)
                    .environment(playbackService)
                    .environment(networkStatusService)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.offset(y: UIScreen.main.bounds.height))
            }
        }
        .animation(.spring(response: 0.35), value: playbackService.state.currentEpisode != nil)
        .animation(.spring(response: 0.35), value: playbackService.isEpisodePlayerUIVisible)
        .animation(.spring(response: 0.35), value: playbackService.isSearchUIVisible)
        .animation(.spring(response: 0.35), value: miniPlayerDockMode)
    }
}

// MARK: - Overlay window above the main window (covers modal sheets)

private final class MiniPlayerOverlayWindow: UIWindow {
    weak var miniPlayerHostView: UIView?

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        backgroundColor = .clear
        windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let root = rootViewController?.view,
              let host = miniPlayerHostView,
              host.superview != nil,
              !host.isHidden,
              host.alpha > 0.01
        else {
            return nil
        }
        let hostFrameInRoot = host.superview!.convert(host.frame, to: root)
        guard hostFrameInRoot.height > 8 else { return nil }

        let pointInRoot = root.convert(point, from: self)
        guard hostFrameInRoot.contains(pointInRoot) else { return nil }

        let local = convert(point, to: host)
        return host.hitTest(local, with: event)
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
        networkStatusService: NetworkStatusService,
        miniPlayerFloatSnapAtTop: Bool,
        isMicroplayerMode: Bool
    ) {
        let root = MiniPlayerOverlayRoot(
            themeManager: themeManager,
            playbackService: playbackService,
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
        let maxStripHeight: CGFloat = isMicroplayerMode ? 120 : 280

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
    var networkStatusService: NetworkStatusService
    /// Drives overlay strip pin (UIKit); must mirror `miniPlayerFloatVerticalSnap` AppStorage.
    var miniPlayerFloatSnapAtTop: Bool
    var isMicroplayerMode: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(
            themeManager: themeManager,
            playbackService: playbackService,
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
        context.coordinator.networkStatusService = networkStatusService
        context.coordinator.miniPlayerFloatSnapAtTop = miniPlayerFloatSnapAtTop
        context.coordinator.isMicroplayerMode = isMicroplayerMode
        context.coordinator.refreshOverlayIfPossible(from: uiView)
    }

    final class Coordinator {
        var themeManager: ThemeManager
        var playbackService: PlaybackService
        var networkStatusService: NetworkStatusService
        var miniPlayerFloatSnapAtTop: Bool
        var isMicroplayerMode: Bool

        init(
            themeManager: ThemeManager,
            playbackService: PlaybackService,
            networkStatusService: NetworkStatusService,
            miniPlayerFloatSnapAtTop: Bool,
            isMicroplayerMode: Bool
        ) {
            self.themeManager = themeManager
            self.playbackService = playbackService
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
