import Foundation

enum LatestPodcastPicker {
    static let defaultLimit = 50
    static let defaultMultiEntryLimit = 36

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
        sourceIdentifier == ClosetPicksSource.identifier
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

    struct SourceItem: Equatable {
        let movieId: String
        let date: Date?
        let title: String
    }

    /// Latest-first for a single podcast source. Missing dates go last so a
    /// catalog dump that stamps `lastUpdated` cannot jump old titles to the front.
    static func sourceCarouselMovieIds(from items: [SourceItem]) -> [String] {
        items.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (left?, right?):
                if left != right { return left > right }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
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
}
