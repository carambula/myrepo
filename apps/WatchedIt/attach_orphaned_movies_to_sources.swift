#!/usr/bin/env swift

import Foundation
import SwiftData

/// Script to find movies without source links and attach them to their correct sources
/// Uses bootstrap_data.json to determine which source each movie should belong to

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
    let tmdbId: Int?
    let year: Int?
}

struct BootstrapData: Codable {
    let version: String?
    let generatedDate: String?
    let dataSources: [BootstrapDataSource]
    let movies: [BootstrapMovie]
}

// MARK: - Database Models

@Model
final class MovieData {
    var id: String
    var title: String
    var year: Int?
    var tmdbId: Int?
    
    @Relationship(deleteRule: .cascade, inverse: \SourceContent.movie)
    var sourceContents: [SourceContent]?
    
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
    
    init(identifier: String, name: String, type: String, isRankedList: Bool = false) {
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

func normalizeTitle(_ title: String) -> String {
    var cleaned = title
    cleaned = cleaned.replacingOccurrences(of: #"^['"]|['"]$"#, with: "", options: .regularExpression)
    cleaned = cleaned.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

// MARK: - Main Function

@MainActor
func attachOrphanedMoviesToSources() async throws {
    print("🔍 Finding Movies Without Source Links\n")
    print(String(repeating: "=", count: 70))
    
    // Load JSON to determine which source each movie should belong to
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    guard FileManager.default.fileExists(atPath: jsonURL.path) else {
        print("❌ Error: bootstrap_data.json not found")
        exit(1)
    }
    
    print("\n📂 Loading bootstrap JSON...")
    let jsonData = try Data(contentsOf: jsonURL)
    let bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: jsonData)
    print("✅ Loaded \(bootstrapData.movies.count) movies from JSON")
    
    // Build map of movies to their sources from JSON
    // Map by TMDB ID first (most reliable), then by normalized title+year
    var movieToSourceByTmdbId: [Int: [BootstrapMovie]] = [:]
    var movieToSourceByTitle: [String: [BootstrapMovie]] = [:] // normalized title -> movies
    
    for movie in bootstrapData.movies {
        if let tmdbId = movie.tmdbId {
            if movieToSourceByTmdbId[tmdbId] == nil {
                movieToSourceByTmdbId[tmdbId] = []
            }
            movieToSourceByTmdbId[tmdbId]?.append(movie)
        }
        
        let normalized = normalizeTitle(movie.title)
        if movieToSourceByTitle[normalized] == nil {
            movieToSourceByTitle[normalized] = []
        }
        movieToSourceByTitle[normalized]?.append(movie)
    }
    
    // Load database
    let dbURL = URL(fileURLWithPath: "WatchedIt/bootstrap_database.store")
    guard FileManager.default.fileExists(atPath: dbURL.path) else {
        print("❌ Error: bootstrap_database.store not found")
        exit(1)
    }
    
    print("\n🗄️ Opening bootstrap database...")
    let schema = Schema([MovieData.self, DataSource.self, SourceContent.self, MovieDataSource.self])
    let config = ModelConfiguration(url: dbURL, allowsSave: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext
    
    // Fetch all data
    let allMovies = try context.fetch(FetchDescriptor<MovieData>())
    let allSources = try context.fetch(FetchDescriptor<DataSource>())
    let allSourceContents = try context.fetch(FetchDescriptor<SourceContent>())
    
    print("✅ Loaded from database:")
    print("   Movies: \(allMovies.count)")
    print("   Sources: \(allSources.count)")
    print("   SourceContent links: \(allSourceContents.count)")
    
    // Build lookup maps
    var sourcesByIdentifier: [String: DataSource] = [:]
    for source in allSources {
        sourcesByIdentifier[source.identifier] = source
    }
    
    // Build map of movies that have source links
    var moviesWithLinks: Set<String> = []
    for link in allSourceContents {
        if let movieId = link.movie?.id {
            moviesWithLinks.insert(movieId)
        }
    }
    
    // Find movies without any source links
    var orphanedMovies: [MovieData] = []
    for movie in allMovies {
        if !moviesWithLinks.contains(movie.id) {
            orphanedMovies.append(movie)
        }
    }
    
    print("\n📊 Analysis:")
    print("   Movies with source links: \(moviesWithLinks.count)")
    print("   Movies without source links: \(orphanedMovies.count)")
    
    if orphanedMovies.isEmpty {
        print("\n✅ No orphaned movies found! All movies have source links.")
        return
    }
    
    print("\n" + String(repeating: "=", count: 70))
    print("🔗 Attaching Orphaned Movies to Sources")
    print(String(repeating: "=", count: 70))
    
    var attachedCount = 0
    var notFoundInJSON = 0
    var sourceNotFound = 0
    
    for (index, movie) in orphanedMovies.enumerated() {
        if index % 50 == 0 && index > 0 {
            print("   Processing \(index)/\(orphanedMovies.count)...")
        }
        
        // Try to find this movie in JSON to determine its source
        var matchingBootstrapMovies: [BootstrapMovie] = []
        
        // First try by TMDB ID
        if let tmdbId = movie.tmdbId {
            matchingBootstrapMovies = movieToSourceByTmdbId[tmdbId] ?? []
        }
        
        // If not found by TMDB ID, try by normalized title
        if matchingBootstrapMovies.isEmpty {
            let normalized = normalizeTitle(movie.title)
            if let candidates = movieToSourceByTitle[normalized] {
                // Filter by year if available
                if let year = movie.year {
                    matchingBootstrapMovies = candidates.filter { $0.year == year }
                }
                if matchingBootstrapMovies.isEmpty {
                    matchingBootstrapMovies = candidates
                }
            }
        }
        
        if matchingBootstrapMovies.isEmpty {
            notFoundInJSON += 1
            continue
        }
        
        // Take the first matching bootstrap movie (or prefer one with rank)
        let bootstrapMovie = matchingBootstrapMovies.first(where: { $0.rank != nil }) ?? matchingBootstrapMovies.first!
        let sourceIdentifier = bootstrapMovie.sourceIdentifier
        
        // Find the source in database
        guard let source = sourcesByIdentifier[sourceIdentifier] else {
            sourceNotFound += 1
            print("   ⚠️  Source '\(sourceIdentifier)' not found for movie '\(movie.title)'")
            continue
        }
        
        // Create SourceContent link
        let sourceContent = SourceContent(
            movie: movie,
            source: source,
            sourceTitle: bootstrapMovie.sourceTitle ?? movie.title,
            rank: source.isRankedList ? bootstrapMovie.rank : nil,
            lastUpdated: Date(),
            discoveredAt: Date()
        )
        context.insert(sourceContent)
        
        // Also create MovieDataSource for backward compatibility
        let movieDataSource = MovieDataSource(
            movie: movie,
            dataSource: source,
            sourceTitle: bootstrapMovie.sourceTitle ?? movie.title,
            rank: source.isRankedList ? bootstrapMovie.rank : nil,
            lastUpdated: Date()
        )
        context.insert(movieDataSource)
        
        attachedCount += 1
        
        // Save periodically
        if attachedCount % 50 == 0 {
            try context.save()
        }
    }
    
    // Final save
    try context.save()
    
    print("\n" + String(repeating: "=", count: 70))
    print("✅ Attachment Complete!")
    print(String(repeating: "=", count: 70))
    print("\n📊 Results:")
    print("   Movies attached to sources: \(attachedCount)")
    print("   Movies not found in JSON: \(notFoundInJSON)")
    print("   Sources not found: \(sourceNotFound)")
    
    if notFoundInJSON > 0 {
        print("\n⚠️  \(notFoundInJSON) movies were not found in bootstrap_data.json")
        print("   These movies may need to be added to the JSON source file")
    }
    
    print("\n✅ Database updated successfully!")
}

// Run
Task { @MainActor in
    do {
        try await attachOrphanedMoviesToSources()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

