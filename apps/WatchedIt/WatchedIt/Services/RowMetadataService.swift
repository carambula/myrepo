//
//  RowMetadataService.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation

struct RowMetadata {
    let topPreferredStreamingService: String?
    let sourcesAndListsText: String
}

enum RowMetadataService {
    static func buildMetadata(
        movies: [Movie],
        movieToSourceIdentifiers: [String: Set<String>],
        sourceNameByIdentifier: [String: String],
        preferredStreamingServices: [String]
    ) -> [String: RowMetadata] {
        let preferredIndex = Dictionary(
            uniqueKeysWithValues: preferredStreamingServices.enumerated().map {
                (normalizeServiceName($1), $0)
            }
        )

        var metadataByMovieIdentifier: [String: RowMetadata] = [:]
        metadataByMovieIdentifier.reserveCapacity(movies.count)

        for movie in movies {
            let sourceNames = (movieToSourceIdentifiers[movie.id] ?? [])
                .compactMap { sourceNameByIdentifier[$0] }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            let sourcesAndListsText = sourceNames.joined(separator: ", ")

            let topService = movie.streamingServices
                .compactMap { service -> (index: Int, name: String)? in
                    let normalized = normalizeServiceName(service.name)
                    guard let index = preferredIndex[normalized] else { return nil }
                    return (index, service.name)
                }
                .sorted { lhs, rhs in lhs.index < rhs.index }
                .first?
                .name

            metadataByMovieIdentifier[movie.id] = RowMetadata(
                topPreferredStreamingService: topService,
                sourcesAndListsText: sourcesAndListsText
            )
        }

        return metadataByMovieIdentifier
    }

    private static func normalizeServiceName(_ value: String) -> String {
        StreamingServiceAssets.normalizedName(value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
