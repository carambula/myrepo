import Foundation
import CloudKit

@MainActor
final class ICloudSyncManager {
    static let shared = ICloudSyncManager()

    static let savedRaceIdsKey = "Cyclismo.savedRaceIds"
    static let listenedRaceIdsKey = "Cyclismo.listenedRaceIds"
    static let watchedRaceIdsKey = "Cyclismo.watchedRaceIds"
    static let selectedThemeKey = "Cyclismo.selectedTheme"
    static let customThemesKey = "Cyclismo.customThemes"
    static let themePreferencesLastUpdatedKey = "Cyclismo.themePreferencesLastUpdated"
    static let raceStatusLastUpdatedMapKey = "Cyclismo.raceStatusLastUpdatedByRaceId"
    static let podcastPlayerPreferenceKey = "Cyclismo.podcastPlayerPreference"
    static let podcastPlayerPreferenceLastUpdatedKey = "Cyclismo.podcastPlayerPreferenceLastUpdated"
    static let youtubeAppPreferenceKey = "Cyclismo.youtubeAppPreference"
    static let youtubeAppPreferenceLastUpdatedKey = "Cyclismo.youtubeAppPreferenceLastUpdated"

    struct UserRaceStatusPayload {
        let raceId: String
        let isSaved: Bool
        let isListened: Bool
        let isWatched: Bool
        let lastUpdated: Date
    }

    struct UserThemePreferencesPayload {
        let customThemesData: Data
        let selectedThemeName: String
        let lastUpdated: Date
    }

    struct UserPodcastPlayerPreferencePayload {
        let preferenceRawValue: String
        let lastUpdated: Date
    }

    struct UserYouTubeAppPreferencePayload {
        let preferenceRawValue: String
        let lastUpdated: Date
    }

    private let defaults = UserDefaults.standard
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private var cachedAccountStatus: (status: CKAccountStatus, timestamp: Date)?
    private let accountStatusCacheTTL: TimeInterval = 30
    private var hasStarted = false
    private var hasRestoredRaceStatusThisSession = false
    private var hasPushedRaceStatusThisSession = false
    private var hasPushedPodcastPreferenceThisSession = false
    private var hasPushedYouTubePreferenceThisSession = false

    private init() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.Carambula-Projects.Cyclismo"
        container = CKContainer(identifier: "iCloud.\(bundleId)")
        privateDatabase = container.privateCloudDatabase
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await restoreRaceStatusesFromCloudKitIfNeeded()
            await pushLocalRaceStatusesToCloudKitIfNeeded()
            await syncPodcastPlayerPreferenceFromCloudKitIfNewer()
            await pushLocalPodcastPlayerPreferenceToCloudKitIfNeeded()
            await syncYouTubeAppPreferenceFromCloudKitIfNewer()
            await pushLocalYouTubeAppPreferenceToCloudKitIfNeeded()
        }
    }

    func syncRaceStatusForRaceId(_ raceId: String) {
        guard !raceId.isEmpty else { return }
        updateRaceStatusTimestamp(for: raceId)

        Task {
            guard let payload = currentRaceStatusPayload(for: raceId) else { return }
            await saveUserRaceStatusPayload(payload)
        }
    }

    func syncPodcastPlayerPreference(_ preferenceRawValue: String) {
        let trimmed = preferenceRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: Self.podcastPlayerPreferenceKey)
        defaults.set(Date(), forKey: Self.podcastPlayerPreferenceLastUpdatedKey)

        Task {
            let payload = UserPodcastPlayerPreferencePayload(
                preferenceRawValue: trimmed,
                lastUpdated: podcastPreferenceLastUpdated()
            )
            await saveUserPodcastPlayerPreferencePayload(payload)
        }
    }

    func syncYouTubeAppPreference(_ preferenceRawValue: String) {
        let trimmed = preferenceRawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: Self.youtubeAppPreferenceKey)
        defaults.set(Date(), forKey: Self.youtubeAppPreferenceLastUpdatedKey)

        Task {
            let payload = UserYouTubeAppPreferencePayload(
                preferenceRawValue: trimmed,
                lastUpdated: youtubePreferenceLastUpdated()
            )
            await saveUserYouTubeAppPreferencePayload(payload)
        }
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
            return .couldNotDetermine
        }
    }

    private func restoreRaceStatusesFromCloudKitIfNeeded() async {
        guard !hasAnyLocalRaceStatus() else { return }
        guard await accountStatus() == .available else { return }

        let payloads = await fetchUserRaceStatusPayloads()
        guard !payloads.isEmpty else { return }

        applyRaceStatusPayloads(payloads)
        hasRestoredRaceStatusThisSession = true
    }

    private func pushLocalRaceStatusesToCloudKitIfNeeded() async {
        guard hasAnyLocalRaceStatus() else { return }
        guard !hasPushedRaceStatusThisSession else { return }
        if hasRestoredRaceStatusThisSession {
            hasPushedRaceStatusThisSession = true
            return
        }
        guard await accountStatus() == .available else { return }

        hasPushedRaceStatusThisSession = true
        let allRaceIds = allRaceStatusRaceIds()
        for raceId in allRaceIds {
            guard let payload = currentRaceStatusPayload(for: raceId) else { continue }
            await saveUserRaceStatusPayload(payload)
        }
    }

    private func saveUserRaceStatusPayload(_ payload: UserRaceStatusPayload) async {
        guard await accountStatus() == .available else { return }
        let recordID = CKRecord.ID(recordName: "UserRaceStatus-\(payload.raceId)")
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "UserRaceStatus", recordID: recordID)
        }

        record["raceId"] = payload.raceId
        record["isSaved"] = payload.isSaved
        record["isListened"] = payload.isListened
        record["isWatched"] = payload.isWatched
        record["lastUpdated"] = payload.lastUpdated
        _ = try? await privateDatabase.save(record)
    }

    private func fetchUserRaceStatusPayloads() async -> [UserRaceStatusPayload] {
        let query = CKQuery(recordType: "UserRaceStatus", predicate: NSPredicate(value: true))
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query)
            var payloads: [UserRaceStatusPayload] = []
            for (_, result) in matchResults {
                guard case .success(let record) = result else { continue }
                guard let raceId = record["raceId"] as? String else { continue }
                payloads.append(
                    UserRaceStatusPayload(
                        raceId: raceId,
                        isSaved: record["isSaved"] as? Bool ?? false,
                        isListened: record["isListened"] as? Bool ?? false,
                        isWatched: record["isWatched"] as? Bool ?? false,
                        lastUpdated: record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
                    )
                )
            }
            return payloads
        } catch {
            return []
        }
    }

    private func applyRaceStatusPayloads(_ payloads: [UserRaceStatusPayload]) {
        var saved = loadSet(key: Self.savedRaceIdsKey)
        var listened = loadSet(key: Self.listenedRaceIdsKey)
        var watched = loadSet(key: Self.watchedRaceIdsKey)
        var timestamps = raceStatusTimestampMap()

        for payload in payloads {
            if payload.isSaved { saved.insert(payload.raceId) } else { saved.remove(payload.raceId) }
            if payload.isListened { listened.insert(payload.raceId) } else { listened.remove(payload.raceId) }
            if payload.isWatched { watched.insert(payload.raceId) } else { watched.remove(payload.raceId) }
            timestamps[payload.raceId] = payload.lastUpdated.timeIntervalSince1970
        }

        storeSet(saved, key: Self.savedRaceIdsKey)
        storeSet(listened, key: Self.listenedRaceIdsKey)
        storeSet(watched, key: Self.watchedRaceIdsKey)
        storeRaceStatusTimestampMap(timestamps)
        Task {
            await SavedRaceNotificationManager.shared.refreshSavedRaceNotifications()
        }
    }

    func saveUserThemePreferencesPayload(_ payload: UserThemePreferencesPayload) async {
        guard await accountStatus() == .available else { return }
        let recordID = CKRecord.ID(recordName: "UserThemePreferences")
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "UserThemePreferences", recordID: recordID)
        }

        record["customThemes"] = payload.customThemesData
        record["selectedThemeName"] = payload.selectedThemeName
        record["lastUpdated"] = payload.lastUpdated
        _ = try? await privateDatabase.save(record)
    }

    func fetchUserThemePreferencesPayload() async throws -> UserThemePreferencesPayload? {
        guard await accountStatus() == .available else { return nil }
        do {
            let recordID = CKRecord.ID(recordName: "UserThemePreferences")
            let record = try await privateDatabase.record(for: recordID)
            return UserThemePreferencesPayload(
                customThemesData: record["customThemes"] as? Data ?? Data(),
                selectedThemeName: record["selectedThemeName"] as? String ?? "Cyclismo",
                lastUpdated: record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
            )
        } catch {
            return nil
        }
    }

    private func syncPodcastPlayerPreferenceFromCloudKitIfNewer() async {
        guard await accountStatus() == .available else { return }
        guard let payload = await fetchUserPodcastPlayerPreferencePayload() else { return }

        let localUpdated = podcastPreferenceLastUpdated()
        if payload.lastUpdated > localUpdated {
            defaults.set(payload.preferenceRawValue, forKey: Self.podcastPlayerPreferenceKey)
            defaults.set(payload.lastUpdated, forKey: Self.podcastPlayerPreferenceLastUpdatedKey)
        }
    }

    private func pushLocalPodcastPlayerPreferenceToCloudKitIfNeeded() async {
        guard !hasPushedPodcastPreferenceThisSession else { return }
        guard await accountStatus() == .available else { return }
        guard let localPreference = localPodcastPlayerPreference() else { return }

        hasPushedPodcastPreferenceThisSession = true
        let payload = UserPodcastPlayerPreferencePayload(
            preferenceRawValue: localPreference,
            lastUpdated: podcastPreferenceLastUpdated()
        )
        await saveUserPodcastPlayerPreferencePayload(payload)
    }

    private func saveUserPodcastPlayerPreferencePayload(_ payload: UserPodcastPlayerPreferencePayload) async {
        guard await accountStatus() == .available else { return }
        let recordID = CKRecord.ID(recordName: "UserPodcastPlayerPreference")
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "UserPodcastPlayerPreference", recordID: recordID)
        }

        record["preferenceRawValue"] = payload.preferenceRawValue
        record["lastUpdated"] = payload.lastUpdated
        _ = try? await privateDatabase.save(record)
    }

    private func fetchUserPodcastPlayerPreferencePayload() async -> UserPodcastPlayerPreferencePayload? {
        guard await accountStatus() == .available else { return nil }
        do {
            let recordID = CKRecord.ID(recordName: "UserPodcastPlayerPreference")
            let record = try await privateDatabase.record(for: recordID)
            let rawValue = (record["preferenceRawValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawValue.isEmpty else { return nil }
            return UserPodcastPlayerPreferencePayload(
                preferenceRawValue: rawValue,
                lastUpdated: record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
            )
        } catch {
            return nil
        }
    }

    private func syncYouTubeAppPreferenceFromCloudKitIfNewer() async {
        guard await accountStatus() == .available else { return }
        guard let payload = await fetchUserYouTubeAppPreferencePayload() else { return }

        let localUpdated = youtubePreferenceLastUpdated()
        if payload.lastUpdated > localUpdated {
            defaults.set(payload.preferenceRawValue, forKey: Self.youtubeAppPreferenceKey)
            defaults.set(payload.lastUpdated, forKey: Self.youtubeAppPreferenceLastUpdatedKey)
        }
    }

    private func pushLocalYouTubeAppPreferenceToCloudKitIfNeeded() async {
        guard !hasPushedYouTubePreferenceThisSession else { return }
        guard await accountStatus() == .available else { return }
        guard let localPreference = localYouTubeAppPreference() else { return }

        hasPushedYouTubePreferenceThisSession = true
        let payload = UserYouTubeAppPreferencePayload(
            preferenceRawValue: localPreference,
            lastUpdated: youtubePreferenceLastUpdated()
        )
        await saveUserYouTubeAppPreferencePayload(payload)
    }

    private func saveUserYouTubeAppPreferencePayload(_ payload: UserYouTubeAppPreferencePayload) async {
        guard await accountStatus() == .available else { return }
        let recordID = CKRecord.ID(recordName: "UserYouTubeAppPreference")
        let record: CKRecord
        do {
            record = try await privateDatabase.record(for: recordID)
        } catch {
            record = CKRecord(recordType: "UserYouTubeAppPreference", recordID: recordID)
        }

        record["preferenceRawValue"] = payload.preferenceRawValue
        record["lastUpdated"] = payload.lastUpdated
        _ = try? await privateDatabase.save(record)
    }

    private func fetchUserYouTubeAppPreferencePayload() async -> UserYouTubeAppPreferencePayload? {
        guard await accountStatus() == .available else { return nil }
        do {
            let recordID = CKRecord.ID(recordName: "UserYouTubeAppPreference")
            let record = try await privateDatabase.record(for: recordID)
            let rawValue = (record["preferenceRawValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawValue.isEmpty else { return nil }
            return UserYouTubeAppPreferencePayload(
                preferenceRawValue: rawValue,
                lastUpdated: record["lastUpdated"] as? Date ?? record.modificationDate ?? Date.distantPast
            )
        } catch {
            return nil
        }
    }

    private func localYouTubeAppPreference() -> String? {
        let value = (defaults.string(forKey: Self.youtubeAppPreferenceKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func youtubePreferenceLastUpdated() -> Date {
        defaults.object(forKey: Self.youtubeAppPreferenceLastUpdatedKey) as? Date ?? Date.distantPast
    }

    private func hasAnyLocalRaceStatus() -> Bool {
        !loadSet(key: Self.savedRaceIdsKey).isEmpty
            || !loadSet(key: Self.listenedRaceIdsKey).isEmpty
            || !loadSet(key: Self.watchedRaceIdsKey).isEmpty
    }

    private func allRaceStatusRaceIds() -> [String] {
        let ids = loadSet(key: Self.savedRaceIdsKey)
            .union(loadSet(key: Self.listenedRaceIdsKey))
            .union(loadSet(key: Self.watchedRaceIdsKey))
        return Array(ids).sorted()
    }

    private func currentRaceStatusPayload(for raceId: String) -> UserRaceStatusPayload? {
        let saved = loadSet(key: Self.savedRaceIdsKey)
        let listened = loadSet(key: Self.listenedRaceIdsKey)
        let watched = loadSet(key: Self.watchedRaceIdsKey)
        let timestamps = raceStatusTimestampMap()
        let date = Date(timeIntervalSince1970: timestamps[raceId] ?? Date().timeIntervalSince1970)

        return UserRaceStatusPayload(
            raceId: raceId,
            isSaved: saved.contains(raceId),
            isListened: listened.contains(raceId),
            isWatched: watched.contains(raceId),
            lastUpdated: date
        )
    }

    private func updateRaceStatusTimestamp(for raceId: String, at date: Date = Date()) {
        var map = raceStatusTimestampMap()
        map[raceId] = date.timeIntervalSince1970
        storeRaceStatusTimestampMap(map)
    }

    private func raceStatusTimestampMap() -> [String: TimeInterval] {
        guard let data = defaults.data(forKey: Self.raceStatusLastUpdatedMapKey),
              let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func storeRaceStatusTimestampMap(_ map: [String: TimeInterval]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: Self.raceStatusLastUpdatedMapKey)
    }

    private func loadSet(key: String) -> Set<String> {
        guard let data = defaults.data(forKey: key) else { return [] }
        let decoded = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return Set(decoded)
    }

    private func storeSet(_ set: Set<String>, key: String) {
        let list = Array(set).sorted()
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: key)
    }

    private func localPodcastPlayerPreference() -> String? {
        let value = (defaults.string(forKey: Self.podcastPlayerPreferenceKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func podcastPreferenceLastUpdated() -> Date {
        defaults.object(forKey: Self.podcastPlayerPreferenceLastUpdatedKey) as? Date ?? Date.distantPast
    }

}
