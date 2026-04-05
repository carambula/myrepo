#!/usr/bin/env swift

import Foundation

/// Script to enrich incomplete movies in RT: Oscars Best and Worst list with TMDB data

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

// MARK: - Movies to Fix

struct MovieToFix {
    let title: String
    let correctYear: Int?
    let correctTmdbId: Int?
    let rank: Int?
    let notes: String
}

// These are the incomplete movies identified from the database
// Note: Current database has wrong years/TMDB IDs - fixing to correct ones
let moviesToFix: [MovieToFix] = [
    MovieToFix(title: "Ordinary People", correctYear: 1980, correctTmdbId: 16619, rank: 65, notes: "Was 2002/TMDB 721945 - fixing to 1980/16619"),
    MovieToFix(title: "A Man for All Seasons", correctYear: 1966, correctTmdbId: 874, rank: 66, notes: "Was 2014/TMDB 1289656 - fixing to 1966/874"),
    MovieToFix(title: "Dances With Wolves", correctYear: 1990, correctTmdbId: 581, rank: 73, notes: "Was 2018/TMDB 577941 - fixing to 1990/581"),
    MovieToFix(title: "Grand Hotel", correctYear: 1932, correctTmdbId: 33680, rank: 74, notes: "Was 1927/TMDB 648745 - fixing to 1932/33680, missing poster/backdrop"),
    MovieToFix(title: "Around the World in 80 Days", correctYear: 1956, correctTmdbId: 2897, rank: 93, notes: "Was 1974/TMDB 229449 - fixing to 1956/2897, missing poster/backdrop"),
    MovieToFix(title: "Cavalcade", correctYear: 1933, correctTmdbId: 56164, rank: 94, notes: "Was 1959/TMDB 865417 - fixing to 1933/56164, missing backdrop"),
]

// MARK: - TMDB API

let tmdbAPIKey = ProcessInfo.processInfo.environment["TMDB_API_KEY"] ?? "4f6ab1dde752aedd41093bab21f383c7"
let tmdbBaseURL = "https://api.themoviedb.org/3"

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let voteAverage: Double?
    let voteCount: Int?
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

struct TMDBResponse: Codable {
    let results: [TMDBMovie]?
}

// MARK: - Main Function

func enrichOscarMovies() async throws {
    print("🔧 Enriching RT: Oscars Best and Worst Movies\n")
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
    print("\n🔍 Finding and enriching incomplete movies...")
    print(String(repeating: "-", count: 70))
    
    var enrichedCount = 0
    
    for movieToFix in moviesToFix {
        print("\n📽️  \(movieToFix.title):")
        
        // Find movie in JSON - match by source, rank, and title
        var found = false
        for (index, movie) in bootstrapData.movies.enumerated() {
            let isCorrectSource = movie.sourceIdentifier == "rt-oscars"
            let isCorrectRank = movieToFix.rank == nil || movie.rank == movieToFix.rank
            let titleMatches = movie.title.lowercased().contains(movieToFix.title.lowercased()) || 
                              movieToFix.title.lowercased().contains(movie.title.lowercased())
            
            if isCorrectSource && isCorrectRank && titleMatches {
                print("   Found: \(movie.title) (current: year=\(movie.year ?? 0), tmdb=\(movie.tmdbId ?? 0), rank=\(movie.rank ?? 0))")
                
                // Use correct TMDB ID and year from movieToFix
                let tmdbId = movieToFix.correctTmdbId
                let year = movieToFix.correctYear
                
                guard let tmdbId = tmdbId, let year = year else {
                    print("   ⚠️  Missing TMDB ID or year for \(movieToFix.title)")
                    break
                }
                
                print("   Fetching TMDB data for ID \(tmdbId)...")
                
                // Fetch movie details from TMDB
                if let details = try? await fetchTMDBMovieDetails(tmdbId: tmdbId) {
                    // Update movie with TMDB data
                    bootstrapData.movies[index].tmdbId = details.id
                    bootstrapData.movies[index].year = year
                    print("   ✅ Year: \(year)")
                    
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
                    var mpaaRating: String? = details.mpaaRating ?? details.certification
                    if mpaaRating == nil, let releaseDates = details.releaseDates?.results {
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
        var details = try decoder.decode(TMDBMovieDetails.self, from: data)
        
        return details
    } catch {
        print("   ⚠️  Error decoding TMDB response: \(error)")
        return nil
    }
}


// Run
Task {
    do {
        try await enrichOscarMovies()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()

