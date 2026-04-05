import AppIntents
import Foundation

struct PodcastLibraryEntity: AppEntity {
    typealias ID = String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Podcast Library Show")
    }

    var id: String
    var title: String
    var author: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(author)")
    }

    init(podcast: Podcast) {
        id = podcast.id
        title = podcast.title
        author = podcast.author
    }
}

struct PodcastLibraryQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PodcastLibraryEntity] {
        let q = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = await MainActor.run { Podcast.loadFollowedPodcasts() }
        let filtered: [Podcast]
        if q.isEmpty {
            filtered = all
        } else {
            filtered = all.filter {
                $0.title.lowercased().contains(q) || $0.author.lowercased().contains(q)
            }
        }
        return filtered.map(PodcastLibraryEntity.init(podcast:))
    }

    func entities(for identifiers: [PodcastLibraryEntity.ID]) async throws -> [PodcastLibraryEntity] {
        await MainActor.run {
            Podcast.loadFollowedPodcasts()
                .filter { identifiers.contains($0.id) }
                .map(PodcastLibraryEntity.init(podcast:))
        }
    }

    func suggestedEntities() async throws -> [PodcastLibraryEntity] {
        await MainActor.run {
            Podcast.loadFollowedPodcasts().map(PodcastLibraryEntity.init(podcast:))
        }
    }
}

extension PodcastLibraryEntity {
    static var defaultQuery = PodcastLibraryQuery()
}

// MARK: - Episode (library only)

struct EpisodeLibraryEntity: AppEntity {
    typealias ID = String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Podcast Episode")
    }

    /// `PodLinkIntentEpisodeID.composite(podcastID:episodeID:)` — only shows you’ve added.
    var id: String
    var title: String
    var podcastTitle: String
    var publishDate: Date

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(podcastTitle)")
    }

    init(episode: Episode, podcast: Podcast) {
        id = PodLinkIntentEpisodeID.composite(podcastID: podcast.id, episodeID: episode.id)
        title = episode.title
        podcastTitle = podcast.title
        publishDate = episode.publishDate
    }
}

struct EpisodeLibraryQuery: EntityQuery {
    func entities(for identifiers: [EpisodeLibraryEntity.ID]) async throws -> [EpisodeLibraryEntity] {
        var results: [EpisodeLibraryEntity] = []
        for rawID in identifiers {
            guard let (podcastID, episodeID) = PodLinkIntentEpisodeID.parse(rawID) else { continue }
            let podcast = await MainActor.run {
                Podcast.loadFollowedPodcasts().first(where: { $0.id == podcastID })
            }
            guard let podcast else { continue }
            if let fetched = try? await RSSFeedService.shared.fetchEpisodes(feedURL: podcast.feedURL),
               let ep = fetched.first(where: { $0.id == episodeID }) {
                let merged = await MainActor.run { EpisodePlaybackStore.merge(ep) }
                results.append(EpisodeLibraryEntity(episode: merged, podcast: podcast))
            }
        }
        return results
    }

    func suggestedEntities() async throws -> [EpisodeLibraryEntity] {
        let episodes = await PodLinkEpisodeSuggestions.recentEpisodes(limit: 30)
        let podcasts = await MainActor.run { Podcast.loadFollowedPodcasts() }
        var out: [EpisodeLibraryEntity] = []
        for ep in episodes {
            guard let podcast = podcasts.first(where: { $0.id == ep.podcastID || $0.feedURL.absoluteString == ep.podcastID })
            else { continue }
            out.append(EpisodeLibraryEntity(episode: ep, podcast: podcast))
        }
        return out
    }
}

extension EpisodeLibraryEntity {
    static var defaultQuery = EpisodeLibraryQuery()
}
