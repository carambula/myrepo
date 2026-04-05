//
//  AppDelegate.swift
//  WatchedItTV
//
//  Created by Aaron Carámbula on 1/31/26.
//

import UIKit
import SwiftData
import CloudKit
import WatchedItCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    private var sharedModelContainer: ModelContainer?
    private let iCloudPromptKey = "tvDidPromptICloudLogin"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        sharedModelContainer = AppDataBootstrapper.makeSharedModelContainer()

        let rootViewController = TVMovieListViewController()
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.view.backgroundColor = .black
        navigationController.navigationBar.isTranslucent = false
        navigationController.navigationBar.barTintColor = .black
        navigationController.navigationBar.backgroundColor = .black

        // Create the window using a UIWindowScene to avoid deprecated APIs on tvOS 26+
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = navigationController
            window.backgroundColor = .black
            window.makeKeyAndVisible()
            self.window = window
        }

        // Seed LocalDatabaseManager with the main context.
        if let container = sharedModelContainer {
            Task { @MainActor in
                LocalDatabaseManager.shared.setup(modelContext: container.mainContext)
                await LocalDatabaseManager.shared.awaitStartupCatalogLoad()
                guard !LocalDatabaseManager.shared.catalogNeedsRestartDueToCorruption else {
                    print("⚠️ [Startup] tvOS: skipping CloudKit and podcast intake (corrupt local store).")
                    return
                }
                await LocalDatabaseManager.shared.restoreUserDataFromCloudKitIfNeeded()
                await LocalDatabaseManager.shared.syncUserDataFromCloudKit(mergeOnlyWhenLocalEmpty: true)
                await LocalDatabaseManager.shared.restoreStreamingPreferencesFromCloudKitIfNeeded()
                await LocalDatabaseManager.shared.syncStreamingPreferencesFromCloudKitIfNewer()
                await LocalDatabaseManager.shared.pushLocalStreamingPreferencesToCloudKitIfNeeded()
                await LocalDatabaseManager.shared.restoreListPreferencesFromCloudKitIfNeeded()
                await LocalDatabaseManager.shared.syncListPreferencesFromCloudKitIfNewer()
                await LocalDatabaseManager.shared.pushLocalListPreferencesToCloudKitIfNeeded()
                await LocalDatabaseManager.shared.pushLocalUserDataToCloudKitIfNeeded()
                let status = await LocalDatabaseManager.shared.cloudAccountStatus()
                self.promptForICloudIfNeeded(status: status)
                await LocalDatabaseManager.shared.performDeferredPodcastEpisodeIntakeIfNeeded(reason: "tvos-startup")
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSwiftDataRecovery),
            name: .swiftDataCorruptionRecovered,
            object: nil
        )

        return true
    }

    @objc private func handleSwiftDataRecovery() {
        sharedModelContainer = AppDataBootstrapper.makeSharedModelContainer()
        if let container = sharedModelContainer {
            Task { @MainActor in
                LocalDatabaseManager.shared.setup(modelContext: container.mainContext)
                LocalDatabaseManager.shared.loadMovies()
            }
        }
    }

    @MainActor
    private func promptForICloudIfNeeded(status: CKAccountStatus) {
        guard status == .noAccount || status == .restricted else { return }
        guard !UserDefaults.standard.bool(forKey: iCloudPromptKey) else { return }
        UserDefaults.standard.set(true, forKey: iCloudPromptKey)

        let title = status == .noAccount ? "Sign in to iCloud" : "iCloud Restricted"
        let message = status == .noAccount
            ? "To sync with your iPhone, sign in to iCloud on this Apple TV. Then return and use Account → Sync from iCloud."
            : "iCloud access is restricted on this Apple TV. Sync is unavailable until restrictions are removed."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if status == .noAccount {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Not Now", style: .cancel))
        window?.rootViewController?.present(alert, animated: true)
    }
}
