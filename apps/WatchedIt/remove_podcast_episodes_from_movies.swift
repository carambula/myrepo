#!/usr/bin/env swift

import Foundation

/// Script to remove podcast episode entries that don't have movie data
/// These should be classified as podcast episodes, not movies

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

func removePodcastEpisodesFromMovies() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🧹 Removing Podcast Episode Entries Without Movie Data\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded existing bootstrap data")
    print("   Total movies: \(bootstrapData.movies.count)")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    // Get podcast source identifiers
    let podcastSources = Set(bootstrapData.dataSources
        .filter { $0.type == "podcast" }
        .map { $0.identifier })
    
    print("\n📋 Podcast sources: \(podcastSources.count)")
    for source in podcastSources {
        print("   - \(source)")
    }
    
    // Identify entries to remove
    var entriesToRemove: [Int] = []
    var entriesBySource: [String: Int] = [:]
    
    for (index, movie) in bootstrapData.movies.enumerated() {
        // Check if this is a podcast source entry
        let isPodcastSource = podcastSources.contains(movie.sourceIdentifier)
        
        // Check if it has podcast episode description
        let hasEpisodeDesc = movie.podcastEpisodeDescription != nil && !movie.podcastEpisodeDescription!.isEmpty
        
        // Check if it lacks movie data
        let hasNoMovieData = movie.tmdbId == nil && movie.year == nil && movie.posterPath == nil && movie.overview == nil
        
        // Check if title looks like a podcast episode title
        let title = movie.title.lowercased()
        let episodePatterns = ["episode", "ep.", "#", "ep ", "podcast", "discussion", "review", "recap", "deep dive", "rewatch", "draft", "hall of fame", "top 5", "top five"]
        let looksLikeEpisode = episodePatterns.contains { title.contains($0) }
        
        // Check if title is very long (podcast episodes often have long titles)
        let isVeryLong = movie.title.count > 100
        
        // Decision: Remove if it's from a podcast source AND:
        // - Has episode description but no movie data, OR
        // - Looks like an episode title but has no movie data
        if isPodcastSource && hasNoMovieData && (hasEpisodeDesc || looksLikeEpisode || isVeryLong) {
            entriesToRemove.append(index)
            entriesBySource[movie.sourceIdentifier, default: 0] += 1
        }
    }
    
    print("\n" + String(repeating: "=", count: 70))
    print("📊 ENTRIES TO REMOVE")
    print(String(repeating: "=", count: 70))
    print("\n   Total entries to remove: \(entriesToRemove.count)")
    print("\n   By source:")
    for (source, count) in entriesBySource.sorted(by: { $0.value > $1.value }) {
        print("      \(source): \(count)")
    }
    
    // Show some examples
    print("\n   Examples of entries to be removed:")
    for (i, index) in entriesToRemove.prefix(10).enumerated() {
        let movie = bootstrapData.movies[index]
        let titlePreview = movie.title.prefix(60)
        print("      \(i + 1). [\(movie.sourceIdentifier)] \(titlePreview)...")
    }
    
    // Remove entries (in reverse order to maintain indices)
    let sortedIndices = entriesToRemove.sorted(by: >)
    for index in sortedIndices {
        bootstrapData.movies.remove(at: index)
    }
    
    // Update source counts
    var sourceCounts: [String: Int] = [:]
    for movie in bootstrapData.movies {
        sourceCounts[movie.sourceIdentifier, default: 0] += 1
    }
    
    for (index, source) in bootstrapData.dataSources.enumerated() {
        if let count = sourceCounts[source.identifier] {
            bootstrapData.dataSources[index].movieCount = count
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
        print("   Removed: \(entriesToRemove.count) podcast episode entries")
        print("   Remaining movies: \(bootstrapData.movies.count)")
        
        print("\n   Updated source counts:")
        for source in bootstrapData.dataSources.sorted(by: { $0.identifier < $1.identifier }) {
            print("      \(source.identifier): \(source.movieCount)")
        }
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

removePodcastEpisodesFromMovies()

