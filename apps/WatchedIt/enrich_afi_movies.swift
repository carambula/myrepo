#!/usr/bin/env swift

import Foundation

/// Script to enrich AFI movies in bootstrap_data.json with complete TMDB metadata

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
    let sourceIdentifier: String
    let rank: Int?
    let sourceTitle: String?
    
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

// MARK: - TMDB API

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
}

struct TMDBSearchResponse: Codable {
    let results: [TMDBMovie]
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let genres: [TMDBGenre]?
    let certification: String?
    let mpaaRating: String?
}

struct TMDBReleaseDates: Codable {
    let results: [TMDBReleaseDateResult]?
}

struct TMDBReleaseDateResult: Codable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]?
}

struct TMDBReleaseDate: Codable {
    let certification: String?
}

struct TMDBCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
}

struct TMDBCredits: Codable {
    let director: String?
    let cast: [TMDBCastMember]?
}

struct TMDBVideo: Codable {
    let id: String
    let name: String
    let key: String
    let type: String
    let official: Bool?
}

struct TMDBVideosResponse: Codable {
    let results: [TMDBVideo]?
}

struct TMDBStreamingProvider: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int
}

struct TMDBWatchProviders: Codable {
    let results: [String: TMDBWatchProviderResult]?
}

struct TMDBWatchProviderResult: Codable {
    let flatrate: [TMDBStreamingProvider]?
    let buy: [TMDBStreamingProvider]?
    let rent: [TMDBStreamingProvider]?
}

class TMDBService {
    static let shared = TMDBService()
    private let apiKey: String
    private let baseURL = "https://api.themoviedb.org/3"
    
    private init() {
        // Try to get API key from environment or Info.plist
        if let key = ProcessInfo.processInfo.environment["TMDB_API_KEY"] {
            self.apiKey = key
        } else {
            // Fallback - you'll need to set this
            self.apiKey = "YOUR_TMDB_API_KEY"
            print("⚠️  Warning: Using placeholder API key. Set TMDB_API_KEY environment variable.")
        }
    }
    
    func searchMovie(title: String, year: Int? = nil) async throws -> TMDBMovie? {
        var urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let year = year {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return response.results.first
    }
    
    func getMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
        let urlString = "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try? JSONDecoder().decode(TMDBMovieDetails.self, from: data)
    }
    
    func getMPAARating(tmdbId: Int) async throws -> String? {
        let urlString = "\(baseURL)/movie/\(tmdbId)/release_dates?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let releaseDates = try? JSONDecoder().decode(TMDBReleaseDates.self, from: data)
        
        if let usResult = releaseDates?.results?.first(where: { $0.iso31661 == "US" }),
           let dates = usResult.releaseDates {
            return dates.first(where: { $0.certification != nil && !$0.certification!.isEmpty })?.certification
        }
        return nil
    }
    
    func getMovieCredits(tmdbId: Int) async throws -> TMDBCredits? {
        let urlString = "\(baseURL)/movie/\(tmdbId)/credits?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let credits = try? JSONDecoder().decode([String: Any].self, from: data)
        
        // Extract director
        let crew = credits?["crew"] as? [[String: Any]]
        let director = crew?.first(where: { ($0["job"] as? String) == "Director" })?["name"] as? String
        
        // Extract cast
        let castArray = credits?["cast"] as? [[String: Any]]
        let cast = castArray?.prefix(10).map { member -> TMDBCastMember in
            TMDBCastMember(
                id: member["id"] as? Int ?? 0,
                name: member["name"] as? String ?? "",
                character: member["character"] as? String,
                profilePath: member["profile_path"] as? String
            )
        }
        
        return TMDBCredits(director: director, cast: cast)
    }
    
    func getMovieVideos(tmdbId: Int) async throws -> BootstrapTrailer? {
        let urlString = "\(baseURL)/movie/\(tmdbId)/videos?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try? JSONDecoder().decode(TMDBVideosResponse.self, from: data)
        
        // Find official trailer
        if let trailer = response?.results?.first(where: { $0.type == "Trailer" && ($0.official == true || $0.name.lowercased().contains("trailer")) }) {
            return BootstrapTrailer(
                id: trailer.id,
                name: trailer.name,
                youtubeKey: trailer.key,
                isOfficial: trailer.official ?? false
            )
        }
        return nil
    }
    
    func getStreamingProviders(tmdbId: Int) async throws -> [BootstrapStreamingService] {
        let urlString = "\(baseURL)/movie/\(tmdbId)/watch/providers?api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try? JSONDecoder().decode(TMDBWatchProviders.self, from: data)
        
        var providers: [BootstrapStreamingService] = []
        
        if let usProviders = response?.results?["US"] {
            // Add streaming services
            if let flatrate = usProviders.flatrate {
                providers.append(contentsOf: flatrate.map { provider in
                    BootstrapStreamingService(
                        providerId: provider.providerId,
                        providerName: provider.providerName,
                        logoPath: provider.logoPath,
                        displayPriority: provider.displayPriority
                    )
                })
            }
        }
        
        return providers
    }
}

// MARK: - Main Function

func enrichAFIMovies() async {
    let inputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    let outputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    
    print("📂 Loading bootstrap data...")
    
    guard let url = URL(fileURLWithPath: inputFile) as URL?,
          let data = try? Data(contentsOf: url),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Could not load bootstrap_data.json")
        return
    }
    
    // Get AFI movies that need enrichment
    let afiMovies = bootstrapData.movies.filter { movie in
        movie.sourceIdentifier == "afi-100-1998" && movie.tmdbId == nil
    }
    
    print("✅ Found \(afiMovies.count) AFI movies to enrich\n")
    
    let tmdbService = TMDBService.shared
    var enriched = 0
    var failed = 0
    
    for (index, movie) in afiMovies.enumerated() {
        guard let movieIndex = bootstrapData.movies.firstIndex(where: { 
            $0.title == movie.title && 
            $0.sourceIdentifier == movie.sourceIdentifier &&
            $0.rank == movie.rank
        }) else {
            continue
        }
        
        let progress = Double(index + 1) / Double(afiMovies.count) * 100
        print("[\(String(format: "%.1f", progress))%] Enriching '\(movie.title)' (\(movie.year ?? 0))...")
        
        do {
            // Search for movie in TMDB
            let searchResult = try await tmdbService.searchMovie(title: movie.title, year: movie.year)
            
            guard let tmdbMovie = searchResult else {
                print("   ⚠️  Not found in TMDB")
                failed += 1
                // Rate limiting
                try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
                continue
            }
            
            print("   ✅ Found: TMDB ID \(tmdbMovie.id)")
            
            // Get full details
            let details = try await tmdbService.getMovieDetails(tmdbId: tmdbMovie.id)
            
            // Fetch additional data in parallel
            async let creditsTask = tmdbService.getMovieCredits(tmdbId: tmdbMovie.id)
            async let streamingTask = tmdbService.getStreamingProviders(tmdbId: tmdbMovie.id)
            async let mpaaTask = tmdbService.getMPAARating(tmdbId: tmdbMovie.id)
            async let videosTask = tmdbService.getMovieVideos(tmdbId: tmdbMovie.id)
            
            let credits = try await creditsTask
            let streaming = try await streamingTask
            let mpaa = try await mpaaTask
            let trailer = try await videosTask
            
            // Update movie
            bootstrapData.movies[movieIndex].tmdbId = tmdbMovie.id
            bootstrapData.movies[movieIndex].posterPath = details?.posterPath ?? tmdbMovie.posterPath
            bootstrapData.movies[movieIndex].backdropPath = details?.backdropPath ?? tmdbMovie.backdropPath
            bootstrapData.movies[movieIndex].overview = details?.overview ?? tmdbMovie.overview
            
            if let details = details {
                bootstrapData.movies[movieIndex].genres = details.genres?.map { $0.name }
            }
            
            bootstrapData.movies[movieIndex].mpaaRating = mpaa
            bootstrapData.movies[movieIndex].streamingServices = streaming.isEmpty ? nil : streaming
            bootstrapData.movies[movieIndex].credits = credits.map { cred in
                BootstrapCredits(
                    director: cred.director,
                    cast: cred.cast?.map { member in
                        BootstrapCastMember(
                            id: member.id,
                            name: member.name,
                            character: member.character,
                            profilePath: member.profilePath
                        )
                    }
                )
            }
            bootstrapData.movies[movieIndex].trailer = trailer
            
            enriched += 1
            print("   ✅ Enriched successfully")
            
            // Rate limiting - TMDB allows 40 requests per 10 seconds
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds between requests
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            failed += 1
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    // Save updated data
    print("\n💾 Saving enriched data...")
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: URL(fileURLWithPath: outputFile))
        
        print("\n✅ Enrichment complete!")
        print("   Enriched: \(enriched)")
        print("   Failed: \(failed)")
        print("   Output: \(outputFile)")
    } catch {
        print("❌ Error saving enriched data: \(error)")
    }
}

// Run
Task {
    await enrichAFIMovies()
    exit(0)
}

RunLoop.main.run()

