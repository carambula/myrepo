//
//  CloudKitManager.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import CloudKit
import Combine
import SwiftData

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private static func debugLog(_ message: @autoclosure () -> String) {
#if DEBUG
        guard ProcessInfo.processInfo.environment["WATCHEDIT_VERBOSE_LOGS"] == "1" else { return }
        print(message())
#endif
    }
    
    struct UserMovieDataPayload {
        let movieId: String
        let isSaved: Bool
        let isRewatched: Bool
        let isListened: Bool
        let isWatched: Bool
        let userRating: Int?
        let userNotes: String?
        let watchedDate: Date?
        let rewatchedDate: Date?
        let listenedDate: Date?
        let tagsData: Data?
        let lastUpdated: Date
    }

    struct UserStreamingPreferencesPayload {
        let preferredServicesData: Data
        let hiddenServicesData: Data
        let lastUpdated: Date
    }

    struct UserListPreferencesPayload {
        let preferredListsData: Data
        let lastUpdated: Date
    }

    struct UserPodcastAppPreferencesPayload {
        let preferredAppName: String
        let lastUpdated: Date
    }

    struct UserThemePreferencesPayload {
        let customThemesData: Data
        let selectedThemeName: String
        let lastUpdated: Date
    }
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let userDataZoneID = CKRecordZone.ID(
        zoneName: "UserMovieDataZone",
        ownerName: CKCurrentUserDefaultName
    )
    private lazy var userDataZone = CKRecordZone(zoneID: userDataZoneID)
    private var cachedAccountStatus: (status: CKAccountStatus, timestamp: Date)?
    private let accountStatusCacheTTL: TimeInterval = 30

    /// UserDefaults key for the user data zone change token (incremental sync).
    private static let userDataZoneChangeTokenKey = "WatchedIt.UserDataZoneChangeToken"
    
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.Carambula-Projects.WatchedIt")
        privateDatabase = container.privateCloudDatabase
    }
    
    func fetchMovies() async {
        isLoading = true
        error = nil
        
        // Check if iCloud is available
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ iCloud not available (status: \(status)), skipping CloudKit fetch")
            movies = []
            isLoading = false
            return
        }
        
        do {
            let query = CKQuery(recordType: "Movie", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
            
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            var fetchedMovies: [Movie] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let movie = Movie(from: record) {
                        fetchedMovies.append(movie)
                    }
                case .failure(let error):
                    print("⚠️ Error fetching record: \(error)")
                }
            }
            
            movies = fetchedMovies
            isLoading = false
        } catch {
            // Log error but don't fail - app works without CloudKit
            print("⚠️ CloudKit fetch error (non-fatal): \(error.localizedDescription)")
            self.error = error
            movies = []
            isLoading = false
        }
    }
    
    func saveMovie(_ movie: Movie) async throws {
        // Check if iCloud is available before attempting to save
        let status = await accountStatus()
        guard status == .available else {
            return
        }
        
        do {
            let recordID = CKRecord.ID(recordName: movie.id)
            
            // Try to fetch existing record first
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
                // Record exists, update its fields
                record["title"] = movie.title
                record["year"] = movie.year
                record["tmdbId"] = movie.tmdbId
                record["posterPath"] = movie.posterPath
                record["backdropPath"] = movie.backdropPath
                record["overview"] = movie.overview
                record["mpaaRating"] = movie.mpaaRating
                record["genres"] = movie.genres
                record["lastUpdated"] = movie.lastUpdated
                
                // Encode rewatchables discussion
                if let discussion = movie.rewatchablesDiscussion,
                   let discussionData = try? JSONEncoder().encode(discussion) {
                    record["rewatchablesDiscussion"] = discussionData
                } else {
                    record["rewatchablesDiscussion"] = nil
                }
                
                // Encode streaming services
                if let servicesData = try? JSONEncoder().encode(movie.streamingServices) {
                    record["streamingServices"] = servicesData
                } else {
                    record["streamingServices"] = nil
                }
            } catch {
                // Record doesn't exist, create new one
                record = movie.toCKRecord()
            }
            
            try await privateDatabase.save(record)
            
            // Update local cache
            if let index = movies.firstIndex(where: { $0.id == movie.id }) {
                movies[index] = movie
            } else {
                movies.append(movie)
            }
        } catch {
            // Silently handle errors - CloudKit sync is optional
            // Suppress duplicate record errors as they're expected during rapid updates
        }
    }
    
    func updateMovieRewatchedStatus(_ movie: Movie, isRewatched: Bool) async throws {
        let userData = UserMovieData(
            movie: nil,
            isSaved: movie.isSaved,
            isRewatched: isRewatched,
            isListened: movie.isListened,
            isWatched: false,
            userRating: nil,
            userNotes: nil,
            watchedDate: nil,
            rewatchedDate: nil,
            listenedDate: nil,
            tags: [],
            lastUpdated: Date(),
            createdAt: Date()
        )
        try await saveUserMovieData(movieId: movie.id, userData: userData)
    }
    
    func updateMovieListenedStatus(_ movie: Movie, isListened: Bool) async throws {
        let userData = UserMovieData(
            movie: nil,
            isSaved: movie.isSaved,
            isRewatched: movie.isRewatched,
            isListened: isListened,
            isWatched: false,
            userRating: nil,
            userNotes: nil,
            watchedDate: nil,
            rewatchedDate: nil,
            listenedDate: nil,
            tags: [],
            lastUpdated: Date(),
            createdAt: Date()
        )
        try await saveUserMovieData(movieId: movie.id, userData: userData)
    }
    
    func updateMovieSavedStatus(_ movie: Movie, isSaved: Bool) async throws {
        let userData = UserMovieData(
            movie: nil,
            isSaved: isSaved,
            isRewatched: movie.isRewatched,
            isListened: movie.isListened,
            isWatched: false,
            userRating: nil,
            userNotes: nil,
            watchedDate: nil,
            rewatchedDate: nil,
            listenedDate: nil,
            tags: [],
            lastUpdated: Date(),
            createdAt: Date()
        )
        try await saveUserMovieData(movieId: movie.id, userData: userData)
    }
    
    func deleteMovie(_ movie: Movie) async throws {
        let recordID = CKRecord.ID(recordName: movie.id)
        try await privateDatabase.deleteRecord(withID: recordID)
        
        movies.removeAll { $0.id == movie.id }
    }
    
    func accountStatus(forceRefresh: Bool = false) async -> CKAccountStatus {
        if !forceRefresh, let cachedAccountStatus {
            let age = Date().timeIntervalSince(cachedAccountStatus.timestamp)
            if age < accountStatusCacheTTL {
                return cachedAccountStatus.status
            }
        }

        do {
            let status = try await container.accountStatus()
            cachedAccountStatus = (status, Date())
            return status
        } catch {
            if let cachedAccountStatus {
                return cachedAccountStatus.status
            }
            // Handle authentication errors gracefully
            print("⚠️ CloudKit account status check failed: \(error.localizedDescription)")
            return .couldNotDetermine
        }
    }

    
    
    var isCloudKitAvailable: Bool {
        get async {
            let status = await accountStatus()
            return status == .available
        }
    }
    
    // MARK: - UserMovieData Sync (New Schema)

    private func ensureUserDataZone() async throws {
        let status = await accountStatus()
        guard status == .available else {
            throw CKError(.notAuthenticated)
        }
        let operation = CKModifyRecordZonesOperation(
            recordZonesToSave: [userDataZone],
            recordZoneIDsToDelete: nil
        )
        try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    if let ckError = error as? CKError,
                       ckError.code == .serverRejectedRequest,
                       (ckError.userInfo["ServerErrorDescription"] as? String)?.contains("already exists") == true {
                        continuation.resume()
                    } else {
                        print("⚠️ CloudKit zone creation failed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            self.privateDatabase.add(operation)
        }
    }

    private func payload(from record: CKRecord) -> UserMovieDataPayload? {
        guard let movieId = record["movieId"] as? String else { return nil }
        let lastUpdated = record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
        return UserMovieDataPayload(
            movieId: movieId,
            isSaved: record["isSaved"] as? Bool ?? false,
            isRewatched: record["isRewatched"] as? Bool ?? false,
            isListened: record["isListened"] as? Bool ?? false,
            isWatched: record["isWatched"] as? Bool ?? false,
            userRating: record["userRating"] as? Int,
            userNotes: record["userNotes"] as? String,
            watchedDate: record["watchedDate"] as? Date,
            rewatchedDate: record["rewatchedDate"] as? Date,
            listenedDate: record["listenedDate"] as? Date,
            tagsData: record["tags"] as? Data,
            lastUpdated: lastUpdated
        )
    }

    private func streamingPreferencesPayload(from record: CKRecord) -> UserStreamingPreferencesPayload {
        let lastUpdated = record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
        return UserStreamingPreferencesPayload(
            preferredServicesData: record["preferredServices"] as? Data ?? Data(),
            hiddenServicesData: record["hiddenServices"] as? Data ?? Data(),
            lastUpdated: lastUpdated
        )
    }

    private func listPreferencesPayload(from record: CKRecord) -> UserListPreferencesPayload {
        let lastUpdated = record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
        return UserListPreferencesPayload(
            preferredListsData: record["preferredLists"] as? Data ?? Data(),
            lastUpdated: lastUpdated
        )
    }

    private func podcastAppPreferencesPayload(from record: CKRecord) -> UserPodcastAppPreferencesPayload {
        let lastUpdated = record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
        return UserPodcastAppPreferencesPayload(
            preferredAppName: record["preferredPodcastApp"] as? String ?? "",
            lastUpdated: lastUpdated
        )
    }

    private func themePreferencesPayload(from record: CKRecord) -> UserThemePreferencesPayload {
        let lastUpdated = record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
        return UserThemePreferencesPayload(
            customThemesData: record["customThemes"] as? Data ?? Data(),
            selectedThemeName: record["selectedThemeName"] as? String ?? "Watched It",
            lastUpdated: lastUpdated
        )
    }
    
    /// Saves user movie data payload directly to CloudKit
    func saveUserMovieDataPayload(_ payload: UserMovieDataPayload) async {
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ CloudKit unavailable for user data save (status: \(status))")
            return
        }

        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserMovieData-\(payload.movieId)",
                zoneID: userDataZoneID
            )
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "UserMovieData", recordID: recordID)
            }
            
            record["movieId"] = payload.movieId
            record["isSaved"] = payload.isSaved
            record["isRewatched"] = payload.isRewatched
            record["isListened"] = payload.isListened
            record["isWatched"] = payload.isWatched
            record["userRating"] = payload.userRating
            record["userNotes"] = payload.userNotes
            record["watchedDate"] = payload.watchedDate
            record["rewatchedDate"] = payload.rewatchedDate
            record["listenedDate"] = payload.listenedDate
            record["tags"] = payload.tagsData
            record["lastUpdated"] = payload.lastUpdated
            
            try await privateDatabase.save(record)
            Self.debugLog("✅ Synced UserMovieData to CloudKit for movie: \(payload.movieId)")
        } catch {
            print("⚠️ Error syncing UserMovieData to CloudKit: \(error.localizedDescription)")
        }
    }

    /// Saves user streaming preferences payload to CloudKit
    func saveUserStreamingPreferencesPayload(_ payload: UserStreamingPreferencesPayload) async {
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ CloudKit unavailable for streaming preferences save (status: \(status))")
            return
        }

        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserStreamingPreferences",
                zoneID: userDataZoneID
            )
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "UserStreamingPreferences", recordID: recordID)
            }

            record["preferredServices"] = payload.preferredServicesData
            record["hiddenServices"] = payload.hiddenServicesData
            record["lastUpdated"] = payload.lastUpdated

            try await privateDatabase.save(record)
            Self.debugLog("✅ Synced streaming preferences to CloudKit")
        } catch {
            print("⚠️ Error syncing streaming preferences to CloudKit: \(error.localizedDescription)")
        }
    }

    /// Saves user list preferences payload to CloudKit
    func saveUserListPreferencesPayload(_ payload: UserListPreferencesPayload) async {
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ CloudKit unavailable for list preferences save (status: \(status))")
            return
        }

        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserListPreferences",
                zoneID: userDataZoneID
            )
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "UserListPreferences", recordID: recordID)
            }

            record["preferredLists"] = payload.preferredListsData
            record["lastUpdated"] = payload.lastUpdated

            try await privateDatabase.save(record)
            Self.debugLog("✅ Synced list preferences to CloudKit")
        } catch {
            print("⚠️ Error syncing list preferences to CloudKit: \(error.localizedDescription)")
        }
    }

    /// Saves user podcast app preferences payload to CloudKit
    func saveUserPodcastAppPreferencesPayload(_ payload: UserPodcastAppPreferencesPayload) async {
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ CloudKit unavailable for podcast app preferences save (status: \(status))")
            return
        }

        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserPodcastAppPreferences",
                zoneID: userDataZoneID
            )
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "UserPodcastAppPreferences", recordID: recordID)
            }

            record["preferredPodcastApp"] = payload.preferredAppName
            record["lastUpdated"] = payload.lastUpdated

            try await privateDatabase.save(record)
            Self.debugLog("✅ Synced podcast app preferences to CloudKit")
        } catch {
            print("⚠️ Error syncing podcast app preferences to CloudKit: \(error.localizedDescription)")
        }
    }

    /// Saves user theme preferences payload to CloudKit
    func saveUserThemePreferencesPayload(_ payload: UserThemePreferencesPayload) async {
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ CloudKit unavailable for theme preferences save (status: \(status))")
            return
        }

        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserThemePreferences",
                zoneID: userDataZoneID
            )
            let record: CKRecord
            do {
                record = try await privateDatabase.record(for: recordID)
            } catch {
                record = CKRecord(recordType: "UserThemePreferences", recordID: recordID)
            }

            record["customThemes"] = payload.customThemesData
            record["selectedThemeName"] = payload.selectedThemeName
            record["lastUpdated"] = payload.lastUpdated

            try await privateDatabase.save(record)
            Self.debugLog("✅ Synced theme preferences to CloudKit")
        } catch {
            print("⚠️ Error syncing theme preferences to CloudKit: \(error.localizedDescription)")
        }
    }
    
    /// Saves user movie data separately to CloudKit (better separation than embedding in Movie)
    func saveUserMovieData(movieId: String, userData: UserMovieData) async throws {
        let payload = UserMovieDataPayload(
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
        await saveUserMovieDataPayload(payload)
    }
    
    /// Fetches user movie data from CloudKit
    func fetchUserMovieData(movieId: String) async throws -> UserMovieData? {
        let status = await accountStatus()
        guard status == .available else {
            return nil
        }
        
        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserMovieData-\(movieId)",
                zoneID: userDataZoneID
            )
            let record = try await privateDatabase.record(for: recordID)
            
            let lastUpdated = record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
            let payload = UserMovieDataPayload(
                movieId: movieId,
                isSaved: record["isSaved"] as? Bool ?? false,
                isRewatched: record["isRewatched"] as? Bool ?? false,
                isListened: record["isListened"] as? Bool ?? false,
                isWatched: record["isWatched"] as? Bool ?? false,
                userRating: record["userRating"] as? Int,
                userNotes: record["userNotes"] as? String,
                watchedDate: record["watchedDate"] as? Date,
                rewatchedDate: record["rewatchedDate"] as? Date,
                listenedDate: record["listenedDate"] as? Date,
                tagsData: record["tags"] as? Data,
                lastUpdated: lastUpdated
            )
            
            let userData = UserMovieData(
                movie: nil,
                isSaved: payload.isSaved,
                isRewatched: payload.isRewatched,
                isListened: payload.isListened,
                isWatched: payload.isWatched,
                userRating: payload.userRating,
                userNotes: payload.userNotes,
                watchedDate: payload.watchedDate,
                rewatchedDate: payload.rewatchedDate,
                listenedDate: payload.listenedDate,
                tags: [],
                lastUpdated: payload.lastUpdated,
                createdAt: payload.lastUpdated
            )
            userData.tagsData = payload.tagsData
            return userData
        } catch {
            // Record doesn't exist
            return nil
        }
    }

    /// Fetches streaming preferences from CloudKit
    func fetchUserStreamingPreferencesPayload() async throws -> UserStreamingPreferencesPayload? {
        let status = await accountStatus()
        guard status == .available else {
            return nil
        }
        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserStreamingPreferences",
                zoneID: userDataZoneID
            )
            let record = try await privateDatabase.record(for: recordID)
            return streamingPreferencesPayload(from: record)
        } catch {
            return nil
        }
    }

    /// Fetches list preferences from CloudKit
    func fetchUserListPreferencesPayload() async throws -> UserListPreferencesPayload? {
        let status = await accountStatus()
        guard status == .available else {
            return nil
        }
        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserListPreferences",
                zoneID: userDataZoneID
            )
            let record = try await privateDatabase.record(for: recordID)
            return listPreferencesPayload(from: record)
        } catch {
            return nil
        }
    }

    /// Fetches podcast app preferences from CloudKit
    func fetchUserPodcastAppPreferencesPayload() async throws -> UserPodcastAppPreferencesPayload? {
        let status = await accountStatus()
        guard status == .available else {
            return nil
        }
        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserPodcastAppPreferences",
                zoneID: userDataZoneID
            )
            let record = try await privateDatabase.record(for: recordID)
            return podcastAppPreferencesPayload(from: record)
        } catch {
            return nil
        }
    }

    /// Fetches theme preferences from CloudKit
    func fetchUserThemePreferencesPayload() async throws -> UserThemePreferencesPayload? {
        let status = await accountStatus()
        guard status == .available else {
            return nil
        }
        do {
            try await ensureUserDataZone()
            let recordID = CKRecord.ID(
                recordName: "UserThemePreferences",
                zoneID: userDataZoneID
            )
            let record = try await privateDatabase.record(for: recordID)
            return themePreferencesPayload(from: record)
        } catch {
            return nil
        }
    }

    /// Fetches all user movie data records from CloudKit
    func fetchUserMovieDataPayloads() async throws -> [UserMovieDataPayload] {
        let status = await accountStatus()
        guard status == .available else {
            return []
        }
        try await ensureUserDataZone()
        return try await fetchUserMovieDataPayloadsFromZoneChanges()
    }

    /// Fetches user movie data for specific movie IDs (no queryable fields required).
    func fetchUserMovieDataPayloads(forMovieIds movieIds: [String]) async throws -> [UserMovieDataPayload] {
        let status = await accountStatus()
        guard status == .available else {
            return []
        }
        try await ensureUserDataZone()
        let payloads = try await fetchUserMovieDataPayloadsById(
            movieIds: movieIds,
            zoneID: userDataZoneID
        )
        if !payloads.isEmpty {
            return payloads
        }

        // Fallback: fetch legacy records stored in the default zone, then migrate.
        let legacyPayloads = try await fetchUserMovieDataPayloadsById(
            movieIds: movieIds,
            zoneID: CKRecordZone.default().zoneID
        )
        if !legacyPayloads.isEmpty {
            print("🔄 Migrating \(legacyPayloads.count) user data records to custom zone")
            for (index, payload) in legacyPayloads.enumerated() {
                await saveUserMovieDataPayload(payload)
                if index % 50 == 0 {
                    await Task.yield()
                }
            }
        }
        return legacyPayloads
    }

    private func fetchUserMovieDataPayloadsById(
        movieIds: [String],
        zoneID: CKRecordZone.ID
    ) async throws -> [UserMovieDataPayload] {
        guard !movieIds.isEmpty else { return [] }

        var payloads: [UserMovieDataPayload] = []
        let payloadsLock = NSLock()

        let chunkSize = 200
        for chunkStart in stride(from: 0, to: movieIds.count, by: chunkSize) {
            let chunk = movieIds[chunkStart..<min(chunkStart + chunkSize, movieIds.count)]
            let recordIDs = chunk.map { CKRecord.ID(recordName: "UserMovieData-\($0)", zoneID: zoneID) }

            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            operation.desiredKeys = [
                "movieId",
                "isSaved",
                "isRewatched",
                "isListened",
                "isWatched",
                "userRating",
                "userNotes",
                "watchedDate",
                "rewatchedDate",
                "listenedDate",
                "tags",
                "lastUpdated"
            ]
            operation.perRecordResultBlock = { _, result in
                if case .success(let record) = result,
                   let payload = self.payload(from: record) {
                    payloadsLock.lock()
                    payloads.append(payload)
                    payloadsLock.unlock()
                }
            }
            try await withCheckedThrowingContinuation { continuation in
                operation.fetchRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        print("⚠️ CloudKit user data fetch by ID failed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                self.privateDatabase.add(operation)
            }
        }

        return payloads
    }

    private func loadUserDataZoneChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: Self.userDataZoneChangeTokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveUserDataZoneChangeToken(_ token: CKServerChangeToken?) {
        guard let token else {
            UserDefaults.standard.removeObject(forKey: Self.userDataZoneChangeTokenKey)
            return
        }
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDataZoneChangeTokenKey)
    }

    /// Fetches user movie data using zone changes (incremental when a change token exists).
    private func fetchUserMovieDataPayloadsFromZoneChanges() async throws -> [UserMovieDataPayload] {
        let zoneID = userDataZoneID
        var allPayloads: [UserMovieDataPayload] = []
        var nextToken: CKServerChangeToken? = loadUserDataZoneChangeToken()

        repeat {
            let configuration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            configuration.previousServerChangeToken = nextToken
            configuration.resultsLimit = 400

            var payloads: [UserMovieDataPayload] = []
            let payloadsLock = NSLock()
            var zoneResult: (token: CKServerChangeToken?, moreComing: Bool)?
            let resultLock = NSLock()

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: configuration]
            )
            operation.fetchAllChanges = true
            operation.recordChangedBlock = { record in
                guard record.recordType == "UserMovieData" else { return }
                if let payload = self.payload(from: record) {
                    payloadsLock.lock()
                    payloads.append(payload)
                    payloadsLock.unlock()
                }
            }
            operation.recordWithIDWasDeletedBlock = { _, _ in }
            operation.recordZoneFetchResultBlock = { zid, result in
                resultLock.lock()
                switch result {
                case .success(let changeResult):
                    zoneResult = (changeResult.serverChangeToken, changeResult.moreComing)
                case .failure(let error):
                    print("⚠️ CloudKit user data zone fetch failed: \(error)")
                    zoneResult = (nil, false)
                }
                resultLock.unlock()
            }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                operation.fetchRecordZoneChangesResultBlock = { result in
                    switch result {
                    case .success:
                        resultLock.lock()
                        let res = zoneResult
                        resultLock.unlock()
                        if let res {
                            self.saveUserDataZoneChangeToken(res.token)
                        }
                        continuation.resume()
                    case .failure(let error):
                        print("⚠️ CloudKit user data zone changes failed: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
                self.privateDatabase.add(operation)
            }

            allPayloads.append(contentsOf: payloads)
            nextToken = zoneResult?.moreComing == true ? loadUserDataZoneChangeToken() : nil
        } while nextToken != nil

        return allPayloads
    }
    
    /// Syncs user status changes to CloudKit (both old and new schemas)
    func syncUserStatus(movieId: String, isRewatched: Bool?, isListened: Bool?, isSaved: Bool?) async throws {
        // Sync to Movie record (backward compatibility)
        // This will be handled by existing saveMovie methods
        
        // Also sync to UserMovieData record if available (new schema)
        // This allows for better separation in the future
        // For now, we'll keep the embedded approach in Movie records for compatibility
    }
    
    /// Resets CloudKit by deleting all movie records
    func resetCloudKit() async throws {
        // Check if iCloud is available
        let status = await accountStatus()
        guard status == .available else {
            print("⚠️ iCloud not available (status: \(status)), skipping CloudKit reset")
            return
        }
        
        do {
            // Fetch all movies
            let query = CKQuery(recordType: "Movie", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            
            var deletedCount = 0
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    try await privateDatabase.deleteRecord(withID: record.recordID)
                    deletedCount += 1
                case .failure(let error):
                    print("⚠️ Error deleting record: \(error)")
                }
            }
            
            // Clear local cache
            movies = []
            
            print("✅ CloudKit reset complete - deleted \(deletedCount) records")
        } catch {
            print("❌ Error resetting CloudKit: \(error.localizedDescription)")
            throw error
        }
    }
}

