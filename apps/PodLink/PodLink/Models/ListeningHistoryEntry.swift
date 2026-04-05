import Foundation

extension Notification.Name {
    static let listeningHistoryDidChange = Notification.Name("PodLink.listeningHistoryDidChange")
}

/// Snapshot of an episode for the listening-history list (synced via iCloud KVS with `ListeningHistoryStore`).
struct ListeningHistoryEntry: Codable, Identifiable, Hashable {
    var id: String { episodeID }

    let episodeID: String
    let podcastID: String
    var episodeTitle: String
    var podcastTitle: String
    var feedURLString: String
    var audioURLString: String
    var videoURLString: String?
    var artworkURLString: String?
    var episodePublishDate: Date
    var duration: TimeInterval
    var playbackPosition: TimeInterval
    var isPlayed: Bool
    var lastListenedAt: Date

    func makeBaseEpisode() -> Episode? {
        guard let audioURL = URL(string: audioURLString),
              audioURL.scheme == "http" || audioURL.scheme == "https" else { return nil }
        let vid = videoURLString.flatMap(URL.init(string:))
        let art = artworkURLString.flatMap(URL.init(string:))
        return Episode(
            id: episodeID,
            podcastID: podcastID,
            title: episodeTitle,
            description: "",
            publishDate: episodePublishDate,
            duration: duration,
            audioURL: audioURL,
            videoURL: vid,
            artworkURL: art,
            playbackPosition: playbackPosition,
            isPlayed: isPlayed
        )
    }

    /// Minimal podcast for playback and artwork when the show is not in the followed library.
    func resolvedPodcast() -> Podcast? {
        guard let feedURL = URL(string: feedURLString) ?? URL(string: podcastID) else { return nil }
        let art = artworkURLString.flatMap(URL.init(string:))
        return Podcast(
            id: podcastID,
            title: podcastTitle,
            author: "",
            description: "",
            feedURL: feedURL,
            artworkURL: art,
            artworkURL600: art
        )
    }

    /// Followed show when possible; otherwise a minimal podcast built from this snapshot.
    func preferredPodcastForPlayback() -> Podcast? {
        let followed = Podcast.loadFollowedPodcasts()
        if let u = URL(string: feedURLString),
           let p = followed.first(where: { $0.feedURL == u }) {
            return p
        }
        if let p = followed.first(where: { $0.id == podcastID }) {
            return p
        }
        return resolvedPodcast()
    }
}
