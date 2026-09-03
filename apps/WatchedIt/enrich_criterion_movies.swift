#!/usr/bin/env swift

import Foundation

/// Script to enrich Criterion Collection movies in bootstrap_data.json with TMDB data

// MARK: - Data Structures (matching bootstrap_data.json)

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

// MARK: - TMDB Service

class TMDBService {
    private let apiKey = "4f6ab1dde752aedd41093bab21f383c7"
    private let baseURL = "https://api.themoviedb.org/3"
    
    struct TMDBSearchResponse: Codable {
        let results: [TMDBMovie]
    }
    
    struct TMDBMovie: Codable {
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
        let genres: [TMDBGenre]?
        let release_dates: TMDBReleaseDates?
        
        var mpaaRating: String? {
            release_dates?.results?.first { $0.iso_3166_1 == "US" }?
                .release_dates.first { $0.certification != nil && !$0.certification!.isEmpty }?
                .certification
        }
    }
    
    struct TMDBGenre: Codable {
        let id: Int
        let name: String
    }
    
    struct TMDBReleaseDates: Codable {
        let results: [TMDBReleaseDateResult]?
    }
    
    struct TMDBReleaseDateResult: Codable {
        let iso_3166_1: String
        let release_dates: [TMDBReleaseDate]
    }
    
    struct TMDBReleaseDate: Codable {
        let certification: String?
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
    
    func searchMovie(title: String) async throws -> TMDBMovie? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedTitle)&language=en-US"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        // Find best match
        let exactMatch = response.results.first { $0.title.lowercased() == title.lowercased() }
        return exactMatch ?? response.results.first
    }
    
    func getMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
        let urlString = "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)&append_to_response=release_dates&language=en-US"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try? JSONDecoder().decode(TMDBMovieDetails.self, from: data)
    }
    
    func getMovieCredits(tmdbId: Int) async throws -> TMDBMovieCredits? {
        let urlString = "\(baseURL)/movie/\(tmdbId)/credits?api_key=\(apiKey)&language=en-US"
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try? JSONDecoder().decode(TMDBMovieCredits.self, from: data)
    }
}

// MARK: - Main Function

func enrichCriterionMovies() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Enriching Criterion Collection Movies with TMDB Data\n")
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
    
    // Get all Criterion movies that need enrichment
    let criterionMovies = bootstrapData.movies.filter { $0.sourceIdentifier == "criterion" }
    print("\n📋 Found \(criterionMovies.count) Criterion Collection movies")
    
    let moviesToEnrich = criterionMovies.filter { movie in
        movie.tmdbId == nil || movie.posterPath == nil || movie.overview == nil
    }
    
    print("   Movies needing enrichment: \(moviesToEnrich.count)")
    
    if moviesToEnrich.isEmpty {
        print("\n✅ All Criterion movies already have TMDB data!")
        return
    }
    
    let tmdbService = TMDBService()
    var enrichedCount = 0
    var failedCount = 0
    
    for (index, movie) in moviesToEnrich.enumerated() {
        guard let movieIndex = bootstrapData.movies.firstIndex(where: { $0.title == movie.title && $0.sourceIdentifier == "criterion" }) else {
            continue
        }
        
        print("\n[\(index + 1)/\(moviesToEnrich.count)] Enriching '\(movie.title)'...")
        
        do {
            // Search for movie
            guard let searchResult = try await tmdbService.searchMovie(title: movie.title) else {
                print("   ⚠️  Not found in TMDB")
                failedCount += 1
                continue
            }
            
            print("   ✅ Found in TMDB (ID: \(searchResult.id))")
            
            // Get details
            let details = try await tmdbService.getMovieDetails(tmdbId: searchResult.id)
            let credits = try? await tmdbService.getMovieCredits(tmdbId: searchResult.id)
            
            // Update movie
            bootstrapData.movies[movieIndex].tmdbId = searchResult.id
            bootstrapData.movies[movieIndex].posterPath = details?.poster_path ?? searchResult.poster_path
            bootstrapData.movies[movieIndex].backdropPath = details?.backdrop_path ?? searchResult.backdrop_path
            bootstrapData.movies[movieIndex].overview = details?.overview ?? searchResult.overview
            
            // Extract year
            if let releaseDate = details?.release_date ?? searchResult.release_date,
               let year = Int(releaseDate.prefix(4)) {
                bootstrapData.movies[movieIndex].year = year
            }
            
            // MPAA rating
            if let mpaa = details?.mpaaRating {
                bootstrapData.movies[movieIndex].mpaaRating = mpaa
            }
            
            // Genres
            if let genres = details?.genres {
                bootstrapData.movies[movieIndex].genres = genres.map { $0.name }
            }
            
            // Credits
            if let creditsData = credits {
                let director = creditsData.crew?.first { $0.job == "Director" }?.name
                let cast = creditsData.cast?.prefix(5).map { member in
                    BootstrapCastMember(
                        id: member.id,
                        name: member.name,
                        character: member.character,
                        profilePath: member.profile_path
                    )
                }
                bootstrapData.movies[movieIndex].credits = BootstrapCredits(
                    director: director,
                    cast: cast
                )
            }
            
            enrichedCount += 1
            
            // Rate limiting
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            failedCount += 1
        }
    }
    
    // Update generated date
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Save
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING ENRICHED DATA")
    print(String(repeating: "=", count: 70))
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Movies enriched: \(enrichedCount)")
        print("   Movies failed: \(failedCount)")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await enrichCriterionMovies()
    exit(0)
}

RunLoop.main.run()

