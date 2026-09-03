#!/usr/bin/env swift

import Foundation

/// Clean up RT Best Movies to have exactly 300 unique movies at correct ranks

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

func cleanupRTBest300() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🧹 Cleaning RT Best Movies to exactly 300\n")
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
    var rtMovies = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    print("   Found \(rtMovies.count) RT Best Movies entries")
    
    // Group by rank
    var moviesByRank: [Int: [BootstrapMovie]] = [:]
    for movie in rtMovies {
        if let rank = movie.rank {
            moviesByRank[rank, default: []].append(movie)
        }
    }
    
    // For each rank, keep only the best entry (most complete data)
    var keptMovies: [BootstrapMovie] = []
    var removedCount = 0
    
    for rank in 1...300 {
        if let movies = moviesByRank[rank] {
            if movies.count > 1 {
                // Multiple movies at same rank - keep the best one
                let sorted = movies.sorted { movie1, movie2 in
                    let score1 = (movie1.tmdbId != nil ? 10 : 0) + 
                                (movie1.posterPath != nil ? 5 : 0) + 
                                (movie1.overview != nil ? 5 : 0) +
                                (movie1.year != nil ? 2 : 0)
                    let score2 = (movie2.tmdbId != nil ? 10 : 0) + 
                                (movie2.posterPath != nil ? 5 : 0) + 
                                (movie2.overview != nil ? 5 : 0) +
                                (movie2.year != nil ? 2 : 0)
                    return score1 > score2
                }
                keptMovies.append(sorted[0])
                removedCount += movies.count - 1
            } else {
                keptMovies.append(movies[0])
            }
        }
    }
    
    print("   Keeping \(keptMovies.count) unique movies")
    print("   Removing \(removedCount) duplicate entries")
    
    // Remove all RT Best Movies and replace with cleaned list
    bootstrapData.movies = bootstrapData.movies.filter { $0.sourceIdentifier != "rt-best-all-time" }
    bootstrapData.movies.append(contentsOf: keptMovies)
    
    // Update source count
    if let index = bootstrapData.dataSources.firstIndex(where: { $0.identifier == "rt-best-all-time" }) {
        bootstrapData.dataSources[index].movieCount = 300
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
        
        print("\n✅ Saved cleaned bootstrap_data.json")
        print("   Total RT Best Movies: \(keptMovies.count)")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

cleanupRTBest300()

