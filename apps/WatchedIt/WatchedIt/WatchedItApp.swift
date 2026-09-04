//
//  WatchedItApp.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import SwiftUI
import SwiftData
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
        Task { await MinCloudClient.shared.registerDevice(pushToken: token) }
    }
}
#endif

@main
struct WatchedItApp: App {
    let sharedModelContainer: ModelContainer = AppDataBootstrapper.makeSharedModelContainer()
    @ObservedObject private var themeManager = ThemeManager.shared
    private let perfLoggingDefaultsKey = "perf_logging_enabled"
    #if os(iOS)
    @UIApplicationDelegateAdaptor(MinCloudAppDelegate.self) private var appDelegate
    #endif

    private var isPerfLoggingEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: perfLoggingDefaultsKey) as? Bool ?? false
        #else
        return UserDefaults.standard.bool(forKey: perfLoggingDefaultsKey)
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            rootContent
                .preferredColorScheme(themeManager.currentTheme.supportsLightMode ? nil : .dark)
                .environmentObject(ThemeManager.shared)
                .task {
                    await performInitialLoad()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    @State private var deepLinkURL: URL?

    @ViewBuilder
    private var rootContent: some View {
        #if os(iOS)
        NewUserExperienceOverlayContainer {
            CollectionsHomeView(deepLinkURL: $deepLinkURL)
        }
        .onOpenURL { url in
            deepLinkURL = url
        }
        #else
        CollectionsHomeView(deepLinkURL: .constant(nil))
        #endif
    }
    
    @MainActor
    private func performInitialLoad() async {
        let startupStart = ProcessInfo.processInfo.systemUptime
        let localDB = LocalDatabaseManager.shared

        // Phase 1: get catalog on screen quickly (await so we never run CloudKit/podcast intake on a known-corrupt store).
        Task.detached { @MainActor in
            let deferredStart = ProcessInfo.processInfo.systemUptime
            try? await Task.sleep(nanoseconds: 120_000_000)
            await localDB.awaitStartupCatalogLoad()
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - startupStart) * 1000
                print("⏱️ [PERF] [Startup] phase 1 catalog load finished at \(String(format: "%.1f", elapsedMs))ms")
            }
            if localDB.catalogNeedsRestartDueToCorruption {
                print("⚠️ [Startup] Skipping CloudKit restores and podcast intake (corrupt local store).")
                return
            }

            // Phase 2: defer cloud and preferences restore until after first paint.
            try? await Task.sleep(nanoseconds: 280_000_000)
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - startupStart) * 1000
                print("⏱️ [PERF] [Startup] phase 2 deferred restores began at \(String(format: "%.1f", elapsedMs))ms")
            }

            let restoreStart = ProcessInfo.processInfo.systemUptime
            await localDB.restoreUserDataFromCloudKitIfNeeded()
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - restoreStart) * 1000
                print("⏱️ [PERF] [Startup] restoreUserDataFromCloudKitIfNeeded: \(String(format: "%.1f", elapsedMs))ms")
            }

            let streamingPrefsStart = ProcessInfo.processInfo.systemUptime
            await localDB.restoreStreamingPreferencesFromCloudKitIfNeeded()
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - streamingPrefsStart) * 1000
                print("⏱️ [PERF] [Startup] restoreStreamingPreferencesFromCloudKitIfNeeded: \(String(format: "%.1f", elapsedMs))ms")
            }

            let listPrefsStart = ProcessInfo.processInfo.systemUptime
            await localDB.restoreListPreferencesFromCloudKitIfNeeded()
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - listPrefsStart) * 1000
                print("⏱️ [PERF] [Startup] restoreListPreferencesFromCloudKitIfNeeded: \(String(format: "%.1f", elapsedMs))ms")
            }

            let podcastPrefsStart = ProcessInfo.processInfo.systemUptime
            await localDB.restorePodcastAppPreferencesFromCloudKitIfNeeded()
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - podcastPrefsStart) * 1000
                print("⏱️ [PERF] [Startup] restorePodcastAppPreferencesFromCloudKitIfNeeded: \(String(format: "%.1f", elapsedMs))ms")
            }

            let themesStart = ProcessInfo.processInfo.systemUptime
            await themeManager.restoreThemesFromCloudKitIfNeeded()
            if isPerfLoggingEnabled {
                let elapsedMs = (ProcessInfo.processInfo.systemUptime - themesStart) * 1000
                let deferredElapsedMs = (ProcessInfo.processInfo.systemUptime - deferredStart) * 1000
                print("⏱️ [PERF] [Startup] restoreThemesFromCloudKitIfNeeded: \(String(format: "%.1f", elapsedMs))ms")
                print("⏱️ [PERF] [Startup] deferred startup phases total: \(String(format: "%.1f", deferredElapsedMs))ms")
            }

            // Phase 3: after app is fully usable, silently scan podcasts for new episodes.
            try? await Task.sleep(nanoseconds: 700_000_000)
            await localDB.performDeferredPodcastEpisodeIntakeIfNeeded(reason: "ios-startup")

            if let context = localDB.modelContext {
                _ = await MinCloudCatalogSync.shared.syncIfAvailable(modelContext: context)
            }
            await TheatricalAvailabilitySync.shared.refresh(
                catalogTmdbIds: localDB.movies.compactMap(\.tmdbId)
            )
            if MinCloudSettings.isSignedIn {
                await MinCloudLibrarySync.shared.syncOnSignIn()
            } else {
                await MinCloudClient.shared.registerDevice()
            }
        }
    }
}
