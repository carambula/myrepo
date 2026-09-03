//
//  CatalogSnapshotService.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation
import SwiftData

struct CollectionSection: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?
    let sourceIdentifier: String?
    let movies: [Movie]
}

struct CatalogSnapshot {
    let sections: [CollectionSection]
    let movieToSourceIdentifiers: [String: Set<String>]
    let sourceNameByIdentifier: [String: String]
}

@MainActor
final class CatalogSnapshotService {
    static let shared = CatalogSnapshotService()
    private init() {}

    private struct SourceSummary {
        let identifier: String
        let name: String
        let type: String
        let isRankedList: Bool
        let isEnabled: Bool
    }

    private struct SourceIndexData {
        let movieToSourceIdentifiers: [String: Set<String>]
        let rankBySourceIdentifier: [String: [String: Int]]
        let latestPodcastDateBySourceIdentifier: [String: [String: Date]]
        let latestGroupKeyBySourceIdentifier: [String: [String: String]]
    }

    func buildSnapshot(
        movies: [Movie],
        dataSources: [DataSource],
        preferredListIdentifiers: [String],
        modelContext: ModelContext?
    ) -> CatalogSnapshot {
        let sourceSummaries = dataSources.map {
            SourceSummary(
                identifier: $0.identifier,
                name: $0.name,
                type: $0.type,
                isRankedList: $0.isRankedList,
                isEnabled: $0.isEnabled
            )
        }
        let sourceNameByIdentifier = Dictionary(uniqueKeysWithValues: sourceSummaries.map { ($0.identifier, $0.name) })
        let preferredSet = Set(preferredListIdentifiers)
        let sourceIndexData = buildSourceIndexData(modelContext: modelContext)
        let movieByIdentifier = Dictionary(uniqueKeysWithValues: movies.map { ($0.id, $0) })

        let orderedSourceSummaries = sourceSummaries
            .filter { $0.isEnabled && preferredSet.contains($0.identifier) }
            .sorted { lhs, rhs in
                let lhsIndex = preferredListIdentifiers.firstIndex(of: lhs.identifier) ?? Int.max
                let rhsIndex = preferredListIdentifiers.firstIndex(of: rhs.identifier) ?? Int.max
                return lhsIndex < rhsIndex
            }

        var sections: [CollectionSection] = []
        sections.reserveCapacity(orderedSourceSummaries.count + 4)

        let latestPodcastMovies = buildLatestPodcastMovies(
            movies: movies,
            latestPodcastDateBySourceIdentifier: sourceIndexData.latestPodcastDateBySourceIdentifier,
            latestGroupKeyBySourceIdentifier: sourceIndexData.latestGroupKeyBySourceIdentifier,
            preferredSourceIdentifiers: preferredSet,
            movieToSourceIdentifiers: sourceIndexData.movieToSourceIdentifiers
        )
        if !latestPodcastMovies.isEmpty {
            sections.append(
                CollectionSection(
                    id: "inspiration-latest-podcasts",
                    title: "Latest",
                    subtitle: "Recent episodes and Closet Picks",
                    sourceIdentifier: nil,
                    movies: latestPodcastMovies
                )
            )
        }

        let recentlySaved = uniqueMoviesPreservingOrder(
            movies
                .filter { $0.isSaved }
                .sorted { $0.lastUpdated > $1.lastUpdated }
                .prefix(25)
                .map { $0 }
        )
        if !recentlySaved.isEmpty {
            sections.append(
                CollectionSection(
                    id: "inspiration-recently-saved",
                    title: "Recently saved",
                    subtitle: "Continue where you left off",
                    sourceIdentifier: nil,
                    movies: recentlySaved
                )
            )
        }

        let toComplete = uniqueMoviesPreservingOrder(
            movies
                .filter { isToCompleteMovie($0) }
                .sorted { $0.lastUpdated > $1.lastUpdated }
                .prefix(25)
                .map { $0 }
        )
        if !toComplete.isEmpty {
            sections.append(
                CollectionSection(
                    id: "inspiration-to-complete",
                    title: "To complete",
                    subtitle: "Half-finished picks",
                    sourceIdentifier: nil,
                    movies: toComplete
                )
            )
        }

        for source in orderedSourceSummaries {
            let sectionMovies = moviesForSource(
                source,
                allMovies: movieByIdentifier,
                movieToSourceIdentifiers: sourceIndexData.movieToSourceIdentifiers,
                rankBySourceIdentifier: sourceIndexData.rankBySourceIdentifier,
                latestPodcastDateBySourceIdentifier: sourceIndexData.latestPodcastDateBySourceIdentifier
            )
            guard !sectionMovies.isEmpty else { continue }
            sections.append(
                CollectionSection(
                    id: "source-\(source.identifier)",
                    title: source.name,
                    subtitle: source.isRankedList ? "Ranked list" : (source.type == "podcast" ? "Podcast collection" : nil),
                    sourceIdentifier: source.identifier,
                    movies: Array(sectionMovies.prefix(25))
                )
            )
        }

        return CatalogSnapshot(
            sections: sections,
            movieToSourceIdentifiers: sourceIndexData.movieToSourceIdentifiers,
            sourceNameByIdentifier: sourceNameByIdentifier
        )
    }

    private func buildSourceIndexData(modelContext: ModelContext?) -> SourceIndexData {
        guard let modelContext else {
            return SourceIndexData(
                movieToSourceIdentifiers: [:],
                rankBySourceIdentifier: [:],
                latestPodcastDateBySourceIdentifier: [:],
                latestGroupKeyBySourceIdentifier: [:]
            )
        }

        var movieToSourceIdentifiers: [String: Set<String>] = [:]
        var rankBySourceIdentifier: [String: [String: Int]] = [:]
        var latestPodcastDateBySourceIdentifier: [String: [String: Date]] = [:]
        var latestGroupKeyBySourceIdentifier: [String: [String: String]] = [:]

        let descriptor = FetchDescriptor<MovieData>()
        let movieDataList = (try? modelContext.fetch(descriptor)) ?? []

        for movieData in movieDataList {
            guard movieData.modelContext != nil else { continue }
            let movieIdentifier = movieData.id
            var sourceIdentifiers = movieToSourceIdentifiers[movieIdentifier, default: Set<String>()]

            for content in movieData.sourceContents ?? [] {
                guard let source = content.source else { continue }
                let sourceIdentifier = source.identifier
                sourceIdentifiers.insert(sourceIdentifier)

                if let rank = content.rank {
                    rankBySourceIdentifier[sourceIdentifier, default: [:]][movieIdentifier] = rank
                }

                if source.type == "podcast" || LatestPodcastPicker.allowsMultipleEntries(sourceIdentifier: sourceIdentifier) {
                    recordLatestEntry(
                        sourceIdentifier: sourceIdentifier,
                        movieIdentifier: movieIdentifier,
                        date: LatestPodcastPicker.entryDate(
                            sourceIdentifier: sourceIdentifier,
                            sourceDate: content.sourceDate,
                            episodePublishDate: content.podcastEpisode?.publishDate,
                            discoveredAt: content.discoveredAt
                        ),
                        groupKey: content.sourceUrl,
                        dates: &latestPodcastDateBySourceIdentifier,
                        groupKeys: &latestGroupKeyBySourceIdentifier
                    )
                }
            }

            for dataSource in movieData.dataSources ?? [] {
                guard let source = dataSource.dataSource else { continue }
                let sourceIdentifier = source.identifier
                sourceIdentifiers.insert(sourceIdentifier)

                if let rank = dataSource.rank {
                    rankBySourceIdentifier[sourceIdentifier, default: [:]][movieIdentifier] = rank
                }

                if source.type == "podcast" || LatestPodcastPicker.allowsMultipleEntries(sourceIdentifier: sourceIdentifier) {
                    recordLatestEntry(
                        sourceIdentifier: sourceIdentifier,
                        movieIdentifier: movieIdentifier,
                        date: LatestPodcastPicker.entryDate(
                            sourceIdentifier: sourceIdentifier,
                            sourceDate: nil,
                            episodePublishDate: dataSource.podcastEpisode?.publishDate,
                            discoveredAt: LatestPodcastPicker.allowsMultipleEntries(sourceIdentifier: sourceIdentifier)
                                ? dataSource.lastUpdated
                                : nil
                        ),
                        groupKey: dataSource.sourceUrl,
                        dates: &latestPodcastDateBySourceIdentifier,
                        groupKeys: &latestGroupKeyBySourceIdentifier
                    )
                }
            }

            movieToSourceIdentifiers[movieIdentifier] = sourceIdentifiers
        }

        return SourceIndexData(
            movieToSourceIdentifiers: movieToSourceIdentifiers,
            rankBySourceIdentifier: rankBySourceIdentifier,
            latestPodcastDateBySourceIdentifier: latestPodcastDateBySourceIdentifier,
            latestGroupKeyBySourceIdentifier: latestGroupKeyBySourceIdentifier
        )
    }

    private func moviesForSource(
        _ source: SourceSummary,
        allMovies: [String: Movie],
        movieToSourceIdentifiers: [String: Set<String>],
        rankBySourceIdentifier: [String: [String: Int]],
        latestPodcastDateBySourceIdentifier: [String: [String: Date]]
    ) -> [Movie] {
        let movieIdentifiers = movieToSourceIdentifiers
            .compactMap { movieIdentifier, sourceIdentifiers in
                sourceIdentifiers.contains(source.identifier) ? movieIdentifier : nil
            }

        var sectionMovies = movieIdentifiers.compactMap { allMovies[$0] }
        guard !sectionMovies.isEmpty else { return [] }

        if source.isRankedList {
            let ranks = rankBySourceIdentifier[source.identifier] ?? [:]
            sectionMovies.sort { lhs, rhs in
                let leftRank = ranks[lhs.id]
                let rightRank = ranks[rhs.id]
                switch (leftRank, rightRank) {
                case let (l?, r?):
                    return l == r
                        ? lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                        : l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
        } else if source.type == "podcast" {
            let dates = latestPodcastDateBySourceIdentifier[source.identifier] ?? [:]
            let movieByIdentifier = Dictionary(uniqueKeysWithValues: sectionMovies.map { ($0.id, $0) })
            let orderedIds = LatestPodcastPicker.sourceCarouselMovieIds(
                from: sectionMovies.map {
                    LatestPodcastPicker.SourceItem(
                        movieId: $0.id,
                        date: dates[$0.id] ?? $0.podcastEpisode?.publishDate,
                        title: $0.title
                    )
                }
            )
            return uniqueMoviesPreservingOrder(orderedIds.compactMap { movieByIdentifier[$0] })
        } else {
            sectionMovies.sort { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }

        let saved = sectionMovies.filter(\.isSaved)
        let toComplete = sectionMovies.filter { isToCompleteMovie($0) && !$0.isSaved }
        let remaining = sectionMovies.filter { !$0.isSaved && !isToCompleteMovie($0) }
        return uniqueMoviesPreservingOrder(saved + toComplete + remaining)
    }

    private func buildLatestPodcastMovies(
        movies: [Movie],
        latestPodcastDateBySourceIdentifier: [String: [String: Date]],
        latestGroupKeyBySourceIdentifier: [String: [String: String]],
        preferredSourceIdentifiers: Set<String>,
        movieToSourceIdentifiers: [String: Set<String>]
    ) -> [Movie] {
        let movieByIdentifier = Dictionary(uniqueKeysWithValues: movies.map { ($0.id, $0) })
        var entries: [LatestPodcastPicker.Entry] = []
        let groupKeys = latestGroupKeyBySourceIdentifier
        for (sourceIdentifier, dateByMovie) in latestPodcastDateBySourceIdentifier {
            if !preferredSourceIdentifiers.isEmpty,
               !preferredSourceIdentifiers.contains(sourceIdentifier) {
                continue
            }
            for (movieIdentifier, date) in dateByMovie {
                guard movieByIdentifier[movieIdentifier] != nil else { continue }
                if !preferredSourceIdentifiers.isEmpty {
                    guard let sourceIdentifiers = movieToSourceIdentifiers[movieIdentifier],
                          sourceIdentifiers.contains(sourceIdentifier) else {
                        continue
                    }
                }
                entries.append(
                    LatestPodcastPicker.Entry(
                        movieId: movieIdentifier,
                        date: date,
                        sourceIdentifier: sourceIdentifier,
                        groupKey: groupKeys[sourceIdentifier]?[movieIdentifier]
                    )
                )
            }
        }
        let movieIds = LatestPodcastPicker.carouselMovieIds(from: entries)
        return movieIds.compactMap { movieByIdentifier[$0] }
    }

    private func recordLatestEntry(
        sourceIdentifier: String,
        movieIdentifier: String,
        date: Date?,
        groupKey: String?,
        dates: inout [String: [String: Date]],
        groupKeys: inout [String: [String: String]]
    ) {
        guard let date else { return }
        let currentSourceDate = dates[sourceIdentifier]?[movieIdentifier]
        if currentSourceDate == nil || currentSourceDate! < date {
            dates[sourceIdentifier, default: [:]][movieIdentifier] = date
            let trimmedKey = groupKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmedKey.isEmpty {
                groupKeys[sourceIdentifier, default: [:]][movieIdentifier] = trimmedKey
            }
        }
    }

    private func isToCompleteMovie(_ movie: Movie) -> Bool {
        movie.podcastEpisode != nil
            && (movie.isListened || movie.isRewatched)
            && movie.isListened != movie.isRewatched
    }

    private func uniqueMoviesPreservingOrder(_ movies: [Movie]) -> [Movie] {
        var seen: Set<String> = []
        return movies.filter { seen.insert($0.id).inserted }
    }
}
