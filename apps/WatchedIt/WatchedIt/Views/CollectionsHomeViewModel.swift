//
//  CollectionsHomeViewModel.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class CollectionsHomeViewModel: ObservableObject {
    @Published private(set) var sections: [CollectionSection] = []
    @Published private(set) var rowMetadataByMovieIdentifier: [String: RowMetadata] = [:]
    @Published private(set) var movieToSourceIdentifiers: [String: Set<String>] = [:]
    @Published private(set) var isPrepared = false

    private var rebuildTask: Task<Void, Never>?
    private var lastSignature: Int = 0

    deinit {
        rebuildTask?.cancel()
    }

    func rebuildIfNeeded(
        movies: [Movie],
        dataSources: [DataSource],
        preferredListIdentifiers: [String],
        preferredStreamingServices: [String],
        modelContext: ModelContext
    ) {
        guard !movies.isEmpty, !dataSources.isEmpty else { return }

        var hasher = Hasher()
        hasher.combine(movies.count)
        hasher.combine(dataSources.count)
        hasher.combine(preferredListIdentifiers)
        hasher.combine(preferredStreamingServices)
        hasher.combine(movies.reduce(into: 0) { partial, movie in
            partial ^= movie.id.hashValue
            partial ^= movie.lastUpdated.hashValue
            partial ^= movie.isSaved.hashValue
            partial ^= movie.isRewatched.hashValue
            partial ^= movie.isListened.hashValue
        })
        let signature = hasher.finalize()
        guard signature != lastSignature else { return }
        lastSignature = signature

        rebuildTask?.cancel()
        isPrepared = false

        rebuildTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = CatalogSnapshotService.shared.buildSnapshot(
                movies: movies,
                dataSources: dataSources,
                preferredListIdentifiers: preferredListIdentifiers,
                modelContext: modelContext
            )
            let metadata = RowMetadataService.buildMetadata(
                movies: movies,
                movieToSourceIdentifiers: snapshot.movieToSourceIdentifiers,
                sourceNameByIdentifier: snapshot.sourceNameByIdentifier,
                preferredStreamingServices: preferredStreamingServices
            )
            guard !Task.isCancelled else { return }
            sections = snapshot.sections
            rowMetadataByMovieIdentifier = metadata
            movieToSourceIdentifiers = snapshot.movieToSourceIdentifiers
            isPrepared = true
        }
    }
}
