//
//  LocalDatabaseManager.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import SwiftData
import Combine
import CloudKit

@MainActor
public class LocalDatabaseManager: ObservableObject {
    public static let shared = LocalDatabaseManager()

    /// Walks `NSUnderlyingErrorKey` chain — SwiftData often wraps SQLite 11 in a Cocoa error.
    private static func errorIndicatesSQLiteDiskCorruption(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        var depth = 0
        while let e = current, depth < 12 {
            if e.domain == "NSSQLiteErrorDomain", e.code == 11 { return true }
            current = e.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return false
    }
    
    private struct KnownPodcastFeedDefinition {
        let identifier: String
        let name: String
        let feedURL: String
    }
    
    private let knownPodcastFeedDefinitions: [KnownPodcastFeedDefinition] = [
        KnownPodcastFeedDefinition(
            identifier: "rewatchables",
            name: "The Rewatchables",
            feedURL: "https://feeds.megaphone.fm/the-rewatchables"
        ),
        KnownPodcastFeedDefinition(
            identifier: "big-picture",
            name: "The Big Picture",
            feedURL: "https://feeds.megaphone.fm/the-big-picture"
        ),
        KnownPodcastFeedDefinition(
            identifier: "blank-check",
            name: "Blank Check",
            feedURL: "https://feeds.megaphone.fm/blank-check"
        ),
        KnownPodcastFeedDefinition(
            identifier: "confused-breakfast",
            name: "The Confused Breakfast",
            feedURL: "https://feeds.megaphone.fm/CTL8333955564"
        )
    ]
    
    public var modelContext: ModelContext?
    
    @Published public var movies: [Movie] = []
    @Published public var isLoading = false // Start as false, will be set to true when loading starts
    @Published public var hasAttemptedInitialLoad = false // Track if we've tried to load at least once
    @Published public var movieStatusVersion = 0 // Bumps on status changes for UI invalidation
    @Published public var isRestoringUserData = false
    @Published public var isCatalogRefreshInProgress = false
    @Published public var pendingPodcastEpisodeCount = 0
    @Published public var isPodcastEpisodeCheckInProgress = false
    /// SQLite 11 (malformed) while the open `ModelContainer` still points at the bad file. Runtime replacement is unsafe; user must restart so `AppDataBootstrapper` can move the store and re-bootstrap.
    @Published public var catalogNeedsRestartDueToCorruption = false
    
    private var pendingLoadRetryCount = 0
    private var cloudRestoreAttemptCount = 0
    private let maxCloudRestoreAttempts = 3
    private var cloudPushAttemptCount = 0
    private let maxCloudPushAttempts = 3
    private var hasPushedUserDataThisSession = false
    private var hasRestoredUserDataThisSession = false
    private var streamingPrefsRestoreAttemptCount = 0
    private let maxStreamingPrefsRestoreAttempts = 3
    private var streamingPrefsPushAttemptCount = 0
    private let maxStreamingPrefsPushAttempts = 3
    private var hasPushedStreamingPrefsThisSession = false
    private var hasRestoredStreamingPrefsThisSession = false
    private var listPrefsRestoreAttemptCount = 0
    private let maxListPrefsRestoreAttempts = 3
    private var listPrefsPushAttemptCount = 0
    private let maxListPrefsPushAttempts = 3
    private var hasPushedListPrefsThisSession = false
    private var hasRestoredListPrefsThisSession = false
    private var podcastAppPrefsRestoreAttemptCount = 0
    private let maxPodcastAppPrefsRestoreAttempts = 3
    private var podcastAppPrefsPushAttemptCount = 0
    private let maxPodcastAppPrefsPushAttempts = 3
    private var hasPushedPodcastAppPrefsThisSession = false
    private var hasRestoredPodcastAppPrefsThisSession = false
    private var hasTriggeredCatalogRefreshThisSession = false
    private var hasTriggeredPodcastCheckThisSession = false
    private let perfLoggingDefaultsKey = "perf_logging_enabled"
    private let pendingPodcastEpisodesDefaultsKey = "pending_podcast_episode_intake_v1"
    private let lastPodcastEpisodeCheckDefaultsKey = "last_podcast_episode_check_at_v1"
    
    private init() {}

    private var isPerfLoggingEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: perfLoggingDefaultsKey) as? Bool ?? false
        #else
        return UserDefaults.standard.bool(forKey: perfLoggingDefaultsKey)
        #endif
    }

    private func logPerf(_ label: String, start: TimeInterval, thresholdMs: Double = 0) {
        guard isPerfLoggingEnabled else { return }
        let elapsedMs = (ProcessInfo.processInfo.systemUptime - start) * 1000
        guard elapsedMs >= thresholdMs else { return }
        print("⏱️ [PERF] [LocalDB] \(label): \(String(format: "%.1f", elapsedMs))ms")
    }
    
    private func bootstrapSidecarURL(for baseURL: URL, suffix: String) -> URL? {
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

    private func makeBootstrapStoreCopy(from bundleURL: URL) throws -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let mergeDirectory = appSupportURL
            .appendingPathComponent("BootstrapMerge", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: mergeDirectory, withIntermediateDirectories: true)

        let tempStoreURL = mergeDirectory.appendingPathComponent(bundleURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: tempStoreURL.path) {
            try? FileManager.default.removeItem(at: tempStoreURL)
        }
        try FileManager.default.copyItem(at: bundleURL, to: tempStoreURL)

        if let walURL = bootstrapSidecarURL(for: bundleURL, suffix: "wal") {
            let tempWalURL = tempStoreURL.appendingPathExtension("wal")
            try? FileManager.default.copyItem(at: walURL, to: tempWalURL)
        }
        if let shmURL = bootstrapSidecarURL(for: bundleURL, suffix: "shm") {
            let tempShmURL = tempStoreURL.appendingPathExtension("shm")
            try? FileManager.default.copyItem(at: shmURL, to: tempShmURL)
        }

        let isWritable = FileManager.default.isWritableFile(atPath: tempStoreURL.path)
        print("📦 [BOOTSTRAP] Temp store ready at \(tempStoreURL.path) (writable=\(isWritable))")

        return tempStoreURL
    }

    public func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        pendingPodcastEpisodeCount = loadPendingPodcastEpisodes().count
        // Don't load movies immediately - let UI appear first
        // Movies will be loaded when needed (onAppear or performInitialEpisodeCheck)
    }
    
    public func loadMovies() {
        guard !catalogNeedsRestartDueToCorruption else { return }
        if modelContext == nil {
            if pendingLoadRetryCount < 3 {
                pendingLoadRetryCount += 1
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    self.loadMovies()
                }
            }
            return
        }
        
        // Check if already loading to avoid duplicate loads
        if isLoading && hasAttemptedInitialLoad {
            return
        }
        
        // Defer actual loading to avoid blocking UI startup
        Task { @MainActor in
            await loadMoviesAsync()
        }
    }

    /// Ensures the first catalog fetch finishes before other startup SwiftData work runs (CloudKit restore, podcast intake).
    @MainActor
    public func awaitStartupCatalogLoad() async {
        var spins = 0
        while modelContext == nil, spins < 120 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            spins += 1
        }
        guard modelContext != nil else {
            print("⚠️ [Startup] awaitStartupCatalogLoad: modelContext still nil")
            return
        }
        var waitLoad = 0
        while isLoading, waitLoad < 2400 {
            try? await Task.sleep(nanoseconds: 25_000_000)
            waitLoad += 1
        }
        if hasAttemptedInitialLoad { return }
        await loadMoviesAsync()
    }

    public func refreshCatalogFromBundleIfNeeded(modelContext: ModelContext) {
        guard !catalogNeedsRestartDueToCorruption else { return }
        let refreshStart = ProcessInfo.processInfo.systemUptime
        guard !isCatalogRefreshInProgress else { return }
        guard BootstrapDataService.shared.isBootstrapUpdateAvailable() else { return }
        guard !hasTriggeredCatalogRefreshThisSession else { return }

        hasTriggeredCatalogRefreshThisSession = true
        isCatalogRefreshInProgress = true

        Task.detached { @MainActor [weak self] in
            guard let self else { return }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 150_000_000)
            do {
                try await self.rebaseOnBootstrapDatabase(modelContext: modelContext)
                print("📦 [BOOTSTRAP] Auto-refreshed catalog from bundled database.")
                self.logPerf("refreshCatalogFromBundleIfNeeded total", start: refreshStart, thresholdMs: 20)
            } catch {
                print("⚠️ [BOOTSTRAP] Auto-refresh failed: \(error)")
                self.logPerf("refreshCatalogFromBundleIfNeeded failed", start: refreshStart)
            }
            self.isCatalogRefreshInProgress = false
        }
    }

    public func refreshCatalogFromBundle() async throws {
        guard let modelContext = modelContext else { return }
        try await rebaseOnBootstrapDatabase(modelContext: modelContext)
    }
    
    @MainActor
    private func loadMoviesAsync() async {
        let loadStart = ProcessInfo.processInfo.systemUptime
        guard let modelContext = modelContext else {
            return
        }
        pendingLoadRetryCount = 0
        
        isLoading = true
        hasAttemptedInitialLoad = true
        
        // Yield immediately to let UI render first
        await Task.yield()
        
        let descriptor = FetchDescriptor<MovieData>()
        
        do {
            let fetchStart = ProcessInfo.processInfo.systemUptime
            // Fetch movies - this might be slow with 3k+ items
            // Fetch directly - modelContext.fetch() must be called on MainActor
            let movieDataList = try modelContext.fetch(descriptor)
            logPerf("fetch MovieData (\(movieDataList.count) rows)", start: fetchStart, thresholdMs: 20)

            // Skip auto-cleaning titles on startup to avoid blocking the UI.
            // Use the manual Clean Data action instead.
            
            // Convert to Movie objects in batches with yields and memory management
            var convertedMovies: [Movie] = []
            convertedMovies.reserveCapacity(movieDataList.count)
            
            // Process in smaller batches to manage memory better
            let batchSize = 200
            var batchCount = 0
            let convertStart = ProcessInfo.processInfo.systemUptime
            
            for batchStart in stride(from: 0, to: movieDataList.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, movieDataList.count)
                
                // Use autoreleasepool to release memory after each batch
                autoreleasepool {
                    for index in batchStart..<batchEnd {
                        let movieData = movieDataList[index]
                        if let movie = movieData.toMovieIfValid() {
                            convertedMovies.append(movie)
                        }
                    }
                }
                
                batchCount += 1
                
                // Yield after each batch to allow memory cleanup
                await Task.yield()
            }
            
            // Defer state update to avoid "Modifying state during view update" warnings
            logPerf("convert MovieData -> Movie (\(convertedMovies.count) rows, \(batchCount) batches)", start: convertStart, thresholdMs: 20)
            let publishStart = ProcessInfo.processInfo.systemUptime
            await Task.yield()
            movies = convertedMovies
            catalogNeedsRestartDueToCorruption = false
            isLoading = false
            logPerf("publish movies array", start: publishStart, thresholdMs: 5)
            logPerf("loadMoviesAsync total", start: loadStart, thresholdMs: 20)
        } catch {
            let nsError = error as NSError
            print("❌ Error loading movies: \(error)")
            print("❌ Error domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
            
            // SQLite 11 (malformed file): do not replace the store while ModelContainer is open.
            // Quarantine schedules a bootstrap restore on the *next* launch (see AppDataBootstrapper).
            if Self.errorIndicatesSQLiteDiskCorruption(error) {
                print("⚠️ [BOOTSTRAP] Database corruption (SQLite 11) in loadMovies. Quarantining store for next launch; restart app.")
                UserDefaults.standard.set(true, forKey: AppDataBootstrapper.pendingSQLiteStoreQuarantineKey)
                movies = []
                isLoading = false
                hasAttemptedInitialLoad = true
                catalogNeedsRestartDueToCorruption = true
                NotificationCenter.default.post(name: .swiftDataCorruptionRecovered, object: nil)
                return
            }
            
            isLoading = false
            logPerf("loadMoviesAsync failed", start: loadStart)
        }
    }
    
    /// Reloads movies without setting isLoading flag (for background refreshes)
    public func refreshMovies() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MovieData>(
            sortBy: [SortDescriptor(\.title)]
        )
        
        do {
            let movieDataList = try context.fetch(descriptor)
            movies = movieDataList.compactMap { $0.toMovieIfValid() }
        } catch {
            print("❌ Error refreshing movies: \(error)")
            if Self.errorIndicatesSQLiteDiskCorruption(error) {
                UserDefaults.standard.set(true, forKey: AppDataBootstrapper.pendingSQLiteStoreQuarantineKey)
                catalogNeedsRestartDueToCorruption = true
            }
        }
    }

    @discardableResult
    public func performDeferredPodcastEpisodeIntakeIfNeeded(reason: String = "startup") async -> Int {
        await performPodcastEpisodeIntake(reason: reason, force: false)
    }

    @discardableResult
    public func forcePodcastEpisodeIntake(reason: String = "manual-refresh") async -> Int {
        await performPodcastEpisodeIntake(reason: reason, force: true)
    }

    private func performPodcastEpisodeIntake(reason: String, force: Bool) async -> Int {
        guard !catalogNeedsRestartDueToCorruption else {
            print("⚠️ [PODCAST] Intake skipped: local store is unusable (SQLite corruption — quit and relaunch the app).")
            return 0
        }
        guard let modelContext else { return 0 }
        if isPodcastEpisodeCheckInProgress {
            guard force else { return 0 }
            var waitedMs = 0
            while isPodcastEpisodeCheckInProgress && waitedMs < 20_000 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                waitedMs += 200
            }
            guard !isPodcastEpisodeCheckInProgress else { return 0 }
        }

        let now = Date()
        let intakeService = PodcastEpisodeIntakeService.shared
        if !force {
            guard !hasTriggeredPodcastCheckThisSession else { return 0 }
            if let lastChecked = UserDefaults.standard.object(forKey: lastPodcastEpisodeCheckDefaultsKey) as? Date,
               now.timeIntervalSince(lastChecked) < intakeService.throttleInterval {
                return 0
            }
            hasTriggeredPodcastCheckThisSession = true
        }

        isPodcastEpisodeCheckInProgress = true
        let start = ProcessInfo.processInfo.systemUptime
        let mode = force ? "forced" : "deferred"
        print("🔔 [PODCAST] \(mode.capitalized) intake started (\(reason))")

        var committedCount = 0
        var completionDetails = "details=unavailable"
        defer {
            UserDefaults.standard.set(Date(), forKey: lastPodcastEpisodeCheckDefaultsKey)
            isPodcastEpisodeCheckInProgress = false
            logPerf("podcast intake total", start: start)
            print("🔔 [PODCAST] \(mode.capitalized) intake finished committed=\(committedCount) \(completionDetails)")
        }

        if BootstrapDataService.shared.isBootstrapUpdateAvailable() {
            do {
                try await rebaseOnBootstrapDatabase(modelContext: modelContext)
                print("📦 [BOOTSTRAP] Reconciled catalog before podcast intake.")
            } catch {
                print("⚠️ [PODCAST] Bootstrap reconcile failed before intake: \(error)")
            }
        }

        // Backward-compat: if a previous build staged intake items, import them first.
        reconcilePendingPodcastEpisodesWithCatalog()
        let legacyPending = loadPendingPodcastEpisodes()
        if !legacyPending.isEmpty {
            let migrated = applyPodcastIntakeItems(legacyPending, modelContext: modelContext)
            persistPendingPodcastEpisodes([])
            print("🔔 [PODCAST] Migrated \(migrated) previously staged items directly into database.")
        }

        let sourceDescriptor = FetchDescriptor<DataSource>()
        var allSources = (try? modelContext.fetch(sourceDescriptor)) ?? []
        let repairedSourceCount = reconcileKnownPodcastSourcesIfNeeded(allSources: &allSources, modelContext: modelContext)
        if repairedSourceCount > 0 {
            print("🔧 [PODCAST] Reconciled \(repairedSourceCount) known podcast source definitions before intake.")
        }
        let allPodcastSources = allSources.filter { $0.type == "podcast" }
        let podcastSources = allSources.filter {
            $0.type == "podcast"
                && $0.isEnabled
                && !(($0.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        if force {
            let enabledIDs = podcastSources.map(\.identifier).sorted()
            let disabledIDs = allPodcastSources.filter { !$0.isEnabled }.map(\.identifier).sorted()
            let missingURLIDs = allPodcastSources
                .filter { (($0.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                .map(\.identifier)
                .sorted()
            print("🔎 [PODCAST] Source eligibility enabled=\(enabledIDs) disabled=\(disabledIDs) missingURL=\(missingURLIDs)")
        }
        guard !podcastSources.isEmpty else {
            let disabledCount = allPodcastSources.filter { !$0.isEnabled }.count
            let missingURLCount = allPodcastSources.filter {
                (($0.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.count
            completionDetails = "details=no-enabled-feeds totalPodcastSources=\(allPodcastSources.count) disabled=\(disabledCount) missingURL=\(missingURLCount)"
            print("⚠️ [PODCAST] Intake skipped: no enabled podcast feeds with URLs. total=\(allPodcastSources.count) disabled=\(disabledCount) missingURL=\(missingURLCount)")
            return 0
        }

        let sources = podcastSources.map {
            PodcastFeedSource(identifier: $0.identifier, name: $0.name, feedURL: $0.url ?? "", lastChecked: $0.lastChecked)
        }
        let states = buildPodcastSourceStates(sources: podcastSources)

        let result = await intakeService.scanAndEnrich(
            sources: sources,
            sourceStates: states,
            existingPendingKeys: [],
            now: now
        )
        let scanned = result.sourceStats.map(\.scannedCount).reduce(0, +)
        let candidates = result.sourceStats.map(\.candidateCount).reduce(0, +)
        let fetchErrors = result.sourceStats.filter { $0.stopReason == "fetch-error" }.count

        let sourceLookup = Dictionary(uniqueKeysWithValues: allSources.map { ($0.identifier, $0) })
        for stat in result.sourceStats {
            sourceLookup[stat.sourceIdentifier]?.lastChecked = now
        }
        try? modelContext.save()

        let committed = applyPodcastIntakeItems(result.pendingItems, modelContext: modelContext)
        committedCount = committed
        let tmdbMisses = max(0, candidates - result.pendingItems.count)
        completionDetails = "details=scanned=\(scanned) candidates=\(candidates) pending=\(result.pendingItems.count) committed=\(committed) fetchErrors=\(fetchErrors) tmdbMisses=\(tmdbMisses)"
        persistPendingPodcastEpisodes([])
        if committed > 0 { loadMovies() } else { refreshMovies() }

        if force || committed == 0 {
            logPodcastIntakeSourceStats(result.sourceStats, reason: reason, committed: committed)
        }

        if isPerfLoggingEnabled {
            let candidates = result.sourceStats.map(\.candidateCount).reduce(0, +)
            let scanned = result.sourceStats.map(\.scannedCount).reduce(0, +)
            print("⏱️ [PERF] [PodcastIntake] scanned=\(scanned) candidates=\(candidates) committed=\(committed)")
        }
        return committed
    }

    private func logPodcastIntakeSourceStats(
        _ stats: [PodcastEpisodeSourceScanStats],
        reason: String,
        committed: Int
    ) {
        guard !stats.isEmpty else {
            print("⚠️ [PODCAST] Intake produced no source stats (reason=\(reason), committed=\(committed)).")
            return
        }

        let statSummary = stats
            .map { stat in
                let reason = stat.stopReason ?? "none"
                return "\(stat.sourceIdentifier):scanned=\(stat.scannedCount),candidates=\(stat.candidateCount),noise=\(stat.skippedByNoise),stopped=\(stat.stoppedEarly),stopReason=\(reason)"
            }
            .joined(separator: " | ")

        print("🔎 [PODCAST] Intake details (reason=\(reason), committed=\(committed)): \(statSummary)")
    }
    
    private func reconcileKnownPodcastSourcesIfNeeded(
        allSources: inout [DataSource],
        modelContext: ModelContext
    ) -> Int {
        var sourcesByIdentifier = Dictionary(uniqueKeysWithValues: allSources.map { ($0.identifier, $0) })
        var repairedCount = 0
        
        for definition in knownPodcastFeedDefinitions {
            if let existing = sourcesByIdentifier[definition.identifier] {
                var didRepair = false
                if existing.type != "podcast" {
                    existing.type = "podcast"
                    didRepair = true
                }
                if existing.url?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    existing.url = definition.feedURL
                    didRepair = true
                }
                if existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.name = definition.name
                    didRepair = true
                }
                if didRepair {
                    repairedCount += 1
                }
                continue
            }
            
            let created = DataSource(
                identifier: definition.identifier,
                name: definition.name,
                type: "podcast",
                url: definition.feedURL,
                isEnabled: true,
                lastUpdated: Date(),
                lastChecked: nil
            )
            modelContext.insert(created)
            allSources.append(created)
            sourcesByIdentifier[definition.identifier] = created
            repairedCount += 1
        }
        
        if repairedCount > 0 {
            try? modelContext.save()
        }
        return repairedCount
    }

    @discardableResult
    public func commitPendingPodcastEpisodes() async -> Int {
        guard let modelContext else { return 0 }
        let pending = loadPendingPodcastEpisodes()
        guard !pending.isEmpty else {
            pendingPodcastEpisodeCount = 0
            return 0
        }

        let start = ProcessInfo.processInfo.systemUptime
        let committed = applyPodcastIntakeItems(pending, modelContext: modelContext)
        persistPendingPodcastEpisodes([])
        loadMovies()
        logPerf("commitPendingPodcastEpisodes (\(committed) items)", start: start)
        return committed
    }

    public func reconcilePendingPodcastEpisodesWithCatalog() {
        guard let modelContext else { return }
        var pending = loadPendingPodcastEpisodes()
        guard !pending.isEmpty else {
            pendingPodcastEpisodeCount = 0
            return
        }

        let catalogMovies = (try? modelContext.fetch(FetchDescriptor<MovieData>())) ?? []
        let tmdbIDsInCatalog = Set(catalogMovies.compactMap(\.tmdbId))
        let titleYearPairs = Set(catalogMovies.map { "\(TitleCleaner.shared.cleanTitle($0.title).lowercased())|\($0.year ?? -1)" })

        let sourceContents = (try? modelContext.fetch(FetchDescriptor<SourceContent>())) ?? []
        let movieDataSources = (try? modelContext.fetch(FetchDescriptor<MovieDataSource>())) ?? []
        let existingEpisodeIDs = Set(sourceContents.compactMap { $0.podcastEpisode?.episodeId } + movieDataSources.compactMap { $0.podcastEpisode?.episodeId })

        pending.removeAll { item in
            if let tmdb = item.movie.tmdbId, tmdbIDsInCatalog.contains(tmdb) {
                return true
            }
            if let episodeID = item.movie.podcastEpisode?.episodeId, existingEpisodeIDs.contains(episodeID) {
                return true
            }
            let key = "\(TitleCleaner.shared.cleanTitle(item.movie.title).lowercased())|\(item.movie.year ?? -1)"
            return titleYearPairs.contains(key)
        }

        persistPendingPodcastEpisodes(pending)
    }

    private func buildPodcastSourceStates(
        sources: [DataSource]
    ) -> [String: PodcastFeedSourceState] {
        var titleSetBySource: [String: Set<String>] = [:]
        var latestDateBySource: [String: Date] = [:]
        var latestTitleBySource: [String: String] = [:]

        for source in sources {
            titleSetBySource[source.identifier] = []
        }

        for source in sources {
            let identifier = source.identifier
            for content in source.sourceContents ?? [] {
                let sourceTitle = content.sourceTitle ?? content.podcastEpisode?.title ?? content.movie?.title ?? ""
                let normalized = PodcastEpisodeIntakeService.shared.normalizeEpisodeTitle(sourceTitle)
                if !normalized.isEmpty {
                    titleSetBySource[identifier, default: []].insert(normalized)
                }
                let date = content.podcastEpisode?.publishDate ?? content.sourceDate
                if let date, (latestDateBySource[identifier] == nil || date > latestDateBySource[identifier]!) {
                    latestDateBySource[identifier] = date
                    latestTitleBySource[identifier] = sourceTitle
                }
            }

            for legacyLink in source.movieDataSources ?? [] {
                let sourceTitle = legacyLink.sourceTitle ?? legacyLink.podcastEpisode?.title ?? legacyLink.movie?.title ?? ""
                let normalized = PodcastEpisodeIntakeService.shared.normalizeEpisodeTitle(sourceTitle)
                if !normalized.isEmpty {
                    titleSetBySource[identifier, default: []].insert(normalized)
                }
                if let date = legacyLink.podcastEpisode?.publishDate,
                   latestDateBySource[identifier] == nil || date > latestDateBySource[identifier]! {
                    latestDateBySource[identifier] = date
                    latestTitleBySource[identifier] = sourceTitle
                }
            }
        }

        var result: [String: PodcastFeedSourceState] = [:]
        for source in sources {
            let latestTitle = latestTitleBySource[source.identifier]
            result[source.identifier] = PodcastFeedSourceState(
                sourceIdentifier: source.identifier,
                existingSourceTitles: titleSetBySource[source.identifier] ?? [],
                latestEpisodeDate: latestDateBySource[source.identifier],
                latestKnownSourceTitle: latestTitle,
                latestKnownSourceTitleNormalized: PodcastEpisodeIntakeService.shared.normalizeEpisodeTitle(latestTitle ?? "")
            )
        }
        return result
    }

    private func applyPodcastIntakeItems(_ items: [PendingPodcastEpisodeIntakeItem], modelContext: ModelContext) -> Int {
        guard !items.isEmpty else { return 0 }

        var committed = 0
        let sourceDescriptor = FetchDescriptor<DataSource>()
        let existingSources = (try? modelContext.fetch(sourceDescriptor)) ?? []
        var sourceByIdentifier = Dictionary(uniqueKeysWithValues: existingSources.map { ($0.identifier, $0) })

        let movieDescriptor = FetchDescriptor<MovieData>()
        let allMovies = (try? modelContext.fetch(movieDescriptor)) ?? []
        var movieByID: [String: MovieData] = Dictionary(uniqueKeysWithValues: allMovies.map { ($0.id, $0) })
        var movieByTMDB: [Int: MovieData] = allMovies.reduce(into: [:]) { partial, movie in
            guard let tmdbId = movie.tmdbId else { return }
            partial[tmdbId] = movie
        }

        for item in items {
            do {
                let source: DataSource
                if let existing = sourceByIdentifier[item.sourceIdentifier] {
                    source = existing
                } else {
                    let created = DataSource(
                        identifier: item.sourceIdentifier,
                        name: item.sourceName,
                        type: "podcast",
                        url: item.sourceFeedURL,
                        isEnabled: true,
                        lastUpdated: Date(),
                        lastChecked: Date()
                    )
                    modelContext.insert(created)
                    sourceByIdentifier[item.sourceIdentifier] = created
                    source = created
                }

                if source.url == nil || source.url?.isEmpty == true {
                    source.url = item.sourceFeedURL
                }
                source.lastChecked = Date()

                let incoming = item.movie
                let movieData: MovieData
                if let existingByID = movieByID[incoming.id] {
                    movieData = existingByID
                } else if let tmdb = incoming.tmdbId, let existingByTMDB = movieByTMDB[tmdb] {
                    movieData = existingByTMDB
                } else {
                    let created = MovieData.fromMovie(incoming)
                    modelContext.insert(created)
                    movieData = created
                    movieByID[created.id] = created
                    if let tmdb = created.tmdbId {
                        movieByTMDB[tmdb] = created
                    }
                }

                let cleanedTitle = TitleCleaner.shared.cleanTitle(incoming.title)
                movieData.title = cleanedTitle
                movieData.year = incoming.year ?? movieData.year
                movieData.tmdbId = incoming.tmdbId ?? movieData.tmdbId
                movieData.posterPath = incoming.posterPath ?? movieData.posterPath
                movieData.backdropPath = incoming.backdropPath ?? movieData.backdropPath
                movieData.overview = incoming.overview ?? movieData.overview
                movieData.mpaaRating = incoming.mpaaRating ?? movieData.mpaaRating
                movieData.genres = incoming.genres.isEmpty ? movieData.genres : incoming.genres
                movieData.streamingServices = incoming.streamingServices.isEmpty ? movieData.streamingServices : incoming.streamingServices
                movieData.credits = incoming.credits ?? movieData.credits
                movieData.trailer = incoming.trailer ?? movieData.trailer
                movieData.lastUpdated = Date()

                let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
                if incoming.isRewatched || incoming.isListened || incoming.isSaved {
                    userData.isRewatched = incoming.isRewatched
                    userData.isListened = incoming.isListened
                    userData.isSaved = incoming.isSaved
                    userData.lastUpdated = Date()
                }

                if let existingState = movieData.states?.first, incoming.isRewatched || incoming.isListened || incoming.isSaved {
                    existingState.isRewatched = incoming.isRewatched
                    existingState.isListened = incoming.isListened
                    existingState.isSaved = incoming.isSaved
                    existingState.lastUpdated = Date()
                }

                if let podcastEpisode = incoming.podcastEpisode {
                    let existingContent = movieData.sourceContents?.first(where: { $0.source?.identifier == source.identifier })
                    if let existingContent {
                        existingContent.sourceTitle = item.sourceTitle
                        existingContent.sourceDescription = item.podcastEpisodeDescription
                        existingContent.sourceDate = item.episodeDate
                        existingContent.podcastEpisode = podcastEpisode
                        existingContent.sourceUrl = item.sourceFeedURL
                        existingContent.applePodcastsUrl = podcastEpisode.applePodcastsUrl
                        existingContent.spotifyUrl = podcastEpisode.spotifyUrl
                        existingContent.lastUpdated = Date()
                    } else {
                        let newContent = SourceContent(
                            movie: movieData,
                            source: source,
                            sourceTitle: item.sourceTitle,
                            sourceDescription: item.podcastEpisodeDescription,
                            sourceDate: item.episodeDate,
                            rank: nil,
                            podcastEpisode: podcastEpisode,
                            rewatchablesDiscussion: nil,
                            sourceUrl: item.sourceFeedURL,
                            applePodcastsUrl: podcastEpisode.applePodcastsUrl,
                            spotifyUrl: podcastEpisode.spotifyUrl,
                            lastUpdated: Date(),
                            discoveredAt: item.discoveredAt
                        )
                        modelContext.insert(newContent)
                    }

                    let existingLegacyLink = movieData.dataSources?.first(where: { $0.dataSource?.identifier == source.identifier })
                    if let existingLegacyLink {
                        existingLegacyLink.sourceTitle = item.sourceTitle
                        existingLegacyLink.sourceUrl = item.sourceFeedURL
                        existingLegacyLink.podcastEpisode = podcastEpisode
                        existingLegacyLink.lastUpdated = Date()
                    } else {
                        let newLegacyLink = MovieDataSource(
                            movie: movieData,
                            dataSource: source,
                            podcastEpisode: podcastEpisode,
                            rewatchablesDiscussion: nil,
                            sourceUrl: item.sourceFeedURL,
                            sourceTitle: item.sourceTitle,
                            rank: nil,
                            lastUpdated: Date()
                        )
                        modelContext.insert(newLegacyLink)
                    }
                }

                committed += 1
            } catch {
                print("⚠️ [PODCAST] Failed to apply intake item \(item.id): \(error)")
            }
        }

        do {
            try modelContext.save()
            try deduplicateMovies()
        } catch {
            print("❌ [PODCAST] Intake commit save failed: \(error)")
            return 0
        }

        return committed
    }

    private func loadPendingPodcastEpisodes() -> [PendingPodcastEpisodeIntakeItem] {
        guard let data = UserDefaults.standard.data(forKey: pendingPodcastEpisodesDefaultsKey),
              !data.isEmpty else {
            return []
        }
        do {
            return try JSONDecoder().decode([PendingPodcastEpisodeIntakeItem].self, from: data)
        } catch {
            print("⚠️ [PODCAST] Failed to decode pending intake queue: \(error)")
            return []
        }
    }

    private func persistPendingPodcastEpisodes(_ items: [PendingPodcastEpisodeIntakeItem]) {
        if items.isEmpty {
            UserDefaults.standard.removeObject(forKey: pendingPodcastEpisodesDefaultsKey)
            pendingPodcastEpisodeCount = 0
            return
        }
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: pendingPodcastEpisodesDefaultsKey)
            pendingPodcastEpisodeCount = items.count
        } catch {
            print("⚠️ [PODCAST] Failed to persist pending intake queue: \(error)")
        }
    }
    
    /// Gets or creates UserMovieData for a movie, migrating from MovieState if needed
    private func getOrCreateUserMovieData(for movieData: MovieData, modelContext: ModelContext) -> UserMovieData {
        // Prefer new schema
        if let userData = movieData.userData {
            return userData
        }
        
        // Migrate from old schema if exists
        if let oldState = movieData.states?.first {
            let userData = UserMovieData(
                movie: movieData,
                isSaved: oldState.isSaved,
                isRewatched: oldState.isRewatched,
                isListened: oldState.isListened,
                isWatched: false,
                userRating: nil,
                userNotes: nil,
                watchedDate: nil,
                rewatchedDate: nil,
                listenedDate: nil,
                tags: [],
                lastUpdated: oldState.lastUpdated,
                createdAt: oldState.lastUpdated
            )
            movieData.userData = userData
            modelContext.insert(userData)
            return userData
        }
        
        // Create new UserMovieData
        let userData = UserMovieData(movie: movieData)
        movieData.userData = userData
        modelContext.insert(userData)
        return userData
    }
    
    /// Optimistically updates a movie's status in the cache immediately (before database operation)
    /// This provides instant UI feedback without waiting for async database operations
    private func optimisticallyUpdateMovieStatus(_ movieId: String, isRewatched: Bool? = nil, isListened: Bool? = nil, isSaved: Bool? = nil) {
        guard let index = movies.firstIndex(where: { $0.id == movieId }) else { return }
        
        // Create a new array to trigger SwiftUI update detection
        var updatedMovies = movies
        let currentMovie = updatedMovies[index]
        
        // Create updated movie with new status values
        let updatedMovie = Movie(
            id: currentMovie.id,
            title: currentMovie.title,
            year: currentMovie.year,
            tmdbId: currentMovie.tmdbId,
            posterPath: currentMovie.posterPath,
            backdropPath: currentMovie.backdropPath,
            overview: currentMovie.overview,
            mpaaRating: currentMovie.mpaaRating,
            genres: currentMovie.genres,
            streamingServices: currentMovie.streamingServices,
            podcastEpisode: currentMovie.podcastEpisode,
            credits: currentMovie.credits,
            rewatchablesDiscussion: currentMovie.rewatchablesDiscussion,
            trailer: currentMovie.trailer,
            isRewatched: isRewatched ?? currentMovie.isRewatched,
            isListened: isListened ?? currentMovie.isListened,
            isSaved: isSaved ?? currentMovie.isSaved,
            lastUpdated: Date()
        )
        
        updatedMovies[index] = updatedMovie
        movies = updatedMovies
        movieStatusVersion += 1
        
        // Post notification to invalidate filter cache in views
        NotificationCenter.default.post(name: NSNotification.Name("MovieUpdated"), object: movieId)
    }
    
    /// Updates a single movie in the cache without reloading all movies
    /// This syncs with the database after the operation completes
    private func updateMovieInCache(_ movieId: String) {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<MovieData>(
            predicate: #Predicate<MovieData> { $0.id == movieId }
        )
        
        if let movieData = try? modelContext.fetch(descriptor).first,
           let movie = movieData.toMovieIfValid(),
           let index = movies.firstIndex(where: { $0.id == movieId }) {
            // Create a new array to trigger SwiftUI update detection
            var updatedMovies = movies
            updatedMovies[index] = movie
            movies = updatedMovies
            movieStatusVersion += 1
            
            // Post notification to invalidate filter cache in views
            NotificationCenter.default.post(name: NSNotification.Name("MovieUpdated"), object: movieId)
        }
    }

    /// Syncs user-specific movie data to CloudKit (if enabled)
    private func syncUserMovieDataToCloudKit(movieId: String, userData: UserMovieData) {
        let payload = CloudKitManager.UserMovieDataPayload(
            movieId: movieId,
            isSaved: userData.isSaved,
            isRewatched: userData.isRewatched,
            isListened: userData.isListened,
            isWatched: userData.isWatched,
            userRating: userData.userRating,
            userNotes: userData.userNotes,
            watchedDate: userData.watchedDate,
            rewatchedDate: userData.rewatchedDate,
            listenedDate: userData.listenedDate,
            tagsData: userData.tagsData,
            lastUpdated: userData.lastUpdated
        )
        Task.detached {
            await CloudKitManager.shared.saveUserMovieDataPayload(payload)
        }
    }

    private func isUserDataEmpty(_ userData: UserMovieData) -> Bool {
        let hasFlags = userData.isSaved || userData.isRewatched || userData.isListened || userData.isWatched
        let hasRating = userData.userRating != nil
        let hasNotes = (userData.userNotes ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasTags = (userData.tagsData?.isEmpty == false)
        let hasDates = userData.watchedDate != nil || userData.rewatchedDate != nil || userData.listenedDate != nil
        return !(hasFlags || hasRating || hasNotes || hasTags || hasDates)
    }
    
    private func scheduleCloudRestoreRetry(after seconds: Double) {
        guard cloudRestoreAttemptCount < maxCloudRestoreAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.restoreUserDataFromCloudKitIfNeeded()
        }
    }

    private func scheduleCloudPushRetry(after seconds: Double) {
        guard cloudPushAttemptCount < maxCloudPushAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.pushLocalUserDataToCloudKitIfNeeded()
        }
    }

    private func scheduleStreamingPrefsRestoreRetry(after seconds: Double) {
        guard streamingPrefsRestoreAttemptCount < maxStreamingPrefsRestoreAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.restoreStreamingPreferencesFromCloudKitIfNeeded()
        }
    }

    private func scheduleStreamingPrefsPushRetry(after seconds: Double) {
        guard streamingPrefsPushAttemptCount < maxStreamingPrefsPushAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.pushLocalStreamingPreferencesToCloudKitIfNeeded()
        }
    }

    private func scheduleListPrefsRestoreRetry(after seconds: Double) {
        guard listPrefsRestoreAttemptCount < maxListPrefsRestoreAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.restoreListPreferencesFromCloudKitIfNeeded()
        }
    }

    private func scheduleListPrefsPushRetry(after seconds: Double) {
        guard listPrefsPushAttemptCount < maxListPrefsPushAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.pushLocalListPreferencesToCloudKitIfNeeded()
        }
    }

    private func schedulePodcastAppPrefsRestoreRetry(after seconds: Double) {
        guard podcastAppPrefsRestoreAttemptCount < maxPodcastAppPrefsRestoreAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.restorePodcastAppPreferencesFromCloudKitIfNeeded()
        }
    }

    private func schedulePodcastAppPrefsPushRetry(after seconds: Double) {
        guard podcastAppPrefsPushAttemptCount < maxPodcastAppPrefsPushAttempts else { return }
        let delay = UInt64(seconds * 1_000_000_000)
        Task.detached { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.pushLocalPodcastAppPreferencesToCloudKitIfNeeded()
        }
    }
    
    private func applyUserMovieDataPayloads(
        _ payloads: [CloudKitManager.UserMovieDataPayload],
        mergeOnlyWhenLocalEmpty: Bool
    ) -> Int {
        guard let modelContext = modelContext else { return 0 }
        var appliedCount = 0
        var missingMovieCount = 0
        var skippedExistingCount = 0
        var skippedNewerLocalCount = 0
        
        for payload in payloads {
            let movieId = payload.movieId
            let descriptor = FetchDescriptor<MovieData>(
                predicate: #Predicate<MovieData> { $0.id == movieId }
            )
            guard let movieData = (try? modelContext.fetch(descriptor))?.first else {
                missingMovieCount += 1
                continue
            }
            
            let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
            let isEmpty = isUserDataEmpty(userData)
            if mergeOnlyWhenLocalEmpty {
                if !isEmpty {
                    skippedExistingCount += 1
                    continue
                }
            } else if !isEmpty, payload.lastUpdated <= userData.lastUpdated {
                skippedNewerLocalCount += 1
                continue
            }
            
            userData.isSaved = payload.isSaved
            userData.isRewatched = payload.isRewatched
            userData.isListened = payload.isListened
            userData.isWatched = payload.isWatched
            userData.userRating = payload.userRating
            userData.userNotes = payload.userNotes
            userData.watchedDate = payload.watchedDate
            userData.rewatchedDate = payload.rewatchedDate
            userData.listenedDate = payload.listenedDate
            userData.tagsData = payload.tagsData
            userData.lastUpdated = payload.lastUpdated
            appliedCount += 1
        }
        
        try? modelContext.save()
        // Update in-memory list without showing full-screen loading (avoids list flicker)
        refreshMovies()
        return appliedCount
    }

    private func fetchAllMovieIds(in modelContext: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<MovieData>()
        let movies = (try? modelContext.fetch(descriptor)) ?? []
        return movies.map { $0.id }
    }

    private func makePayload(for movieId: String, userData: UserMovieData) -> CloudKitManager.UserMovieDataPayload {
        CloudKitManager.UserMovieDataPayload(
            movieId: movieId,
            isSaved: userData.isSaved,
            isRewatched: userData.isRewatched,
            isListened: userData.isListened,
            isWatched: userData.isWatched,
            userRating: userData.userRating,
            userNotes: userData.userNotes,
            watchedDate: userData.watchedDate,
            rewatchedDate: userData.rewatchedDate,
            listenedDate: userData.listenedDate,
            tagsData: userData.tagsData,
            lastUpdated: userData.lastUpdated
        )
    }
    
    private func makePayload(for movieId: String, state: MovieState) -> CloudKitManager.UserMovieDataPayload {
        CloudKitManager.UserMovieDataPayload(
            movieId: movieId,
            isSaved: state.isSaved,
            isRewatched: state.isRewatched,
            isListened: state.isListened,
            isWatched: false,
            userRating: nil,
            userNotes: nil,
            watchedDate: nil,
            rewatchedDate: nil,
            listenedDate: nil,
            tagsData: nil,
            lastUpdated: state.lastUpdated
        )
    }

    private func hasAnyUserStatus(in modelContext: ModelContext) -> Bool {
        let userDataDescriptor = FetchDescriptor<UserMovieData>()
        if let allUserData = try? modelContext.fetch(userDataDescriptor) {
            if allUserData.contains(where: { !isUserDataEmpty($0) }) {
                return true
            }
        }

        let oldStateDescriptor = FetchDescriptor<MovieState>()
        if let oldStates = try? modelContext.fetch(oldStateDescriptor) {
            if oldStates.contains(where: { $0.isSaved || $0.isRewatched || $0.isListened }) {
                return true
            }
        }

        return false
    }

    /// Pulls user-specific movie data from CloudKit and merges into local storage
    /// Never overwrites existing local user data; only fills empty records.
    public func syncUserDataFromCloudKit(mergeOnlyWhenLocalEmpty: Bool = true) async {
        guard !catalogNeedsRestartDueToCorruption else { return }
        do {
            guard let modelContext = modelContext else {
                return
            }
            let status = await CloudKitManager.shared.accountStatus()
            guard status == .available else {
                return
            }
            // Zone changes (incremental) when token exists; full when nil
            let payloads = try await CloudKitManager.shared.fetchUserMovieDataPayloads()
            _ = applyUserMovieDataPayloads(payloads, mergeOnlyWhenLocalEmpty: mergeOnlyWhenLocalEmpty)
        } catch {
            print("⚠️ Failed to fetch user data payloads from iCloud: \(error)")
        }
    }

    /// Restores user data from iCloud only if there is no local status data.
    public func restoreUserDataFromCloudKitIfNeeded() async {
        guard !catalogNeedsRestartDueToCorruption else { return }
        guard let modelContext = modelContext else { return }

        if hasAnyUserStatus(in: modelContext) {
            return
        }
        
        if cloudRestoreAttemptCount >= maxCloudRestoreAttempts {
            return
        }
        cloudRestoreAttemptCount += 1
        isRestoringUserData = true
        
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            isRestoringUserData = false
            scheduleCloudRestoreRetry(after: 2.0)
            return
        }
        
        // Use zone changes (incremental when token exists; full on first run when token is nil)
        let payloads: [CloudKitManager.UserMovieDataPayload]
        do {
            payloads = try await CloudKitManager.shared.fetchUserMovieDataPayloads()
        } catch {
            print("⚠️ Failed to fetch user data payloads from iCloud: \(error)")
            isRestoringUserData = false
            scheduleCloudRestoreRetry(after: 3.0)
            return
        }
        
        if payloads.isEmpty {
            isRestoringUserData = false
            scheduleCloudRestoreRetry(after: 5.0)
            return
        }
        
        _ = applyUserMovieDataPayloads(payloads, mergeOnlyWhenLocalEmpty: true)
        hasRestoredUserDataThisSession = true
        isRestoringUserData = false
    }

    /// Pushes local user data to iCloud if available, to ensure fresh installs can restore.
    public func pushLocalUserDataToCloudKitIfNeeded() async {
        guard !catalogNeedsRestartDueToCorruption else { return }
        guard let modelContext = modelContext else { return }
        guard hasAnyUserStatus(in: modelContext) else { return }
        guard !hasPushedUserDataThisSession else { return }
        if hasRestoredUserDataThisSession {
            hasPushedUserDataThisSession = true
            return
        }
        if cloudPushAttemptCount >= maxCloudPushAttempts {
            return
        }
        cloudPushAttemptCount += 1
        
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            scheduleCloudPushRetry(after: 3.0)
            return
        }
        
        var payloads: [CloudKitManager.UserMovieDataPayload] = []
        
        let userDataDescriptor = FetchDescriptor<UserMovieData>()
        if let allUserData = try? modelContext.fetch(userDataDescriptor) {
            for userData in allUserData where !isUserDataEmpty(userData) {
                guard let movieId = userData.movie?.id else { continue }
                payloads.append(makePayload(for: movieId, userData: userData))
            }
        }
        
        let oldStateDescriptor = FetchDescriptor<MovieState>()
        if let oldStates = try? modelContext.fetch(oldStateDescriptor) {
            for state in oldStates where (state.isSaved || state.isRewatched || state.isListened) {
                guard let movieId = state.movie?.id else { continue }
                payloads.append(makePayload(for: movieId, state: state))
            }
        }
        
        if payloads.isEmpty {
            return
        }
        
        hasPushedUserDataThisSession = true
        for (index, payload) in payloads.enumerated() {
            await CloudKitManager.shared.saveUserMovieDataPayload(payload)
            if index % 50 == 0 {
                await Task.yield()
            }
        }
    }

    /// Restores streaming preferences from iCloud only if there is no local preference data.
    public func restoreStreamingPreferencesFromCloudKitIfNeeded() async {
        if hasAnyStreamingPreferences() {
            return
        }
        if streamingPrefsRestoreAttemptCount >= maxStreamingPrefsRestoreAttempts {
            return
        }
        streamingPrefsRestoreAttemptCount += 1

        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            scheduleStreamingPrefsRestoreRetry(after: 2.0)
            return
        }

        do {
            guard let payload = try await CloudKitManager.shared.fetchUserStreamingPreferencesPayload() else {
                scheduleStreamingPrefsRestoreRetry(after: 5.0)
                return
            }
            applyStreamingPreferencesPayload(payload)
            hasRestoredStreamingPrefsThisSession = true
        } catch {
            print("⚠️ Failed to fetch streaming preferences from iCloud: \(error)")
            scheduleStreamingPrefsRestoreRetry(after: 3.0)
        }
    }

    /// Syncs streaming preferences from iCloud when the payload is newer.
    public func syncStreamingPreferencesFromCloudKitIfNewer() async {
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await CloudKitManager.shared.fetchUserStreamingPreferencesPayload() else {
                return
            }
            let localUpdated = StreamingPreferences.lastUpdated()
            guard payload.lastUpdated > localUpdated else { return }
            applyStreamingPreferencesPayload(payload)
        } catch {
            print("⚠️ Failed to sync streaming preferences from iCloud: \(error)")
        }
    }

    /// Pushes local streaming preferences to iCloud if available.
    public func pushLocalStreamingPreferencesToCloudKitIfNeeded() async {
        guard hasAnyStreamingPreferences() else { return }
        guard !hasPushedStreamingPrefsThisSession else { return }
        if hasRestoredStreamingPrefsThisSession {
            hasPushedStreamingPrefsThisSession = true
            return
        }
        if streamingPrefsPushAttemptCount >= maxStreamingPrefsPushAttempts {
            return
        }
        streamingPrefsPushAttemptCount += 1

        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            scheduleStreamingPrefsPushRetry(after: 3.0)
            return
        }

        let preferredData = StreamingPreferences.preferredServicesData()
        let hiddenData = StreamingPreferences.hiddenServicesData()
        var lastUpdated = StreamingPreferences.lastUpdated()
        if lastUpdated == Date.distantPast {
            lastUpdated = Date()
            StreamingPreferences.updateLastUpdated(lastUpdated)
        }

        let payload = CloudKitManager.UserStreamingPreferencesPayload(
            preferredServicesData: preferredData,
            hiddenServicesData: hiddenData,
            lastUpdated: lastUpdated
        )
        hasPushedStreamingPrefsThisSession = true
        await CloudKitManager.shared.saveUserStreamingPreferencesPayload(payload)
    }

    private func hasAnyStreamingPreferences() -> Bool {
        let preferred = StreamingPreferences.decode(from: StreamingPreferences.preferredServicesData())
        let hidden = StreamingPreferences.decode(from: StreamingPreferences.hiddenServicesData())
        return !preferred.isEmpty || !hidden.isEmpty
    }

    private func applyStreamingPreferencesPayload(_ payload: CloudKitManager.UserStreamingPreferencesPayload) {
        StreamingPreferences.setPreferredServicesData(payload.preferredServicesData)
        StreamingPreferences.setHiddenServicesData(payload.hiddenServicesData)
        StreamingPreferences.updateLastUpdated(payload.lastUpdated)
    }

    /// Restores list preferences from iCloud only if there is no local preference data.
    public func restoreListPreferencesFromCloudKitIfNeeded() async {
        if hasAnyListPreferences() {
            return
        }
        if listPrefsRestoreAttemptCount >= maxListPrefsRestoreAttempts {
            return
        }
        listPrefsRestoreAttemptCount += 1

        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            scheduleListPrefsRestoreRetry(after: 2.0)
            return
        }

        do {
            guard let payload = try await CloudKitManager.shared.fetchUserListPreferencesPayload() else {
                scheduleListPrefsRestoreRetry(after: 5.0)
                return
            }
            applyListPreferencesPayload(payload)
            hasRestoredListPrefsThisSession = true
        } catch {
            print("⚠️ Failed to fetch list preferences from iCloud: \(error)")
            scheduleListPrefsRestoreRetry(after: 3.0)
        }
    }

    /// Syncs list preferences from iCloud when the payload is newer.
    public func syncListPreferencesFromCloudKitIfNewer() async {
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await CloudKitManager.shared.fetchUserListPreferencesPayload() else {
                return
            }
            let localUpdated = ListPreferences.lastUpdated()
            guard payload.lastUpdated > localUpdated else { return }
            applyListPreferencesPayload(payload)
        } catch {
            print("⚠️ Failed to sync list preferences from iCloud: \(error)")
        }
    }

    /// Exposes CloudKit account status for platform UI prompts.
    public func cloudAccountStatus() async -> CKAccountStatus {
        await CloudKitManager.shared.accountStatus()
    }

    /// Pushes local list preferences to iCloud if available.
    public func pushLocalListPreferencesToCloudKitIfNeeded() async {
        guard hasAnyListPreferences() else { return }
        guard !hasPushedListPrefsThisSession else { return }
        if hasRestoredListPrefsThisSession {
            hasPushedListPrefsThisSession = true
            return
        }
        if listPrefsPushAttemptCount >= maxListPrefsPushAttempts {
            return
        }
        listPrefsPushAttemptCount += 1

        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            scheduleListPrefsPushRetry(after: 3.0)
            return
        }

        let preferredData = UserDefaults.standard.data(forKey: ListPreferences.storageKey) ?? Data()
        var lastUpdated = ListPreferences.lastUpdated()
        if lastUpdated == Date.distantPast {
            lastUpdated = Date()
            ListPreferences.updateLastUpdated(lastUpdated)
        }

        let payload = CloudKitManager.UserListPreferencesPayload(
            preferredListsData: preferredData,
            lastUpdated: lastUpdated
        )
        hasPushedListPrefsThisSession = true
        await CloudKitManager.shared.saveUserListPreferencesPayload(payload)
    }

    private func hasAnyListPreferences() -> Bool {
        let preferred = ListPreferences.decode(from: UserDefaults.standard.data(forKey: ListPreferences.storageKey) ?? Data())
        return !preferred.isEmpty
    }

    private func applyListPreferencesPayload(_ payload: CloudKitManager.UserListPreferencesPayload) {
        UserDefaults.standard.set(payload.preferredListsData, forKey: ListPreferences.storageKey)
        ListPreferences.updateLastUpdated(payload.lastUpdated)
    }

    /// Restores podcast app preferences from iCloud only if there is no local preference data.
    public func restorePodcastAppPreferencesFromCloudKitIfNeeded() async {
        if hasAnyPodcastAppPreferences() {
            return
        }
        if podcastAppPrefsRestoreAttemptCount >= maxPodcastAppPrefsRestoreAttempts {
            return
        }
        podcastAppPrefsRestoreAttemptCount += 1

        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            schedulePodcastAppPrefsRestoreRetry(after: 2.0)
            return
        }

        do {
            guard let payload = try await CloudKitManager.shared.fetchUserPodcastAppPreferencesPayload() else {
                schedulePodcastAppPrefsRestoreRetry(after: 5.0)
                return
            }
            applyPodcastAppPreferencesPayload(payload)
            hasRestoredPodcastAppPrefsThisSession = true
        } catch {
            print("⚠️ Failed to fetch podcast app preferences from iCloud: \(error)")
            schedulePodcastAppPrefsRestoreRetry(after: 3.0)
        }
    }

    /// Syncs podcast app preferences from iCloud when the payload is newer.
    public func syncPodcastAppPreferencesFromCloudKitIfNewer() async {
        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else { return }
        do {
            guard let payload = try await CloudKitManager.shared.fetchUserPodcastAppPreferencesPayload() else {
                return
            }
            let localUpdated = PodcastAppPreferences.lastUpdated()
            guard payload.lastUpdated > localUpdated else { return }
            applyPodcastAppPreferencesPayload(payload)
        } catch {
            print("⚠️ Failed to sync podcast app preferences from iCloud: \(error)")
        }
    }

    /// Pushes local podcast app preferences to iCloud if available.
    public func pushLocalPodcastAppPreferencesToCloudKitIfNeeded() async {
        guard hasAnyPodcastAppPreferences() else { return }
        guard !hasPushedPodcastAppPrefsThisSession else { return }
        if hasRestoredPodcastAppPrefsThisSession {
            hasPushedPodcastAppPrefsThisSession = true
            return
        }
        if podcastAppPrefsPushAttemptCount >= maxPodcastAppPrefsPushAttempts {
            return
        }
        podcastAppPrefsPushAttemptCount += 1

        let status = await CloudKitManager.shared.accountStatus()
        guard status == .available else {
            schedulePodcastAppPrefsPushRetry(after: 3.0)
            return
        }

        let preferredAppName = PodcastAppPreferences.preferredAppName() ?? ""
        var lastUpdated = PodcastAppPreferences.lastUpdated()
        if lastUpdated == Date.distantPast {
            lastUpdated = Date()
            PodcastAppPreferences.updateLastUpdated(lastUpdated)
        }

        let payload = CloudKitManager.UserPodcastAppPreferencesPayload(
            preferredAppName: preferredAppName,
            lastUpdated: lastUpdated
        )
        hasPushedPodcastAppPrefsThisSession = true
        await CloudKitManager.shared.saveUserPodcastAppPreferencesPayload(payload)
    }

    private func hasAnyPodcastAppPreferences() -> Bool {
        let preferred = PodcastAppPreferences.preferredAppName() ?? ""
        return preferred.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func applyPodcastAppPreferencesPayload(_ payload: CloudKitManager.UserPodcastAppPreferencesPayload) {
        if !payload.preferredAppName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            PodcastAppPreferences.setPreferredAppName(payload.preferredAppName)
        }
        PodcastAppPreferences.updateLastUpdated(payload.lastUpdated)
    }
    
    /// Cleans all movie titles in the database using TMDB to find official titles
    func cleanAllTitles() async throws {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<MovieData>()
        let allMovies = try modelContext.fetch(descriptor)
        
        var cleanedCount = 0
        for movieData in allMovies {
            // Use TMDB to find the official title
            let officialTitle = await TitleCleaner.shared.cleanTitleWithTMDB(movieData.title)
            if officialTitle != movieData.title {
                movieData.title = officialTitle
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
            try modelContext.save()
        }
        
        loadMovies()
        
        // Also sync cleaned titles to CloudKit
        let isAvailable = await CloudKitManager.shared.isCloudKitAvailable
        if isAvailable {
            for movie in movies {
                try? await CloudKitManager.shared.saveMovie(movie)
            }
        }
    }

    /// Normalizes streaming service names by merging case-only variants.
    /// Prefers mixed-case names (e.g. "HBO Max") when available.
    func normalizeStreamingServicesCase() async {
        guard let modelContext = modelContext else {
            return
        }
        
        let descriptor = FetchDescriptor<MovieData>()
        do {
            let allMovies = try modelContext.fetch(descriptor)
            var updatedCount = 0
            
            for (index, movieData) in allMovies.enumerated() {
                let normalized = normalizeStreamingServices(movieData.streamingServices)
                if normalized != movieData.streamingServices {
                    movieData.streamingServices = normalized
                    updatedCount += 1
                }
                
                if index % 200 == 0 {
                    await Task.yield()
                }
            }
            
            if updatedCount > 0 {
                try modelContext.save()
                // Startup normalization can run right after initial fetch;
                // use a cache refresh to avoid showing the full-screen loading spinner again.
                refreshMovies()
            }
        } catch {
            print("❌ [STREAMING] Failed to normalize streaming services: \(error)")
        }
    }

    private func normalizeStreamingServices(_ services: [StreamingService]) -> [StreamingService] {
        var orderedKeys: [String] = []
        var entries: [String: StreamingService] = [:]
        var hasMixedCaps: [String: Bool] = [:]
        
        for service in services {
            let trimmedName = service.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let key = trimmedName.lowercased()
            
            if entries[key] == nil {
                orderedKeys.append(key)
                entries[key] = StreamingService(
                    id: service.id,
                    name: trimmedName,
                    logoPath: service.logoPath,
                    url: service.url
                )
                hasMixedCaps[key] = isMixedCaps(trimmedName)
                continue
            }
            
            var current = entries[key]!
            let currentMixed = hasMixedCaps[key] ?? false
            let candidateMixed = isMixedCaps(trimmedName)
            
            if !currentMixed && candidateMixed {
                let resolvedId = current.id.isEmpty ? service.id : current.id
                current = StreamingService(
                    id: resolvedId,
                    name: trimmedName,
                    logoPath: current.logoPath ?? service.logoPath,
                    url: current.url ?? service.url
                )
                hasMixedCaps[key] = true
            } else {
                current = StreamingService(
                    id: current.id,
                    name: current.name,
                    logoPath: current.logoPath ?? service.logoPath,
                    url: current.url ?? service.url
                )
            }
            
            entries[key] = current
        }
        
        return orderedKeys.compactMap { entries[$0] }
    }
    
    private func isMixedCaps(_ value: String) -> Bool {
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let hasUpper = letters.contains { CharacterSet.uppercaseLetters.contains($0) }
        let hasLower = letters.contains { CharacterSet.lowercaseLetters.contains($0) }
        return hasUpper && hasLower
    }
    
    func saveMovie(_ movie: Movie, reload: Bool = true) throws {
        guard let modelContext = modelContext else {
            throw NSError(domain: "LocalDatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not set"])
        }
        
        // Get or create data source
        let rewatchablesDataSource = try getOrCreateDataSource(
            modelContext: modelContext,
            identifier: "rewatchables",
            name: "The Rewatchables",
            type: "podcast"
        )
        
        // Check for existing movie by ID
        let descriptor = FetchDescriptor<MovieData>(
            predicate: #Predicate<MovieData> { $0.id == movie.id }
        )
        
        let movieData: MovieData
        if let existing = try? modelContext.fetch(descriptor).first {
            // Update existing movie data
            movieData = existing
            // Clean title before saving to ensure consistency
            let cleanedTitle = TitleCleaner.shared.cleanTitle(movie.title)
            movieData.title = cleanedTitle
            movieData.year = movie.year
            movieData.tmdbId = movie.tmdbId
            movieData.posterPath = movie.posterPath
            movieData.backdropPath = movie.backdropPath
            movieData.overview = movie.overview
            movieData.mpaaRating = movie.mpaaRating
            movieData.genres = movie.genres
            movieData.streamingServices = movie.streamingServices
            movieData.credits = movie.credits
            movieData.trailer = movie.trailer
            movieData.lastUpdated = movie.lastUpdated
        } else {
            // Create new movie data
            movieData = MovieData.fromMovie(movie)
            modelContext.insert(movieData)
        }
        
        // Update or create user movie data (new schema)
        let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
        userData.isRewatched = movie.isRewatched
        userData.isListened = movie.isListened
        userData.isSaved = movie.isSaved
        userData.lastUpdated = movie.lastUpdated
        
        // Also update old MovieState for backward compatibility during migration
        if let existingState = movieData.states?.first {
            existingState.isRewatched = movie.isRewatched
            existingState.isListened = movie.isListened
            existingState.isSaved = movie.isSaved
            existingState.lastUpdated = movie.lastUpdated
        }
        
        // Update or create source content (new schema) or movie data source (old schema)
        if let podcastEpisode = movie.podcastEpisode {
            // Try new schema first
            let existingSourceContent = movieData.sourceContents?.first(where: { $0.source?.identifier == "rewatchables" })
            if let sourceContent = existingSourceContent {
                sourceContent.podcastEpisode = podcastEpisode
                sourceContent.rewatchablesDiscussion = movie.rewatchablesDiscussion
                sourceContent.lastUpdated = movie.lastUpdated
            } else {
                // Create new SourceContent
                let sourceContent = SourceContent(
                    movie: movieData,
                    source: rewatchablesDataSource,
                    sourceTitle: podcastEpisode.title,
                    sourceDescription: podcastEpisode.description,
                    sourceDate: podcastEpisode.publishDate,
                    rank: nil,
                    podcastEpisode: podcastEpisode,
                    rewatchablesDiscussion: movie.rewatchablesDiscussion,
                    sourceUrl: nil,
                    applePodcastsUrl: podcastEpisode.applePodcastsUrl,
                    spotifyUrl: podcastEpisode.spotifyUrl,
                    lastUpdated: movie.lastUpdated,
                    discoveredAt: movie.lastUpdated
                )
                modelContext.insert(sourceContent)
            }
            
            // Also update old MovieDataSource for backward compatibility
            let existingDataSource = movieData.dataSources?.first(where: { $0.dataSource?.identifier == "rewatchables" })
            if let movieDataSource = existingDataSource {
                movieDataSource.podcastEpisode = podcastEpisode
                movieDataSource.rewatchablesDiscussion = movie.rewatchablesDiscussion
                movieDataSource.lastUpdated = movie.lastUpdated
            } else {
                let movieDataSource = MovieDataSource(
                    movie: movieData,
                    dataSource: rewatchablesDataSource,
                    podcastEpisode: podcastEpisode,
                    rewatchablesDiscussion: movie.rewatchablesDiscussion,
                    lastUpdated: movie.lastUpdated
                )
                modelContext.insert(movieDataSource)
            }
        }
        
        try modelContext.save()
        if reload {
            loadMovies()
        } else {
            updateMovieInCache(movie.id)
        }

        // Sync user data separately to CloudKit (if enabled)
        syncUserMovieDataToCloudKit(movieId: movie.id, userData: userData)
    }
    
    public func queueRewatchedStatusUpdate(_ movie: Movie, isRewatched: Bool) {
        // Update UI immediately with optimistic update (before database operation)
        optimisticallyUpdateMovieStatus(movie.id, isRewatched: isRewatched)
        
        Task { @MainActor in
            persistRewatchedStatus(movie, isRewatched: isRewatched)
        }
    }
    
    public func updateRewatchedStatus(_ movie: Movie, isRewatched: Bool) throws {
        // Update UI immediately with optimistic update (before database operation)
        optimisticallyUpdateMovieStatus(movie.id, isRewatched: isRewatched)
        persistRewatchedStatus(movie, isRewatched: isRewatched)
    }
    
    private func persistRewatchedStatus(_ movie: Movie, isRewatched: Bool) {
        guard let modelContext = modelContext else {
            return // Silently fail if context not set
        }
        
        let descriptor = FetchDescriptor<MovieData>(
            predicate: #Predicate<MovieData> { $0.id == movie.id }
        )
        
        if let movieData = try? modelContext.fetch(descriptor).first {
            // Get or create user movie data (new schema)
            let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
            userData.isRewatched = isRewatched
            userData.lastUpdated = Date()
            
            // Also update old MovieState for backward compatibility
            if let existingState = movieData.states?.first {
                existingState.isRewatched = isRewatched
                existingState.lastUpdated = Date()
            }
            
            try? modelContext.save()
            
            // Update local cache immediately
            updateMovieInCache(movie.id)
            
            // Sync user data separately to CloudKit (if enabled)
            syncUserMovieDataToCloudKit(movieId: movie.id, userData: userData)
            MinCloudLibrarySync.shared.pushMovie(
                movieId: movie.id,
                isSaved: userData.isSaved,
                isRewatched: userData.isRewatched,
                isListened: userData.isListened,
                isWatched: userData.isWatched
            )
        }
    }
    
    public func queueListenedStatusUpdate(_ movie: Movie, isListened: Bool) {
        // Update UI immediately with optimistic update (before database operation)
        optimisticallyUpdateMovieStatus(movie.id, isListened: isListened)
        
        Task { @MainActor in
            persistListenedStatus(movie, isListened: isListened)
        }
    }
    
    public func updateListenedStatus(_ movie: Movie, isListened: Bool) throws {
        // Update UI immediately with optimistic update (before database operation)
        optimisticallyUpdateMovieStatus(movie.id, isListened: isListened)
        persistListenedStatus(movie, isListened: isListened)
    }
    
    private func persistListenedStatus(_ movie: Movie, isListened: Bool) {
        guard let modelContext = modelContext else {
            return // Silently fail if context not set
        }
        
        let descriptor = FetchDescriptor<MovieData>(
            predicate: #Predicate<MovieData> { $0.id == movie.id }
        )
        
        if let movieData = try? modelContext.fetch(descriptor).first {
            // Get or create user movie data (new schema)
            let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
            userData.isListened = isListened
            userData.lastUpdated = Date()
            
            // Also update old MovieState for backward compatibility
            if let existingState = movieData.states?.first {
                existingState.isListened = isListened
                existingState.lastUpdated = Date()
            }
            
            try? modelContext.save()
            
            // Update local cache immediately
            updateMovieInCache(movie.id)
            
            // Sync user data separately to CloudKit (if enabled)
            syncUserMovieDataToCloudKit(movieId: movie.id, userData: userData)
            MinCloudLibrarySync.shared.pushMovie(
                movieId: movie.id,
                isSaved: userData.isSaved,
                isRewatched: userData.isRewatched,
                isListened: userData.isListened,
                isWatched: userData.isWatched
            )
        }
    }
    
    public func queueSavedStatusUpdate(_ movie: Movie, isSaved: Bool) {
        // Update UI immediately with optimistic update (before database operation)
        optimisticallyUpdateMovieStatus(movie.id, isSaved: isSaved)
        
        Task { @MainActor in
            persistSavedStatus(movie, isSaved: isSaved)
        }
    }
    
    public func updateSavedStatus(_ movie: Movie, isSaved: Bool) throws {
        // Update UI immediately with optimistic update (before database operation)
        optimisticallyUpdateMovieStatus(movie.id, isSaved: isSaved)
        persistSavedStatus(movie, isSaved: isSaved)
    }
    
    private func persistSavedStatus(_ movie: Movie, isSaved: Bool) {
        guard let modelContext = modelContext else {
            return // Silently fail if context not set
        }
        
        let descriptor = FetchDescriptor<MovieData>(
            predicate: #Predicate<MovieData> { $0.id == movie.id }
        )
        
        if let movieData = try? modelContext.fetch(descriptor).first {
            // Get or create user movie data (new schema)
            let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
            userData.isSaved = isSaved
            userData.lastUpdated = Date()
            
            // Also update old MovieState for backward compatibility
            if let existingState = movieData.states?.first {
                existingState.isSaved = isSaved
                existingState.lastUpdated = Date()
            }
            
            try? modelContext.save()
            
            // Update local cache immediately
            updateMovieInCache(movie.id)
            
            // Sync user data separately to CloudKit (if enabled)
            syncUserMovieDataToCloudKit(movieId: movie.id, userData: userData)
            MinCloudLibrarySync.shared.pushMovie(
                movieId: movie.id,
                isSaved: userData.isSaved,
                isRewatched: userData.isRewatched,
                isListened: userData.isListened,
                isWatched: userData.isWatched
            )
        }
    }

    func applyMinCloudLibrary(_ items: [MinCloudMovLibraryItem]) {
        guard let modelContext else { return }
        for item in items {
            let movieId = item.movieId
            let descriptor = FetchDescriptor<MovieData>(
                predicate: #Predicate<MovieData> { $0.id == movieId }
            )
            guard let movieData = try? modelContext.fetch(descriptor).first else { continue }
            let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
            userData.isSaved = userData.isSaved || (item.isSaved ?? false)
            userData.isRewatched = userData.isRewatched || (item.isRewatched ?? false)
            userData.isListened = userData.isListened || (item.isListened ?? false)
            userData.isWatched = userData.isWatched || (item.isWatched ?? false)
            if let rating = item.rating { userData.userRating = rating }
            if let notes = item.notes { userData.userNotes = notes }
            userData.lastUpdated = Date()
            updateMovieInCache(movieId)
        }
        try? modelContext.save()
        refreshMovies()
    }

    func minCloudLibraryPayload() -> [[String: Any]] {
        guard let modelContext else { return [] }
        let rows = (try? modelContext.fetch(FetchDescriptor<UserMovieData>())) ?? []
        return rows.compactMap { userData -> [String: Any]? in
            guard let movieId = userData.movie?.id else { return nil }
            guard userData.isSaved || userData.isRewatched || userData.isListened || userData.isWatched else {
                return nil
            }
            var item: [String: Any] = [
                "movieId": movieId,
                "isSaved": userData.isSaved,
                "isRewatched": userData.isRewatched,
                "isListened": userData.isListened,
                "isWatched": userData.isWatched
            ]
            if let rating = userData.userRating { item["rating"] = rating }
            if let notes = userData.userNotes { item["notes"] = notes }
            return item
        }
    }
    
    func saveMovies(_ movies: [Movie]) throws {
        guard let modelContext = modelContext else {
            throw NSError(domain: "LocalDatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not set"])
        }
        
        // Load all existing movies for matching
        let allMoviesDescriptor = FetchDescriptor<MovieData>()
        let allExistingMovies = (try? modelContext.fetch(allMoviesDescriptor)) ?? []
        
        for movie in movies {
            var existing: MovieData?
            
            // Try to find by ID first (most direct)
            if !movie.id.isEmpty {
                existing = allExistingMovies.first(where: { $0.id == movie.id })
            }
            
            // If not found by ID, try by TMDB ID (most reliable)
            if existing == nil, let tmdbId = movie.tmdbId {
                existing = allExistingMovies.first(where: { $0.tmdbId == tmdbId })
            }
            
            // If still not found, try by episode ID
            if existing == nil, let episodeId = movie.podcastEpisode?.episodeId {
                // Fetch all MovieDataSource items and filter in memory since podcastEpisode is computed
                let allDataSources = try? modelContext.fetch(FetchDescriptor<MovieDataSource>())
                if let movieDataSource = allDataSources?.first(where: { $0.podcastEpisode?.episodeId == episodeId }) {
                    existing = movieDataSource.movie
                }
            }
            
            let movieData: MovieData
            if let existingData = existing {
            // Update existing - preserve watched/listened states and user data
            movieData = existingData
            movieData.id = movie.id // Update ID if it changed (e.g., from UUID to deterministic)
            // Clean title before saving to ensure consistency
            let cleanedTitle = TitleCleaner.shared.cleanTitle(movie.title)
            movieData.title = cleanedTitle
                movieData.year = movie.year ?? movieData.year
                movieData.tmdbId = movie.tmdbId ?? movieData.tmdbId
                movieData.posterPath = movie.posterPath ?? movieData.posterPath
                movieData.backdropPath = movie.backdropPath ?? movieData.backdropPath
                movieData.overview = movie.overview ?? movieData.overview
                movieData.mpaaRating = movie.mpaaRating ?? movieData.mpaaRating
                movieData.genres = movie.genres.isEmpty ? movieData.genres : movie.genres
                movieData.streamingServices = movie.streamingServices.isEmpty ? movieData.streamingServices : movie.streamingServices
                movieData.credits = movie.credits ?? movieData.credits
                movieData.trailer = movie.trailer ?? movieData.trailer
                movieData.lastUpdated = movie.lastUpdated
            } else {
                // Create new
                movieData = MovieData.fromMovie(movie)
                modelContext.insert(movieData)
            }
            
            // Update or create user movie data (preserve existing states)
            let userData = getOrCreateUserMovieData(for: movieData, modelContext: modelContext)
            // Only update if movie has explicit states
            if movie.isRewatched || movie.isListened || movie.isSaved {
                userData.isRewatched = movie.isRewatched
                userData.isListened = movie.isListened
                userData.isSaved = movie.isSaved
                userData.lastUpdated = movie.lastUpdated
            }
            
            // Also update old MovieState for backward compatibility
            if let existingState = movieData.states?.first {
                if movie.isRewatched || movie.isListened || movie.isSaved {
                    existingState.isRewatched = movie.isRewatched
                    existingState.isListened = movie.isListened
                    existingState.isSaved = movie.isSaved
                    existingState.lastUpdated = movie.lastUpdated
                }
            }
            
            // Note: MovieDataSource linking is handled by source linking logic
            // This ensures each source has its own MovieDataSource entry with correct podcast data
        }
        
        try modelContext.save()
        
        // Deduplicate any remaining duplicates
        try deduplicateMovies()
        
        loadMovies()
    }
    
    /// Gets or creates a data source
    private func getOrCreateDataSource(
        modelContext: ModelContext,
        identifier: String,
        name: String,
        type: String
    ) throws -> DataSource {
        let descriptor = FetchDescriptor<DataSource>(
            predicate: #Predicate<DataSource> { $0.identifier == identifier }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }
        
        let dataSource = DataSource(
            identifier: identifier,
            name: name,
            type: type
        )
        modelContext.insert(dataSource)
        try modelContext.save()
        
        return dataSource
    }
    
    /// Deduplicates movies by removing duplicates based on TMDB ID or episode ID
    /// Retains the entry with the most data and preserves all associations
    private func deduplicateMovies() throws {
        guard let modelContext = modelContext else {
            return
        }
        
        let descriptor = FetchDescriptor<MovieData>()
        let allMovies = try modelContext.fetch(descriptor)
        
        // Group by TMDB ID (most reliable)
        var seenByTmdbId: [Int: [MovieData]] = [:]
        var duplicates: [MovieData] = []
        
        // First, group all movies by TMDB ID
        for movie in allMovies {
            if let tmdbId = movie.tmdbId {
                if seenByTmdbId[tmdbId] == nil {
                    seenByTmdbId[tmdbId] = []
                }
                seenByTmdbId[tmdbId]?.append(movie)
            }
        }
        
        // For each TMDB ID group with multiple entries, find the one with most data and merge others into it
        for (_, movies) in seenByTmdbId where movies.count > 1 {
            // Find the movie with the most complete data
            let bestMovie = movies.max(by: { calculateDataCompleteness(movieData: $0) < calculateDataCompleteness(movieData: $1) })!
            
            // Merge all other movies into the best one
            for movie in movies where movie.id != bestMovie.id {
                mergeMovieDataWithAllAssociations(target: bestMovie, source: movie, modelContext: modelContext)
                duplicates.append(movie)
            }
        }
        
        // Group remaining by episode ID (for movies without TMDB ID)
        var seenByEpisodeId: [String: [MovieData]] = [:]
        for movie in allMovies where movie.tmdbId == nil && !duplicates.contains(where: { $0.id == movie.id }) {
            // Use relationship directly instead of predicate
            if let movieDataSource = movie.dataSources?.first,
               let episodeId = movieDataSource.podcastEpisode?.episodeId {
                if seenByEpisodeId[episodeId] == nil {
                    seenByEpisodeId[episodeId] = []
                }
                seenByEpisodeId[episodeId]?.append(movie)
            }
        }
        
        // For each episode ID group with multiple entries, find the one with most data and merge others
        for (episodeId, movies) in seenByEpisodeId where movies.count > 1 {
            // Find the movie with the most complete data
            let bestMovie = movies.max(by: { calculateDataCompleteness(movieData: $0) < calculateDataCompleteness(movieData: $1) })!
            
            // Merge all other movies into the best one
            for movie in movies where movie.id != bestMovie.id {
                mergeMovieDataWithAllAssociations(target: bestMovie, source: movie, modelContext: modelContext)
                duplicates.append(movie)
            }
        }
        
        // Delete duplicates
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
        
        if !duplicates.isEmpty {
            try modelContext.save()
            loadMovies() // Reload to reflect changes
        }
    }
    
    /// Calculates data completeness score for a movie
    private func calculateDataCompleteness(movieData: MovieData) -> Int {
        var score = 0
        if movieData.posterPath != nil { score += 1 }
        if movieData.backdropPath != nil { score += 1 }
        if movieData.overview != nil && !(movieData.overview?.isEmpty ?? true) { score += 1 }
        if movieData.mpaaRating != nil { score += 1 }
        if !movieData.genres.isEmpty { score += 1 }
        if !movieData.streamingServices.isEmpty { score += 1 }
        if movieData.credits != nil { score += 1 }
        if movieData.trailer != nil { score += 1 }
        // Add points for each data source association
        if let dataSources = movieData.dataSources, !dataSources.isEmpty {
            score += dataSources.count * 2 // Weight associations higher
        }
        // Add points for user states
        if let userData = movieData.userData {
            if userData.isRewatched { score += 1 }
            if userData.isListened { score += 1 }
            if userData.isSaved { score += 1 }
        } else if let state = movieData.states?.first {
            if state.isRewatched { score += 1 }
            if state.isListened { score += 1 }
            if state.isSaved { score += 1 }
        }
        return score
    }
    
    /// Merges data from source movie into target, preserving user data and ALL associations
    /// This version merges ALL data sources, not just the first one
    private func mergeMovieDataWithAllAssociations(target: MovieData, source: MovieData, modelContext: ModelContext) {
        // Merge basic movie data fields - keep the best from both
        if target.posterPath == nil && source.posterPath != nil {
            target.posterPath = source.posterPath
        }
        if target.backdropPath == nil && source.backdropPath != nil {
            target.backdropPath = source.backdropPath
        }
        if (target.overview == nil || target.overview?.isEmpty == true) && 
           source.overview != nil && !(source.overview?.isEmpty ?? true) {
            target.overview = source.overview
        }
        if target.mpaaRating == nil && source.mpaaRating != nil {
            target.mpaaRating = source.mpaaRating
        }
        if target.genres.isEmpty && !source.genres.isEmpty {
            target.genres = source.genres
        }
        if target.streamingServices.isEmpty && !source.streamingServices.isEmpty {
            target.streamingServices = source.streamingServices
        }
        if target.credits == nil && source.credits != nil {
            target.credits = source.credits
        }
        if target.trailer == nil && source.trailer != nil {
            target.trailer = source.trailer
        }
        if target.oscarAwards == nil && source.oscarAwards != nil {
            target.oscarAwards = source.oscarAwards
        }
        if let sourceMedia = source.physicalMedia {
            if let existing = target.physicalMedia {
                target.physicalMedia = existing.merging(inferred: sourceMedia)
            } else {
                target.physicalMedia = sourceMedia
            }
        }
        
        // Merge user data (new schema) and fallback MovieState
        if let targetUserData = target.userData {
            if let sourceUserData = source.userData {
                targetUserData.isRewatched = targetUserData.isRewatched || sourceUserData.isRewatched
                targetUserData.isListened = targetUserData.isListened || sourceUserData.isListened
                targetUserData.isSaved = targetUserData.isSaved || sourceUserData.isSaved
                targetUserData.isWatched = targetUserData.isWatched || sourceUserData.isWatched
                if targetUserData.userRating == nil {
                    targetUserData.userRating = sourceUserData.userRating
                }
                if targetUserData.userNotes == nil || targetUserData.userNotes?.isEmpty == true {
                    targetUserData.userNotes = sourceUserData.userNotes
                }
                if targetUserData.watchedDate == nil { targetUserData.watchedDate = sourceUserData.watchedDate }
                if targetUserData.rewatchedDate == nil { targetUserData.rewatchedDate = sourceUserData.rewatchedDate }
                if targetUserData.listenedDate == nil { targetUserData.listenedDate = sourceUserData.listenedDate }
                let mergedTags = Set(targetUserData.tags).union(Set(sourceUserData.tags))
                targetUserData.tags = Array(mergedTags)
                if sourceUserData.lastUpdated > targetUserData.lastUpdated {
                    targetUserData.lastUpdated = sourceUserData.lastUpdated
                }
            } else if let sourceState = source.states?.first {
                targetUserData.isRewatched = targetUserData.isRewatched || sourceState.isRewatched
                targetUserData.isListened = targetUserData.isListened || sourceState.isListened
                targetUserData.isSaved = targetUserData.isSaved || sourceState.isSaved
                if sourceState.lastUpdated > targetUserData.lastUpdated {
                    targetUserData.lastUpdated = sourceState.lastUpdated
                }
            }
        } else if let sourceUserData = source.userData {
            sourceUserData.movie = target
            target.userData = sourceUserData
        } else if let sourceState = source.states?.first {
            let newState = MovieState(
                isRewatched: sourceState.isRewatched,
                isListened: sourceState.isListened,
                isSaved: sourceState.isSaved,
                lastUpdated: sourceState.lastUpdated,
                movie: target
            )
            modelContext.insert(newState)
        }
        
        // Merge ALL data sources - move all associations from source to target
        if let sourcesToMerge = source.dataSources {
            for sourceDataSource in sourcesToMerge {
                // Check if this source already exists in target (by data source identifier)
                let sourceExists = target.dataSources?.contains(where: { 
                    $0.dataSource?.identifier == sourceDataSource.dataSource?.identifier 
                }) ?? false
                
                if !sourceExists {
                    // Move the association to target
                    sourceDataSource.movie = target
                } else {
                    // Source already exists - merge the data if target is missing it
                    if let existingSource = target.dataSources?.first(where: { 
                        $0.dataSource?.identifier == sourceDataSource.dataSource?.identifier 
                    }) {
                        // Keep the one with more data
                        if existingSource.podcastEpisode == nil && sourceDataSource.podcastEpisode != nil {
                            existingSource.podcastEpisode = sourceDataSource.podcastEpisode
                        }
                        if existingSource.rewatchablesDiscussion == nil && sourceDataSource.rewatchablesDiscussion != nil {
                            existingSource.rewatchablesDiscussion = sourceDataSource.rewatchablesDiscussion
                        }
                        if sourceDataSource.lastUpdated > existingSource.lastUpdated {
                            existingSource.lastUpdated = sourceDataSource.lastUpdated
                        }
                    }
                }
            }
        }
        
        // Use most recent lastUpdated for the movie itself
        if source.lastUpdated > target.lastUpdated {
            target.lastUpdated = source.lastUpdated
        }
    }
    
    /// Legacy merge function - kept for backwards compatibility but uses the new merge logic
    private func mergeMovieData(target: MovieData, source: MovieData, modelContext: ModelContext) {
        mergeMovieDataWithAllAssociations(target: target, source: source, modelContext: modelContext)
    }
    
    /// Cleanup method to remove duplicates - can be called manually
    func cleanupDuplicates() async throws {
        try deduplicateMovies()
        loadMovies()
    }
    
    func movieCount() -> Int {
        guard let modelContext = modelContext else { return 0 }
        
        let descriptor = FetchDescriptor<MovieData>()
        return (try? modelContext.fetch(descriptor).count) ?? 0
    }
    
    /// Resets the database by deleting all movies and related data
    func resetDatabase() async throws {
        guard let modelContext = modelContext else {
            throw NSError(domain: "LocalDatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext not set"])
        }
        
        // Delete all movie data (cascade will handle states and data sources)
        let movieDescriptor = FetchDescriptor<MovieData>()
        let allMovies = try modelContext.fetch(movieDescriptor)
        
        for movie in allMovies {
            modelContext.delete(movie)
        }
        
        // Also delete any orphaned states or data sources (shouldn't happen with cascade, but just in case)
        let stateDescriptor = FetchDescriptor<MovieState>()
        let allStates = try modelContext.fetch(stateDescriptor)
        for state in allStates where state.movie == nil {
            modelContext.delete(state)
        }
        
        let dataSourceDescriptor = FetchDescriptor<MovieDataSource>()
        let allDataSources = try modelContext.fetch(dataSourceDescriptor)
        for dataSource in allDataSources where dataSource.movie == nil {
            modelContext.delete(dataSource)
        }
        
        try modelContext.save()
        loadMovies()
    }
    
    /// Replaces the existing database with the bootstrap database
    /// This replaces the user database with the bootstrap database file directly
    /// This is faster and more reliable than importing from JSON
    public func rebaseOnBootstrapDatabase(modelContext: ModelContext) async throws {
        guard !catalogNeedsRestartDueToCorruption else { return }
        if shouldPreserveUserData(modelContext: modelContext) {
            try await mergeBootstrapCatalogFromBundledStore(modelContext: modelContext)
            reconcilePendingPodcastEpisodesWithCatalog()
            return
        }
        
        // Get the bootstrap database from bundle
        guard let bootstrapDBURL = Bundle.main.url(forResource: "bootstrap_database", withExtension: "store") else {
            return
        }
        
        // Get the current store URL
        let storeURL = AppDataBootstrapper.persistentStoreURL()
        
        // Save any pending changes
        try? modelContext.save()
        
        // Delete existing database files
        if FileManager.default.fileExists(atPath: storeURL.path) {
            try FileManager.default.removeItem(at: storeURL)
        }
        let walURL = storeURL.appendingPathExtension("wal")
        let shmURL = storeURL.appendingPathExtension("shm")
        try? FileManager.default.removeItem(at: walURL)
        try? FileManager.default.removeItem(at: shmURL)
        
        // Copy bootstrap database
        try FileManager.default.copyItem(at: bootstrapDBURL, to: storeURL)
        // Also copy WAL/SHM if present in bundle to avoid corruption on open
        let bootstrapWalURL = bootstrapSidecarURL(for: bootstrapDBURL, suffix: "wal")
        let bootstrapShmURL = bootstrapSidecarURL(for: bootstrapDBURL, suffix: "shm")
        if let bootstrapWalURL {
            try? FileManager.default.copyItem(at: bootstrapWalURL, to: walURL)
        }
        if let bootstrapShmURL {
            try? FileManager.default.copyItem(at: bootstrapShmURL, to: shmURL)
        }
        _ = BootstrapDataService.shared.recordBootstrapImportDate()
        
        // Update in-memory list without full-screen spinner. If the store was replaced
        // while the container was open, the context may be stale; user may need to restart.
        refreshMovies()
    }
    
    /// Fallback method: Import from JSON (slower, but works if bootstrap database not available)
    private func rebaseOnBootstrapDatabaseFromJSON(modelContext: ModelContext) async throws {
        return
    }

    /// Returns true when user data or local lists exist and must be preserved
    private func shouldPreserveUserData(modelContext: ModelContext) -> Bool {
        let userDataCount = (try? modelContext.fetch(FetchDescriptor<UserMovieData>()).count) ?? 0
        let legacyStateCount = (try? modelContext.fetch(FetchDescriptor<MovieState>()).count) ?? 0
        let localListCount = (try? modelContext.fetch(FetchDescriptor<DataSource>()).filter { $0.isLocalList }.count) ?? 0
        return userDataCount > 0 || legacyStateCount > 0 || localListCount > 0
    }

    /// Merges catalog data from the bundled bootstrap store while preserving user data and lists
    private func mergeBootstrapCatalogFromBundledStore(modelContext: ModelContext) async throws {
        guard let bootstrapDBURL = Bundle.main.url(forResource: "bootstrap_database", withExtension: "store") else {
            return
        }

        print("📦 [BOOTSTRAP] Starting catalog merge from bundle store.")
        let tempStoreURL = try makeBootstrapStoreCopy(from: bootstrapDBURL)
        defer {
            let tempFolderURL = tempStoreURL.deletingLastPathComponent()
            try? FileManager.default.removeItem(at: tempFolderURL)
        }

        let schema = Schema([MovieData.self, DataSource.self, MovieDataSource.self, SourceContent.self, UserMovieData.self])
        let bootstrapConfig = ModelConfiguration(
            schema: schema,
            url: tempStoreURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let bootstrapContainer = try ModelContainer(for: schema, configurations: [bootstrapConfig])
        let bootstrapContext = bootstrapContainer.mainContext

        let bootstrapSources = (try? bootstrapContext.fetch(FetchDescriptor<DataSource>())) ?? []
        let bootstrapMovies = (try? bootstrapContext.fetch(FetchDescriptor<MovieData>())) ?? []
        let bootstrapContents = (try? bootstrapContext.fetch(FetchDescriptor<SourceContent>())) ?? []
        var bootstrapMovieById: [String: MovieData] = [:]
        var bootstrapMovieByTmdbId: [Int: MovieData] = [:]
        var bootstrapMovieByImdbId: [String: MovieData] = [:]
        var bootstrapMovieByTitleYear: [String: MovieData] = [:]
        for movie in bootstrapMovies {
            bootstrapMovieById[movie.id] = movie
            if let tmdbId = movie.tmdbId {
                bootstrapMovieByTmdbId[tmdbId] = movie
            }
            if let imdbId = movie.imdbId?.trimmingCharacters(in: .whitespacesAndNewlines), !imdbId.isEmpty {
                bootstrapMovieByImdbId[imdbId] = movie
            }
            if let key = normalizedTitleYearKey(title: movie.title, year: movie.year) {
                bootstrapMovieByTitleYear[key] = movie
            }
        }

        let currentSources = (try? modelContext.fetch(FetchDescriptor<DataSource>())) ?? []
        var sourceById: [String: DataSource] = [:]
        for source in currentSources {
            sourceById[source.identifier] = source
        }

        let currentMovies = (try? modelContext.fetch(FetchDescriptor<MovieData>())) ?? []
        var movieById: [String: MovieData] = [:]
        var movieByTmdbId: [Int: MovieData] = [:]
        var movieByImdbId: [String: MovieData] = [:]
        var movieByTitleYear: [String: MovieData] = [:]
        var moviesByTitleKey: [String: [MovieData]] = [:]
        var moviesByTmdbId: [Int: [MovieData]] = [:]
        var moviesByImdbId: [String: [MovieData]] = [:]
        var moviesByTitleYearKey: [String: [MovieData]] = [:]
        for movie in currentMovies {
            movieById[movie.id] = movie
            if let tmdbId = movie.tmdbId {
                moviesByTmdbId[tmdbId, default: []].append(movie)
                if let existing = movieByTmdbId[tmdbId] {
                    let currentScore = calculateDataCompleteness(movieData: movie)
                    let existingScore = calculateDataCompleteness(movieData: existing)
                    if currentScore > existingScore {
                        movieByTmdbId[tmdbId] = movie
                    }
                } else {
                    movieByTmdbId[tmdbId] = movie
                }
            }
            if let imdbId = movie.imdbId?.trimmingCharacters(in: .whitespacesAndNewlines), !imdbId.isEmpty {
                moviesByImdbId[imdbId, default: []].append(movie)
                if let existing = movieByImdbId[imdbId] {
                    let currentScore = calculateDataCompleteness(movieData: movie)
                    let existingScore = calculateDataCompleteness(movieData: existing)
                    if currentScore > existingScore {
                        movieByImdbId[imdbId] = movie
                    }
                } else {
                    movieByImdbId[imdbId] = movie
                }
            }
            if let key = normalizedTitleYearKey(title: movie.title, year: movie.year) {
                moviesByTitleYearKey[key, default: []].append(movie)
                if let existing = movieByTitleYear[key] {
                    let currentScore = calculateDataCompleteness(movieData: movie)
                    let existingScore = calculateDataCompleteness(movieData: existing)
                    if currentScore > existingScore {
                        movieByTitleYear[key] = movie
                    }
                } else {
                    movieByTitleYear[key] = movie
                }
            }
            if let titleKey = normalizedTitleKey(title: movie.title) {
                moviesByTitleKey[titleKey, default: []].append(movie)
            }
        }

        let currentContents = (try? modelContext.fetch(FetchDescriptor<SourceContent>())) ?? []
        var contentByKey: [String: SourceContent] = [:]
        var contentsByMovieId: [String: [SourceContent]] = [:]
        var localMovieSourceIds: [String: Set<String>] = [:]
        var localMovieLocalListIds: [String: Set<String>] = [:]
        for content in currentContents {
            if let movieId = content.movie?.id, let sourceId = content.source?.identifier {
                contentByKey["\(movieId)|\(sourceId)"] = content
                contentsByMovieId[movieId, default: []].append(content)
                if let source = sourceById[sourceId], source.isLocalList {
                    localMovieLocalListIds[movieId, default: []].insert(sourceId)
                } else {
                    localMovieSourceIds[movieId, default: []].insert(sourceId)
                }
            }
        }

        let currentLinks = (try? modelContext.fetch(FetchDescriptor<MovieDataSource>())) ?? []
        var linkByKey: [String: MovieDataSource] = [:]
        var linksByMovieId: [String: [MovieDataSource]] = [:]
        for link in currentLinks {
            if let movieId = link.movie?.id, let sourceId = link.dataSource?.identifier {
                linkByKey["\(movieId)|\(sourceId)"] = link
                linksByMovieId[movieId, default: []].append(link)
                if let source = sourceById[sourceId], source.isLocalList {
                    localMovieLocalListIds[movieId, default: []].insert(sourceId)
                } else {
                    localMovieSourceIds[movieId, default: []].insert(sourceId)
                }
            }
        }

        var bootstrapMovieSourceIds: [String: Set<String>] = [:]
        for content in bootstrapContents {
            guard let movieId = content.movie?.id,
                  let sourceId = content.source?.identifier else { continue }
            bootstrapMovieSourceIds[movieId, default: []].insert(sourceId)
        }

        // Upsert sources (skip local user lists)
        for bootstrapSource in bootstrapSources where bootstrapSource.type != "local" {
            if let existing = sourceById[bootstrapSource.identifier] {
                if existing.isLocalList { continue }
                existing.name = bootstrapSource.name
                existing.type = bootstrapSource.type
                existing.url = bootstrapSource.url
                existing.isRankedList = bootstrapSource.isRankedList
                existing.lastUpdated = Date()
            } else {
                let newSource = DataSource(
                    identifier: bootstrapSource.identifier,
                    name: bootstrapSource.name,
                    type: bootstrapSource.type,
                    url: bootstrapSource.url,
                    isEnabled: bootstrapSource.isEnabled,
                    lastUpdated: Date(),
                    lastChecked: bootstrapSource.lastChecked,
                    createdAt: bootstrapSource.createdAt,
                    isRankedList: bootstrapSource.isRankedList
                )
                modelContext.insert(newSource)
                sourceById[newSource.identifier] = newSource
            }
        }

        // Upsert movies (preserve user data)
        var matchedLocalMovieIds = Set<String>()
        var localToBootstrapMatch: [String: String] = [:]
        var bootstrapToCurrentMovie: [String: MovieData] = [:]
        var bootstrapMovieIndex = 0
        for bootstrapMovie in bootstrapMovies {
            bootstrapMovieIndex += 1
            let titleYearKey = normalizedTitleYearKey(title: bootstrapMovie.title, year: bootstrapMovie.year)
            let titleKey = normalizedTitleKey(title: bootstrapMovie.title)
            var targets: [MovieData] = []
            var seenIds = Set<String>()
            func addTargets(_ candidates: [MovieData]) {
                for candidate in candidates where seenIds.insert(candidate.id).inserted {
                    targets.append(candidate)
                }
            }

            if let byId = movieById[bootstrapMovie.id] {
                addTargets([byId])
            }
            if let tmdbId = bootstrapMovie.tmdbId, let tmdbCandidates = moviesByTmdbId[tmdbId] {
                addTargets(tmdbCandidates)
            } else if let imdbId = bootstrapMovie.imdbId?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !imdbId.isEmpty,
                      let imdbCandidates = moviesByImdbId[imdbId] {
                addTargets(imdbCandidates)
            } else if let titleYearKey, let titleYearCandidates = moviesByTitleYearKey[titleYearKey] {
                addTargets(titleYearCandidates)
            }

            if targets.isEmpty {
                let sourceIds = bootstrapMovieSourceIds[bootstrapMovie.id]
                if let fuzzyMatch = bestFuzzyTitleMatch(
                    title: bootstrapMovie.title,
                    year: bootstrapMovie.year,
                    sourceIds: sourceIds,
                    candidates: currentMovies,
                    candidateSourceIds: localMovieSourceIds
                ) {
                    addTargets([fuzzyMatch])
                } else if let titleOnlyMatch = bestTitleOnlyMatch(
                    titleKey: titleKey,
                    year: bootstrapMovie.year,
                    candidates: titleKey.flatMap { moviesByTitleKey[$0] }
                ) {
                    addTargets([titleOnlyMatch])
                }
            }

            if !targets.isEmpty {
                if titleYearKey != nil, movieById[bootstrapMovie.id] == nil, bootstrapMovie.tmdbId == nil {
                    print("🔎 [BOOTSTRAP] Matched by title/year for '\(bootstrapMovie.title)'")
                }
                if titleYearKey == nil, titleKey != nil, movieById[bootstrapMovie.id] == nil, bootstrapMovie.tmdbId == nil {
                    print("🔎 [BOOTSTRAP] Matched by title-only for '\(bootstrapMovie.title)'")
                }
                if bootstrapMovie.title.lowercased().contains("10 things i hate about you") {
                    let ids = targets.map(\.id).joined(separator: ", ")
                    let incomingServices = bootstrapMovie.streamingServices.map { $0.name }.joined(separator: ", ")
                    print("🔎 [BOOTSTRAP] 10 Things targets=[\(ids)] incoming=[\(incomingServices)]")
                }
                for target in targets {
                    mergeCatalogFields(target: target, source: bootstrapMovie)
                    matchedLocalMovieIds.insert(target.id)
                    if let existing = localToBootstrapMatch[target.id], existing != bootstrapMovie.id {
                        print("⚠️ [BOOTSTRAP] Conflicting match for \(target.id): \(existing) vs \(bootstrapMovie.id)")
                    } else {
                        localToBootstrapMatch[target.id] = bootstrapMovie.id
                    }
                    if let current = bootstrapToCurrentMovie[bootstrapMovie.id] {
                        let currentScore = calculateDataCompleteness(movieData: current)
                        let newScore = calculateDataCompleteness(movieData: target)
                        if newScore > currentScore {
                            bootstrapToCurrentMovie[bootstrapMovie.id] = target
                        }
                    } else {
                        bootstrapToCurrentMovie[bootstrapMovie.id] = target
                    }
                }
            } else {
                let newMovie = MovieData(
                    id: bootstrapMovie.id,
                    title: bootstrapMovie.title,
                    year: bootstrapMovie.year,
                    tmdbId: bootstrapMovie.tmdbId,
                    imdbId: bootstrapMovie.imdbId,
                    originalTitle: bootstrapMovie.originalTitle,
                    releaseDate: bootstrapMovie.releaseDate,
                    posterPath: bootstrapMovie.posterPath,
                    backdropPath: bootstrapMovie.backdropPath,
                    overview: bootstrapMovie.overview,
                    tagline: bootstrapMovie.tagline,
                    mpaaRating: bootstrapMovie.mpaaRating,
                    runtime: bootstrapMovie.runtime,
                    genres: bootstrapMovie.genres,
                    streamingServices: bootstrapMovie.streamingServices,
                    credits: bootstrapMovie.credits,
                    trailer: bootstrapMovie.trailer,
                    oscarAwards: bootstrapMovie.oscarAwards,
                    physicalMedia: PhysicalMediaCatalog.shared.resolvedMedia(
                        stored: bootstrapMovie.physicalMedia,
                        tmdbId: bootstrapMovie.tmdbId
                    ),
                    keywords: bootstrapMovie.keywords,
                    lastUpdated: Date(),
                    createdAt: bootstrapMovie.createdAt,
                    cloudKitRecordID: bootstrapMovie.cloudKitRecordID
                )
                modelContext.insert(newMovie)
                movieById[newMovie.id] = newMovie
                if let tmdbId = newMovie.tmdbId {
                    moviesByTmdbId[tmdbId, default: []].append(newMovie)
                    movieByTmdbId[tmdbId] = newMovie
                }
                if let imdbId = newMovie.imdbId?.trimmingCharacters(in: .whitespacesAndNewlines), !imdbId.isEmpty {
                    moviesByImdbId[imdbId, default: []].append(newMovie)
                    movieByImdbId[imdbId] = newMovie
                }
                if let key = normalizedTitleYearKey(title: newMovie.title, year: newMovie.year) {
                    moviesByTitleYearKey[key, default: []].append(newMovie)
                    movieByTitleYear[key] = newMovie
                }
                bootstrapToCurrentMovie[bootstrapMovie.id] = newMovie
            }

            if bootstrapMovieIndex % 200 == 0 {
                await Task.yield()
            }
        }

        // Upsert source content links (skip local user lists)
        var bootstrapContentIndex = 0
        for bootstrapContent in bootstrapContents {
            bootstrapContentIndex += 1
            guard let sourceId = bootstrapContent.source?.identifier else { continue }
            guard let source = sourceById[sourceId], !source.isLocalList else { continue }

            let bootstrapMovieId = bootstrapContent.movie?.id
            let bootstrapTmdbId = bootstrapContent.movie?.tmdbId
            let bootstrapImdbId = bootstrapContent.movie?.imdbId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let movie = bootstrapMovieId.flatMap { movieById[$0] }
                ?? (bootstrapTmdbId.flatMap { movieByTmdbId[$0] })
                ?? (bootstrapImdbId.flatMap { movieByImdbId[$0] })
            guard let targetMovie = movie else { continue }

            let key = "\(targetMovie.id)|\(sourceId)"
            if let existing = contentByKey[key] {
                existing.sourceTitle = bootstrapContent.sourceTitle ?? existing.sourceTitle
                existing.sourceDescription = bootstrapContent.sourceDescription ?? existing.sourceDescription
                existing.sourceDate = bootstrapContent.sourceDate ?? existing.sourceDate
                existing.rank = bootstrapContent.rank ?? existing.rank
                existing.podcastEpisode = bootstrapContent.podcastEpisode ?? existing.podcastEpisode
                existing.rewatchablesDiscussion = bootstrapContent.rewatchablesDiscussion ?? existing.rewatchablesDiscussion
                existing.sourceUrl = bootstrapContent.sourceUrl ?? existing.sourceUrl
                existing.applePodcastsUrl = bootstrapContent.applePodcastsUrl ?? existing.applePodcastsUrl
                existing.spotifyUrl = bootstrapContent.spotifyUrl ?? existing.spotifyUrl
                existing.lastUpdated = Date()
            } else {
                let newContent = SourceContent(
                    movie: targetMovie,
                    source: source,
                    sourceTitle: bootstrapContent.sourceTitle,
                    sourceDescription: bootstrapContent.sourceDescription,
                    sourceDate: bootstrapContent.sourceDate,
                    rank: bootstrapContent.rank,
                    podcastEpisode: bootstrapContent.podcastEpisode,
                    rewatchablesDiscussion: bootstrapContent.rewatchablesDiscussion,
                    sourceUrl: bootstrapContent.sourceUrl,
                    applePodcastsUrl: bootstrapContent.applePodcastsUrl,
                    spotifyUrl: bootstrapContent.spotifyUrl,
                    lastUpdated: Date(),
                    discoveredAt: bootstrapContent.discoveredAt
                )
                modelContext.insert(newContent)
                contentByKey[key] = newContent
            }

            if let existingLink = linkByKey[key] {
                existingLink.sourceTitle = bootstrapContent.sourceTitle ?? existingLink.sourceTitle
                existingLink.rank = bootstrapContent.rank ?? existingLink.rank
                existingLink.sourceUrl = bootstrapContent.sourceUrl ?? existingLink.sourceUrl
                existingLink.podcastEpisode = bootstrapContent.podcastEpisode ?? existingLink.podcastEpisode
                existingLink.rewatchablesDiscussion = bootstrapContent.rewatchablesDiscussion ?? existingLink.rewatchablesDiscussion
                existingLink.lastUpdated = Date()
            } else {
                let newLink = MovieDataSource(
                    movie: targetMovie,
                    dataSource: source,
                    podcastEpisode: bootstrapContent.podcastEpisode,
                    rewatchablesDiscussion: bootstrapContent.rewatchablesDiscussion,
                    sourceUrl: bootstrapContent.sourceUrl,
                    sourceTitle: bootstrapContent.sourceTitle,
                    rank: bootstrapContent.rank,
                    lastUpdated: Date()
                )
                modelContext.insert(newLink)
                linkByKey[key] = newLink
            }

            if bootstrapContentIndex % 300 == 0 {
                await Task.yield()
            }
        }

        // Cleanup unmatched local movies
        var cleanupIndex = 0
        for localMovie in currentMovies where !matchedLocalMovieIds.contains(localMovie.id) {
            cleanupIndex += 1
            let localSourceIds = localMovieSourceIds[localMovie.id]
            let localListIds = localMovieLocalListIds[localMovie.id]
            let hasUserData = movieHasUserData(localMovie, localListIds: localListIds)

            if hasUserData {
                if let bootstrapMatch = bestBootstrapMatchForUnmatchedLocal(
                    localMovie: localMovie,
                    bootstrapByTmdbId: bootstrapMovieByTmdbId,
                    bootstrapByImdbId: bootstrapMovieByImdbId,
                    bootstrapByTitleYear: bootstrapMovieByTitleYear,
                    bootstrapMovieSourceIds: bootstrapMovieSourceIds,
                    localMovieSourceIds: localSourceIds,
                    bootstrapMovies: bootstrapMovies
                ),
                   let targetMovie = bootstrapToCurrentMovie[bootstrapMatch.id] ?? movieById[bootstrapMatch.id] {
                    if targetMovie.id != localMovie.id {
                        transferUserDataAndLocalLists(
                            from: localMovie,
                            to: targetMovie,
                            modelContext: modelContext,
                            contentByKey: &contentByKey,
                            linkByKey: &linkByKey,
                            contentsByMovieId: contentsByMovieId,
                            linksByMovieId: linksByMovieId,
                            sourceById: sourceById
                        )
                        modelContext.delete(localMovie)
                    }
                } else {
                    print("⚠️ [BOOTSTRAP] Unmatched local movie with user data kept: \(localMovie.title)")
                }
            } else {
                modelContext.delete(localMovie)
            }

            if cleanupIndex % 200 == 0 {
                await Task.yield()
            }
        }

        try modelContext.save()
        // Update in-memory list without showing full-screen loading (avoids list flicker)
        refreshMovies()

        _ = BootstrapDataService.shared.recordBootstrapAppliedSignature()
    }

    private func normalizedTitleYearKey(title: String, year: Int?) -> String? {
        let cleanedTitle = TitleCleaner.shared.cleanTitle(title).lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty, let year else { return nil }
        return "\(cleanedTitle)|\(year)"
    }

    private func normalizedTitleKey(title: String) -> String? {
        let cleanedTitle = TitleCleaner.shared.cleanTitle(title).lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return nil }
        return cleanedTitle
    }

    private func bestTitleOnlyMatch(
        titleKey: String?,
        year: Int?,
        candidates: [MovieData]?
    ) -> MovieData? {
        guard let titleKey, let candidates, !candidates.isEmpty else { return nil }

        if let year {
            if let exact = candidates.first(where: { $0.year == year }) {
                return exact
            }
            let closest = candidates
                .filter { $0.year != nil }
                .min { abs(($0.year ?? 0) - year) < abs(($1.year ?? 0) - year) }
            if let closest {
                return closest
            }
        }

        return candidates.max(by: { calculateDataCompleteness(movieData: $0) < calculateDataCompleteness(movieData: $1) })
    }

    private func bestFuzzyTitleMatch(
        title: String,
        year: Int?,
        sourceIds: Set<String>?,
        candidates: [MovieData],
        candidateSourceIds: [String: Set<String>]
    ) -> MovieData? {
        let incomingTokens = fuzzyTitleTokens(from: title)
        guard !incomingTokens.isEmpty else { return nil }
        let incomingKey = normalizedTitleKey(title: title) ?? ""
        if incomingKey.isEmpty { return nil }

        var bestCandidate: MovieData? = nil
        var bestScore: Double = 0.0

        for candidate in candidates {
            let candidateKey = normalizedTitleKey(title: candidate.title) ?? ""
            if candidateKey.isEmpty { continue }
            if let sourceIds, !sourceIds.isEmpty {
                let candidateSources = candidateSourceIds[candidate.id] ?? []
                if candidateSources.intersection(sourceIds).isEmpty {
                    continue
                }
            }

            let candidateTokens = fuzzyTitleTokens(from: candidate.title)
            if candidateTokens.isEmpty { continue }

            let intersectionCount = incomingTokens.intersection(candidateTokens).count
            let unionCount = incomingTokens.union(candidateTokens).count
            let tokenScore = unionCount == 0 ? 0.0 : Double(intersectionCount) / Double(unionCount)

            var substringScore = 0.0
            if incomingKey.count >= 4 && candidateKey.count >= 4 {
                if incomingKey.contains(candidateKey) || candidateKey.contains(incomingKey) {
                    substringScore = 0.15
                }
            }

            var yearScore = 0.0
            if let year, let candidateYear = candidate.year {
                if year == candidateYear {
                    yearScore = 0.2
                } else if abs(year - candidateYear) <= 1 {
                    yearScore = 0.1
                }
            }

            let totalScore = tokenScore + substringScore + yearScore
            if totalScore >= 0.55 && totalScore > bestScore {
                bestScore = totalScore
                bestCandidate = candidate
            }
        }

        if let bestCandidate {
            print("🔎 [BOOTSTRAP] Fuzzy match '\(title)' -> '\(bestCandidate.title)' (score=\(bestScore))")
        }
        return bestCandidate
    }

    private func fuzzyTitleTokens(from title: String) -> Set<String> {
        let cleaned = TitleCleaner.shared.cleanTitle(title)
        let normalized = cleaned.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
        let stopwords: Set<String> = ["the", "a", "an", "and", "of", "to", "in", "on", "for", "with"]
        let tokens = normalized
            .split(separator: " ")
            .map { String($0) }
            .filter { $0.count >= 3 && !stopwords.contains($0) }
        return Set(tokens)
    }

    private func bestBootstrapMatchForUnmatchedLocal(
        localMovie: MovieData,
        bootstrapByTmdbId: [Int: MovieData],
        bootstrapByImdbId: [String: MovieData],
        bootstrapByTitleYear: [String: MovieData],
        bootstrapMovieSourceIds: [String: Set<String>],
        localMovieSourceIds: Set<String>?,
        bootstrapMovies: [MovieData]
    ) -> MovieData? {
        if let tmdbId = localMovie.tmdbId, let match = bootstrapByTmdbId[tmdbId] {
            return match
        }
        if let imdbId = localMovie.imdbId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !imdbId.isEmpty,
           let match = bootstrapByImdbId[imdbId] {
            return match
        }
        if let key = normalizedTitleYearKey(title: localMovie.title, year: localMovie.year),
           let match = bootstrapByTitleYear[key] {
            return match
        }
        return bestFuzzyTitleMatch(
            title: localMovie.title,
            year: localMovie.year,
            sourceIds: localMovieSourceIds,
            candidates: bootstrapMovies,
            candidateSourceIds: bootstrapMovieSourceIds
        )
    }

    private func movieHasUserData(_ movie: MovieData, localListIds: Set<String>?) -> Bool {
        if let localListIds, !localListIds.isEmpty {
            return true
        }
        if let userData = movie.userData, !isUserDataEmpty(userData) {
            return true
        }
        if let state = movie.states?.first {
            if state.isRewatched || state.isListened || state.isSaved {
                return true
            }
        }
        return false
    }

    private func transferUserDataAndLocalLists(
        from source: MovieData,
        to target: MovieData,
        modelContext: ModelContext,
        contentByKey: inout [String: SourceContent],
        linkByKey: inout [String: MovieDataSource],
        contentsByMovieId: [String: [SourceContent]],
        linksByMovieId: [String: [MovieDataSource]],
        sourceById: [String: DataSource]
    ) {
        let targetUserData = getOrCreateUserMovieData(for: target, modelContext: modelContext)

        if let sourceUserData = source.userData {
            mergeUserMovieData(target: targetUserData, source: sourceUserData)
            modelContext.delete(sourceUserData)
        } else if let state = source.states?.first {
            targetUserData.isRewatched = targetUserData.isRewatched || state.isRewatched
            targetUserData.isListened = targetUserData.isListened || state.isListened
            targetUserData.isSaved = targetUserData.isSaved || state.isSaved
            targetUserData.lastUpdated = max(targetUserData.lastUpdated, state.lastUpdated)
        }

        let sourceContents = contentsByMovieId[source.id] ?? []
        for content in sourceContents {
            guard let sourceId = content.source?.identifier,
                  let dataSource = sourceById[sourceId],
                  dataSource.isLocalList else { continue }
            let key = "\(target.id)|\(sourceId)"
            if contentByKey[key] != nil {
                modelContext.delete(content)
            } else {
                content.movie = target
                content.lastUpdated = Date()
                contentByKey[key] = content
            }
        }

        let sourceLinks = linksByMovieId[source.id] ?? []
        for link in sourceLinks {
            guard let sourceId = link.dataSource?.identifier,
                  let dataSource = sourceById[sourceId],
                  dataSource.isLocalList else { continue }
            let key = "\(target.id)|\(sourceId)"
            if linkByKey[key] != nil {
                modelContext.delete(link)
            } else {
                link.movie = target
                link.lastUpdated = Date()
                linkByKey[key] = link
            }
        }
    }

    private func mergeUserMovieData(target: UserMovieData, source: UserMovieData) {
        target.isSaved = target.isSaved || source.isSaved
        target.isRewatched = target.isRewatched || source.isRewatched
        target.isListened = target.isListened || source.isListened
        target.isWatched = target.isWatched || source.isWatched

        if target.userRating == nil {
            target.userRating = source.userRating
        }
        if let notes = source.userNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if target.userNotes == nil || target.userNotes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                target.userNotes = notes
            }
        }
        if target.watchedDate == nil { target.watchedDate = source.watchedDate }
        if target.rewatchedDate == nil { target.rewatchedDate = source.rewatchedDate }
        if target.listenedDate == nil { target.listenedDate = source.listenedDate }

        let mergedTags = Set(target.tags).union(source.tags)
        target.tags = Array(mergedTags)

        target.lastUpdated = max(target.lastUpdated, source.lastUpdated)
    }

    /// Merges catalog-only fields, preserving user-specific data
    private func mergeCatalogFields(target: MovieData, source: MovieData) {
        // Never replace identifiers; they anchor user data and CloudKit sync.
        target.title = source.title
        target.year = source.year ?? target.year
        target.tmdbId = source.tmdbId ?? target.tmdbId
        target.imdbId = source.imdbId ?? target.imdbId
        target.originalTitle = source.originalTitle ?? target.originalTitle
        target.releaseDate = source.releaseDate ?? target.releaseDate
        target.posterPath = source.posterPath ?? target.posterPath
        target.backdropPath = source.backdropPath ?? target.backdropPath
        target.overview = source.overview ?? target.overview
        target.tagline = source.tagline ?? target.tagline
        target.mpaaRating = source.mpaaRating ?? target.mpaaRating
        target.runtime = source.runtime ?? target.runtime
        if !source.genres.isEmpty {
            target.genres = source.genres
        }
        // Do not wipe TMDB/streaming data the user or podcast intake already has when the bundled row has none.
        if !source.streamingServices.isEmpty {
            target.streamingServices = source.streamingServices
        }
        if let credits = source.credits {
            target.credits = credits
        }
        if let trailer = source.trailer {
            target.trailer = trailer
        }
        if let oscarAwards = source.oscarAwards {
            target.oscarAwards = oscarAwards
        }
        if let physicalMedia = source.physicalMedia {
            if let existing = target.physicalMedia, existing.manualOverride {
                target.physicalMedia = existing
            } else if let existing = target.physicalMedia {
                target.physicalMedia = existing.merging(inferred: physicalMedia)
            } else {
                target.physicalMedia = physicalMedia
            }
        } else if target.physicalMedia == nil {
            target.physicalMedia = PhysicalMediaCatalog.shared.media(forTmdbId: target.tmdbId)
        }
        if !source.keywords.isEmpty {
            target.keywords = source.keywords
        }
        target.lastUpdated = Date()
    }
    
    /// Recovers from database corruption by replacing with bootstrap database
    private func recoverFromCorruption(modelContext: ModelContext) async throws {
        // Get the bootstrap database from bundle
        guard let bootstrapDBURL = Bundle.main.url(forResource: "bootstrap_database", withExtension: "store") else {
            throw NSError(domain: "LocalDatabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bootstrap database not found in bundle"])
        }
        
        // Get the current store URL
        let storeURL = AppDataBootstrapper.persistentStoreURL()
        
        // Don't try to save - the database is corrupted, save will fail
        // Just proceed to delete the corrupted files
        
        // Delete all database files (including WAL and SHM)
        // Use force unwrap with try? to handle errors gracefully
        if FileManager.default.fileExists(atPath: storeURL.path) {
            try? FileManager.default.removeItem(at: storeURL)
        }
        let walURL = storeURL.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: walURL.path) {
            try? FileManager.default.removeItem(at: walURL)
        }
        let shmURL = storeURL.appendingPathExtension("shm")
        if FileManager.default.fileExists(atPath: shmURL.path) {
            try? FileManager.default.removeItem(at: shmURL)
        }
        
        // Copy bootstrap database
        try FileManager.default.copyItem(at: bootstrapDBURL, to: storeURL)
        // Also copy WAL/SHM if present in bundle to avoid corruption on open
        let bootstrapWalURL = bootstrapSidecarURL(for: bootstrapDBURL, suffix: "wal")
        let bootstrapShmURL = bootstrapSidecarURL(for: bootstrapDBURL, suffix: "shm")
        if let bootstrapWalURL {
            try? FileManager.default.copyItem(at: bootstrapWalURL, to: walURL)
        }
        if let bootstrapShmURL {
            try? FileManager.default.copyItem(at: bootstrapShmURL, to: shmURL)
        }
        _ = BootstrapDataService.shared.recordBootstrapImportDate()
    }
    
    /// Completely resets the app to a fresh state like a new user
    /// Deletes local database files, clears CloudKit, and clears UserDefaults
    /// On next launch, the app will copy the bootstrap database
    func completeReset(modelContext: ModelContext) async throws {
        // Step 1: Clear CloudKit data
        do {
            try await CloudKitManager.shared.resetCloudKit()
        } catch {
            // Continue anyway - CloudKit might not be in use
        }
        
        // Step 2: Get store URL and delete database files
        // This will cause the app to copy bootstrap database on next launch
        // Get the store URL from ModelConfiguration (same way WatchedItApp does it)
        let storeURL = AppDataBootstrapper.persistentStoreURL()
        
        // Delete main database file
        if FileManager.default.fileExists(atPath: storeURL.path) {
            do {
                try FileManager.default.removeItem(at: storeURL)
            } catch {
            }
        }
        
        // Delete WAL and SHM files
        let walURL = storeURL.appendingPathExtension("wal")
        if FileManager.default.fileExists(atPath: walURL.path) {
            try? FileManager.default.removeItem(at: walURL)
        }
        
        let shmURL = storeURL.appendingPathExtension("shm")
        if FileManager.default.fileExists(atPath: shmURL.path) {
            try? FileManager.default.removeItem(at: shmURL)
        }
        
        // Step 3: Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
    }
}

public extension Notification.Name {
    static let swiftDataCorruptionRecovered = Notification.Name("swiftDataCorruptionRecovered")
}
