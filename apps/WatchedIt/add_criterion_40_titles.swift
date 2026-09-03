#!/usr/bin/env swift

import Foundation

/// Script to add Criterion Collection 40 titles from Wikipedia to bootstrap_data.json
/// and enrich them with TMDB data

// MARK: - Data Structures

struct BootstrapDataSource: Codable {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isRankedList: Bool
    var movieCount: Int
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
    var version: String?
    var generatedDate: String?
    var dataSources: [BootstrapDataSource]
    var movies: [BootstrapMovie]
}

// MARK: - Criterion 40 Titles

let criterion40Titles = [
    "8½",
    "Tokyo Story",
    "All That Jazz",
    "Bicycle Thieves",
    "Repo Man",
    "Naked",
    "Jules and Jim",
    "Being There",
    "Weekend",
    "Yi Yi",
    "The Night of the Hunter",
    "Pickpocket",
    "Sweet Smell of Success",
    "On the Waterfront",
    "Do the Right Thing",
    "Ratcatcher",
    "Sunday Bloody Sunday",
    "Mirror",
    "Barry Lyndon",
    "Safe",
    "Seconds",
    "His Girl Friday",
    "Mishima: A Life in Four Chapters",
    "Y tu mamá también",
    "My Own Private Idaho",
    "Love & Basketball",
    "Night of the Living Dead",
    "Ace in the Hole",
    "3 Women",
    "The Red Shoes",
    "Down by Law",
    "La ciénaga",
    "Wanda",
    "House",
    "Sullivan's Travels",
    "The Battle of Algiers",
    "A Woman Under the Influence",
    "Cléo from 5 to 7",
    "Persona",
    "In the Mood for Love"
]

// MARK: - TMDB API Helper

struct TMDBConfig {
    static let apiKey = "4f6ab1dde752aedd41093bab21f383c7"  // Using the API key from the codebase
    static let baseURL = "https://api.themoviedb.org/3"
}

struct TMDBMovieSearchResult: Codable {
    let id: Int
    let title: String
    let release_date: String?
    let poster_path: String?
    let backdrop_path: String?
    let overview: String?
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let release_date: String?
    let poster_path: String?
    let backdrop_path: String?
    let overview: String?
    let certification: String?
    let genres: [TMDBGenre]?
    let runtime: Int?
    
    var mpaa_rating: String? { certification }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBMovieCredits: Codable {
    let crew: [TMDBPerson]?
    let cast: [TMDBPerson]?
}

struct TMDBPerson: Codable {
    let id: Int
    let name: String
    let character: String?
    let profile_path: String?
    let job: String?
}

struct TMDBSearchResponse: Codable {
    let results: [TMDBMovieSearchResult]
}

func searchTMDBMovie(title: String) async throws -> TMDBMovieSearchResult? {
    guard !TMDBConfig.apiKey.isEmpty else {
        print("⚠️  TMDB_API_KEY not set, skipping enrichment")
        return nil
    }
    
    let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
    let urlString = "\(TMDBConfig.baseURL)/search/movie?api_key=\(TMDBConfig.apiKey)&query=\(encodedTitle)&language=en-US"
    
    guard let url = URL(string: urlString) else { return nil }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
    
    // Find best match (exact title match preferred)
    let exactMatch = response.results.first { $0.title.lowercased() == title.lowercased() }
    return exactMatch ?? response.results.first
}

func getTMDBMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
    guard !TMDBConfig.apiKey.isEmpty else { return nil }
    
    let urlString = "\(TMDBConfig.baseURL)/movie/\(tmdbId)?api_key=\(TMDBConfig.apiKey)&language=en-US"
    guard let url = URL(string: urlString) else { return nil }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    return try? JSONDecoder().decode(TMDBMovieDetails.self, from: data)
}

func getTMDBMovieCredits(tmdbId: Int) async throws -> TMDBMovieCredits? {
    guard !TMDBConfig.apiKey.isEmpty else { return nil }
    
    let urlString = "\(TMDBConfig.baseURL)/movie/\(tmdbId)/credits?api_key=\(TMDBConfig.apiKey)&language=en-US"
    guard let url = URL(string: urlString) else { return nil }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    return try? JSONDecoder().decode(TMDBMovieCredits.self, from: data)
}

// MARK: - Main Function

func addCriterion40Titles() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("📚 Adding Criterion Collection 40 Titles\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded existing bootstrap data")
    print("   Sources: \(bootstrapData.dataSources.count)")
    print("   Movies: \(bootstrapData.movies.count)")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    // Get existing titles for criterion source
    let existingTitles = Set(bootstrapData.movies
        .filter { $0.sourceIdentifier == "criterion" }
        .map { $0.title.lowercased().trimmingCharacters(in: .whitespaces) })
    
    print("\n📋 Processing \(criterion40Titles.count) Criterion 40 titles...")
    
    // Update criterion source if it exists, or create it
    var criterionSourceIndex = bootstrapData.dataSources.firstIndex { $0.identifier == "criterion" }
    if criterionSourceIndex == nil {
        let newSource = BootstrapDataSource(
            identifier: "criterion",
            name: "Criterion Collection",
            type: "url",
            url: "https://en.wikipedia.org/wiki/Criterion_Closet#Criterion_Collection_40",
            isRankedList: true,
            movieCount: 0
        )
        bootstrapData.dataSources.append(newSource)
        criterionSourceIndex = bootstrapData.dataSources.count - 1
    }
    
    var newMovies: [BootstrapMovie] = []
    var moviesWithData: [BootstrapMovie] = []
    
    for (index, title) in criterion40Titles.enumerated() {
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Check if already exists
        if existingTitles.contains(normalizedTitle) {
            print("   ⏭️  Skipping '\(title)' (already exists)")
            continue
        }
        
        print("   📽️  Processing '\(title)'...")
        
        // Create base movie entry
        var movie = BootstrapMovie(
            title: title,
            sourceIdentifier: "criterion",
            rank: index + 1,
            sourceTitle: nil,
            tmdbId: nil,
            year: nil,
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
        
        // Try to enrich with TMDB data
        if !TMDBConfig.apiKey.isEmpty {
            do {
                if let searchResult = try await searchTMDBMovie(title: title) {
                    movie.tmdbId = searchResult.id
                    movie.posterPath = searchResult.poster_path
                    movie.backdropPath = searchResult.backdrop_path
                    movie.overview = searchResult.overview
                    
                    // Extract year from release_date
                    if let releaseDate = searchResult.release_date,
                       let year = Int(releaseDate.prefix(4)) {
                        movie.year = year
                    }
                    
                    // Get additional details
                    if let details = try await getTMDBMovieDetails(tmdbId: searchResult.id) {
                        movie.mpaaRating = details.mpaa_rating
                        movie.genres = details.genres?.map { $0.name }
                        
                        // Get credits
                        if let credits = try await getTMDBMovieCredits(tmdbId: searchResult.id) {
                            let director = credits.crew?.first { $0.job == "Director" }?.name
                            
                            let cast = credits.cast?.prefix(5).map { member in
                                BootstrapCastMember(
                                    id: member.id,
                                    name: member.name,
                                    character: member.character,
                                    profilePath: member.profile_path
                                )
                            }
                            
                            movie.credits = BootstrapCredits(
                                director: director,
                                cast: cast
                            )
                        }
                    }
                    
                    print("      ✅ Enriched with TMDB data (ID: \(searchResult.id))")
                    moviesWithData.append(movie)
                } else {
                    print("      ⚠️  No TMDB match found")
                    newMovies.append(movie)
                }
            } catch {
                print("      ⚠️  TMDB lookup failed: \(error.localizedDescription)")
                newMovies.append(movie)
            }
        } else {
            print("      ⚠️  TMDB API key not available")
            newMovies.append(movie)
        }
        
        // Small delay to avoid rate limiting
        try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
    }
    
    // Add all movies
    bootstrapData.movies.append(contentsOf: newMovies)
    bootstrapData.movies.append(contentsOf: moviesWithData)
    
    // Update criterion source count
    if let index = criterionSourceIndex {
        bootstrapData.dataSources[index].movieCount = criterion40Titles.count
    }
    
    // Update generated date
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Save
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING UPDATED DATA")
    print(String(repeating: "=", count: 70))
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Total Movies: \(bootstrapData.movies.count)")
        print("   New Movies Added: \(newMovies.count + moviesWithData.count)")
        print("   Movies with TMDB Data: \(moviesWithData.count)")
        print("   Criterion Source: \(bootstrapData.dataSources.first { $0.identifier == "criterion" }?.movieCount ?? 0) movies")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await addCriterion40Titles()
    exit(0)
}

RunLoop.main.run()

