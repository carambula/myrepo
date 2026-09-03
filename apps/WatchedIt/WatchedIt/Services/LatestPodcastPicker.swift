import Foundation

enum LatestPodcastPicker {
    struct Entry: Equatable {
        let movieId: String
        let date: Date
        let sourceIdentifier: String
    }

    /// Newest episode from each podcast, newest show first.
    /// A full catalog dump can contain every historical episode; taking a global
    /// top-N by date lets one busy feed fill the carousel with old titles.
    static func carouselMovieIds(from entries: [Entry], limit: Int = 20) -> [String] {
        guard limit > 0, !entries.isEmpty else { return [] }

        var latestBySource: [String: Entry] = [:]
        for entry in entries {
            if let current = latestBySource[entry.sourceIdentifier] {
                if entry.date > current.date
                    || (entry.date == current.date && entry.movieId < current.movieId) {
                    latestBySource[entry.sourceIdentifier] = entry
                }
            } else {
                latestBySource[entry.sourceIdentifier] = entry
            }
        }

        let ordered = latestBySource.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if lhs.sourceIdentifier != rhs.sourceIdentifier {
                return lhs.sourceIdentifier < rhs.sourceIdentifier
            }
            return lhs.movieId < rhs.movieId
        }

        var seen = Set<String>()
        var movieIds: [String] = []
        movieIds.reserveCapacity(min(limit, ordered.count))
        for entry in ordered {
            if seen.insert(entry.movieId).inserted {
                movieIds.append(entry.movieId)
            }
            if movieIds.count == limit {
                break
            }
        }
        return movieIds
    }
}
