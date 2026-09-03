#!/usr/bin/env swift

import Foundation
import SwiftData

/// Diagnostic script to analyze bootstrap database for missing source associations
/// Reports movies without source links and compares JSON expectations vs database reality

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

// MARK: - Database Models (simplified)

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
    
    init(identifier: String, name: String, type: String) {
        self.identifier = identifier
        self.name = name
        self.type = type
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

// MARK: - Main Diagnostic Function

@MainActor
func diagnoseBootstrapDatabase() async throws {
    print("🔍 Bootstrap Database Diagnostic\n")
    print(String(repeating: "=", count: 70))
    
    // Load JSON
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    guard FileManager.default.fileExists(atPath: jsonURL.path) else {
        print("❌ Error: bootstrap_data.json not found")
        exit(1)
    }
    
    print("\n📂 Loading bootstrap JSON...")
    let jsonData = try Data(contentsOf: jsonURL)
    let bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: jsonData)
    print("✅ Loaded \(bootstrapData.dataSources.count) sources and \(bootstrapData.movies.count) movies from JSON")
    
    // Load database - copy to temp location to avoid migration issues
    let sourceDBURL = URL(fileURLWithPath: "WatchedIt/bootstrap_database.store")
    guard FileManager.default.fileExists(atPath: sourceDBURL.path) else {
        print("❌ Error: bootstrap_database.store not found")
        exit(1)
    }
    
    print("\n🗄️ Opening bootstrap database...")
    
    // Copy to temp location for read access
    let tempDir = FileManager.default.temporaryDirectory
    let tempDBURL = tempDir.appendingPathComponent("diagnostic_db_\(UUID().uuidString).store")
    try FileManager.default.copyItem(at: sourceDBURL, to: tempDBURL)
    defer {
        try? FileManager.default.removeItem(at: tempDBURL)
    }
    
    let schema = Schema([MovieData.self, DataSource.self, SourceContent.self, MovieDataSource.self])
    let config = ModelConfiguration(url: tempDBURL, allowsSave: true, cloudKitDatabase: .none)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext
    
    // Fetch all data
    let allMovies = try context.fetch(FetchDescriptor<MovieData>())
    let allSources = try context.fetch(FetchDescriptor<DataSource>())
    let allSourceContents = try context.fetch(FetchDescriptor<SourceContent>())
    let allMovieDataSourceLinks = try context.fetch(FetchDescriptor<MovieDataSource>())
    
    print("✅ Loaded from database:")
    print("   Movies: \(allMovies.count)")
    print("   Sources: \(allSources.count)")
    print("   SourceContent links: \(allSourceContents.count)")
    print("   MovieDataSource links: \(allMovieDataSourceLinks.count)")
    
    // Build lookup maps
    var moviesByTmdbId: [Int: MovieData] = [:]
    var moviesByNormalizedTitle: [String: [MovieData]] = [:]
    var sourcesByIdentifier: [String: DataSource] = [:]
    
    for movie in allMovies {
        if let tmdbId = movie.tmdbId {
            moviesByTmdbId[tmdbId] = movie
        }
        let normalized = normalizeTitle(movie.title)
        if moviesByNormalizedTitle[normalized] == nil {
            moviesByNormalizedTitle[normalized] = []
        }
        moviesByNormalizedTitle[normalized]?.append(movie)
    }
    
    for source in allSources {
        sourcesByIdentifier[source.identifier] = source
    }
    
    // Build existing link maps
    var movieSourceLinks: [String: Set<String>] = [:] // movieId -> Set<sourceIdentifier>
    for link in allSourceContents {
        if let movieId = link.movie?.id, let sourceId = link.source?.identifier {
            if movieSourceLinks[movieId] == nil {
                movieSourceLinks[movieId] = []
            }
            movieSourceLinks[movieId]?.insert(sourceId)
        }
    }
    
    // Count expected links per source
    var expectedLinksPerSource: [String: Int] = [:]
    for movie in bootstrapData.movies {
        expectedLinksPerSource[movie.sourceIdentifier, default: 0] += 1
    }
    
    // Count actual links per source
    var actualLinksPerSource: [String: Int] = [:]
    for link in allSourceContents {
        if let sourceId = link.source?.identifier {
            actualLinksPerSource[sourceId, default: 0] += 1
        }
    }
    
    // Find movies with no source links
    var moviesWithoutSources: [MovieData] = []
    for movie in allMovies {
        let linkCount = movieSourceLinks[movie.id]?.count ?? 0
        if linkCount == 0 {
            moviesWithoutSources.append(movie)
        }
    }
    
    // REPORT SECTION
    print("\n" + String(repeating: "=", count: 70))
    print("📊 DIAGNOSTIC REPORT")
    print(String(repeating: "=", count: 70))
    
    // 1. Source Link Counts Comparison
    print("\n1️⃣ SOURCE LINK COUNTS (JSON Expected vs Database Actual):")
    print(String(repeating: "-", count: 70))
    var totalMissing = 0
    for sourceId in Set(expectedLinksPerSource.keys).union(Set(actualLinksPerSource.keys)).sorted() {
        let expected = expectedLinksPerSource[sourceId] ?? 0
        let actual = actualLinksPerSource[sourceId] ?? 0
        let diff = expected - actual
        let sourceName = bootstrapData.dataSources.first { $0.identifier == sourceId }?.name ?? sourceId
        if diff != 0 {
            print("  ⚠️  \(sourceName) (\(sourceId)):")
            print("      Expected: \(expected) links")
            print("      Actual:   \(actual) links")
            print("      Missing:  \(diff) links")
            totalMissing += diff
        } else {
            print("  ✅ \(sourceName) (\(sourceId)): \(expected) links")
        }
    }
    
    // 2. Movies Without Any Source Links
    print("\n2️⃣ MOVIES WITHOUT ANY SOURCE LINKS:")
    print(String(repeating: "-", count: 70))
    print("   Total movies with 0 source links: \(moviesWithoutSources.count)")
    if !moviesWithoutSources.isEmpty {
        print("\n   Sample of movies without sources (first 20):")
        for (index, movie) in moviesWithoutSources.prefix(20).enumerated() {
            print("   \(index + 1). \(movie.title)\(movie.year.map { " (\($0))" } ?? "") [ID: \(movie.id)]")
        }
        if moviesWithoutSources.count > 20 {
            print("   ... and \(moviesWithoutSources.count - 20) more")
        }
    }
    
    // 3. Check for "Breaking Away" specifically
    print("\n3️⃣ SEARCHING FOR 'BREAKING AWAY':")
    print(String(repeating: "-", count: 70))
    let breakingAwayVariations = ["Breaking Away", "breaking away", "BREAKING AWAY"]
    var foundBreakingAway: [MovieData] = []
    
    for movie in allMovies {
        if breakingAwayVariations.contains(movie.title) || movie.title.lowercased().contains("breaking away") {
            foundBreakingAway.append(movie)
        }
    }
    
    if foundBreakingAway.isEmpty {
        print("  ❌ 'Breaking Away' NOT FOUND in database")
        
        // Check if it exists in JSON
        let inJSON = bootstrapData.movies.first { movie in
            normalizeTitle(movie.title).contains("breaking away")
        }
        if let jsonMovie = inJSON {
            print("  ⚠️  But it EXISTS in bootstrap_data.json:")
            print("      Title: \(jsonMovie.title)")
            print("      Source: \(jsonMovie.sourceIdentifier)")
            print("      TMDB ID: \(jsonMovie.tmdbId ?? 0)")
            print("      Year: \(jsonMovie.year ?? 0)")
            print("  💡 This suggests the database generation failed to create this movie entry")
        } else {
            print("  ⚠️  Also NOT FOUND in bootstrap_data.json")
            print("  💡 This movie needs to be added to the JSON source data")
        }
    } else {
        for movie in foundBreakingAway {
            print("  ✅ Found: \(movie.title) [ID: \(movie.id), Year: \(movie.year ?? 0), TMDB: \(movie.tmdbId ?? 0)]")
            let sources = movieSourceLinks[movie.id] ?? []
            if sources.isEmpty {
                print("     ❌ Has NO source links attached")
            } else {
                print("     ✅ Has \(sources.count) source link(s): \(sources.joined(separator: ", "))")
                
                // Check if Rewatchables is in the list
                if sources.contains("rewatchables") {
                    print("     ✅ Rewatchables link exists")
                } else {
                    print("     ❌ Missing Rewatchables link (should have it)")
                    
                    // Check JSON
                    let shouldHaveRewatchables = bootstrapData.movies.contains { bootstrapMovie in
                        normalizeTitle(bootstrapMovie.title).contains("breaking away") &&
                        bootstrapMovie.sourceIdentifier == "rewatchables"
                    }
                    if shouldHaveRewatchables {
                        print("     💡 JSON indicates this should have Rewatchables link")
                    }
                }
            }
        }
    }
    
    // 4. Rewatchables-specific analysis
    print("\n4️⃣ REWATCHABLES SOURCE ANALYSIS:")
    print(String(repeating: "-", count: 70))
    let rewatchablesExpected = expectedLinksPerSource["rewatchables"] ?? 0
    let rewatchablesActual = actualLinksPerSource["rewatchables"] ?? 0
    print("   Expected: \(rewatchablesExpected) movies")
    print("   Actual:   \(rewatchablesActual) movies")
    print("   Missing:  \(rewatchablesExpected - rewatchablesActual) movies")
    
    // Find Rewatchables movies from JSON that might be missing from database
    let rewatchablesMoviesInJSON = bootstrapData.movies.filter { $0.sourceIdentifier == "rewatchables" }
    var missingFromDatabase: [BootstrapMovie] = []
    
    for jsonMovie in rewatchablesMoviesInJSON {
        var found = false
        
        // Try to find by TMDB ID
        if let tmdbId = jsonMovie.tmdbId, moviesByTmdbId[tmdbId] != nil {
            found = true
        }
        
        // Try to find by title
        if !found {
            let normalized = normalizeTitle(jsonMovie.title)
            if let candidates = moviesByNormalizedTitle[normalized] {
                if let year = jsonMovie.year {
                    found = candidates.contains { $0.year == year }
                } else {
                    found = true
                }
            }
        }
        
        if !found {
            missingFromDatabase.append(jsonMovie)
        }
    }
    
    if !missingFromDatabase.isEmpty {
        print("\n   ⚠️  \(missingFromDatabase.count) Rewatchables movies from JSON not found in database:")
        for (index, movie) in missingFromDatabase.prefix(10).enumerated() {
            print("   \(index + 1). \(movie.title)\(movie.year.map { " (\($0))" } ?? "") [TMDB: \(movie.tmdbId ?? 0)]")
        }
        if missingFromDatabase.count > 10 {
            print("   ... and \(missingFromDatabase.count - 10) more")
        }
    } else {
        print("   ✅ All Rewatchables movies from JSON exist in database")
    }
    
    // 5. Movies in database but missing expected source links
    print("\n5️⃣ MOVIES MISSING EXPECTED SOURCE LINKS:")
    print(String(repeating: "-", count: 70))
    var missingLinkCount = 0
    var missingLinkExamples: [(MovieData, String)] = [] // (movie, expectedSource)
    
    for jsonMovie in bootstrapData.movies {
        // Find the movie in database
        var dbMovie: MovieData? = nil
        
        if let tmdbId = jsonMovie.tmdbId {
            dbMovie = moviesByTmdbId[tmdbId]
        }
        
        if dbMovie == nil {
            let normalized = normalizeTitle(jsonMovie.title)
            if let candidates = moviesByNormalizedTitle[normalized] {
                if let year = jsonMovie.year {
                    dbMovie = candidates.first { $0.year == year }
                } else {
                    dbMovie = candidates.first
                }
            }
        }
        
        if let movie = dbMovie {
            let existingSources = movieSourceLinks[movie.id] ?? []
            let expectedSource = jsonMovie.sourceIdentifier
            if !existingSources.contains(expectedSource) {
                missingLinkCount += 1
                if missingLinkExamples.count < 20 {
                    missingLinkExamples.append((movie, expectedSource))
                }
            }
        }
    }
    
    print("   Total movies missing expected source links: \(missingLinkCount)")
    if !missingLinkExamples.isEmpty {
        print("\n   Sample of missing links (first 20):")
        for (index, (movie, expectedSource)) in missingLinkExamples.enumerated() {
            let sourceName = bootstrapData.dataSources.first { $0.identifier == expectedSource }?.name ?? expectedSource
            print("   \(index + 1). '\(movie.title)' missing link to: \(sourceName)")
        }
    }
    
    // 6. Summary and Recommendations
    print("\n" + String(repeating: "=", count: 70))
    print("📋 SUMMARY & RECOMMENDATIONS")
    print(String(repeating: "=", count: 70))
    
    var issuesFound = false
    
    if totalMissing > 0 {
        issuesFound = true
        print("\n⚠️  ISSUE: Missing source links detected")
        print("   Total missing links across all sources: \(totalMissing)")
    }
    
    if !moviesWithoutSources.isEmpty {
        issuesFound = true
        print("\n⚠️  ISSUE: Movies exist without any source associations")
        print("   Count: \(moviesWithoutSources.count)")
    }
    
    if missingLinkCount > 0 {
        issuesFound = true
        print("\n⚠️  ISSUE: Movies missing expected source links")
        print("   Count: \(missingLinkCount)")
    }
    
    if !missingFromDatabase.isEmpty {
        issuesFound = true
        print("\n⚠️  ISSUE: Movies in JSON but not in database")
        print("   Count: \(missingFromDatabase.count)")
    }
    
    if !issuesFound {
        print("\n✅ No major issues detected!")
    } else {
        print("\n💡 RECOMMENDED FIXES:")
        print("   1. Run 'swift fix_bootstrap_database_links.swift' to create missing links")
        print("   2. If movies are missing from database, regenerate from JSON:")
        print("      swift generate_bootstrap_database.swift")
        print("   3. If movies are missing from JSON, re-scrape the sources")
    }
    
    print("\n" + String(repeating: "=", count: 70))
}

// Run diagnostic
Task { @MainActor in
    do {
        try await diagnoseBootstrapDatabase()
        print("\n✅ Diagnostic completed")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()
