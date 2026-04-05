import Foundation

enum PodLinkIntentError: LocalizedError {
    case podcastNotInLibrary
    case episodeNotFound
    case emptyLibrary
    case nothingPlaying
    case queueEmpty
    case invalidEpisodeIdentifier
    case searchFoundNoPodcasts
    case podcastAlreadyInLibrary

    var errorDescription: String? {
        switch self {
        case .podcastNotInLibrary:
            return "That show isn’t in your PodLink library yet."
        case .episodeNotFound:
            return "That episode couldn’t be found in the feed."
        case .emptyLibrary:
            return "Add podcasts in PodLink first."
        case .nothingPlaying:
            return "Nothing is playing in PodLink."
        case .queueEmpty:
            return "Your Up Next queue is empty."
        case .invalidEpisodeIdentifier:
            return "That episode reference isn’t valid."
        case .searchFoundNoPodcasts:
            return "No podcasts matched that search."
        case .podcastAlreadyInLibrary:
            return "That show is already in your library."
        }
    }
}

/// Stable composite key for Siri / Shortcuts (`podcast.id` + separator + `episode.id`).
enum PodLinkIntentEpisodeID {
    static let separator = "::podlink::"

    nonisolated static func composite(podcastID: String, episodeID: String) -> String {
        podcastID + separator + episodeID
    }

    nonisolated static func parse(_ composite: String) -> (podcastID: String, episodeID: String)? {
        let parts = composite.components(separatedBy: separator)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }
}

enum PodLinkEpisodeSuggestions {
    /// Recent episodes from feeds you follow (for Siri pickers).
    static func recentEpisodes(limit: Int = 24) async -> [Episode] {
        let podcasts = await MainActor.run { Podcast.loadFollowedPodcasts() }
        guard !podcasts.isEmpty else { return [] }
        var collected: [Episode] = []
        for podcast in podcasts {
            guard collected.count < limit else { break }
            if let fetched = try? await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL) {
                let merged = fetched.map { EpisodePlaybackStore.merge($0) }
                collected.append(contentsOf: merged.prefix(8))
            }
        }
        return collected
            .sorted { $0.publishDate > $1.publishDate }
            .prefix(limit)
            .map { $0 }
    }
}

enum PodLinkIntentPlayback {
    static func followedPodcast(id: String) -> Podcast? {
        Podcast.loadFollowedPodcasts().first { $0.id == id || $0.feedURL.absoluteString == id }
    }

    static func playEpisode(compositeID: String) async throws {
        guard let (podcastID, episodeID) = PodLinkIntentEpisodeID.parse(compositeID) else {
            throw PodLinkIntentError.invalidEpisodeIdentifier
        }
        try await playEpisode(podcastID: podcastID, episodeID: episodeID)
    }

    static func playEpisode(podcastID: String, episodeID: String) async throws {
        guard let podcast = followedPodcast(id: podcastID) else {
            throw PodLinkIntentError.podcastNotInLibrary
        }
        let episodes = try await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL)
        guard let raw = episodes.first(where: { $0.id == episodeID }) else {
            throw PodLinkIntentError.episodeNotFound
        }
        let merged = EpisodePlaybackStore.merge(raw)
        await PlaybackService.shared.play(episode: merged, podcast: podcast)
    }

    static func playLatestEpisode(podcastID: String) async throws {
        guard let podcast = followedPodcast(id: podcastID) else {
            throw PodLinkIntentError.podcastNotInLibrary
        }
        let episodes = try await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL)
        let merged = episodes.map { EpisodePlaybackStore.merge($0) }.sorted { $0.publishDate > $1.publishDate }
        guard let pick = merged.first(where: { !$0.isEffectivelyFinished }) ?? merged.first else {
            throw PodLinkIntentError.episodeNotFound
        }
        await PlaybackService.shared.play(episode: pick, podcast: podcast)
    }

    static func resumePlayback() async throws {
        let playback = PlaybackService.shared
        if playback.state.currentEpisode != nil {
            playback.resume()
            return
        }
        await playback.restoreResumeSessionIfNeeded()
        guard playback.state.currentEpisode != nil else {
            throw PodLinkIntentError.nothingPlaying
        }
        playback.resume()
    }
}
