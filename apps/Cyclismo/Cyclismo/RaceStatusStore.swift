import Foundation

/// Shared saved / watched / listened race flags. Used by the UI and agent adapters.
enum RaceStatusStore {
    static let savedKey = ICloudSyncManager.savedRaceIdsKey
    static let listenedKey = ICloudSyncManager.listenedRaceIdsKey
    static let watchedKey = ICloudSyncManager.watchedRaceIdsKey

    struct Status: Equatable {
        var isSaved: Bool
        var isListened: Bool
        var isWatched: Bool
    }

    static func loadSet(key: String) -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let decoded = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return Set(decoded)
    }

    static func status(for raceId: String) -> Status {
        Status(
            isSaved: loadSet(key: savedKey).contains(raceId),
            isListened: loadSet(key: listenedKey).contains(raceId),
            isWatched: loadSet(key: watchedKey).contains(raceId)
        )
    }

    static func set(_ isOn: Bool, raceId: String, key: String) {
        var set = loadSet(key: key)
        if isOn {
            set.insert(raceId)
        } else {
            set.remove(raceId)
        }
        let list = Array(set).sorted()
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
        Task { @MainActor in
            ICloudSyncManager.shared.syncRaceStatusForRaceId(raceId)
            if key == savedKey {
                await SavedRaceNotificationManager.shared.refreshSavedRaceNotifications(requestAuthorization: isOn)
            }
        }
    }

    static func apply(_ status: Status, raceId: String) {
        set(status.isSaved, raceId: raceId, key: savedKey)
        set(status.isListened, raceId: raceId, key: listenedKey)
        set(status.isWatched, raceId: raceId, key: watchedKey)
    }
}
