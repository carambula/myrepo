import Foundation

enum DownloadSettingsKeys {
    static let wifiOnly = "downloadsWifiOnly"
    static let deleteAfterListened = "downloadsDeleteAfterListened"
    static let retentionDays = "downloadsRetentionDays"
    static let autoDownloadFollowed = "downloadsAutoDownloadFollowed"
}

enum DownloadRetentionEngine {
    static func runSweep(now: Date = Date()) {
        let retentionDays = UserDefaults.standard.object(forKey: DownloadSettingsKeys.retentionDays) as? Int ?? 30
        guard retentionDays > 0 else { return }

        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        for record in DownloadMetadataStore.allRecords().values where record.downloadedAt < cutoff {
            DownloadManager.shared.deleteDownload(for: record.episodeID)
        }
    }

    static func handleEpisodeMarkedPlayed(episodeID: String) {
        let deleteAfterListened = UserDefaults.standard.object(forKey: DownloadSettingsKeys.deleteAfterListened) as? Bool ?? false
        guard deleteAfterListened else { return }
        DownloadManager.shared.deleteDownload(for: episodeID)
    }
}
