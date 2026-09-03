//
//  YourTubeApp.swift
//  YourTube
//
//  Created by Aaron Carámbula on 3/22/26.
//

import SwiftUI
import SwiftData

@main
struct YourTubeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var themeManager = ThemeManager.shared
    @State private var authService = GoogleOAuthService()
    @State private var syncStore = UserDataSyncStore()
    @State private var deepLinkVideoID: String?

    init() {
        PlaybackAudioSession.configureForBackgroundVideo()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            YTChannel.self,
            YTVideo.self,
            UserSubscription.self,
            WatchState.self,
            ThemePreference.self,
            SearchHistoryEntry.self,
            ChannelOrderPreference.self,
        ])

        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localStoreURL = appSupportURL.appendingPathComponent("YourTube.store")

        // First preference: CloudKit-backed store.
        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("CloudKit ModelContainer failed, falling back to local store: \(error)")
        }

        // Second preference: local on-disk store.
        do {
            let localConfig = ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            print("Local ModelContainer failed, resetting local SwiftData files: \(error)")
        }

        // Last resort: remove local store files and recreate from scratch.
        do {
            let fileManager = FileManager.default
            let potentialStoreFiles = [
                localStoreURL,
                localStoreURL.appendingPathExtension("wal"),
                localStoreURL.appendingPathExtension("shm"),
            ]
            for fileURL in potentialStoreFiles where fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }

            let resetConfig = ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [resetConfig])
        } catch {
            fatalError("Could not create ModelContainer even after reset: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(
                themeManager: themeManager,
                authService: authService,
                syncStore: syncStore,
                deepLinkVideoID: $deepLinkVideoID
            )
            .onOpenURL { url in
                deepLinkVideoID = DeepLinkHandler.videoID(from: url)
            }
        }
        .onChange(of: scenePhase) {
            PlaybackAudioSession.handleScenePhaseChange(scenePhase)
        }
        .modelContainer(sharedModelContainer)
    }
}
