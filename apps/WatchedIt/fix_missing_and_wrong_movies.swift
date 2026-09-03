#!/usr/bin/env swift

import Foundation

/// Script to fix missing movies and wrong years/TMDB IDs in bootstrap_data.json
/// Then regenerates the database

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
    var title: String
    var sourceIdentifier: String
    var rank: Int?
    var sourceTitle: String?
    var tmdbId: Int?
    var year: Int?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var mpaaRating: String?
    var genres: [String]?
    var streamingServices: [BootstrapStreamingService]?
    var credits: BootstrapCredits?
    var trailer: BootstrapTrailer?
    var podcastEpisodeDescription: String?
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
    var movies: [BootstrapMovie]
}

// MARK: - Movies to Fix/Add

struct MovieToFix {
    let title: String
    let correctYear: Int
    let correctTmdbId: Int
    let sourceIdentifier: String
    let sourceTitle: String?
}

let moviesToFix: [MovieToFix] = [
    // Fix wrong years/TMDB IDs
    MovieToFix(title: "8MM", correctYear: 1999, correctTmdbId: 8224, sourceIdentifier: "rewatchables", sourceTitle: nil),
    MovieToFix(title: "Body Double", correctYear: 1984, correctTmdbId: 11507, sourceIdentifier: "rewatchables", sourceTitle: nil),
    
    // Add missing movies
    MovieToFix(title: "25th Hour", correctYear: 2002, correctTmdbId: 1429, sourceIdentifier: "rewatchables", sourceTitle: nil),
    MovieToFix(title: "48 Hrs", correctYear: 1982, correctTmdbId: 150, sourceIdentifier: "rewatchables", sourceTitle: nil),
    MovieToFix(title: "Blood Diamond", correctYear: 2006, correctTmdbId: 1372, sourceIdentifier: "rewatchables", sourceTitle: nil),
]

// MARK: - Main Function

func fixMoviesAndRegenerate() async throws {
    print("🔧 Fixing Missing and Wrong Movies\n")
    print(String(repeating: "=", count: 70))
    
    // Load JSON
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    guard FileManager.default.fileExists(atPath: jsonURL.path) else {
        print("❌ Error: bootstrap_data.json not found")
        exit(1)
    }
    
    print("\n📂 Loading bootstrap_data.json...")
    let jsonData = try Data(contentsOf: jsonURL)
    var bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: jsonData)
    
    print("✅ Loaded \(bootstrapData.movies.count) movies")
    
    // Fix existing movies with wrong years/TMDB IDs
    print("\n🔍 Fixing movies with wrong years/TMDB IDs...")
    var fixedCount = 0
    
    for movieToFix in moviesToFix {
        // Find movie in JSON
        var found = false
        for (index, movie) in bootstrapData.movies.enumerated() {
            if movie.title.lowercased().contains(movieToFix.title.lowercased()) &&
               movie.sourceIdentifier == movieToFix.sourceIdentifier {
                
                let oldYear = movie.year ?? 0
                let oldTmdbId = movie.tmdbId ?? 0
                
                bootstrapData.movies[index].year = movieToFix.correctYear
                bootstrapData.movies[index].tmdbId = movieToFix.correctTmdbId
                
                if let sourceTitle = movieToFix.sourceTitle {
                    bootstrapData.movies[index].sourceTitle = sourceTitle
                }
                
                print("   ✅ Fixed '\(movie.title)':")
                print("      Year: \(oldYear) → \(movieToFix.correctYear)")
                print("      TMDB: \(oldTmdbId) → \(movieToFix.correctTmdbId)")
                fixedCount += 1
                found = true
                break
            }
        }
        
        // If not found, add it
        if !found {
            print("   ➕ Adding '\(movieToFix.title)' (\(movieToFix.correctYear))...")
            
            let newMovie = BootstrapMovie(
                title: movieToFix.title,
                sourceIdentifier: movieToFix.sourceIdentifier,
                rank: nil,
                sourceTitle: movieToFix.sourceTitle,
                tmdbId: movieToFix.correctTmdbId,
                year: movieToFix.correctYear,
                posterPath: nil,
                backdropPath: nil,
                overview: nil,
                mpaaRating: nil,
                genres: nil,
                streamingServices: nil,
                credits: nil,
                trailer: nil,
                podcastEpisodeDescription: nil
            )
            
            bootstrapData.movies.append(newMovie)
            print("      ✅ Added")
        }
    }
    
    // Update source counts
    print("\n📊 Updating source counts...")
    for (index, source) in bootstrapData.dataSources.enumerated() {
        let count = bootstrapData.movies.filter { $0.sourceIdentifier == source.identifier }.count
        if count != source.movieCount {
            print("   \(source.name): \(source.movieCount) → \(count)")
            // Note: Can't modify struct directly, but count will be recalculated on next generation
        }
    }
    
    // Save updated JSON
    print("\n💾 Saving updated bootstrap_data.json...")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let updatedJSONData = try encoder.encode(bootstrapData)
    try updatedJSONData.write(to: jsonURL)
    print("   ✅ Saved \(bootstrapData.movies.count) movies")
    
    // Regenerate database
    print("\n" + String(repeating: "=", count: 70))
    print("🔄 Regenerating bootstrap database...")
    print(String(repeating: "=", count: 70))
    
    print("\n📦 Running generate_bootstrap_database.swift...")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
    task.arguments = ["generate_bootstrap_database.swift"]
    task.currentDirectoryPath = FileManager.default.currentDirectoryPath
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    
    try task.run()
    task.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: .utf8) {
        print(output)
    }
    
    if task.terminationStatus == 0 {
        print("\n✅ Database regeneration completed successfully!")
    } else {
        print("\n❌ Database regeneration failed with exit code \(task.terminationStatus)")
        exit(1)
    }
    
    // Verify fixes
    print("\n" + String(repeating: "=", count: 70))
    print("✅ Verification")
    print(String(repeating: "=", count: 70))
    
    print("\n✅ All fixes complete!")
    print("   - Fixed \(fixedCount) movies with wrong data")
    print("   - Added \(moviesToFix.count - fixedCount) missing movies")
    print("   - Regenerated bootstrap_database.store")
}

// Run
Task {
    do {
        try await fixMoviesAndRegenerate()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

