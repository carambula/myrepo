import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
final class MinCloudAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Task {
            let granted = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted == true {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        MinCloudSettings.pushToken = token
        Task { await MinCloudClient.shared.registerDevice() }
    }
}
#endif

/// Retains the `NotificationCenter` token for iCloud KVS updates (required for block-based observers).
private final class UbiquitousKeyValueStoreSyncObserver {
    static let shared = UbiquitousKeyValueStoreSyncObserver()

    private var token: NSObjectProtocol?

    private init() {
        // Driven by the in-memory iCloud mirror (`CloudKeyValueWriter`), which updates itself off
        // the main thread before posting, so these reconciliations read warm values without blocking.
        token = NotificationCenter.default.addObserver(
            forName: .cloudKeyValueStoreDidChange,
            object: nil,
            queue: nil
        ) { _ in
            // Reconcile off the main thread: both calls decode/encode JSON (followed podcasts plus up to
            // 300 listening-history rows) which blocked the main thread at launch. They persist to
            // thread-safe stores and post their change notifications back on the main thread.
            DispatchQueue.global(qos: .utility).async {
                Podcast.applyFollowedPodcastsFromUbiquitousStore()
                ListeningHistoryStore.applyFromUbiquitousStore()
            }
        }
    }
}

@main
struct PodLinkApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(MinCloudAppDelegate.self) private var appDelegate
    #endif
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
        CloudKeyValueWriter.start()
        _ = UbiquitousKeyValueStoreSyncObserver.shared
        // NOTE: Do NOT register custom fonts here. The Rotina fonts are only rendered inside the Font
        // Settings preview (`FontOverrideSettingsView`); no launch UI uses them. Registering 16 woff2
        // files at launch (even off-main) held the Core Text font-registry lock while the main thread did
        // first layout, producing the `GSFont ... already exists` spam and multi-second launch hangs.
        // Registration now happens lazily, only when the Font Settings screen actually needs the fonts.
        #if DEBUG
        MainThreadHangMonitor.shared.start()
        #endif
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
}
