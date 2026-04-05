import Foundation
import Network
import Observation
import CryptoKit

@Observable
final class NetworkStatusService {
    static let shared = NetworkStatusService()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "PodLink.NetworkStatusService.Monitor")
    private(set) var isOnline = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = online
            }
        }
        monitor.start(queue: queue)
    }
}

@Observable
final class DownloadManager {
    static let shared = DownloadManager()

    enum State: Equatable {
        case notDownloaded
        case downloading
        case downloaded
        case failed(String)
    }

    private static let downloadsDirectoryName = "EpisodeDownloads"

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private(set) var runtimeStates: [String: State] = [:]
    private var isOnWiFi = true
    private var isNetworkAvailable = true
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "PodLink.DownloadManager.Network")

    private init() {
        startNetworkMonitor()
    }

    func state(for episode: Episode) -> State {
        if let runtime = runtimeStates[episode.id] {
            return runtime
        }
        if DownloadMetadataStore.contains(episode: episode) {
            return .downloaded
        }
        return .notDownloaded
    }

    func downloadedRecords() -> [DownloadRecord] {
        DownloadMetadataStore.sortedRecordsNewestFirst()
    }

    func totalStorageBytes() -> Int64 {
        DownloadMetadataStore.totalStoredBytes()
    }

    func startDownload(for episode: Episode, podcast: Podcast?) {
        guard activeTasks[episode.id] == nil else { return }
        guard state(for: episode) != .downloaded else { return }
        guard isNetworkAvailable else {
            runtimeStates[episode.id] = .failed("No network connection")
            NotificationCenter.default.post(name: .episodeDownloadStateDidChange, object: episode.id)
            return
        }

        let wifiOnly = UserDefaults.standard.object(forKey: DownloadSettingsKeys.wifiOnly) as? Bool ?? true
        if wifiOnly && !isOnWiFi {
            runtimeStates[episode.id] = .failed("Wi-Fi required by settings")
            NotificationCenter.default.post(name: .episodeDownloadStateDidChange, object: episode.id)
            return
        }

        runtimeStates[episode.id] = .downloading
        NotificationCenter.default.post(name: .episodeDownloadStateDidChange, object: episode.id)

        activeTasks[episode.id] = Task { [weak self] in
            guard let self else { return }
            await self.performDownload(for: episode, podcast: podcast)
        }
    }

    func deleteDownload(for episodeID: String) {
        if let task = activeTasks.removeValue(forKey: episodeID) {
            task.cancel()
        }
        runtimeStates.removeValue(forKey: episodeID)

        if let record = DownloadMetadataStore.record(for: episodeID) {
            try? FileManager.default.removeItem(at: record.localFileURL)
        }
        DownloadMetadataStore.remove(episodeID: episodeID)
    }

    func deleteDownload(for episode: Episode) {
        if let record = DownloadMetadataStore.record(for: episode) {
            deleteDownload(for: record.episodeID)
            return
        }
        deleteDownload(for: episode.id)
    }

    func clearAllDownloads() {
        for id in DownloadMetadataStore.allRecords().keys {
            deleteDownload(for: id)
        }
    }

    /// Cleans stale metadata when the local file no longer exists.
    func healMissingFileMetadata(for episodeID: String) {
        guard let record = DownloadMetadataStore.record(for: episodeID) else { return }
        guard !FileManager.default.fileExists(atPath: record.localFileURL.path) else { return }
        DownloadMetadataStore.remove(record: record)
        runtimeStates.removeValue(forKey: episodeID)
    }

    private func performDownload(for episode: Episode, podcast: Podcast?) async {
        defer {
            activeTasks.removeValue(forKey: episode.id)
        }

        do {
            let destination = try makeDestinationURL(for: episode)
            let (tempURL, _) = try await URLSession.shared.download(from: episode.audioURL)
            if Task.isCancelled { return }

            let fileManager = FileManager.default
            try ensureDownloadsDirectory()
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)

            let attrs = try fileManager.attributesOfItem(atPath: destination.path)
            let bytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0

            var updatedEpisode = episode
            updatedEpisode.isDownloaded = true
            updatedEpisode.downloadedFileURL = destination

            let record = DownloadRecord(
                episodeID: episode.id,
                localFilePath: destination.path,
                downloadedAt: Date(),
                fileSizeBytes: bytes,
                episode: updatedEpisode,
                podcast: podcast
            )
            DownloadMetadataStore.upsert(record)
            runtimeStates[episode.id] = .downloaded
            NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episode.id)
        } catch {
            runtimeStates[episode.id] = .failed("Download failed")
            NotificationCenter.default.post(name: .episodeDownloadStateDidChange, object: episode.id)
        }
    }

    private func startNetworkMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task {
                self?.isOnWiFi = path.usesInterfaceType(.wifi)
                self?.isNetworkAvailable = path.status == .satisfied
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func ensureDownloadsDirectory() throws {
        _ = try downloadsDirectoryURL()
    }

    private func downloadsDirectoryURL() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = root.appendingPathComponent("PodLink", isDirectory: true)
            .appendingPathComponent(Self.downloadsDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeDestinationURL(for episode: Episode) throws -> URL {
        let audioKey = episode.audioURL.absoluteString
        let digest = SHA256.hash(data: Data(audioKey.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        let stem = String(hash.prefix(24))
        let ext = episode.audioURL.pathExtension.isEmpty ? "mp3" : episode.audioURL.pathExtension
        return try downloadsDirectoryURL().appendingPathComponent("\(stem).\(ext)")
    }
}
