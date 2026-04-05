#!/usr/bin/env swift

import Foundation

/// Script to add missing movies to RT Best Movies list with correct ranks and enrich with TMDB data

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

// Movies to add with their ranks
struct MovieToAdd {
    let rank: Int
    let title: String
    let year: Int
}

let moviesToAdd: [MovieToAdd] = [
    MovieToAdd(rank: 3, title: "Casablanca", year: 1942),
    MovieToAdd(rank: 38, title: "Sinners", year: 2025),
    MovieToAdd(rank: 70, title: "Before Sunrise", year: 1995),
    MovieToAdd(rank: 74, title: "The Good, the Bad and the Ugly", year: 1966),
    MovieToAdd(rank: 204, title: "Aladdin", year: 1992),
    MovieToAdd(rank: 213, title: "Hell or High Water", year: 2016),
    MovieToAdd(rank: 227, title: "A Fistful of Dollars", year: 1964),
    MovieToAdd(rank: 232, title: "Lady Bird", year: 2017),
    MovieToAdd(rank: 235, title: "Brooklyn", year: 2015),
    MovieToAdd(rank: 263, title: "WALL-E", year: 2008),
    MovieToAdd(rank: 285, title: "I Was Born, But ...", year: 1932),
    MovieToAdd(rank: 288, title: "Robot Dreams", year: 2023),
    MovieToAdd(rank: 300, title: "One Flew Over the Cuckoo's Nest", year: 1975)
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
    
    func searchMovie(title: String, year: Int) async throws -> TMDBMovie? {
        let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
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

func addMissingRTBestMovies() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🎬 Adding Missing RT Best Movies\n")
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
    print("   Found \(rtMovies.count) existing RT Best Movies entries")
    
    let tmdbService = TMDBService()
    var moviesToProcess: [(movieToAdd: MovieToAdd, existingIndex: Int?)] = []
    
    // Check which movies already exist
    for movieToAdd in moviesToAdd {
        let existing = rtMovies.first { movie in
            let titleMatch = movie.title.lowercased().contains(movieToAdd.title.lowercased()) ||
                           movieToAdd.title.lowercased().contains(movie.title.lowercased())
            let yearMatch = movie.year == movieToAdd.year
            return titleMatch && yearMatch
        }
        
        if let existing = existing {
            if let existingIndex = bootstrapData.movies.firstIndex(where: { movie in
                movie.title == existing.title &&
                movie.sourceIdentifier == "rt-best-all-time" &&
                movie.year == existing.year
            }) {
                moviesToProcess.append((movieToAdd: movieToAdd, existingIndex: existingIndex))
                print("   Found existing: \(movieToAdd.title) (\(movieToAdd.year)) - currently at rank \(existing.rank ?? -1)")
            }
        } else {
            moviesToProcess.append((movieToAdd: movieToAdd, existingIndex: nil))
            print("   Missing: \(movieToAdd.title) (\(movieToAdd.year))")
        }
    }
    
    print("\n" + String(repeating: "=", count: 70))
    print("🎬 PROCESSING MOVIES")
    print(String(repeating: "=", count: 70))
    
    var addedCount = 0
    var updatedCount = 0
    
    for (index, item) in moviesToProcess.enumerated() {
        let movieToAdd = item.movieToAdd
        print("\n[\(index + 1)/\(moviesToProcess.count)] Processing rank \(movieToAdd.rank): \(movieToAdd.title) (\(movieToAdd.year))")
        
        var movie: BootstrapMovie
        
        if let existingIndex = item.existingIndex {
            // Update existing movie
            movie = bootstrapData.movies[existingIndex]
            movie.rank = movieToAdd.rank
            print("   ✅ Updating existing entry")
        } else {
            // Create new movie
            movie = BootstrapMovie(
                title: movieToAdd.title,
                sourceIdentifier: "rt-best-all-time",
                rank: movieToAdd.rank,
                sourceTitle: nil,
                tmdbId: nil,
                year: movieToAdd.year,
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
            bootstrapData.movies.append(movie)
            addedCount += 1
            print("   ✅ Created new entry")
        }
        
        // Enrich with TMDB if not already enriched
        if movie.tmdbId == nil {
            do {
                if let searchResult = try await tmdbService.searchMovie(title: movieToAdd.title, year: movieToAdd.year) {
                    print("   ✅ Found in TMDB (ID: \(searchResult.id))")
                    
                    let details = try? await tmdbService.getMovieDetails(tmdbId: searchResult.id)
                    let credits = try? await tmdbService.getMovieCredits(tmdbId: searchResult.id)
                    
                    if let existingIndex = item.existingIndex {
                        bootstrapData.movies[existingIndex].tmdbId = searchResult.id
                        bootstrapData.movies[existingIndex].posterPath = details?.poster_path ?? searchResult.poster_path
                        bootstrapData.movies[existingIndex].backdropPath = details?.backdrop_path ?? searchResult.backdrop_path
                        bootstrapData.movies[existingIndex].overview = details?.overview ?? searchResult.overview
                        
                        if let releaseDate = details?.release_date ?? searchResult.release_date,
                           let releaseYear = Int(releaseDate.prefix(4)) {
                            bootstrapData.movies[existingIndex].year = releaseYear
                        }
                        
                        if let mpaa = details?.mpaaRating {
                            bootstrapData.movies[existingIndex].mpaaRating = mpaa
                        }
                        
                        if let genres = details?.genres {
                            bootstrapData.movies[existingIndex].genres = genres.map { $0.name }
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
                            bootstrapData.movies[existingIndex].credits = BootstrapCredits(
                                director: director,
                                cast: cast
                            )
                        }
                        updatedCount += 1
                    } else {
                        // Update the newly added movie
                        if let lastIndex = bootstrapData.movies.lastIndex(where: { $0.title == movieToAdd.title && $0.sourceIdentifier == "rt-best-all-time" }) {
                            bootstrapData.movies[lastIndex].tmdbId = searchResult.id
                            bootstrapData.movies[lastIndex].posterPath = details?.poster_path ?? searchResult.poster_path
                            bootstrapData.movies[lastIndex].backdropPath = details?.backdrop_path ?? searchResult.backdrop_path
                            bootstrapData.movies[lastIndex].overview = details?.overview ?? searchResult.overview
                            
                            if let releaseDate = details?.release_date ?? searchResult.release_date,
                               let releaseYear = Int(releaseDate.prefix(4)) {
                                bootstrapData.movies[lastIndex].year = releaseYear
                            }
                            
                            if let mpaa = details?.mpaaRating {
                                bootstrapData.movies[lastIndex].mpaaRating = mpaa
                            }
                            
                            if let genres = details?.genres {
                                bootstrapData.movies[lastIndex].genres = genres.map { $0.name }
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
                                bootstrapData.movies[lastIndex].credits = BootstrapCredits(
                                    director: director,
                                    cast: cast
                                )
                            }
                        }
                    }
                    
                    try? await Task.sleep(nanoseconds: 250_000_000) // Rate limiting
                } else {
                    print("   ⚠️  Not found in TMDB")
                }
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
            }
        } else {
            // Just update the rank if it's different
            if let existingIndex = item.existingIndex {
                if bootstrapData.movies[existingIndex].rank != movieToAdd.rank {
                    bootstrapData.movies[existingIndex].rank = movieToAdd.rank
                    updatedCount += 1
                    print("   ✅ Rank updated")
                } else {
                    print("   ✅ Already at correct rank")
                }
            }
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
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Added: \(addedCount) new movies")
        print("   Updated: \(updatedCount) existing movies")
        print("   Total RT Best Movies: \(rtMoviesAfter.count)")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await addMissingRTBestMovies()
    exit(0)
}

RunLoop.main.run()

