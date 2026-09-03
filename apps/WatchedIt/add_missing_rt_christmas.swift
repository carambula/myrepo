#!/usr/bin/env swift

import Foundation

/// Script to add the 2 missing RT Christmas movies

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

// Missing titles with their ranks
let missingTitles: [(rank: Int, title: String, year: Int)] = [
    (rank: 15, title: "Little Women (1994)", year: 1994),
    (rank: 85, title: "Miracle on 34th Street (1994)", year: 1994),
    (rank: 43, title: "How the Grinch Stole Christmas (1967)", year: 1967)
]

// TMDB Service
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
    
    func cleanTitle(_ title: String) -> String {
        var cleaned = title
        let yearPattern = #"\s*\(\d{4}\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: yearPattern) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    func searchMovie(title: String, year: Int) async throws -> TMDBMovie? {
        let cleanedTitle = cleanTitle(title)
        let encodedTitle = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanedTitle
        let urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(encodedTitle)&year=\(year)&language=en-US"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        
        // Find best match by year
        let yearMatch = response.results.first { movie in
            if let releaseDate = movie.release_date, let movieYear = Int(releaseDate.prefix(4)) {
                return abs(movieYear - year) <= 1
            }
            return false
        }
        
        return yearMatch ?? response.results.first
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

func addMissingRTChristmas() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎄 Adding Missing RT Christmas Movies\n")
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
    
    let tmdbService = TMDBService()
    var newMovies: [BootstrapMovie] = []
    
    for (rank, title, year) in missingTitles {
        print("\n📽️  Adding [Rank \(rank)]: \(title)")
        
        var movie = BootstrapMovie(
            title: title,
            sourceIdentifier: "rt-christmas",
            rank: rank,
            sourceTitle: nil,
            tmdbId: nil,
            year: year,
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
        
        // Enrich with TMDB
        do {
            if let searchResult = try await tmdbService.searchMovie(title: title, year: year) {
                print("   ✅ Found in TMDB (ID: \(searchResult.id))")
                
                let details = try? await tmdbService.getMovieDetails(tmdbId: searchResult.id)
                let credits = try? await tmdbService.getMovieCredits(tmdbId: searchResult.id)
                
                movie.tmdbId = searchResult.id
                movie.posterPath = details?.poster_path ?? searchResult.poster_path
                movie.backdropPath = details?.backdrop_path ?? searchResult.backdrop_path
                movie.overview = details?.overview ?? searchResult.overview
                
                if let releaseDate = details?.release_date ?? searchResult.release_date,
                   let releaseYear = Int(releaseDate.prefix(4)) {
                    movie.year = releaseYear
                }
                
                if let mpaa = details?.mpaaRating {
                    movie.mpaaRating = mpaa
                }
                
                if let genres = details?.genres {
                    movie.genres = genres.map { $0.name }
                }
                
                if let creditsData = credits {
                    let director = creditsData.crew?.first { $0.job == "Director" }?.name
                    let cast = creditsData.cast?.prefix(5).compactMap { member -> BootstrapCastMember? in
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
                
                try? await Task.sleep(nanoseconds: 250_000_000)
            } else {
                print("   ⚠️  Not found in TMDB")
            }
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
        }
        
        newMovies.append(movie)
    }
    
    // Add movies
    bootstrapData.movies.append(contentsOf: newMovies)
    
    // Update source count
    if let index = bootstrapData.dataSources.firstIndex(where: { $0.identifier == "rt-christmas" }) {
        bootstrapData.dataSources[index].movieCount = 100
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
        print("   Added \(newMovies.count) movies")
        print("   RT Christmas total: 100 movies")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await addMissingRTChristmas()
    exit(0)
}

RunLoop.main.run()

