import Foundation

enum ListeningHistoryStore {
    static let storageKey = "listeningHistoryV1"

    private static let maxEntries = 300

    /// Merged local + iCloud rows, optionally hydrating `UserDefaults` when local was empty after reinstall.
    static func loadEntriesForDisplay() -> [ListeningHistoryEntry] {
        let merged = mergedEntriesFromStores()
        if UserDefaults.standard.data(forKey: storageKey) == nil, !merged.isEmpty,
           let data = try? JSONEncoder().encode(merged) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        return merged
    }

    static func applyFromUbiquitousStore() {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
              !decodeEntries(data).isEmpty else { return }
        let merged = mergedEntriesFromStores()
        guard let out = try? JSONEncoder().encode(merged) else { return }
        UserDefaults.standard.set(out, forKey: storageKey)
        NotificationCenter.default.post(name: .listeningHistoryDidChange, object: nil)
    }

    /// Call after meaningful progress, finished, or manual position changes from the player UI.
    static func recordListening(
        episode: Episode,
        podcast: Podcast?,
        position: TimeInterval,
        duration: TimeInterval,
        date: Date = .now
    ) {
        let policy = PlaybackProgressPolicy.current
        let dur = duration > 0 ? duration : episode.duration
        let played = episode.isPlayed || (dur > 0 && policy.isFinished(playbackPosition: position, duration: dur))
        let partial = policy.hasMeaningfulProgress(playbackPosition: position, duration: dur)
        guard played || partial else { return }

        let feedStr: String
        if let p = podcast {
            feedStr = p.feedURL.absoluteString
        } else if let u = URL(string: episode.podcastID), u.scheme != nil {
            feedStr = u.absoluteString
        } else {
            feedStr = episode.podcastID
        }

        let podcastTitle = podcast?.title ?? "Podcast"
        let art = episode.artworkURL?.absoluteString ?? podcast?.displayArtworkURL?.absoluteString

        let incoming = ListeningHistoryEntry(
            episodeID: episode.id,
            podcastID: episode.podcastID,
            episodeTitle: episode.title,
            podcastTitle: podcastTitle,
            feedURLString: feedStr,
            audioURLString: episode.audioURL.absoluteString,
            videoURLString: episode.videoURL?.absoluteString,
            artworkURLString: art,
            episodePublishDate: episode.publishDate,
            duration: dur > 0 ? dur : episode.duration,
            playbackPosition: position,
            isPlayed: played,
            lastListenedAt: date
        )

        var entries = mergedEntriesFromStores()
        if let idx = entries.firstIndex(where: { $0.episodeID == episode.id }) {
            entries[idx] = upsertMerge(existing: entries[idx], incoming: incoming)
        } else {
            entries.append(incoming)
        }
        persist(entries)
    }

    // MARK: - Private

    private static func decodeEntries(_ data: Data?) -> [ListeningHistoryEntry] {
        guard let data, let decoded = try? JSONDecoder().decode([ListeningHistoryEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func mergedEntriesFromStores() -> [ListeningHistoryEntry] {
        let local = decodeEntries(UserDefaults.standard.data(forKey: storageKey))
        let cloud = decodeEntries(NSUbiquitousKeyValueStore.default.data(forKey: storageKey))
        return mergeEntryArrays(local, cloud)
    }

    private static func mergeEntryArrays(_ a: [ListeningHistoryEntry], _ b: [ListeningHistoryEntry]) -> [ListeningHistoryEntry] {
        var byID: [String: ListeningHistoryEntry] = [:]
        for e in a + b {
            if let existing = byID[e.episodeID] {
                byID[e.episodeID] = preferEntry(existing, e)
            } else {
                byID[e.episodeID] = e
            }
        }
        return Array(byID.values)
    }

    private static func preferEntry(_ x: ListeningHistoryEntry, _ y: ListeningHistoryEntry) -> ListeningHistoryEntry {
        if x.lastListenedAt != y.lastListenedAt {
            return x.lastListenedAt > y.lastListenedAt ? x : y
        }
        if x.isPlayed != y.isPlayed { return x.isPlayed ? x : y }
        if x.playbackPosition != y.playbackPosition {
            return x.playbackPosition > y.playbackPosition ? x : y
        }
        return x
    }

    private static func upsertMerge(existing: ListeningHistoryEntry, incoming: ListeningHistoryEntry) -> ListeningHistoryEntry {
        ListeningHistoryEntry(
            episodeID: incoming.episodeID,
            podcastID: incoming.podcastID,
            episodeTitle: incoming.episodeTitle.isEmpty ? existing.episodeTitle : incoming.episodeTitle,
            podcastTitle: incoming.podcastTitle == "Podcast" ? existing.podcastTitle : incoming.podcastTitle,
            feedURLString: incoming.feedURLString.isEmpty ? existing.feedURLString : incoming.feedURLString,
            audioURLString: incoming.audioURLString.isEmpty ? existing.audioURLString : incoming.audioURLString,
            videoURLString: incoming.videoURLString ?? existing.videoURLString,
            artworkURLString: incoming.artworkURLString ?? existing.artworkURLString,
            episodePublishDate: incoming.episodePublishDate,
            duration: max(existing.duration, incoming.duration),
            playbackPosition: max(existing.playbackPosition, incoming.playbackPosition),
            isPlayed: existing.isPlayed || incoming.isPlayed,
            lastListenedAt: max(existing.lastListenedAt, incoming.lastListenedAt)
        )
    }

    private static func persist(_ entries: [ListeningHistoryEntry]) {
        let trimmed = entries
            .sorted { $0.lastListenedAt > $1.lastListenedAt }
            .prefix(maxEntries)
        let array = Array(trimmed)
        guard let data = try? JSONEncoder().encode(array) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        NSUbiquitousKeyValueStore.default.set(data, forKey: storageKey)
        NotificationCenter.default.post(name: .listeningHistoryDidChange, object: nil)
    }
}
