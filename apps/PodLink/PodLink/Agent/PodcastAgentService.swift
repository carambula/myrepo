import Foundation
import MinAppKit

@MainActor
final class PodcastAgentService: AgentLibraryExporting {
    static let shared = PodcastAgentService()

    private struct FollowUndo: Codable {
        let podcast: Podcast
        let wasFollowed: Bool
        let existed: Bool
    }

    func followed(query: String? = nil) -> [Podcast] {
        var items = Podcast.loadFollowedPodcasts()
        if let query, !query.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(query) || $0.author.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    func history(query: String? = nil) -> [ListeningHistoryEntry] {
        var items = ListeningHistoryStore.loadEntriesForDisplay()
        if let query, !query.isEmpty {
            items = items.filter {
                $0.episodeTitle.localizedCaseInsensitiveContains(query)
                    || $0.podcastTitle.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    func follow(query: String) async throws -> Podcast {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AgentKitError.notFound("Search for a podcast title.") }
        let results = try await PodcastSearchService.shared.search(query: trimmed, limit: 5)
        guard let first = results.first else { throw AgentKitError.notFound("No podcasts matched.") }
        var library = Podcast.mergedFollowedPodcastsForMutation()
        if let existing = library.first(where: { $0.id == first.id }) {
            return existing
        }
        var toAdd = first
        toAdd.isFollowed = true
        library.append(toAdd)
        Podcast.saveFollowedPodcasts(library)
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .pod,
            tool: "follow_podcast",
            summary: "Followed \(toAdd.title)",
            payload: FollowUndo(podcast: toAdd, wasFollowed: false, existed: false)
        )
        return toAdd
    }

    func unfollow(id: String?, title: String?) throws -> Podcast {
        var library = Podcast.mergedFollowedPodcastsForMutation()
        guard let index = library.firstIndex(where: { podcast in
            (id != nil && podcast.id == id) || (title != nil && podcast.title.localizedCaseInsensitiveContains(title!))
        }) else {
            throw AgentKitError.notFound("That podcast is not in your library.")
        }
        let removed = library.remove(at: index)
        Podcast.saveFollowedPodcasts(library)
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .pod,
            tool: "unfollow_podcast",
            summary: "Unfollowed \(removed.title)",
            payload: FollowUndo(podcast: removed, wasFollowed: true, existed: true)
        )
        return removed
    }

    func exportLibraryJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let payload = LibraryExport(
            podcasts: followed().map {
                ExportPodcast(id: $0.id, title: $0.title, author: $0.author, feedURL: $0.feedURL.absoluteString, isFollowed: true)
            },
            listeningHistory: history().map {
                ExportListen(
                    episodeID: $0.episodeID,
                    episodeTitle: $0.episodeTitle,
                    podcastTitle: $0.podcastTitle,
                    isPlayed: $0.isPlayed,
                    lastListenedAt: ISO8601DateFormatter().string(from: $0.lastListenedAt)
                )
            }
        )
        return try encoder.encode(payload)
    }

    func undoLastAgentWrite() throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .pod) else {
            throw AgentKitError.nothingToUndo
        }
        let payload = try AgentJournal.shared.decodePayload(record, as: FollowUndo.self)
        var library = Podcast.mergedFollowedPodcastsForMutation()
        if record.tool == "follow_podcast" {
            library.removeAll { $0.id == payload.podcast.id }
        } else if record.tool == "unfollow_podcast" {
            if !library.contains(where: { $0.id == payload.podcast.id }) {
                library.append(payload.podcast)
            }
        }
        Podcast.saveFollowedPodcasts(library)
        _ = try AgentJournal.shared.markUndone(id: record.id)
        return "Undid \(record.summary)"
    }

    private struct LibraryExport: Codable {
        let podcasts: [ExportPodcast]
        let listeningHistory: [ExportListen]
    }

    private struct ExportPodcast: Codable {
        let id: String
        let title: String
        let author: String
        let feedURL: String
        let isFollowed: Bool
    }

    private struct ExportListen: Codable {
        let episodeID: String
        let episodeTitle: String
        let podcastTitle: String
        let isPlayed: Bool
        let lastListenedAt: String
    }
}
