#!/usr/bin/env swift

import Foundation

/// Script to fix Breaking Away year/TMDB ID and regenerate database
/// This will:
/// 1. Fix Breaking Away entry in bootstrap_data.json (TMDB 20283, year 1979)
/// 2. Regenerate bootstrap_database.store with all fixes

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
    
    // Enriched fields
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

// MARK: - Main Function

func fixBreakingAwayAndRegenerate() async throws {
    print("🔧 Fixing Breaking Away and Regenerating Database\n")
    print(String(repeating: "=", count: 70))
    
    // Step 1: Fix Breaking Away in JSON
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    guard FileManager.default.fileExists(atPath: jsonURL.path) else {
        print("❌ Error: bootstrap_data.json not found")
        exit(1)
    }
    
    print("\n📂 Loading bootstrap_data.json...")
    let jsonData = try Data(contentsOf: jsonURL)
    var bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: jsonData)
    
    // Find and fix Breaking Away
    print("\n🔍 Searching for Breaking Away entry...")
    var fixed = false
    for (index, movie) in bootstrapData.movies.enumerated() {
        if movie.title.lowercased().contains("breaking away") && 
           movie.sourceIdentifier == "rewatchables" {
            
            print("   Found: \(movie.title)")
            print("   Current: Year=\(movie.year ?? 0), TMDB=\(movie.tmdbId ?? 0)")
            
            // Update to correct values
            bootstrapData.movies[index].year = 1979
            bootstrapData.movies[index].tmdbId = 20283
            
            print("   Fixed:  Year=1979, TMDB=20283")
            fixed = true
            break
        }
    }
    
    if !fixed {
        print("   ⚠️  Breaking Away entry not found, may already be correct")
    }
    
    // Save updated JSON
    print("\n💾 Saving updated bootstrap_data.json...")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let updatedJSONData = try encoder.encode(bootstrapData)
    try updatedJSONData.write(to: jsonURL)
    print("   ✅ Saved")
    
    // Step 2: Regenerate database
    print("\n" + "=" * 70)
    print("🔄 Regenerating bootstrap database...")
    print(String(repeating: "=", count: 70))
    
    // Run generate_bootstrap_database.swift
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
    
    print("\n" + "=" * 70)
    print("✅ All fixes complete!")
    print(String(repeating: "=", count: 70))
    print("\nNext steps:")
    print("  1. Verify fixes: python3 diagnose_database_sqlite.py")
    print("  2. Replace bootstrap_database.store in Xcode bundle if needed")
}


// Run
Task {
    do {
        try await fixBreakingAwayAndRegenerate()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

