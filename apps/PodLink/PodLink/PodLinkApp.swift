import SwiftUI
import AVFoundation

/// Retains the `NotificationCenter` token for iCloud KVS updates (required for block-based observers).
private final class UbiquitousKeyValueStoreSyncObserver {
    static let shared = UbiquitousKeyValueStoreSyncObserver()

    private var token: NSObjectProtocol?

    private init() {
        token = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { notification in
            let followedKey = Podcast.followedPodcastsStorageKey
            let historyKey = ListeningHistoryStore.storageKey
            if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                if keys.contains(followedKey) {
                    Podcast.applyFollowedPodcastsFromUbiquitousStore()
                }
                if keys.contains(historyKey) {
                    ListeningHistoryStore.applyFromUbiquitousStore()
                }
            } else {
                Podcast.applyFollowedPodcastsFromUbiquitousStore()
                ListeningHistoryStore.applyFromUbiquitousStore()
            }
        }
    }
}

@main
struct PodLinkApp: App {
    @State private var themeManager = ThemeManager.shared
    @State private var playbackService = PlaybackService.shared
    @State private var downloadManager = DownloadManager.shared
    @State private var networkStatusService = NetworkStatusService.shared
    @AppStorage("miniPlayerFloatVerticalSnap") private var miniPlayerFloatVerticalSnap = MiniPlayerFloatVerticalSnap.bottom.rawValue
    @AppStorage("miniPlayerSize") private var miniPlayerSize = MiniPlayerSize.slim.rawValue

    private var miniPlayerFloatSnapAtTop: Bool {
        miniPlayerFloatVerticalSnap == MiniPlayerFloatVerticalSnap.top.rawValue
    }

    private var isMicroplayerMode: Bool {
        miniPlayerSize == MiniPlayerSize.microplayer.rawValue
    }

    init() {
        configureAudioSession()
        _ = UbiquitousKeyValueStoreSyncObserver.shared
        _ = NSUbiquitousKeyValueStore.default.synchronize()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .environment(playbackService)
                .environment(downloadManager)
                .environment(networkStatusService)
                .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : nil)
                .background(
                    MiniPlayerOverlaySceneAnchor(
                        themeManager: themeManager,
                        playbackService: playbackService,
                        networkStatusService: networkStatusService,
                        miniPlayerFloatSnapAtTop: miniPlayerFloatSnapAtTop,
                        isMicroplayerMode: isMicroplayerMode
                    )
                )
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}
