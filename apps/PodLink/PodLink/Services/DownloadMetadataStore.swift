import Foundation

extension Notification.Name {
    static let episodeDownloadStateDidChange = Notification.Name("episodeDownloadStateDidChange")
    static let downloadedEpisodesDidChange = Notification.Name("downloadedEpisodesDidChange")
}

struct DownloadRecord: Codable, Hashable, Identifiable {
    var episodeID: String
    var localFilePath: String
    var downloadedAt: Date
    var fileSizeBytes: Int64
    var audioURLString: String?
    var episode: Episode
    var podcast: Podcast?

    var id: String { episodeID }

    var localFileURL: URL {
        URL(fileURLWithPath: localFilePath)
    }

    var canonicalAudioURLString: String {
        audioURLString ?? episode.audioURL.absoluteString
    }

    init(
        episodeID: String,
        localFilePath: String,
        downloadedAt: Date,
        fileSizeBytes: Int64,
        audioURLString: String? = nil,
        episode: Episode,
        podcast: Podcast?
    ) {
        self.episodeID = episodeID
        self.localFilePath = localFilePath
        self.downloadedAt = downloadedAt
        self.fileSizeBytes = fileSizeBytes
        self.audioURLString = audioURLString ?? episode.audioURL.absoluteString
        self.episode = episode
        self.podcast = podcast
    }
}

enum DownloadMetadataStore {
    private static let legacyUserDefaultsStorageKey = "downloadRecordsV1"
    private static let storageFileName = "downloadRecords.json"

    private static let cacheLock = NSLock()
    private static var cachedSnapshot: [String: DownloadRecord]?
    private static var audioURLIndex: [String: String]?

    private static func buildAudioURLIndex(from records: [String: DownloadRecord]) -> [String: String] {
        var index: [String: String] = [:]
        index.reserveCapacity(records.count)
        for (episodeID, record) in records {
            index[record.canonicalAudioURLString] = episodeID
        }
        return index
    }

    static func allRecords() -> [String: DownloadRecord] {
        cacheLock.lock()
        if let snapshot = cachedSnapshot {
            cacheLock.unlock()
            return snapshot
        }
        cacheLock.unlock()

        let records: [String: DownloadRecord]
        if let fromDisk = loadRecordsFromDisk() {
            records = fromDisk
        } else if let migrated = migrateLegacyUserDefaultsRecords() {
            records = migrated
        } else {
            records = [:]
        }

        cacheLock.lock()
        cachedSnapshot = records
        audioURLIndex = buildAudioURLIndex(from: records)
        cacheLock.unlock()
        return records
    }

    static func sortedRecordsNewestFirst() -> [DownloadRecord] {
        allRecords().values.sorted { $0.downloadedAt > $1.downloadedAt }
    }

    static func record(for episodeID: String) -> DownloadRecord? {
        allRecords()[episodeID]
    }

    static func record(for episode: Episode) -> DownloadRecord? {
        let records = allRecords()
        if let byID = records[episode.id] {
            return byID
        }
        let audio = episode.audioURL.absoluteString
        cacheLock.lock()
        let indexedID = audioURLIndex?[audio]
        cacheLock.unlock()
        if let indexedID, let record = records[indexedID] {
            return record
        }
        return nil
    }

    static func upsert(_ record: DownloadRecord) {
        var records = allRecords()

        // Keep one authoritative record per media URL so feed ID churn does not orphan downloads.
        let audio = record.canonicalAudioURLString
        for (key, existing) in records where key != record.episodeID && existing.canonicalAudioURLString == audio {
            records.removeValue(forKey: key)
        }

        records[record.episodeID] = record
        persist(records)
        NotificationCenter.default.post(name: .episodeDownloadStateDidChange, object: record.episodeID)
        NotificationCenter.default.post(name: .downloadedEpisodesDidChange, object: nil)
    }

    static func remove(episodeID: String) {
        var records = allRecords()
        guard records.removeValue(forKey: episodeID) != nil else { return }
        persist(records)
        NotificationCenter.default.post(name: .episodeDownloadStateDidChange, object: episodeID)
        NotificationCenter.default.post(name: .downloadedEpisodesDidChange, object: nil)
    }

    static func remove(record: DownloadRecord) {
        remove(episodeID: record.episodeID)
    }

    static func contains(episodeID: String) -> Bool {
        allRecords()[episodeID] != nil
    }

    static func contains(episode: Episode) -> Bool {
        record(for: episode) != nil
    }

    static func totalStoredBytes() -> Int64 {
        allRecords().values.reduce(0) { $0 + max(0, $1.fileSizeBytes) }
    }

    private static func persist(_ records: [String: DownloadRecord]) {
        cacheLock.lock()
        cachedSnapshot = records
        audioURLIndex = buildAudioURLIndex(from: records)
        cacheLock.unlock()
        guard let data = try? JSONEncoder().encode(records),
              let fileURL = metadataFileURL() else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func loadRecordsFromDisk() -> [String: DownloadRecord]? {
        guard let fileURL = metadataFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let records = try? JSONDecoder().decode([String: DownloadRecord].self, from: data) else {
            return nil
        }
        return records
    }

    private static func migrateLegacyUserDefaultsRecords() -> [String: DownloadRecord]? {
        guard let data = UserDefaults.standard.data(forKey: legacyUserDefaultsStorageKey),
              let records = try? JSONDecoder().decode([String: DownloadRecord].self, from: data) else {
            return [:]
        }
        persist(records)
        UserDefaults.standard.removeObject(forKey: legacyUserDefaultsStorageKey)
        return records
    }

    private static func metadataFileURL() -> URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let dir = appSupport
            .appendingPathComponent("PodLink", isDirectory: true)
            .appendingPathComponent("EpisodeDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(storageFileName)
    }
}
