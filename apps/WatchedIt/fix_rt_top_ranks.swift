#!/usr/bin/env swift

import Foundation

/// Fix top ranks: Godfather=1, Seven Samurai=2, Casablanca=3

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

func fixRTTopRanks() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Fixing Top Ranks: Godfather=1, Seven Samurai=2, Casablanca=3\n")
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
    
    // Find and set the correct top 3
    var foundMovies: [(index: Int, targetRank: Int)] = []
    
    // Find The Godfather (1972) - should be rank 1
    if let godfatherIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title.contains("The Godfather") &&
        movie.year == 1972 &&
        movie.sourceIdentifier == "rt-best-all-time"
    }) {
        foundMovies.append((index: godfatherIndex, targetRank: 1))
        print("   Found The Godfather (1972) at index \(godfatherIndex)")
    }
    
    // Find Seven Samurai (1954) - should be rank 2
    if let sevenSamuraiIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title.contains("Seven Samurai") &&
        movie.year == 1954 &&
        movie.sourceIdentifier == "rt-best-all-time"
    }) {
        foundMovies.append((index: sevenSamuraiIndex, targetRank: 2))
        print("   Found Seven Samurai (1954) at index \(sevenSamuraiIndex)")
    }
    
    // Find Casablanca (1942) - should be rank 3
    if let casablancaIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title.contains("Casablanca") &&
        movie.year == 1942 &&
        movie.sourceIdentifier == "rt-best-all-time"
    }) {
        foundMovies.append((index: casablancaIndex, targetRank: 3))
        print("   Found Casablanca (1942) at index \(casablancaIndex)")
    }
    
    // Set their ranks
    for (index, targetRank) in foundMovies {
        bootstrapData.movies[index].rank = targetRank
        print("   ✅ Set rank \(targetRank): \(bootstrapData.movies[index].title)")
    }
    
    // Remove any duplicate Casablanca entries (keep only the 1942 one at rank 3)
    let casablancaEntries = bootstrapData.movies.enumerated().filter { (index, movie) in
        movie.title.contains("Casablanca") &&
        movie.sourceIdentifier == "rt-best-all-time"
    }
    
    for (index, movie) in casablancaEntries {
        if movie.year != 1942 || movie.rank != 3 {
            print("   Removing duplicate Casablanca: rank \(movie.rank ?? -1), year \(movie.year ?? -1)")
            bootstrapData.movies.remove(at: index)
        }
    }
    
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
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

fixRTTopRanks()

