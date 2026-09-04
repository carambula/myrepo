import Foundation

/// Library / episode-list status filter used by search.
enum EpisodeStatusFilter: String, CaseIterable, Identifiable, Hashable {
    case all = "All"
    case downloaded = "Downloaded"
    case notDownloaded = "Not downloaded"
    case saved = "Saved"
    case notSaved = "Not saved"
    case listened = "Listened"
    case notListened = "Not listened"
    case complete = "Complete"
    case notComplete = "Not complete"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all: return "checkmark"
        case .downloaded: return "arrow.down.circle.fill"
        case .notDownloaded: return "arrow.down.circle"
        case .saved: return "bookmark.fill"
        case .notSaved: return "bookmark"
        case .listened: return "headphones"
        case .notListened: return "headphones"
        case .complete: return "checkmark.circle.fill"
        case .notComplete: return "circle"
        }
    }

    func matches(_ episode: Episode) -> Bool {
        switch self {
        case .all:
            return true
        case .downloaded:
            return episode.isDownloaded
        case .notDownloaded:
            return !episode.isDownloaded
        case .saved:
            return episode.isBookmarked
        case .notSaved:
            return !episode.isBookmarked
        case .listened:
            return episode.hasBeenListenedTo
        case .notListened:
            return !episode.hasBeenListenedTo
        case .complete:
            return episode.isEffectivelyFinished
        case .notComplete:
            return !episode.isEffectivelyFinished
        }
    }
}

struct LibrarySearchFilters: Equatable {
    var status: EpisodeStatusFilter = .all
    var showNewOnly = false
    var showVideoOnly = false
    var selectedCategory: PodcastCategory?

    static let newEpisodeMaxAge: TimeInterval = 14 * 24 * 60 * 60

    var isRestrictingLibrary: Bool {
        status != .all || showNewOnly || showVideoOnly || selectedCategory != nil
    }

    func matches(episode: Episode, podcast: Podcast, now: Date = .now) -> Bool {
        if !status.matches(episode) { return false }
        if showVideoOnly && !episode.hasVideo { return false }
        if showNewOnly, now.timeIntervalSince(episode.publishDate) > Self.newEpisodeMaxAge {
            return false
        }
        if let selectedCategory {
            let wanted = selectedCategory.rawValue
            let hasCategory = podcast.categories.contains {
                $0.caseInsensitiveCompare(wanted) == .orderedSame
            }
            if !hasCategory { return false }
        }
        return true
    }

    func matchesDiscover(_ podcast: Podcast) -> Bool {
        guard let selectedCategory else { return true }
        let wanted = selectedCategory.rawValue
        return podcast.categories.contains {
            $0.caseInsensitiveCompare(wanted) == .orderedSame
        }
    }
}
