import Foundation

enum PodcastListSorter {
    /// Unplayed / in-progress latest episodes first, then finished, then shows with no latest episode.
    static func sort(_ podcasts: [Podcast], latestEpisodes: [String: Episode]) -> [Podcast] {
        podcasts.sorted { lhs, rhs in
            let lhsEpisode = latestEpisodes[lhs.id]
            let rhsEpisode = latestEpisodes[rhs.id]

            let lhsGroup = sortGroup(for: lhsEpisode)
            let rhsGroup = sortGroup(for: rhsEpisode)
            if lhsGroup != rhsGroup { return lhsGroup < rhsGroup }

            let lhsDate = lhsEpisode?.publishDate ?? .distantPast
            let rhsDate = rhsEpisode?.publishDate ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }

    static func sortGroup(for episode: Episode?) -> Int {
        guard let episode else { return 2 }
        return episode.isEffectivelyFinished ? 1 : 0
    }
}
