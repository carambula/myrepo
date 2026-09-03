//
//  MovieSearchEngine.swift
//  WatchedIt
//
//  Created by Cursor on 3/1/26.
//

import Foundation

struct MovieSearchFilters: Equatable {
    var watchFilter: WatchFilter = .all
    var selectedGenre: String? = nil
    var selectedMPAARating: String? = nil
    var selectedPersonName: String? = nil
    var selectedReleaseYear: Int? = nil
    var selectedListIdentifier: String? = nil
    var selectedStreamingService: String? = nil
    var theatricalFilter: TheatricalFilter? = nil
    var sortOption: SortOption = .episodeDateDesc
    var preferredStreamingServices: [String] = []
}

enum MovieSearchEngine {
    nonisolated static func buildIndex(from movies: [Movie]) -> [String: String] {
        var index: [String: String] = [:]
        index.reserveCapacity(movies.count)

        for movie in movies {
            var fields: [String] = [movie.title]
            if let year = movie.year { fields.append(String(year)) }
            if let overview = movie.overview { fields.append(overview) }
            if let mpaaRating = movie.mpaaRating { fields.append(mpaaRating) }
            fields.append(contentsOf: movie.genres)
            fields.append(contentsOf: movie.streamingServices.map(\.name))

            if let credits = movie.credits {
                if let director = credits.director { fields.append(director) }
                fields.append(contentsOf: credits.cast.map(\.name))
            }

            if let episode = movie.podcastEpisode {
                fields.append(episode.title)
            }

            if let media = movie.physicalMedia {
                fields.append(contentsOf: media.searchTokens)
            }

            if let run = movie.theatricalRun {
                fields.append(contentsOf: run.searchTokens)
            }

            index[movie.id] = fields.joined(separator: " ").lowercased()
        }

        return index
    }

    nonisolated static func filterMovies(
        movies: [Movie],
        query: String,
        filters: MovieSearchFilters,
        movieSearchIndex: [String: String],
        sourceCache: [String: Set<String>],
        restrictedMovieIDs: Set<String>?
    ) -> [Movie] {
        var filtered = movies
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = trimmedQuery.lowercased()
        let queryTerms = normalizedQuery.split(whereSeparator: \.isWhitespace).map(String.init)

        if let restrictedMovieIDs, !restrictedMovieIDs.isEmpty {
            filtered = filtered.filter { restrictedMovieIDs.contains($0.id) }
        }

        if !normalizedQuery.isEmpty {
            filtered = filtered.filter { movie in
                if let indexedContent = movieSearchIndex[movie.id] {
                    if queryTerms.isEmpty {
                        return indexedContent.contains(normalizedQuery)
                    }
                    for term in queryTerms where !indexedContent.contains(term) {
                        return false
                    }
                    return true
                }
                if movie.title.lowercased().contains(normalizedQuery) {
                    return true
                }
                if let year = movie.year, String(year).contains(trimmedQuery) {
                    return true
                }
                return false
            }
        }

        switch filters.watchFilter {
        case .all:
            break
        case .completed:
            filtered = filtered.filter { $0.isRewatched && $0.isListened }
        case .incomplete:
            filtered = filtered.filter { $0.isRewatched != $0.isListened }
        case .rewatched:
            filtered = filtered.filter { $0.isRewatched }
        case .listened:
            filtered = filtered.filter { $0.isListened }
        case .saved:
            filtered = filtered.filter { $0.isSaved }
        }

        if let selectedGenre = filters.selectedGenre {
            filtered = filtered.filter { $0.genres.contains(selectedGenre) }
        }

        if let selectedMPAARating = filters.selectedMPAARating {
            filtered = filtered.filter { $0.mpaaRating == selectedMPAARating }
        }

        if let selectedPersonName = filters.selectedPersonName {
            filtered = filtered.filter { movie in
                movieMatchesPersonFilter(movie, personName: selectedPersonName)
            }
        }

        if let selectedReleaseYear = filters.selectedReleaseYear {
            filtered = filtered.filter { $0.year == selectedReleaseYear }
        }

        if let selectedListIdentifier = filters.selectedListIdentifier {
            filtered = filtered.filter { movie in
                sourceCache[movie.id]?.contains(selectedListIdentifier) == true
            }
        }

        if let theatricalFilter = filters.theatricalFilter {
            filtered = filtered.filter { $0.theatricalRun?.matches(theatricalFilter) == true }
        }

        if let selectedStreamingService = filters.selectedStreamingService {
            if selectedStreamingService == "My Services" {
                let preferredKeys = Set(filters.preferredStreamingServices.map {
                    normalizeServiceName($0)
                })
                guard !preferredKeys.isEmpty else {
                    return filtered
                }
                filtered = filtered.filter { movie in
                    movie.streamingServices.contains { service in
                        preferredKeys.contains(normalizeServiceName(service.name))
                    }
                }
            } else {
                let normalizedSelected = normalizeServiceName(selectedStreamingService)
                filtered = filtered.filter { movie in
                    movie.streamingServices.contains { service in
                        normalizeServiceName(service.name) == normalizedSelected
                    }
                }
            }
        }

        switch filters.sortOption {
        case .title:
            filtered.sort { $0.title < $1.title }
        case .releaseDateAsc:
            filtered.sort {
                let y1 = $0.year ?? 0
                let y2 = $1.year ?? 0
                if y1 != y2 { return y1 < y2 }
                return $0.title < $1.title
            }
        case .releaseDateDesc:
            filtered.sort {
                let y1 = $0.year ?? 0
                let y2 = $1.year ?? 0
                if y1 != y2 { return y1 > y2 }
                return $0.title < $1.title
            }
        case .episodeDateAsc:
            filtered.sort {
                let d1 = $0.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = $1.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 < d2 }
                return $0.title < $1.title
            }
        case .episodeDateDesc:
            filtered.sort {
                let d1 = $0.podcastEpisode?.publishDate ?? Date.distantPast
                let d2 = $1.podcastEpisode?.publishDate ?? Date.distantPast
                if d1 != d2 { return d1 > d2 }
                return $0.title < $1.title
            }
        case .ranking:
            filtered.sort { $0.title < $1.title }
        }

        return filtered
    }

    private nonisolated static func normalizeServiceName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private nonisolated static func movieMatchesPersonFilter(_ movie: Movie, personName: String) -> Bool {
        guard let credits = movie.credits else { return false }
        if let director = credits.director, director.localizedCaseInsensitiveContains(personName) {
            return true
        }
        return credits.cast.contains { castMember in
            castMember.name.localizedCaseInsensitiveContains(personName)
        }
    }
}
