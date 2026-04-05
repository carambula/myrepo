#!/usr/bin/env swift

import Foundation

/// Script to clean up duplicate entries in RT Best Movies list

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

func cleanupRTBestDuplicates() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🧹 Cleaning up RT Best Movies duplicates\n")
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
    print("   Found \(rtMovies.count) RT Best Movies entries")
    
    // Find duplicates by rank
    var moviesByRank: [Int: [BootstrapMovie]] = [:]
    for movie in rtMovies {
        if let rank = movie.rank {
            moviesByRank[rank, default: []].append(movie)
        }
    }
    
    var duplicatesToRemove: [Int] = []
    var removedCount = 0
    
    for (rank, movies) in moviesByRank where movies.count > 1 {
        print("\n   Rank \(rank): \(movies.count) entries")
        
        // Keep the one with year and most complete data, remove others
        let sorted = movies.sorted { movie1, movie2 in
            // Prefer movies with year
            if movie1.year != nil && movie2.year == nil { return true }
            if movie1.year == nil && movie2.year != nil { return false }
            
            // Prefer movies with more data
            let score1 = (movie1.tmdbId != nil ? 10 : 0) + (movie1.posterPath != nil ? 5 : 0) + (movie1.overview != nil ? 5 : 0)
            let score2 = (movie2.tmdbId != nil ? 10 : 0) + (movie2.posterPath != nil ? 5 : 0) + (movie2.overview != nil ? 5 : 0)
            return score1 > score2
        }
        
        // Keep the best one
        let keeper = sorted[0]
        print("      Keeping: \(keeper.title) (\(keeper.year ?? 0))")
        
        // Mark others for removal
        for duplicate in sorted.dropFirst() {
            print("      Removing: \(duplicate.title) (\(duplicate.year ?? 0))")
            if let index = bootstrapData.movies.firstIndex(where: { movie in
                movie.title == duplicate.title &&
                movie.sourceIdentifier == "rt-best-all-time" &&
                movie.rank == duplicate.rank &&
                movie.year == duplicate.year
            }) {
                duplicatesToRemove.append(index)
                removedCount += 1
            }
        }
    }
    
    // Remove duplicates
    bootstrapData.movies = bootstrapData.movies.enumerated().compactMap { index, movie in
        if duplicatesToRemove.contains(index) {
            return nil
        }
        return movie
    }
    
    // Fix Casablanca year if needed
    if let casablancaIndex = bootstrapData.movies.firstIndex(where: { movie in
        movie.title.contains("Casablanca") && movie.rank == 3
    }) {
        if bootstrapData.movies[casablancaIndex].year == 1943 {
            bootstrapData.movies[casablancaIndex].year = 1942
            print("\n   ✅ Fixed Casablanca year to 1942")
        }
    }
    
    // Update source count
    let rtMoviesAfter = bootstrapData.movies.filter { $0.sourceIdentifier == "rt-best-all-time" }
    if let index = bootstrapData.dataSources.firstIndex(where: { $0.identifier == "rt-best-all-time" }) {
        bootstrapData.dataSources[index].movieCount = rtMoviesAfter.count
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
        print("   Removed: \(removedCount) duplicate entries")
        print("   Total RT Best Movies: \(rtMoviesAfter.count)")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

cleanupRTBestDuplicates()

