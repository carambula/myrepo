import Foundation

enum LatestPodcastPicker {
    static let defaultLimit = 50
    static let defaultMultiEntryLimit = 36
    static let searchLimit = 100

    struct Entry: Equatable {
        let movieId: String
        let date: Date
        let sourceIdentifier: String
        let groupKey: String?

        init(movieId: String, date: Date, sourceIdentifier: String, groupKey: String? = nil) {
            self.movieId = movieId
            self.date = date
            self.sourceIdentifier = sourceIdentifier
            self.groupKey = groupKey
        }
    }

    static func allowsMultipleEntries(sourceIdentifier: String) -> Bool {
        ClosetPicksSource.sortsByRecency(sourceIdentifier)
    }

    static func entryDate(
        sourceIdentifier: String,
        sourceDate: Date?,
        episodePublishDate: Date?,
        discoveredAt: Date? = nil
    ) -> Date? {
        if allowsMultipleEntries(sourceIdentifier: sourceIdentifier) {
            return sourceDate ?? episodePublishDate ?? discoveredAt
        }
        return [episodePublishDate, sourceDate].compactMap { $0 }.max()
    }

    /// Newest episode from each podcast, newest show first.
    /// Closet Picks can contribute a whole drop (grouped by episode URL) so a
    /// guest episode does not collapse to a single poster.
    static func carouselMovieIds(
        from entries: [Entry],
        limit: Int = defaultLimit,
        multiEntryLimit: Int = defaultMultiEntryLimit
    ) -> [String] {
        guard limit > 0, !entries.isEmpty else { return [] }

        var regular: [Entry] = []
        var multiBySource: [String: [Entry]] = [:]
        for entry in entries {
            if allowsMultipleEntries(sourceIdentifier: entry.sourceIdentifier) {
                multiBySource[entry.sourceIdentifier, default: []].append(entry)
            } else {
                regular.append(entry)
            }
        }

        var selected: [Entry] = []
        selected.append(contentsOf: latestOnePerSource(regular))
        for sourceEntries in multiBySource.values {
            selected.append(contentsOf: latestGroups(from: sourceEntries, limit: multiEntryLimit))
        }

        let ordered = selected.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if let recency = compareRecency(lhs.groupKey, rhs.groupKey) {
                return recency
            }
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

    /// Newest episodes across every show, for header search. Same movie from
    /// multiple sources keeps the newest date. Caps so Latest does not dump
    /// the entire catalog.
    static func recentMovieIds(from entries: [Entry], limit: Int = searchLimit) -> [String] {
        guard limit > 0, !entries.isEmpty else { return [] }

        var newestDateByMovie: [String: Date] = [:]
        for entry in entries {
            if let current = newestDateByMovie[entry.movieId] {
                if entry.date > current {
                    newestDateByMovie[entry.movieId] = entry.date
                }
            } else {
                newestDateByMovie[entry.movieId] = entry.date
            }
        }

        return newestDateByMovie
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }

    struct SourceItem: Equatable {
        let movieId: String
        let date: Date?
        let title: String
        let recency: Int?

        init(movieId: String, date: Date?, title: String, recency: Int? = nil) {
            self.movieId = movieId
            self.date = date
            self.title = title
            self.recency = recency
        }
    }

    /// Latest-first for a single podcast or Closet Picks source. Missing dates
    /// go last so a catalog dump that stamps `lastUpdated` cannot jump old
    /// titles to the front. Closet Picks then uses Watch & Shop collection IDs
    /// (newer drops have higher IDs) when episode dates are missing or tied.
    static func sourceCarouselMovieIds(from items: [SourceItem], preferRecency: Bool = false) -> [String] {
        items.sorted { lhs, rhs in
            if preferRecency, let recency = compareRecency(lhs.recency, rhs.recency) {
                return recency
            }
            switch (lhs.date, rhs.date) {
            case let (left?, right?):
                if left != right { return left > right }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                break
            }
            if let recency = compareRecency(lhs.recency, rhs.recency) {
                return recency
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }.map(\.movieId)
    }

    private static func latestOnePerSource(_ entries: [Entry]) -> [Entry] {
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
        return Array(latestBySource.values)
    }

    private static func latestGroups(from entries: [Entry], limit: Int) -> [Entry] {
        guard limit > 0, !entries.isEmpty else { return [] }

        var groups: [String: (date: Date, entries: [Entry])] = [:]
        for entry in entries {
            let trimmedKey = entry.groupKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let key = trimmedKey.isEmpty ? entry.movieId : trimmedKey
            if var existing = groups[key] {
                if entry.date > existing.date {
                    existing.date = entry.date
                }
                existing.entries.append(entry)
                groups[key] = existing
            } else {
                groups[key] = (date: entry.date, entries: [entry])
            }
        }

        let orderedGroups = groups.values.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            if let recency = compareRecency(
                lhs.entries.compactMap(\.groupKey).first,
                rhs.entries.compactMap(\.groupKey).first
            ) {
                return recency
            }
            let lhsId = lhs.entries.map(\.movieId).min() ?? ""
            let rhsId = rhs.entries.map(\.movieId).min() ?? ""
            return lhsId < rhsId
        }

        var seen = Set<String>()
        var selected: [Entry] = []
        selected.reserveCapacity(min(limit, entries.count))
        for group in orderedGroups {
            let groupEntries = group.entries.sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date > rhs.date }
                return lhs.movieId < rhs.movieId
            }
            for entry in groupEntries {
                if seen.insert(entry.movieId).inserted {
                    selected.append(entry)
                }
                if selected.count == limit {
                    return selected
                }
            }
        }
        return selected
    }

    private static func compareRecency(_ lhs: Int?, _ rhs: Int?) -> Bool? {
        switch (lhs, rhs) {
        case let (left?, right?) where left != right:
            return left > right
        default:
            return nil
        }
    }

    private static func compareRecency(_ lhsKey: String?, _ rhsKey: String?) -> Bool? {
        compareRecency(
            ClosetPicksSource.shopCollectionID(from: lhsKey),
            ClosetPicksSource.shopCollectionID(from: rhsKey)
        )
    }
}
