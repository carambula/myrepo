//
//  AppDataBootstrapper.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 1/31/26.
//

import Foundation
import SwiftData
import CoreData

@MainActor
public enum AppDataBootstrapper {
    /// Set when a prior run hit SQLite 11 at fetch time; next launch moves the store aside and copies the bundled bootstrap.
    public static let pendingSQLiteStoreQuarantineKey = "WatchedItPendingSQLiteStoreQuarantine"

    public static func persistentStoreURL() -> URL {
        let directories: [FileManager.SearchPathDirectory] = [
            .applicationSupportDirectory,
            .libraryDirectory,
            .cachesDirectory,
            .documentDirectory
        ]

        for directory in directories {
            if let baseURL = try? FileManager.default.url(
                for: directory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) {
                let containerURL = baseURL.appendingPathComponent("WatchedIt", isDirectory: true)
                if (try? FileManager.default.createDirectory(
                    at: containerURL,
                    withIntermediateDirectories: true
                )) != nil {
                    return containerURL.appendingPathComponent("default.store")
                }
            }
        }

        let fallbackDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("WatchedIt", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
        return fallbackDirectory.appendingPathComponent("default.store")
    }

    public static func makeSharedModelContainer() -> ModelContainer {
        // This function must not throw - all errors are handled internally
        func bootstrapDebugLog(_ message: @autoclosure () -> String) {
#if DEBUG
            guard ProcessInfo.processInfo.environment["WATCHEDIT_VERBOSE_LOGS"] == "1" else { return }
            print(message())
#endif
        }
        
        func bootstrapSidecarURL(for baseURL: URL, suffix: String) -> URL? {
            let dashURL = URL(fileURLWithPath: baseURL.path + "-\(suffix)")
            if FileManager.default.fileExists(atPath: dashURL.path) {
                return dashURL
            }
            let dotURL = baseURL.appendingPathExtension(suffix)
            if FileManager.default.fileExists(atPath: dotURL.path) {
                return dotURL
            }
            return nil
        }

        /// SQLite / Core Data use **`basename-wal` / `basename-shm`** next to the main file. Older code only removed **`basename.wal`**, leaving stale `-wal` files that corrupt the next main file copy (SQLite 11).
        func removeSQLiteSidecarFilesNextToStore(at baseURL: URL) {
            let candidates = [
                URL(fileURLWithPath: baseURL.path + "-wal"),
                URL(fileURLWithPath: baseURL.path + "-shm"),
                URL(fileURLWithPath: baseURL.path + "-journal"),
                baseURL.appendingPathExtension("wal"),
                baseURL.appendingPathExtension("shm"),
            ]
            for url in candidates where FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                bootstrapDebugLog("📦 [BOOTSTRAP] Removed SQLite sidecar: \(url.lastPathComponent)")
            }
        }

        func isBootstrapBundleUsable(at baseURL: URL) -> Bool {
            let walURL = bootstrapSidecarURL(for: baseURL, suffix: "wal")
            let shmURL = bootstrapSidecarURL(for: baseURL, suffix: "shm")
            let walSize = walURL.flatMap { (try? FileManager.default.attributesOfItem(atPath: $0.path)[.size] as? NSNumber)?.intValue } ?? 0
            if walURL != nil && walSize == 0 {
                // A zero-byte WAL is a strong signal of an invalid bundle store.
                return false
            }
            if shmURL == nil {
                // Missing SHM isn't fatal, but we'll still allow it.
            }
            return true
        }

        func deleteStoreFiles(at baseURL: URL) {
            try? FileManager.default.removeItem(at: baseURL)
            removeSQLiteSidecarFilesNextToStore(at: baseURL)
        }

        /// Moves store files to a backup path instead of deleting. Use for the main app store
        /// to avoid "vnode unlinked while in use" (deleting a file that Core Data may still have open).
        func moveStoreFilesToBackup(at baseURL: URL) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let backupBase = baseURL.appendingPathExtension("backup-\(timestamp)")
            if FileManager.default.fileExists(atPath: baseURL.path) {
                try? FileManager.default.moveItem(at: baseURL, to: backupBase)
            }
            // Move extension-style sidecars if present (legacy)
            let walURL = baseURL.appendingPathExtension("wal")
            let shmURL = baseURL.appendingPathExtension("shm")
            let backupWal = backupBase.appendingPathExtension("wal")
            let backupShm = backupBase.appendingPathExtension("shm")
            if FileManager.default.fileExists(atPath: walURL.path) { try? FileManager.default.moveItem(at: walURL, to: backupWal) }
            if FileManager.default.fileExists(atPath: shmURL.path) { try? FileManager.default.moveItem(at: shmURL, to: backupShm) }
            // Critical: also remove dash-style WAL/SHM (SQLite default); they are NOT moved with the main file.
            removeSQLiteSidecarFilesNextToStore(at: baseURL)
            bootstrapDebugLog("📦 [BOOTSTRAP] Moved existing store to backup: \(backupBase.lastPathComponent)")
        }

        func currentPersistenceFrameworkVersion() -> Int? {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("persistence-version-\(UUID().uuidString).store")
            let model = NSManagedObjectModel()
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            var addedStore: NSPersistentStore?
            defer {
                if let store = addedStore {
                    try? coordinator.remove(store)
                }
                deleteStoreFiles(at: tempURL)
            }
            do {
                let store = try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: tempURL,
                    options: nil
                )
                addedStore = store
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                    ofType: NSSQLiteStoreType,
                    at: tempURL
                )
                return (metadata["NSPersistenceFrameworkVersionKey"] as? NSNumber)?.intValue
            } catch {
                return nil
            }
        }

        /// Uses move (not delete) so we never unlink a file Core Data may still have open.
        /// Returns true if the store was moved to backup (caller should not copy bundled bootstrap).
        func dropStoreIfIncompatible(at baseURL: URL) -> Bool {
            guard FileManager.default.fileExists(atPath: baseURL.path) else {
                bootstrapDebugLog("📦 [BOOTSTRAP] dropStoreIfIncompatible: no store at path, skip.")
                return false
            }
            bootstrapDebugLog("📦 [BOOTSTRAP] dropStoreIfIncompatible: checking store at \(baseURL.lastPathComponent)...")
            do {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                    ofType: NSSQLiteStoreType,
                    at: baseURL
                )
                let storedVersion = (metadata["NSPersistenceFrameworkVersionKey"] as? NSNumber)?.intValue
                let currentVersion = currentPersistenceFrameworkVersion()
                // Only move when we have a confirmed mismatch. If we can't read either version
                // (e.g. store has no version key, or temp-store check failed), leave the store
                // in place so ModelContainer can try to open it. This prevents wiping a valid
                // store and ending up with an empty DB after "fixing" the other app target.
                if let storedVersion, let currentVersion, storedVersion != currentVersion {
                    print("⚠️ [BOOTSTRAP] Persistence framework mismatch (\(storedVersion) vs \(currentVersion)). Moving local store to backup.")
                    moveStoreFilesToBackup(at: baseURL)
                    return true
                }
                if storedVersion == nil || currentVersion == nil {
                    bootstrapDebugLog("📦 [BOOTSTRAP] Could not read persistence version (stored: \(storedVersion != nil), current: \(currentVersion != nil)). Leaving store in place.")
                }
            } catch {
                let nsError = error as NSError
                let description = String(describing: error)
                if nsError.domain == "NSSQLiteErrorDomain" && nsError.code == 11 {
                    print("⚠️ [BOOTSTRAP] Database corruption (SQLite 11). Moving local store to backup.")
                    moveStoreFilesToBackup(at: baseURL)
                    return true
                } else if description.contains("Persistence-") || description.contains("previously used on a build") {
                    print("⚠️ [BOOTSTRAP] Incompatible store format. Moving local store to backup.")
                    moveStoreFilesToBackup(at: baseURL)
                    return true
                }
            }
            return false
        }

        // Include both old and new models for migration
        let schema = Schema([
            MovieModel.self, // Old model - kept for migration
            MovieData.self,
            MovieState.self, // Old - will be migrated to UserMovieData
            DataSource.self,
            MovieDataSource.self, // Old - will be migrated to SourceContent
            // New ideal schema entities
            UserMovieData.self,
            SourceContent.self,
            BootstrapVersion.self,
        ])

        // Disable CloudKit sync for SwiftData - we'll use our own CloudKitManager
        let storeURL = persistentStoreURL()
        bootstrapDebugLog("📦 [BOOTSTRAP] Store URL: \(storeURL.path)")
        bootstrapDebugLog("📦 [BOOTSTRAP] Store exists before check: \(FileManager.default.fileExists(atPath: storeURL.path))")

        // Runtime fetch can fail with SQLite 11 even when metadata read succeeded; quarantine replaces the store on next launch.
        if UserDefaults.standard.bool(forKey: Self.pendingSQLiteStoreQuarantineKey) {
            print("📦 [BOOTSTRAP] Prior session reported SQLite corruption at fetch time — replacing local store with bundled catalog.")
            if FileManager.default.fileExists(atPath: storeURL.path) {
                moveStoreFilesToBackup(at: storeURL)
            }
            removeSQLiteSidecarFilesNextToStore(at: storeURL)
            let quarantineBootstrapURL =
                Bundle.main.url(forResource: "bootstrap_database", withExtension: "store")
                ?? Bundle.main.url(forResource: "bootstrap_database", withExtension: "store", subdirectory: "WatchedIt")
            if let quarantineBootstrapURL, isBootstrapBundleUsable(at: quarantineBootstrapURL) {
                try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                do {
                    // Copy main SQLite file only. Stale `default.store-wal` next to the path is what caused SQLite 11 after restore.
                    try FileManager.default.copyItem(at: quarantineBootstrapURL, to: storeURL)
                    removeSQLiteSidecarFilesNextToStore(at: storeURL)
                    _ = BootstrapDataService.shared.recordBootstrapImportDate()
                    UserDefaults.standard.set(false, forKey: Self.pendingSQLiteStoreQuarantineKey)
                    print("📦 [BOOTSTRAP] Bundled bootstrap restored after SQLite quarantine.")
                } catch {
                    print("⚠️ [BOOTSTRAP] Quarantine bootstrap copy failed (will retry next launch): \(error)")
                }
            } else {
                UserDefaults.standard.set(false, forKey: Self.pendingSQLiteStoreQuarantineKey)
                print("⚠️ [BOOTSTRAP] Quarantine: bundled bootstrap missing or unusable; cleared quarantine flag.")
            }
        }

        let storeWasMovedByVersionCheck = dropStoreIfIncompatible(at: storeURL)
        bootstrapDebugLog("📦 [BOOTSTRAP] After dropStoreIfIncompatible, store exists: \(FileManager.default.fileExists(atPath: storeURL.path)), storeWasMovedByVersionCheck: \(storeWasMovedByVersionCheck)")
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        } catch {
            print("⚠️ Failed to create Application Support directory: \(error)")
        }

        // Check if we have a pre-populated bootstrap database
        var usedBootstrapDatabase = false
        var hasUserData = false
        let bootstrapDBURL =
            Bundle.main.url(forResource: "bootstrap_database", withExtension: "store")
            ?? Bundle.main.url(forResource: "bootstrap_database", withExtension: "store", subdirectory: "WatchedIt")
        if let bootstrapDBURL {
            let databaseExists = FileManager.default.fileExists(atPath: storeURL.path)
            bootstrapDebugLog("📦 [BOOTSTRAP] databaseExists=\(databaseExists), storeWasMovedByVersionCheck=\(storeWasMovedByVersionCheck)")

            if !databaseExists {
                // Only copy bundled bootstrap on genuine first launch. If we just moved the store
                // due to version check/corruption, the bundled store may be corrupt too—start empty instead.
                if !storeWasMovedByVersionCheck {
                    // First launch - copy pre-populated database
                    do {
                        if !isBootstrapBundleUsable(at: bootstrapDBURL) {
                            throw NSError(domain: "Bootstrap", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bundled store sidecars invalid"])
                        }
                        try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try FileManager.default.copyItem(at: bootstrapDBURL, to: storeURL)
                        removeSQLiteSidecarFilesNextToStore(at: storeURL)
                        usedBootstrapDatabase = true
                        _ = BootstrapDataService.shared.recordBootstrapImportDate()
                        bootstrapDebugLog("📦 [BOOTSTRAP] First launch: copied bootstrap to \(storeURL.lastPathComponent)")
                    } catch {
                        print("⚠️ [BOOTSTRAP] Could not copy bootstrap database: \(error)")
                        // Continue with empty database
                    }
                } else {
                    bootstrapDebugLog("📦 [BOOTSTRAP] Store was reset (version/corruption); not copying bundled bootstrap. ModelContainer will create empty store.")
                    try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                }
            } else {
                // Database exists - check if it's empty (corrupted or failed previous attempt)
                var databaseIsEmpty = false
                var shouldReplace = false

                do {
                    // Use the full schema to avoid schema mismatch errors that can
                    // incorrectly mark a valid store as "corrupted" and trigger replacement.
                    let tempConfig = ModelConfiguration(
                        url: storeURL,
                        allowsSave: false,
                        cloudKitDatabase: .none
                    )
                    let tempContainer = try ModelContainer(for: schema, configurations: [tempConfig])
                    let tempContext = tempContainer.mainContext
                    let descriptor = FetchDescriptor<MovieData>()
                    let movieCount = try tempContext.fetch(descriptor).count
                    let userDataDescriptor = FetchDescriptor<UserMovieData>()
                    let userDataCount = try tempContext.fetch(userDataDescriptor).count
                    hasUserData = userDataCount > 0
                    databaseIsEmpty = movieCount == 0
                    if databaseIsEmpty {
                        shouldReplace = userDataCount == 0
                    }
                } catch {
                    print("⚠️ Could not open existing database (treating as corrupted): \(error)")
                    databaseIsEmpty = true
                    shouldReplace = true
                }

                // NOTE: Do NOT replace based on bootstrap database modification date.
                // Using file mtime is unreliable with WAL and can wipe user data on every launch.
                // We only replace if the existing database is empty or corrupted.

                if shouldReplace {
                    do {
                        let bootstrapUsable = isBootstrapBundleUsable(at: bootstrapDBURL)
                        // Move (don't delete) so we never unlink a file the temp container may still have open
                        moveStoreFilesToBackup(at: storeURL)
                        bootstrapDebugLog("📦 [BOOTSTRAP] Replaced empty/corrupt store with bootstrap.")

                        if bootstrapUsable {
                            try FileManager.default.copyItem(at: bootstrapDBURL, to: storeURL)
                            removeSQLiteSidecarFilesNextToStore(at: storeURL)
                            usedBootstrapDatabase = true
                        }

                        if usedBootstrapDatabase {
                            _ = BootstrapDataService.shared.recordBootstrapImportDate()
                        }
                    } catch {
                        print("⚠️ Could not replace database with bootstrap: \(error)")
                    }
                }
            }
        }

        do {
            bootstrapDebugLog("📦 [BOOTSTRAP] Creating ModelContainer...")
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            bootstrapDebugLog("📦 [BOOTSTRAP] ModelContainer created successfully.")

            // Setup LocalDatabaseManager with the model context on main actor ASAP
            Task { @MainActor in
                LocalDatabaseManager.shared.setup(modelContext: container.mainContext)
            }

            // Defer lightweight setup to after UI appears
            Task.detached { @MainActor in
                // Wait for UI to render first
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                _ = container.mainContext
            }
            return container
        } catch {
            // If migration/corruption: move store to backup (never delete open files), then copy bootstrap and retry.
            print("⚠️ [BOOTSTRAP] ModelContainer creation failed: \(error)")
            if let nsError = error as NSError?,
               nsError.domain == "NSSQLiteErrorDomain",
               nsError.code == 11 {
                print("⚠️ [BOOTSTRAP] Database corruption (SQLite 11) at creation.")
            }

            let storeURL = persistentStoreURL()
            if FileManager.default.fileExists(atPath: storeURL.path) {
                moveStoreFilesToBackup(at: storeURL)
            }
            // Ensure path is clear (move may have left nothing if path was already gone)
            try? FileManager.default.removeItem(at: storeURL)
            removeSQLiteSidecarFilesNextToStore(at: storeURL)
            bootstrapDebugLog("📦 [BOOTSTRAP] Cleared store path for bootstrap copy.")

            // Try to copy bootstrap database if available
            if let bootstrapDBURL = Bundle.main.url(forResource: "bootstrap_database", withExtension: "store") {
                do {
                    if isBootstrapBundleUsable(at: bootstrapDBURL) {
                        bootstrapDebugLog("📦 [BOOTSTRAP] Copying bootstrap after container creation failure...")
                        try FileManager.default.copyItem(at: bootstrapDBURL, to: storeURL)
                        removeSQLiteSidecarFilesNextToStore(at: storeURL)
                        bootstrapDebugLog("📦 [BOOTSTRAP] Bootstrap copy done, retrying ModelContainer...")
                    }
                } catch {
                    print("⚠️ [BOOTSTRAP] Could not copy bootstrap database: \(error)")
                }
            }

            // Try one more time
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                bootstrapDebugLog("📦 [BOOTSTRAP] ModelContainer created successfully after bootstrap replace.")
                Task { @MainActor in
                    LocalDatabaseManager.shared.setup(modelContext: container.mainContext)
                }
                return container
            } catch {
                print("❌ [BOOTSTRAP] CRITICAL: Could not create ModelContainer even after reset: \(error)")
                // Create an empty database instead of crashing
                do {
                    let emptyContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                    Task { @MainActor in
                        LocalDatabaseManager.shared.setup(modelContext: emptyContainer.mainContext)
                    }
                    return emptyContainer
                } catch {
                    // Last resort: create in-memory database
                    let inMemoryConfig = ModelConfiguration(
                        schema: schema,
                        isStoredInMemoryOnly: true,
                        allowsSave: true,
                        cloudKitDatabase: .none
                    )
                    let inMemoryContainer = try! ModelContainer(for: schema, configurations: [inMemoryConfig])
                    Task { @MainActor in
                        LocalDatabaseManager.shared.setup(modelContext: inMemoryContainer.mainContext)
                    }
                    return inMemoryContainer
                }
            }
        }
    }
}
