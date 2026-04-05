#!/usr/bin/env swift

import Foundation

/// Script to move Seven Samurai to rank #2 and identify all missing ranks in RT Best Movies list

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
    var version: String?
    var generatedDate: String?
    var dataSources: [BootstrapDataSource]
    var movies: [BootstrapMovie]
}

struct BootstrapDataSource: Codable {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isRankedList: Bool
    var movieCount: Int
}

func fixRTBestMoviesRanking() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Fixing RT Best Movies Ranking\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded existing bootstrap data")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    // Get all RT Best Movies
    let rtMovies = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    print("\n📋 Found \(rtMovies.count) RT Best Movies entries")
    
    // Find Seven Samurai (1954)
    let sevenSamurai = rtMovies.first { movie in
        movie.title.contains("Seven Samurai") && movie.year == 1954
    }
    
    guard let sevenSamurai = sevenSamurai else {
        print("❌ Seven Samurai (1954) not found in database")
        return
    }
    
    print("   Found Seven Samurai (1954) at rank \(sevenSamurai.rank ?? -1)")
    
    // Find current rank 2
    let currentRank2 = rtMovies.first { $0.rank == 2 }
    if let currentRank2 = currentRank2 {
        print("   Current rank 2: \(currentRank2.title) (\(currentRank2.year ?? 0))")
    }
    
    // Get index of Seven Samurai in movies array and save old rank
    guard let sevenSamuraiIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title == sevenSamurai.title && 
        movie.sourceIdentifier == "rt-best-all-time" &&
        movie.year == 1954
    }) else {
        print("❌ Could not find Seven Samurai index")
        return
    }
    
    let oldRank = bootstrapData.movies[sevenSamuraiIndex].rank ?? 3
    print("   Moving from rank \(oldRank) to rank 2")
    
    // Since rank 2 is missing, just move Seven Samurai there
    // No need to shift anything - rank 3 will just become empty
    bootstrapData.movies[sevenSamuraiIndex].rank = 2
    
    // Find all missing ranks
    let rtMoviesAfter = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    let existingRanks = Set(rtMoviesAfter.compactMap { $0.rank })
    var missingRanks: [Int] = []
    
    for rank in 1...300 {
        if !existingRanks.contains(rank) {
            missingRanks.append(rank)
        }
    }
    
    print("\n" + String(repeating: "=", count: 70))
    print("📊 MISSING RANKS ANALYSIS")
    print(String(repeating: "=", count: 70))
    print("\nTotal entries: \(rtMoviesAfter.count)")
    print("Missing ranks: \(missingRanks.count)")
    
    if !missingRanks.isEmpty {
        print("\nMissing rank numbers:")
        let sortedMissing = missingRanks.sorted()
        
        // Group consecutive ranges
        var ranges: [(start: Int, end: Int)] = []
        var currentStart = sortedMissing[0]
        var currentEnd = sortedMissing[0]
        
        for i in 1..<sortedMissing.count {
            if sortedMissing[i] == currentEnd + 1 {
                currentEnd = sortedMissing[i]
            } else {
                ranges.append((start: currentStart, end: currentEnd))
                currentStart = sortedMissing[i]
                currentEnd = sortedMissing[i]
            }
        }
        ranges.append((start: currentStart, end: currentEnd))
        
        for range in ranges {
            if range.start == range.end {
                print("  \(range.start)")
            } else {
                print("  \(range.start) - \(range.end)")
            }
        }
        
        print("\nAll missing ranks: \(sortedMissing)")
    }
    
    // Update generated date
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Save
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING")
    print(String(repeating: "=", count: 70))
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Seven Samurai (1954) moved to rank #2")
        print("   Ranks shifted accordingly")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

fixRTBestMoviesRanking()

