//
//  fit_minApp.swift
//  fit min
//
//  Created by Aaron Carámbula on 6/15/26.
//

import SwiftUI
import SwiftData
import MinAppKit

@main
struct fit_minApp: App {
    @State private var themeManager = ThemeManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SetTimer.self,
        ])

        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localStoreURL = appSupportURL.appendingPathComponent("FitMin.store")

        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("CloudKit ModelContainer failed, falling back to local store: \(error)")
        }

        do {
            let localConfig = ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            print("Local ModelContainer failed, resetting local SwiftData files: \(error)")
        }

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
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : .light)
                .themeBackground()
                .ideasRageShake(app: .fit)
                .task {
                    TimerSoundService.shared.prewarm()
                    themeManager.syncFromCloud()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
