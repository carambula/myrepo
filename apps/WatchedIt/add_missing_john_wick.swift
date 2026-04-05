#!/usr/bin/env swift

import Foundation

/// Script to add missing John Wick movies from Rewatchables to bootstrap data

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

// MARK: - Movies to Add

struct MovieToAdd {
    let title: String
    let year: Int
    let tmdbId: Int
    let sourceIdentifier: String
    let sourceTitle: String
}

let moviesToAdd: [MovieToAdd] = [
    MovieToAdd(title: "John Wick", year: 2014, tmdbId: 245891, sourceIdentifier: "rewatchables", sourceTitle: "John Wick"),
    MovieToAdd(title: "John Wick: Chapter 2", year: 2017, tmdbId: 324552, sourceIdentifier: "rewatchables", sourceTitle: "John Wick: Chapter 2"),
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

func addMissingJohnWickMovies() async throws {
    print("🔧 Adding Missing John Wick Movies to Bootstrap Data\n")
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
    
    // Check if movies already exist
    print("\n🔍 Checking if movies already exist...")
    print(String(repeating: "-", count: 70))
    
    var addedCount = 0
    
    for movieToAdd in moviesToAdd {
        print("\n📽️  \(movieToAdd.title) (\(movieToAdd.year)):")
        
        // Check if already exists
        let exists = bootstrapData.movies.contains { movie in
            (movie.tmdbId == movieToAdd.tmdbId) ||
            (movie.title.lowercased() == movieToAdd.title.lowercased() && 
             movie.sourceIdentifier == movieToAdd.sourceIdentifier)
        }
        
        if exists {
            print("   ℹ️  Already exists in JSON, skipping...")
            continue
        }
        
        print("   Fetching TMDB data for ID \(movieToAdd.tmdbId)...")
        
        // Fetch movie details from TMDB
        if let details = try? await fetchTMDBMovieDetails(tmdbId: movieToAdd.tmdbId) {
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
            
            // Get director
            var director: String? = nil
            if let directorPerson = details.credits?.crew?.first(where: { $0.job == "Director" }) {
                director = directorPerson.name
            }
            
            // Create new movie
            let newMovie = BootstrapMovie(
                title: details.title,
                sourceIdentifier: movieToAdd.sourceIdentifier,
                rank: nil,
                sourceTitle: movieToAdd.sourceTitle,
                tmdbId: details.id,
                year: movieToAdd.year,
                posterPath: details.posterPath,
                backdropPath: details.backdropPath,
                overview: details.overview,
                mpaaRating: mpaaRating,
                genres: details.genres?.map { $0.name },
                streamingServices: nil,
                credits: director != nil ? BootstrapCredits(director: director, cast: nil) : nil,
                trailer: nil,
                podcastEpisodeDescription: nil
            )
            
            bootstrapData.movies.append(newMovie)
            addedCount += 1
            
            print("   ✅ Added to JSON")
            print("   ✅ Year: \(movieToAdd.year)")
            if let poster = details.posterPath {
                print("   ✅ Poster added")
            }
            if let backdrop = details.backdropPath {
                print("   ✅ Backdrop added")
            }
            if let overview = details.overview {
                print("   ✅ Overview added")
            }
            if let genres = details.genres, !genres.isEmpty {
                print("   ✅ Genres: \(genres.map { $0.name }.joined(separator: ", "))")
            }
            if let rating = mpaaRating {
                print("   ✅ MPAA Rating: \(rating)")
            }
            if let director = director {
                print("   ✅ Director: \(director)")
            }
        } else {
            print("   ⚠️  Could not fetch TMDB data")
        }
    }
    
    // Update source counts
    print("\n📊 Updating source counts...")
    for (index, source) in bootstrapData.dataSources.enumerated() {
        let count = bootstrapData.movies.filter { $0.sourceIdentifier == source.identifier }.count
        if count != source.movieCount {
            print("   \(source.name): \(source.movieCount) → \(count)")
            // Note: Can't modify struct directly, but count will be recalculated on next generation
        }
    }
    
    // Save updated JSON
    print("\n💾 Saving updated bootstrap_data.json...")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let updatedJSONData = try encoder.encode(bootstrapData)
    try updatedJSONData.write(to: jsonURL)
    print("   ✅ Saved \(bootstrapData.movies.count) movies")
    
    print("\n" + String(repeating: "=", count: 70))
    print("✅ Added \(addedCount) missing John Wick movies")
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
        try await addMissingJohnWickMovies()
        print("\n✅ Script completed successfully")
        exit(0)
    } catch {
        print("\n❌ Error: \(error)")
        exit(1)
    }
}

RunLoop.main.run()





