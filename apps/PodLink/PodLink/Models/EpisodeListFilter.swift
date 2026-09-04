import Foundation

enum EpisodeListFilter {
    /// Returns `episodes` unchanged when search and status are idle so long show lists avoid a full scan.
    static func apply(
        _ episodes: [Episode],
        searchText: String,
        statusFilter: EpisodeStatusFilter
    ) -> [Episode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty && statusFilter == .all {
            return episodes
        }
        return episodes.filter { episode in
            guard statusFilter.matches(episode) else { return false }
            if query.isEmpty { return true }
            return episode.title.localizedCaseInsensitiveContains(query)
                || episode.description.localizedCaseInsensitiveContains(query)
        }
    }
}
