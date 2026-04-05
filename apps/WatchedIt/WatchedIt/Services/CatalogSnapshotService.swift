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
        let latestPodcastDateByMovieIdentifier: [String: Date]
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
            latestPodcastDateByMovieIdentifier: sourceIndexData.latestPodcastDateByMovieIdentifier,
            preferredSourceIdentifiers: preferredSet,
            movieToSourceIdentifiers: sourceIndexData.movieToSourceIdentifiers
        )
        if !latestPodcastMovies.isEmpty {
            sections.append(
                CollectionSection(
                    id: "inspiration-latest-podcasts",
                    title: "Latest podcasts",
                    subtitle: "Recent episodes",
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
                latestPodcastDateByMovieIdentifier: [:]
            )
        }

        var movieToSourceIdentifiers: [String: Set<String>] = [:]
        var rankBySourceIdentifier: [String: [String: Int]] = [:]
        var latestPodcastDateBySourceIdentifier: [String: [String: Date]] = [:]
        var latestPodcastDateByMovieIdentifier: [String: Date] = [:]

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

                if let date = content.podcastEpisode?.publishDate ?? content.sourceDate {
                    let currentSourceDate = latestPodcastDateBySourceIdentifier[sourceIdentifier]?[movieIdentifier]
                    if currentSourceDate == nil || currentSourceDate! < date {
                        latestPodcastDateBySourceIdentifier[sourceIdentifier, default: [:]][movieIdentifier] = date
                    }
                    let currentMovieDate = latestPodcastDateByMovieIdentifier[movieIdentifier]
                    if currentMovieDate == nil || currentMovieDate! < date {
                        latestPodcastDateByMovieIdentifier[movieIdentifier] = date
                    }
                }
            }

            for dataSource in movieData.dataSources ?? [] {
                guard let source = dataSource.dataSource else { continue }
                let sourceIdentifier = source.identifier
                sourceIdentifiers.insert(sourceIdentifier)

                if let rank = dataSource.rank {
                    rankBySourceIdentifier[sourceIdentifier, default: [:]][movieIdentifier] = rank
                }

                if let date = dataSource.podcastEpisode?.publishDate {
                    let currentSourceDate = latestPodcastDateBySourceIdentifier[sourceIdentifier]?[movieIdentifier]
                    if currentSourceDate == nil || currentSourceDate! < date {
                        latestPodcastDateBySourceIdentifier[sourceIdentifier, default: [:]][movieIdentifier] = date
                    }
                    let currentMovieDate = latestPodcastDateByMovieIdentifier[movieIdentifier]
                    if currentMovieDate == nil || currentMovieDate! < date {
                        latestPodcastDateByMovieIdentifier[movieIdentifier] = date
                    }
                }
            }

            movieToSourceIdentifiers[movieIdentifier] = sourceIdentifiers
        }

        return SourceIndexData(
            movieToSourceIdentifiers: movieToSourceIdentifiers,
            rankBySourceIdentifier: rankBySourceIdentifier,
            latestPodcastDateBySourceIdentifier: latestPodcastDateBySourceIdentifier,
            latestPodcastDateByMovieIdentifier: latestPodcastDateByMovieIdentifier
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
            sectionMovies.sort { lhs, rhs in
                let leftDate = dates[lhs.id] ?? Date.distantPast
                let rightDate = dates[rhs.id] ?? Date.distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
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
        latestPodcastDateByMovieIdentifier: [String: Date],
        preferredSourceIdentifiers: Set<String>,
        movieToSourceIdentifiers: [String: Set<String>]
    ) -> [Movie] {
        let ordered = movies
            .filter { movie in
                guard latestPodcastDateByMovieIdentifier[movie.id] != nil else { return false }
                guard !preferredSourceIdentifiers.isEmpty else { return true }
                guard let sourceIdentifiers = movieToSourceIdentifiers[movie.id] else { return false }
                return !preferredSourceIdentifiers.intersection(sourceIdentifiers).isEmpty
            }
            .sorted { lhs, rhs in
                let leftDate = latestPodcastDateByMovieIdentifier[lhs.id] ?? Date.distantPast
                let rightDate = latestPodcastDateByMovieIdentifier[rhs.id] ?? Date.distantPast
                if leftDate != rightDate { return leftDate > rightDate }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        return Array(uniqueMoviesPreservingOrder(ordered).prefix(20))
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
