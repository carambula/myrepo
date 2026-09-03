import AppIntents
import Foundation
import MinAppKit

struct ListPodLinkListeningHistoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Show PodLink Listening History"
    static var description = IntentDescription("Lists recent episodes you have listened to.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let entries = await MainActor.run { PodcastAgentService.shared.history() }
        if entries.isEmpty {
            return .result(dialog: IntentDialog("No listening history yet."))
        }
        let lines = entries.prefix(10).map {
            "\($0.episodeTitle)\(AgentSecurity.metadataSeparator)\($0.podcastTitle)"
        }.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: lines))
    }
}

struct ListFollowedPodcastsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Followed Podcasts in PodLink"
    static var description = IntentDescription("Lists the shows in your PodLink library.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let shows = await MainActor.run { PodcastAgentService.shared.followed() }
        if shows.isEmpty {
            return .result(dialog: IntentDialog("You are not following any podcasts."))
        }
        let lines = shows.prefix(20).map(\.title).joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: lines))
    }
}

struct UnfollowPodcastInPodLinkIntent: AppIntent {
    static var title: LocalizedStringResource = "Unfollow Podcast in PodLink"
    static var description = IntentDescription("Removes a followed show. Reversible for 7 days from Account, Agents.")
    static var openAppWhenRun = false

    @Parameter(title: "Podcast")
    var podcast: PodcastLibraryEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = try await MainActor.run {
            try PodcastAgentService.shared.unfollow(id: podcast.id, title: podcast.title).title
        }
        return .result(dialog: IntentDialog("Unfollowed \(title)."))
    }
}

struct UndoLastPodLinkAgentWriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last PodLink Agent Change"
    static var description = IntentDescription("Reverses the most recent agent podcast write.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await MainActor.run { try PodcastAgentService.shared.undoLastAgentWrite() }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}
