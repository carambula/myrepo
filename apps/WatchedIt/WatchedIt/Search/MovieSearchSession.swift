//
//  MovieSearchSession.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class MovieSearchSession: ObservableObject {
    @Published var query: String = ""
    @Published var filters = MovieSearchFilters()
    @Published private(set) var results: [Movie] = []
    @Published private(set) var isComputing: Bool = false
    @Published private(set) var availableGenres: [String] = []
    @Published private(set) var availableMPAARatings: [String] = []
    @Published private(set) var availableStreamingServices: [String] = []
    @Published private(set) var sourceLineByMovieID: [String: String] = [:]

    let title: String
    let allowsListFilter: Bool

    private let allMovies: [Movie]
    private let restrictedMovieIDs: Set<String>?
    private let preferredStreamingServices: [String]
    private var movieSearchIndex: [String: String] = [:]
    private var sourceCache: [String: Set<String>] = [:]
    private var recomputeTask: Task<Void, Never>?
    private var indexBuildTask: Task<[String: String], Never>?

    init(
        title: String,
        movies: [Movie],
        restrictedMovieIDs: Set<String>?,
        allowsListFilter: Bool,
        modelContext: ModelContext,
        preferredStreamingServices: [String]
    ) {
        self.title = title
        self.allMovies = movies
        self.restrictedMovieIDs = restrictedMovieIDs
        self.allowsListFilter = allowsListFilter
        self.preferredStreamingServices = preferredStreamingServices

        rebuildFilterOptions()
        sourceCache = Self.buildSourceCache(modelContext: modelContext)
        let sourceNameByIdentifier = Self.buildSourceNameByIdentifier(modelContext: modelContext)
        sourceLineByMovieID = Self.buildSourceLineCache(
            movieToSourceIdentifiers: sourceCache,
            sourceNameByIdentifier: sourceNameByIdentifier
        )
        results = initialScopedMovies()

        indexBuildTask = Task.detached(priority: .utility) { [allMovies] in
            MovieSearchEngine.buildIndex(from: allMovies)
        }

        Task { [weak self] in
            guard let self else { return }
            if let builtIndex = await indexBuildTask?.value {
                movieSearchIndex = builtIndex
            }
            scheduleRecompute(immediate: true)
        }
    }

    deinit {
        recomputeTask?.cancel()
        indexBuildTask?.cancel()
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        scheduleRecompute()
    }

    func updateFilters(_ update: (inout MovieSearchFilters) -> Void) {
        var copy = filters
        update(&copy)
        filters = copy
        scheduleRecompute()
    }

    func clearFilters() {
        filters = MovieSearchFilters()
        scheduleRecompute()
    }

    private func rebuildFilterOptions() {
        let pool = initialScopedMovies()

        availableGenres = Array(
            Set(pool.flatMap(\.genres).filter {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("TV Movie") != .orderedSame
            })
        ).sorted()

        availableMPAARatings = Array(
            Set(pool.compactMap(\.mpaaRating).filter { !$0.isEmpty })
        ).sorted()

        let uniqueServices = Set(pool.flatMap(\.streamingServices).map {
            StreamingServiceAssets.normalizedName($0.name)
        }.filter { !$0.isEmpty })
        availableStreamingServices = Array(uniqueServices).sorted()
    }

    private func initialScopedMovies() -> [Movie] {
        guard let restrictedMovieIDs, !restrictedMovieIDs.isEmpty else {
            return allMovies
        }
        return allMovies.filter { restrictedMovieIDs.contains($0.id) }
    }

    private func scheduleRecompute(immediate: Bool = false) {
        recomputeTask?.cancel()
        let querySnapshot = query
        let filtersSnapshot = filters
        let movieSnapshot = allMovies
        let indexSnapshot = movieSearchIndex
        let sourceCacheSnapshot = sourceCache
        let restrictedMovieIDsSnapshot = restrictedMovieIDs
        let preferredSnapshot = preferredStreamingServices

        recomputeTask = Task {
            if !immediate {
                do {
                    try await Task.sleep(nanoseconds: 70_000_000)
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }
            isComputing = true
            let computed = await Task.detached(priority: .userInitiated) {
                var mutableFilters = filtersSnapshot
                mutableFilters.preferredStreamingServices = preferredSnapshot
                return MovieSearchEngine.filterMovies(
                    movies: movieSnapshot,
                    query: querySnapshot,
                    filters: mutableFilters,
                    movieSearchIndex: indexSnapshot,
                    sourceCache: sourceCacheSnapshot,
                    restrictedMovieIDs: restrictedMovieIDsSnapshot
                )
            }.value
            guard !Task.isCancelled else { return }
            results = computed
            isComputing = false
        }
    }

    private static func buildSourceCache(modelContext: ModelContext) -> [String: Set<String>] {
        var cache: [String: Set<String>] = [:]
        
        // First, build cache from SourceContent (new schema) using a direct fetch
        let sourceContentDescriptor = FetchDescriptor<SourceContent>()
        if let sourceContents = try? modelContext.fetch(sourceContentDescriptor) {
            for sourceContent in sourceContents {
                // Safely access relationships with nil-coalescing to prevent crashes
                guard let movieID = sourceContent.movie?.id,
                      let sourceID = sourceContent.source?.identifier else {
                    continue
                }
                cache[movieID, default: Set<String>()].insert(sourceID)
            }
        }
        
        // Also check old schema (MovieDataSource) for backwards compatibility
        let movieDataSourceDescriptor = FetchDescriptor<MovieDataSource>()
        if let movieDataSources = try? modelContext.fetch(movieDataSourceDescriptor) {
            for movieDataSource in movieDataSources {
                // Safely access relationships with nil-coalescing to prevent crashes
                guard let movieID = movieDataSource.movie?.id,
                      let sourceID = movieDataSource.dataSource?.identifier else {
                    continue
                }
                cache[movieID, default: Set<String>()].insert(sourceID)
            }
        }

        return cache
    }

    private static func buildSourceNameByIdentifier(modelContext: ModelContext) -> [String: String] {
        let descriptor = FetchDescriptor<DataSource>()
        let dataSources = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: dataSources.map { ($0.identifier, $0.name) })
    }

    private static func buildSourceLineCache(
        movieToSourceIdentifiers: [String: Set<String>],
        sourceNameByIdentifier: [String: String]
    ) -> [String: String] {
        var sourceLineByMovieID: [String: String] = [:]
        sourceLineByMovieID.reserveCapacity(movieToSourceIdentifiers.count)

        for (movieID, sourceIDs) in movieToSourceIdentifiers {
            let names = sourceIDs
                .compactMap { sourceNameByIdentifier[$0] }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            if !names.isEmpty {
                sourceLineByMovieID[movieID] = names.joined(separator: ", ")
            }
        }

        return sourceLineByMovieID
    }
}
