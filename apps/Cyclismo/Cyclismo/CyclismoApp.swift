//
//  CyclismoApp.swift
//  Cyclismo
//
//  Created by Aaron Carámbula on 2/8/26.
//

import SwiftUI
import MinAppKit

@main
struct CyclismoApp: App {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var deepLinkURL: URL?

    init() {
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "CyclismoURLCache"
        )
        ICloudSyncManager.shared.start()
        Task {
            await SavedRaceNotificationManager.shared.refreshSavedRaceNotifications()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkURL: $deepLinkURL)
                .environmentObject(themeManager)
                .themeBackground()
                .ideasRageShake(app: .cyc)
                .onOpenURL { url in
                    deepLinkURL = url
                }
                .task {
                    await themeManager.restoreThemesFromCloudKitIfNeeded()
                    await themeManager.syncThemesFromCloudKitIfNewer()
                    await themeManager.pushLocalThemesToCloudKitIfNeeded()
                }
        }
    }
}
