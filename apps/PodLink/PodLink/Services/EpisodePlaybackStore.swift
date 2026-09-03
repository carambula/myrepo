import Foundation
import CryptoKit

extension Notification.Name {
    static let episodePlaybackStateDidChange = Notification.Name("episodePlaybackStateDidChange")
}

enum EpisodePlaybackStore {
    private static func positionKey(_ id: String) -> String { "position_\(id)" }
    private static func playedKey(_ id: String) -> String { "played_\(id)" }
    private static func bookmarkKey(_ id: String) -> String { "bookmark_\(id)" }
    private static func relistenedKey(_ id: String) -> String { "relistened_\(id)" }
    private static func cloudPositionKey(_ id: String) -> String { "position_\(stableID(id))" }
    private static func cloudPlayedKey(_ id: String) -> String { "played_\(stableID(id))" }
    private static func cloudBookmarkKey(_ id: String) -> String { "bookmark_\(stableID(id))" }
    private static func cloudRelistenedKey(_ id: String) -> String { "relistened_\(stableID(id))" }

    private static func stableID(_ id: String) -> String {
        let digest = SHA256.hash(data: Data(id.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func cloudDouble(forKey key: String, legacyKey: String) -> Double? {
        if CloudKeyValueWriter.object(forKey: key) != nil {
            return CloudKeyValueWriter.double(forKey: key)
        }
        if CloudKeyValueWriter.object(forKey: legacyKey) != nil {
            let value = CloudKeyValueWriter.double(forKey: legacyKey)
            CloudKeyValueWriter.setDouble(value, forKey: key)
            return value
        }
        return nil
    }

    private static func cloudBool(forKey key: String, legacyKey: String) -> Bool? {
        if CloudKeyValueWriter.object(forKey: key) != nil {
            return CloudKeyValueWriter.bool(forKey: key)
        }
        if CloudKeyValueWriter.object(forKey: legacyKey) != nil {
            let value = CloudKeyValueWriter.bool(forKey: legacyKey)
            CloudKeyValueWriter.setBool(value, forKey: key)
            return value
        }
        return nil
    }
    /// `podcastID` matches `Episode.podcastID` (typically the feed URL string).
    private static func lastPlayedEpisodeKey(podcastID: String) -> String {
        "lastPlayedEpisode_podcast_\(podcastID)"
    }

    /// Latest episode the user listened to for this feed (drives show-detail “Resume” / “Up next”).
    static func recordLastPlayedEpisode(episodeID: String, podcastID: String) {
        UserDefaults.standard.set(episodeID, forKey: lastPlayedEpisodeKey(podcastID: podcastID))
    }

    static func lastPlayedEpisodeID(forPodcastID podcastID: String) -> String? {
        UserDefaults.standard.string(forKey: lastPlayedEpisodeKey(podcastID: podcastID))
    }

    /// Applies saved position, played flag, bookmark, and migration from “almost done” positions.
    static func merge(_ episode: Episode, postNotificationsForMigration: Bool = false) -> Episode {
        var e = episode
        let ud = UserDefaults.standard

        if let local = ud.object(forKey: positionKey(episode.id)) as? Double {
            e.playbackPosition = local
        } else if let cloudPosition = cloudDouble(
            forKey: cloudPositionKey(episode.id),
            legacyKey: positionKey(episode.id)
        ) {
            e.playbackPosition = cloudPosition
        }

        if ud.bool(forKey: playedKey(episode.id)) ||
            (cloudBool(
                forKey: cloudPlayedKey(episode.id),
                legacyKey: playedKey(episode.id)
            ) ?? false) {
            e.isPlayed = true
        }

        if ud.object(forKey: bookmarkKey(episode.id)) != nil {
            e.isBookmarked = ud.bool(forKey: bookmarkKey(episode.id))
        } else if let cloudBookmarked = cloudBool(
            forKey: cloudBookmarkKey(episode.id),
            legacyKey: bookmarkKey(episode.id)
        ) {
            e.isBookmarked = cloudBookmarked
        }

        if ud.object(forKey: relistenedKey(episode.id)) != nil {
            e.hasRelistened = ud.bool(forKey: relistenedKey(episode.id))
        } else if let cloudRelistened = cloudBool(
            forKey: cloudRelistenedKey(episode.id),
            legacyKey: relistenedKey(episode.id)
        ) {
            e.hasRelistened = cloudRelistened
        }

        let policy = PlaybackProgressPolicy.current
        let dur = e.duration
        if dur > 0, !e.isPlayed, policy.isFinished(playbackPosition: e.playbackPosition, duration: dur) {
            e.isPlayed = true
            persistPlayed(true, episodeID: e.id, notify: postNotificationsForMigration)
        }

        if let record = DownloadMetadataStore.record(for: e) {
            let localURL = record.localFileURL
            if FileManager.default.fileExists(atPath: localURL.path) {
                e.isDownloaded = true
                e.downloadedFileURL = localURL
            } else {
                e.isDownloaded = false
                e.downloadedFileURL = nil
                DownloadMetadataStore.remove(record: record)
            }
        } else {
            e.isDownloaded = false
            e.downloadedFileURL = nil
        }

        return e
    }

    static func persistPosition(_ position: TimeInterval, episodeID: String, notify: Bool = true) {
        UserDefaults.standard.set(position, forKey: positionKey(episodeID))
        CloudKeyValueWriter.setDouble(position, forKey: cloudPositionKey(episodeID))
        if notify {
            NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episodeID)
        }
    }

    static func persistPlayed(_ played: Bool, episodeID: String, notify: Bool = true) {
        UserDefaults.standard.set(played, forKey: playedKey(episodeID))
        CloudKeyValueWriter.setBool(played, forKey: cloudPlayedKey(episodeID))
        if played {
            DownloadRetentionEngine.handleEpisodeMarkedPlayed(episodeID: episodeID)
        }
        if notify {
            NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episodeID)
        }
    }

    /// Saves position and marks played when thresholds are met.
    static func saveProgress(
        episodeID: String,
        position: TimeInterval,
        duration: TimeInterval,
        policy: PlaybackProgressPolicy = .current
    ) {
        persistPosition(position, episodeID: episodeID, notify: false)
        if duration > 0, policy.isFinished(playbackPosition: position, duration: duration) {
            let already = UserDefaults.standard.bool(forKey: playedKey(episodeID))
            if !already {
                persistPlayed(true, episodeID: episodeID, notify: false)
            }
        }
        NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episodeID)
    }

    static func persistBookmark(_ bookmarked: Bool, episodeID: String, notify: Bool = true) {
        UserDefaults.standard.set(bookmarked, forKey: bookmarkKey(episodeID))
        CloudKeyValueWriter.setBool(bookmarked, forKey: cloudBookmarkKey(episodeID))
        if notify {
            NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episodeID)
        }
    }

    static func persistRelistened(_ relistened: Bool, episodeID: String, notify: Bool = true) {
        UserDefaults.standard.set(relistened, forKey: relistenedKey(episodeID))
        CloudKeyValueWriter.setBool(relistened, forKey: cloudRelistenedKey(episodeID))
        if notify {
            NotificationCenter.default.post(name: .episodePlaybackStateDidChange, object: episodeID)
        }
    }

    /// Marks a finished episode as relistened the next time playback starts.
    static func markRelistenedIfPreviouslyFinished(_ episode: Episode) {
        let merged = merge(episode)
        guard merged.isEffectivelyFinished else { return }
        persistRelistened(true, episodeID: episode.id)
    }
}
