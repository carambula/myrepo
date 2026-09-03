#!/usr/bin/env swift

import Foundation
import SwiftData

/// Script to fix missing links in bootstrap database by comparing JSON to database
/// and ensuring all source-film associations are present

// MARK: - Data Structures

struct BootstrapDataSource: Codable {
    let identifier: String
    let name: String
    let type: String
    let url: String?
    let isRankedList: Bool
    let movieCount: Int
}

struct BootstrapMovie: Codable {
    let title: String
    let sourceIdentifier: String
    let rank: Int?
    let sourceTitle: String?
    
    // Enriched fields
    let tmdbId: Int?
    let year: Int?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let mpaaRating: String?
    let genres: [String]?
    let streamingServices: [BootstrapStreamingService]?
    let credits: BootstrapCredits?
    let trailer: BootstrapTrailer?
    let podcastEpisodeDescription: String?
}

struct BootstrapStreamingService: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int
}

struct BootstrapCredits: Codable {
    let director: String?
    let cast: [BootstrapCastMember]?
}

struct BootstrapCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
}

struct BootstrapTrailer: Codable {
    let id: String
    let name: String
    let youtubeKey: String
    let isOfficial: Bool
}

struct BootstrapData: Codable {
    let version: String?
    let generatedDate: String?
    let dataSources: [BootstrapDataSource]
    let movies: [BootstrapMovie]
}

// MARK: - Database Models (simplified for script)

@Model
final class MovieData {
    var id: String
    var title: String
    var year: Int?
    var tmdbId: Int?
    
    init(id: String, title: String, year: Int? = nil, tmdbId: Int? = nil) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbId = tmdbId
    }
}

@Model
final class DataSource {
    var identifier: String
    var name: String
    var type: String
    var isRankedList: Bool
    
    init(identifier: String, name: String, type: String, isRankedList: Bool) {
        self.identifier = identifier
        self.name = name
        self.type = type
        self.isRankedList = isRankedList
    }
}

@Model
final class SourceContent {
    var movie: MovieData?
    var source: DataSource?
    var sourceTitle: String?
    var rank: Int?
    var lastUpdated: Date
    var discoveredAt: Date
    
    init(movie: MovieData? = nil, source: DataSource? = nil, sourceTitle: String? = nil, rank: Int? = nil, lastUpdated: Date = Date(), discoveredAt: Date = Date()) {
        self.movie = movie
        self.source = source
        self.sourceTitle = sourceTitle
        self.rank = rank
        self.lastUpdated = lastUpdated
        self.discoveredAt = discoveredAt
    }
}

@Model
final class MovieDataSource {
    var movie: MovieData?
    var dataSource: DataSource?
    var sourceTitle: String?
    var rank: Int?
    var lastUpdated: Date
    
    init(movie: MovieData? = nil, dataSource: DataSource? = nil, sourceTitle: String? = nil, rank: Int? = nil, lastUpdated: Date = Date()) {
        self.movie = movie
        self.dataSource = dataSource
        self.sourceTitle = sourceTitle
        self.rank = rank
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Title Cleaning

func cleanTitle(_ title: String) -> String {
    var cleaned = title
    // Remove quotes
    cleaned = cleaned.replacingOccurrences(of: #"^['"]|['"]$"#, with: "", options: .regularExpression)
    // Remove list numbering
    cleaned = cleaned.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

func normalizeTitle(_ title: String) -> String {
    return cleanTitle(title).lowercased()
}

// MARK: - Main Function

@MainActor
func fixBootstrapDatabaseLinks() async throws {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let dbURL = URL(fileURLWithPath: "WatchedIt/bootstrap_database.store")
    
    print("📂 Loading bootstrap JSON...")
    let jsonData = try Data(contentsOf: jsonURL)
    let bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: jsonData)
    print("✅ Loaded \(bootstrapData.movies.count) movies from JSON")
    
    print("🗄️ Opening bootstrap database...")
    let schema = Schema([MovieData.self, DataSource.self, SourceContent.self, MovieDataSource.self])
    let config = ModelConfiguration(url: dbURL, allowsSave: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext
    
    // Load existing data
    let existingMovies = try context.fetch(FetchDescriptor<MovieData>())
    let existingSources = try context.fetch(FetchDescriptor<DataSource>())
    let existingSourceContents = try context.fetch(FetchDescriptor<SourceContent>())
    let existingMovieDataSourceLinks = try context.fetch(FetchDescriptor<MovieDataSource>())
    
    print("📊 Database state:")
    print("   Movies: \(existingMovies.count)")
    print("   Sources: \(existingSources.count)")
    print("   SourceContent links: \(existingSourceContents.count)")
    print("   MovieDataSource links: \(existingMovieDataSourceLinks.count)")
    
    // Build lookup maps
    var moviesByTmdbId: [Int: MovieData] = [:]
    var moviesByNormalizedTitle: [String: [MovieData]] = [:]
    var sourcesByIdentifier: [String: DataSource] = [:]
    
    for movie in existingMovies {
        if let tmdbId = movie.tmdbId {
            moviesByTmdbId[tmdbId] = movie
        }
        let normalized = normalizeTitle(movie.title)
        if moviesByNormalizedTitle[normalized] == nil {
            moviesByNormalizedTitle[normalized] = []
        }
        moviesByNormalizedTitle[normalized]?.append(movie)
    }
    
    for source in existingSources {
        sourcesByIdentifier[source.identifier] = source
    }
    
    // Build existing link map: (movieId, sourceId) -> SourceContent
    var existingLinks: [String: SourceContent] = [:]
    var existingMovieDataSourceMap: [String: MovieDataSource] = [:]
    
    for link in existingSourceContents {
        if let movieId = link.movie?.id, let sourceId = link.source?.identifier {
            existingLinks["\(movieId)-\(sourceId)"] = link
        }
    }
    
    for link in existingMovieDataSourceLinks {
        if let movieId = link.movie?.id, let sourceId = link.dataSource?.identifier {
            existingMovieDataSourceMap["\(movieId)-\(sourceId)"] = link
        }
    }
    
    print("\n🔍 Analyzing missing links and ranks...")
    
    // Count expected vs actual
    var expectedLinks: [String: Int] = [:]
    var actualLinks: [String: Int] = [:]
    
    for movie in bootstrapData.movies {
        expectedLinks[movie.sourceIdentifier, default: 0] += 1
    }
    
    for link in existingSourceContents {
        if let sourceId = link.source?.identifier {
            actualLinks[sourceId, default: 0] += 1
        }
    }
    
    print("\n📊 Link Count Comparison:")
    var totalMissing = 0
    for sourceId in Set(expectedLinks.keys).union(Set(actualLinks.keys)).sorted() {
        let expected = expectedLinks[sourceId] ?? 0
        let actual = actualLinks[sourceId] ?? 0
        let diff = expected - actual
        if diff != 0 {
            print("  ⚠️ \(sourceId): Expected \(expected), Actual \(actual), Missing \(diff)")
            totalMissing += diff
        } else {
            print("  ✅ \(sourceId): \(expected) links")
        }
    }
    
    print("\n🔧 Fixing missing links and ranks...")
    var linksCreated = 0
    var ranksFixed = 0
    var moviesNotFound = 0
    var sourcesNotFound = 0
    
    for (index, bootstrapMovie) in bootstrapData.movies.enumerated() {
        if index % 500 == 0 {
            print("   Processing \(index)/\(bootstrapData.movies.count)...")
        }
        
        // Find the movie
        var movie: MovieData? = nil
        
        // Try by TMDB ID first
        if let tmdbId = bootstrapMovie.tmdbId {
            movie = moviesByTmdbId[tmdbId]
        }
        
        // Try by normalized title (clean rank numbers from JSON title)
        if movie == nil {
            let normalized = normalizeTitle(bootstrapMovie.title)
            if let candidates = moviesByNormalizedTitle[normalized] {
                // If multiple candidates, prefer one matching year if available
                if let year = bootstrapMovie.year {
                    movie = candidates.first { $0.year == year } ?? candidates.first
                } else {
                    movie = candidates.first
                }
            }
        }
        
        // If still not found and title has rank number, try without it
        if movie == nil && bootstrapMovie.title.range(of: #"^\d+\."#, options: .regularExpression) != nil {
            let titleWithoutRank = bootstrapMovie.title.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizeTitle(titleWithoutRank)
            if let candidates = moviesByNormalizedTitle[normalized] {
                if let year = bootstrapMovie.year {
                    movie = candidates.first { $0.year == year } ?? candidates.first
                } else {
                    movie = candidates.first
                }
            }
        }
        
        guard let foundMovie = movie else {
            moviesNotFound += 1
            continue
        }
        
        // Find the source
        guard let source = sourcesByIdentifier[bootstrapMovie.sourceIdentifier] else {
            sourcesNotFound += 1
            continue
        }
        
        let linkKey = "\(foundMovie.id)-\(bootstrapMovie.sourceIdentifier)"
        let expectedRank = source.isRankedList ? bootstrapMovie.rank : nil
        
        // Check if link already exists
        if let existingLink = existingLinks[linkKey] {
            // Link exists - check if rank needs to be fixed
            if source.isRankedList {
                if existingLink.rank != expectedRank {
                    existingLink.rank = expectedRank
                    ranksFixed += 1
                }
            }
            
            // Also update MovieDataSource
            if let existingMovieDataSource = existingMovieDataSourceMap[linkKey] {
                if source.isRankedList {
                    if existingMovieDataSource.rank != expectedRank {
                        existingMovieDataSource.rank = expectedRank
                    }
                }
            }
        } else {
            // Create missing link
            let sourceContent = SourceContent(
                movie: foundMovie,
                source: source,
                sourceTitle: bootstrapMovie.sourceTitle,
                rank: expectedRank,
                lastUpdated: Date(),
                discoveredAt: Date()
            )
            context.insert(sourceContent)
            existingLinks[linkKey] = sourceContent
            
            // Also create MovieDataSource for backward compatibility
            let movieDataSource = MovieDataSource(
                movie: foundMovie,
                dataSource: source,
                sourceTitle: bootstrapMovie.sourceTitle,
                rank: expectedRank,
                lastUpdated: Date()
            )
            context.insert(movieDataSource)
            existingMovieDataSourceMap[linkKey] = movieDataSource
            
            linksCreated += 1
        }
        
        // Save periodically
        if (linksCreated + ranksFixed) % 100 == 0 {
            try context.save()
        }
    }
    
    // Final save
    try context.save()
    
    print("\n✅ Fix complete!")
    print("   Links created: \(linksCreated)")
    print("   Ranks fixed: \(ranksFixed)")
    print("   Movies not found: \(moviesNotFound)")
    print("   Sources not found: \(sourcesNotFound)")
}

// Run
Task { @MainActor in
    do {
        try await fixBootstrapDatabaseLinks()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

