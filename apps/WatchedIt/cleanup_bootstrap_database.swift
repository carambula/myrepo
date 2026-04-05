#!/usr/bin/env swift

//
//  cleanup_bootstrap_database.swift
//  Cleans up the bootstrap database using DataCleanupService
//
//  Usage: swift cleanup_bootstrap_database.swift
//

import Foundation
import SwiftData

// MARK: - Models (matching MovieDataModel)

@Model
final class MovieData {
    var id: String
    var title: String
    var year: Int?
    var tmdbId: Int?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var mpaaRating: String?
    var genres: [String]
    var streamingServices: [String]
    var credits: String?
    var trailer: String?
    var lastUpdated: Date
    
    @Relationship(deleteRule: .cascade, inverse: \MovieDataSource.movie)
    var dataSources: [MovieDataSource]?
    
    @Relationship(deleteRule: .cascade, inverse: \MovieState.movie)
    var states: [MovieState]?
    
    init(
        id: String = UUID().uuidString,
        title: String = "",
        year: Int? = nil,
        tmdbId: Int? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        overview: String? = nil,
        mpaaRating: String? = nil,
        genres: [String] = [],
        streamingServices: [String] = [],
        credits: String? = nil,
        trailer: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbId = tmdbId
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.mpaaRating = mpaaRating
        self.genres = genres
        self.streamingServices = streamingServices
        self.credits = credits
        self.trailer = trailer
        self.lastUpdated = lastUpdated
    }
}

@Model
final class DataSource {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isEnabled: Bool
    var lastUpdated: Date
    var lastChecked: Date?
    var createdAt: Date
    var isRankedList: Bool
    
    @Relationship(deleteRule: .nullify, inverse: \MovieDataSource.dataSource)
    var movieDataSources: [MovieDataSource]?
    
    init(
        identifier: String,
        name: String,
        type: String,
        url: String? = nil,
        isEnabled: Bool = true,
        lastUpdated: Date = Date(),
        lastChecked: Date? = nil,
        createdAt: Date = Date(),
        isRankedList: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.type = type
        self.url = url
        self.isEnabled = isEnabled
        self.lastUpdated = lastUpdated
        self.lastChecked = lastChecked
        self.createdAt = createdAt
        self.isRankedList = isRankedList
    }
}

@Model
final class MovieDataSource {
    var movie: MovieData?
    var dataSource: DataSource?
    var podcastEpisodeData: Data?
    var rewatchablesDiscussionData: Data?
    var sourceUrl: String?
    var sourceTitle: String?
    var rank: Int?
    
    init(
        movie: MovieData? = nil,
        dataSource: DataSource? = nil,
        podcastEpisode: Any? = nil,
        rewatchablesDiscussion: Any? = nil,
        sourceUrl: String? = nil,
        sourceTitle: String? = nil,
        rank: Int? = nil,
        lastUpdated: Date = Date()
    ) {
        self.movie = movie
        self.dataSource = dataSource
        self.sourceUrl = sourceUrl
        self.sourceTitle = sourceTitle
        self.rank = rank
        self.podcastEpisodeData = nil
        self.rewatchablesDiscussionData = nil
    }
}

@Model
final class MovieState {
    var isRewatched: Bool
    var isListened: Bool
    var isSaved: Bool
    var lastUpdated: Date
    
    var movie: MovieData?
    
    init(
        isRewatched: Bool = false,
        isListened: Bool = false,
        isSaved: Bool = false,
        lastUpdated: Date = Date(),
        movie: MovieData? = nil
    ) {
        self.isRewatched = isRewatched
        self.isListened = isListened
        self.isSaved = isSaved
        self.lastUpdated = lastUpdated
        self.movie = movie
    }
}

// MARK: - Main Script

@MainActor
func cleanupBootstrapDatabase() async throws {
    print("🧹 Cleaning up bootstrap database...")
    
    let bootstrapDBPath = "WatchedIt/bootstrap_database.store"
    let bootstrapDBURL = URL(fileURLWithPath: bootstrapDBPath)
    
    guard FileManager.default.fileExists(atPath: bootstrapDBPath) else {
        print("❌ Error: bootstrap_database.store not found at \(bootstrapDBPath)")
        exit(1)
    }
    
    // Create backup
    let backupPath = "WatchedIt/bootstrap_database.store.backup"
    let backupURL = URL(fileURLWithPath: backupPath)
    
    if FileManager.default.fileExists(atPath: backupPath) {
        try? FileManager.default.removeItem(at: backupURL)
    }
    
    print("📦 Creating backup...")
    try FileManager.default.copyItem(at: bootstrapDBURL, to: backupURL)
    print("✅ Backup created: \(backupPath)")
    
    // Open the bootstrap database
    print("🗄️ Opening bootstrap database...")
    let schema = Schema([MovieData.self, DataSource.self, MovieDataSource.self, MovieState.self])
    let config = ModelConfiguration(
        url: bootstrapDBURL,
        allowsSave: true,
        cloudKitDatabase: .none
    )
    
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = container.mainContext
    
    // Get initial counts
    let initialMovies = try context.fetch(FetchDescriptor<MovieData>())
    print("📊 Initial state: \(initialMovies.count) movies")
    
    // Import the cleanup service logic
    // Since we can't import the actual service, we'll need to implement the cleanup here
    // For now, let's use a simpler approach - just run basic deduplication
    
    print("🔄 Running cleanup...")
    
    // Step 1: Clean all titles
    var titlesUpdated = 0
    for movie in initialMovies {
        let originalTitle = movie.title
        let cleanedTitle = cleanTitle(originalTitle)
        
        if cleanedTitle != originalTitle {
            movie.title = cleanedTitle
            titlesUpdated += 1
        }
    }
    
    if titlesUpdated > 0 {
        try context.save()
        print("✅ Cleaned \(titlesUpdated) titles")
    }
    
    // Step 2: Deduplicate by TMDB ID
    let allMovies = try context.fetch(FetchDescriptor<MovieData>())
    var moviesByTmdbId: [Int: [MovieData]] = [:]
    for movie in allMovies {
        if let tmdbId = movie.tmdbId {
            if moviesByTmdbId[tmdbId] == nil {
                moviesByTmdbId[tmdbId] = []
            }
            moviesByTmdbId[tmdbId]?.append(movie)
        }
    }
    
    var duplicatesRemoved = 0
    for (tmdbId, duplicates) in moviesByTmdbId where duplicates.count > 1 {
        // Find best movie (most complete data, cleanest title)
        let bestMovie = duplicates.max(by: { m1, m2 in
            let score1 = calculateDataCompleteness(m1)
            let score2 = calculateDataCompleteness(m2)
            if score1 != score2 {
                return score1 < score2
            }
            let title1 = cleanTitle(m1.title)
            let title2 = cleanTitle(m2.title)
            let clean1 = !title1.contains(" with ") && title1.count < 60
            let clean2 = !title2.contains(" with ") && title2.count < 60
            if clean1 != clean2 {
                return !clean1
            }
            return title1.count > title2.count
        })!
        
        // Merge others into best
        for duplicate in duplicates where duplicate.id != bestMovie.id {
            mergeMovieData(target: bestMovie, source: duplicate, context: context)
            context.delete(duplicate)
            duplicatesRemoved += 1
        }
    }
    
    // Step 3: Deduplicate by cleaned title
    var moviesByTitle: [String: [MovieData]] = [:]
    let remainingMovies = try context.fetch(FetchDescriptor<MovieData>())
    for movie in remainingMovies {
        let normalizedTitle = cleanTitle(movie.title).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTitle.count >= 3 else { continue }
        
        if moviesByTitle[normalizedTitle] == nil {
            moviesByTitle[normalizedTitle] = []
        }
        moviesByTitle[normalizedTitle]?.append(movie)
    }
    
    for (_, duplicates) in moviesByTitle where duplicates.count > 1 {
        let bestMovie = duplicates.max(by: { m1, m2 in
            if (m1.tmdbId != nil) != (m2.tmdbId != nil) {
                return m1.tmdbId == nil
            }
            let score1 = calculateDataCompleteness(m1)
            let score2 = calculateDataCompleteness(m2)
            if score1 != score2 {
                return score1 < score2
            }
            let title1 = cleanTitle(m1.title)
            let title2 = cleanTitle(m2.title)
            let clean1 = !title1.contains(" with ") && title1.count < 60
            let clean2 = !title2.contains(" with ") && title2.count < 60
            if clean1 != clean2 {
                return !clean1
            }
            return title1.count > title2.count
        })!
        
        for duplicate in duplicates where duplicate.id != bestMovie.id {
            if bestMovie.tmdbId == nil && duplicate.tmdbId != nil {
                bestMovie.tmdbId = duplicate.tmdbId
            }
            mergeMovieData(target: bestMovie, source: duplicate, context: context)
            context.delete(duplicate)
            duplicatesRemoved += 1
        }
    }
    
    if duplicatesRemoved > 0 {
        try context.save()
        print("✅ Removed \(duplicatesRemoved) duplicate movies")
    }
    
    // Final counts
    let finalMovies = try context.fetch(FetchDescriptor<MovieData>())
    print("📊 Final state: \(finalMovies.count) movies")
    print("✅ Cleanup complete! Removed \(initialMovies.count - finalMovies.count) duplicates")
    
    // Get file size
    let attributes = try FileManager.default.attributesOfItem(atPath: bootstrapDBPath)
    let fileSize = attributes[.size] as! Int64
    let fileSizeMB = Double(fileSize) / 1_000_000.0
    
    print("\n📦 Bootstrap database cleaned:")
    print("   Location: \(bootstrapDBPath)")
    print("   Size: \(String(format: "%.2f", fileSizeMB)) MB")
    print("   Movies: \(finalMovies.count)")
}

// MARK: - Helper Functions

func cleanTitle(_ title: String) -> String {
    var cleaned = title
    
    // Remove list numbering patterns
    let listNumberingPatterns = [
        #"^(\d+)\.\s+"#,
        #"^#(\d+)\s+"#,
        #"^(\d+)\)\s+"#,
        #"^\((\d+)\)\s+"#,
        #"^(\d+)[:–\-]\s+"#,
    ]
    
    for pattern in listNumberingPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
            if match.numberOfRanges > 1,
               let numberRange = Range(match.range(at: 1), in: cleaned),
               let number = Int(String(cleaned[numberRange])),
               number <= 999 {
                if let fullRange = Range(match.range, in: cleaned) {
                    cleaned = String(cleaned[fullRange.upperBound...])
                    cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
    }
    
    // Remove quotes
    let quoteChars: [Character] = ["'", "'", "'", "'", "\"", "\"", "\"", "\""]
    while !cleaned.isEmpty, let first = cleaned.first, quoteChars.contains(first) {
        cleaned = String(cleaned.dropFirst())
    }
    while !cleaned.isEmpty, let last = cleaned.last, quoteChars.contains(last) {
        cleaned = String(cleaned.dropLast())
    }
    
    let wrappedQuotePattern = #"^["'""'`´](.*)["'""'`´]$"#
    if let regex = try? NSRegularExpression(pattern: wrappedQuotePattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
       match.numberOfRanges > 1,
       let contentRange = Range(match.range(at: 1), in: cleaned) {
        cleaned = String(cleaned[contentRange])
    }
    
    // Remove "Live From" patterns
    let liveFromPattern = #"(?i)\s*(?:LIVE|Live)\s+From\s+[A-Za-z\s]+"#
    if let regex = try? NSRegularExpression(pattern: liveFromPattern) {
        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
        if let match = regex.firstMatch(in: cleaned, range: nsRange) {
            if let range = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[..<range.lowerBound]) + String(cleaned[range.upperBound...])
            }
        }
    }
    
    cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return cleaned
}

func calculateDataCompleteness(_ movie: MovieData) -> Int {
    var score = 0
    if movie.posterPath != nil { score += 1 }
    if movie.backdropPath != nil { score += 1 }
    if movie.overview != nil && !(movie.overview?.isEmpty ?? true) { score += 1 }
    if movie.mpaaRating != nil { score += 1 }
    if !movie.genres.isEmpty { score += 1 }
    if !movie.streamingServices.isEmpty { score += 1 }
    if movie.credits != nil { score += 1 }
    if movie.trailer != nil { score += 1 }
    if let dataSources = movie.dataSources, !dataSources.isEmpty {
        score += dataSources.count * 2
    }
    return score
}

func mergeMovieData(target: MovieData, source: MovieData, context: ModelContext) {
    if target.posterPath == nil && source.posterPath != nil {
        target.posterPath = source.posterPath
    }
    if target.backdropPath == nil && source.backdropPath != nil {
        target.backdropPath = source.backdropPath
    }
    if (target.overview == nil || target.overview?.isEmpty == true) &&
       source.overview != nil && !(source.overview?.isEmpty ?? true) {
        target.overview = source.overview
    }
    if target.mpaaRating == nil && source.mpaaRating != nil {
        target.mpaaRating = source.mpaaRating
    }
    if target.genres.isEmpty && !source.genres.isEmpty {
        target.genres = source.genres
    }
    if target.streamingServices.isEmpty && !source.streamingServices.isEmpty {
        target.streamingServices = source.streamingServices
    }
    if target.credits == nil && source.credits != nil {
        target.credits = source.credits
    }
    if target.trailer == nil && source.trailer != nil {
        target.trailer = source.trailer
    }
    
    let targetTitle = cleanTitle(target.title)
    let sourceTitle = cleanTitle(source.title)
    if sourceTitle.count < targetTitle.count && !sourceTitle.contains(" with ") {
        target.title = sourceTitle
    } else if targetTitle.contains(" with ") && !sourceTitle.contains(" with ") {
        target.title = sourceTitle
    }
    
    // Merge data sources
    if let sourcesToMerge = source.dataSources {
        for sourceDataSource in sourcesToMerge {
            let sourceExists = target.dataSources?.contains(where: {
                $0.dataSource?.identifier == sourceDataSource.dataSource?.identifier
            }) ?? false
            
            if !sourceExists {
                sourceDataSource.movie = target
            } else if let existingSource = target.dataSources?.first(where: {
                $0.dataSource?.identifier == sourceDataSource.dataSource?.identifier
            }) {
                if existingSource.rank == nil && sourceDataSource.rank != nil {
                    existingSource.rank = sourceDataSource.rank
                }
            }
        }
    }
    
    if source.lastUpdated > target.lastUpdated {
        target.lastUpdated = source.lastUpdated
    }
}

// Run the cleanup
Task { @MainActor in
    do {
        try await cleanupBootstrapDatabase()
        exit(0)
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

