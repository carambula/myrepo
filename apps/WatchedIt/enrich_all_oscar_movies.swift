#!/usr/bin/env swift

import Foundation

/// Script to enrich all incomplete Oscar movies with complete TMDB data

// MARK: - Data Structures

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
    let version: String?
    let generatedDate: String?
    let dataSources: [BootstrapDataSource]
    var movies: [BootstrapMovie]
}

struct BootstrapDataSource: Codable {
    let identifier: String
    let name: String
    let type: String
    let url: String?
    let isRankedList: Bool
    let movieCount: Int
}

// MARK: - Movies to Enrich

struct MovieToEnrich {
    let title: String
    let year: Int
    let tmdbId: Int
    let rank: Int?
    let notes: String
}

// All movies the user requested to be enriched
let moviesToEnrich: [MovieToEnrich] = [
    MovieToEnrich(title: "Casablanca", year: 1942, tmdbId: 289, rank: nil, notes: ""),
    MovieToEnrich(title: "On the Waterfront", year: 1954, tmdbId: 654, rank: nil, notes: ""),
    MovieToEnrich(title: "All About Eve", year: 1950, tmdbId: 705, rank: nil, notes: ""),
    MovieToEnrich(title: "It Happened One Night", year: 1934, tmdbId: 3083, rank: nil, notes: ""),
    MovieToEnrich(title: "Rebecca", year: 1940, tmdbId: 3084, rank: nil, notes: ""),
    MovieToEnrich(title: "All Quiet on the Western Front", year: 1930, tmdbId: 143, rank: nil, notes: ""),
    MovieToEnrich(title: "Sunrise", year: 1927, tmdbId: 631, rank: nil, notes: ""),
    MovieToEnrich(title: "Annie Hall", year: 1977, tmdbId: 703, rank: nil, notes: ""),
    MovieToEnrich(title: "The Best Years of Our Lives", year: 1946, tmdbId: 887, rank: nil, notes: ""),
    MovieToEnrich(title: "The French Connection", year: 1971, tmdbId: 1051, rank: nil, notes: ""),
    MovieToEnrich(title: "The Lost Weekend", year: 1945, tmdbId: 28580, rank: nil, notes: ""),
    MovieToEnrich(title: "Argo", year: 2012, tmdbId: 68734, rank: nil, notes: ""),
    MovieToEnrich(title: "The Bridge on the River Kwai", year: 1957, tmdbId: 826, rank: nil, notes: ""),
    MovieToEnrich(title: "Unforgiven", year: 1992, tmdbId: 33, rank: nil, notes: ""),
    MovieToEnrich(title: "12 Years a Slave", year: 2013, tmdbId: 76203, rank: nil, notes: ""),
    MovieToEnrich(title: "In the Heat of the Night", year: 1967, tmdbId: 10633, rank: nil, notes: ""),
    MovieToEnrich(title: "The King's Speech", year: 2010, tmdbId: 45269, rank: nil, notes: ""),
    MovieToEnrich(title: "One Flew Over the Cuckoo's Nest", year: 1975, tmdbId: 510, rank: nil, notes: ""),
    MovieToEnrich(title: "Grand Hotel", year: 1932, tmdbId: 33680, rank: 74, notes: "Already enriched but double-checking"),
]

// MARK: - TMDB API

let tmdbAPIKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"] ?? "4f6ab1dde752aedd41093bab21f383c7"
let tmdbBaseURL = "https://api.themoviedb.org/3"

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let genres: [TMDBGenre]?
    let releaseDates: TMDBReleaseDates?
    let credits: TMDBCredits?
    let videos: TMDBVideos?
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
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
    let releaseDate: String?
}

struct TMDBCredits: Codable {
    let cast: [TMDBPerson]?
    let crew: [TMDBPerson]?
}

struct TMDBPerson: Codable {
    let id: Int
    let name: String
    let character: String?
    let job: String?
    let profilePath: String?
}

struct TMDBVideos: Codable {
    let results: [TMDBVideo]?
}

struct TMDBVideo: Codable {
    let id: String
    let key: String
    let name: String
    let type: String
    let official: Bool?
}

// MARK: - Main Function

func enrichAllOscarMovies() async throws {
    print("🔧 Enriching All RT: Oscars Best and Worst Movies\n")
    print(String(repeating: "=", count: 70))
    
    // Load JSON
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    guard FileManager.default.fileExists(atPath: jsonURL.path) else {
        print("❌ Error: bootstrap_data.json not found")
        exit(1)
    }
    
    print("\n📂 Loading bootstrap_data.json...")
    let jsonData = try Data(contentsOf: jsonURL)
    var bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: jsonData)
    
    print("✅ Loaded \(bootstrapData.movies.count) movies")
    
    // Find and enrich each movie
    print("\n🔍 Finding and enriching Oscar movies...")
    print(String(repeating: "-", count: 70))
    
    var enrichedCount = 0
    var notFoundCount = 0
    
    for movieToEnrich in moviesToEnrich {
        print("\n📽️  \(movieToEnrich.title) (\(movieToEnrich.year)):")
        
        // Find movie in JSON - match by title and source
        var found = false
        for (index, movie) in bootstrapData.movies.enumerated() {
            let isCorrectSource = movie.sourceIdentifier == "rt-oscars"
            let titleMatches = movie.title.lowercased().contains(movieToEnrich.title.lowercased()) || 
                              movieToEnrich.title.lowercased().contains(movie.title.lowercased())
            
            if isCorrectSource && titleMatches {
                print("   Found: \(movie.title) (current: year=\(movie.year ?? 0), tmdb=\(movie.tmdbId ?? 0))")
                
                print("   Fetching TMDB data for ID \(movieToEnrich.tmdbId)...")
                
                // Fetch movie details from TMDB
                if let details = try? await fetchTMDBMovieDetails(tmdbId: movieToEnrich.tmdbId) {
                    // Update movie with TMDB data
                    bootstrapData.movies[index].tmdbId = details.id
                    bootstrapData.movies[index].year = movieToEnrich.year
                    print("   ✅ Year: \(movieToEnrich.year)")
                    
                    if let poster = details.posterPath {
                        bootstrapData.movies[index].posterPath = poster
                        print("   ✅ Poster added")
                    }
                    
                    if let backdrop = details.backdropPath {
                        bootstrapData.movies[index].backdropPath = backdrop
                        print("   ✅ Backdrop added")
                    }
                    
                    if let overview = details.overview, !overview.isEmpty {
                        bootstrapData.movies[index].overview = overview
                        print("   ✅ Overview updated")
                    }
                    
                    if let genres = details.genres, !genres.isEmpty {
                        bootstrapData.movies[index].genres = genres.map { $0.name }
                        print("   ✅ Genres: \(genres.map { $0.name }.joined(separator: ", "))")
                    }
                    
                    // Get MPAA rating
                    var mpaaRating: String? = nil
                    if let releaseDates = details.releaseDates?.results {
                        for result in releaseDates {
                            if result.iso31661 == "US", let dates = result.releaseDates {
                                mpaaRating = dates.first(where: { $0.certification != nil && !$0.certification!.isEmpty })?.certification
                                break
                            }
                        }
                    }
                    if let rating = mpaaRating {
                        bootstrapData.movies[index].mpaaRating = rating
                        print("   ✅ MPAA Rating: \(rating)")
                    }
                    
                    // Get director
                    if let director = details.credits?.crew?.first(where: { $0.job == "Director" }) {
                        if bootstrapData.movies[index].credits == nil {
                            bootstrapData.movies[index].credits = BootstrapCredits(director: director.name, cast: nil)
                        } else {
                            var credits = bootstrapData.movies[index].credits!
                            credits = BootstrapCredits(director: director.name, cast: credits.cast)
                            bootstrapData.movies[index].credits = credits
                        }
                        print("   ✅ Director: \(director.name)")
                    }
                    
                    enrichedCount += 1
                    found = true
                    print("   ✅ Enriched successfully")
                } else {
                    print("   ⚠️  Could not fetch TMDB data")
                }
                
                break
            }
        }
        
        if !found {
            print("   ⚠️  Movie not found in JSON")
            notFoundCount += 1
        }
    }
    
    // Save updated JSON
    print("\n💾 Saving updated bootstrap_data.json...")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let updatedJSONData = try encoder.encode(bootstrapData)
    try updatedJSONData.write(to: jsonURL)
    print("   ✅ Saved")
    
    print("\n" + String(repeating: "=", count: 70))
    print("✅ Enriched \(enrichedCount) movies")
    if notFoundCount > 0 {
        print("⚠️  \(notFoundCount) movies not found in JSON")
    }
    print("\n💡 Next step: Run 'swift generate_bootstrap_database.swift' to regenerate the database")
}

// MARK: - TMDB API Functions

func fetchTMDBMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
    let urlString = "\(tmdbBaseURL)/movie/\(tmdbId)?api_key=\(tmdbAPIKey)&append_to_response=credits,videos,release_dates"
    guard let url = URL(string: urlString) else { return nil }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    
    do {
        let details = try decoder.decode(TMDBMovieDetails.self, from: data)
        return details
    } catch {
        print("   ⚠️  Error decoding TMDB response: \(error)")
        return nil
    }
}

// Run
Task {
    do {
        try await enrichAllOscarMovies()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

