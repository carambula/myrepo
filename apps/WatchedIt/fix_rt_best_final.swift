#!/usr/bin/env swift

import Foundation

/// Final fixes for RT Best Movies: Move Godfather to rank 1, remove duplicate Casablanca

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

func fixRTBestFinal() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Final fixes for RT Best Movies\n")
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
    
    // 1. Move The Godfather (1972) from rank 28 to rank 1
    // Note: Ranks 2 and 3 are already correct (Seven Samurai, Casablanca), so don't shift
    if let godfatherIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title.contains("The Godfather") && 
        movie.year == 1972 &&
        movie.sourceIdentifier == "rt-best-all-time"
    }) {
        print("\n   Moving The Godfather (1972) from rank 28 to rank 1")
        bootstrapData.movies[godfatherIndex].rank = 1
        print("   ✅ Set The Godfather to rank 1")
    }
    
    // 2. Remove duplicate Casablanca at rank 4 (keep the one at rank 3 with year 1942)
    if let duplicateCasablancaIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title.contains("Casablanca") &&
        movie.rank == 4 &&
        movie.sourceIdentifier == "rt-best-all-time"
    }) {
        print("   Removing duplicate Casablanca at rank 4")
        bootstrapData.movies.remove(at: duplicateCasablancaIndex)
        
        // Shift ranks 5-300 down by 1
        for i in 0..<bootstrapData.movies.count {
            if bootstrapData.movies[i].sourceIdentifier == "rt-best-all-time",
               let rank = bootstrapData.movies[i].rank,
               rank > 4 {
                bootstrapData.movies[i].rank = rank - 1
            }
        }
    }
    
    // Update source count
    let rtMoviesAfter = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    if let index = bootstrapData.dataSources.firstIndex(where: { $0.identifier == "rt-best-all-time" }) {
        bootstrapData.dataSources[index].movieCount = rtMoviesAfter.count
    }
    
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Find missing ranks
    let existingRanks = Set(rtMoviesAfter.compactMap { $0.rank })
    let missingRanks = (1...300).filter { !existingRanks.contains($0) }
    
    print("\n" + String(repeating: "=", count: 70))
    print("📊 FINAL STATUS")
    print(String(repeating: "=", count: 70))
    print("\n   Total entries: \(rtMoviesAfter.count)")
    print("   Missing ranks: \(missingRanks.count)")
    if !missingRanks.isEmpty {
        print("   Missing: \(missingRanks)")
    }
    
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
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

fixRTBestFinal()

