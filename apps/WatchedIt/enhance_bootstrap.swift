#!/usr/bin/env swift

// Script to enhance bootstrap data with movie metadata from TMDB and Rotten Tomatoes
// Run this script to update bootstrap_movies.json with genres, RT scores, MPAA ratings, and release dates

import Foundation

let tmdbAPIKey = "4f6ab1dde752aedd41093bab21f383c7"
// Note: Replace with your actual OMDb API key from http://www.omdbapi.com/
// The current key may be invalid - check RottenTomatoesService.swift for the correct key
let omdbAPIKey = "497dede8" // TODO: Update with valid API key
let tmdbBaseURL = "https://api.themoviedb.org/3"
let omdbBaseURL = "https://www.omdbapi.com"

struct BootstrapEpisode: Codable {
    var title: String
    var movieTitle: String?
    var publishDate: String?
    var guid: String
    var description: String?
    // Enhanced fields
    var year: Int?
    var genres: [String]?
    var rtScore: Int?
    var mpaaRating: String?
    var tmdbId: Int?
    // Additional enhanced fields
    var overview: String?
    var posterPath: String?
    var backdropPath: String?
    var director: String?
    var cast: [BootstrapCastMember]?
    var applePodcastsUrl: String?
    var spotifyUrl: String?
    // Trailer fields
    var trailer: BootstrapTrailer?
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

struct TMDBSearchResponse: Codable {
    let results: [TMDBMovie]
}

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    
    var year: Int? {
        guard let releaseDate = releaseDate,
              !releaseDate.isEmpty,
              let yearString = releaseDate.components(separatedBy: "-").first,
              let yearInt = Int(yearString) else {
            return nil
        }
        return yearInt
    }
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let genres: [TMDBGenre]?
    let releaseDates: TMDBReleaseDatesInfo?
    let credits: TMDBCreditsInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case genres
        case releaseDates = "release_dates"
        case credits
    }
    
    var year: Int? {
        guard let releaseDate = releaseDate,
              !releaseDate.isEmpty,
              let yearString = releaseDate.components(separatedBy: "-").first,
              let yearInt = Int(yearString) else {
            return nil
        }
        return yearInt
    }
    
    var genreNames: [String] {
        genres?.map { $0.name } ?? []
    }
    
    var mpaaRating: String? {
        guard let releaseDates = releaseDates?.results else { return nil }
        for country in releaseDates {
            if country.iso31661 == "US" {
                if let releaseDate = country.releaseDates.first(where: { $0.type == 3 || $0.type == 2 }) {
                    return releaseDate.certification.isEmpty ? nil : releaseDate.certification
                }
                if let releaseDate = country.releaseDates.first, !releaseDate.certification.isEmpty {
                    return releaseDate.certification
                }
            }
        }
        return nil
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBReleaseDatesInfo: Codable {
    let results: [TMDBReleaseDateCountry]
}

struct TMDBReleaseDateCountry: Codable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]
    
    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

struct TMDBReleaseDate: Codable {
    let certification: String
    let type: Int
}

struct TMDBCreditsInfo: Codable {
    let cast: [TMDBCastMember]?
    let crew: [TMDBCrewMember]?
    
    var director: String? {
        crew?.first { $0.job == "Director" }?.name
    }
}

struct TMDBCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
    }
}

struct TMDBCrewMember: Codable {
    let id: Int
    let name: String
    let job: String
}

struct TMDBVideosResponse: Codable {
    let results: [TMDBVideo]
}

struct TMDBVideo: Codable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool
    let size: Int
}

struct OMDBResponse: Codable {
    let Response: String?
    let Error: String?
    let Ratings: [OMDBRating]?
    let Year: String?
    let Rated: String?
    
    var isSuccess: Bool {
        Response == "True"
    }
}

struct OMDBRating: Codable {
    let Source: String
    let Value: String
}

func searchTMDB(title: String, year: Int?) async throws -> TMDBMovie? {
    var urlString = "\(tmdbBaseURL)/search/movie?api_key=\(tmdbAPIKey)&query=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    if let year = year {
        urlString += "&year=\(year)"
    }
    
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
    
    return response.results.first
}

func getTMDBDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
    let urlString = "\(tmdbBaseURL)/movie/\(tmdbId)?api_key=\(tmdbAPIKey)&append_to_response=release_dates,credits"
    
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    return try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
}

func getTMDBVideos(tmdbId: Int) async throws -> [TMDBVideo] {
    let urlString = "\(tmdbBaseURL)/movie/\(tmdbId)/videos?api_key=\(tmdbAPIKey)"
    
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(TMDBVideosResponse.self, from: data)
    
    // Filter for trailers and teasers, prefer official trailers
    let trailers = response.results.filter { video in
        (video.type == "Trailer" || video.type == "Teaser") && video.site == "YouTube"
    }
    
    // Sort: official trailers first, then by size (prefer larger)
    return trailers.sorted { first, second in
        if first.official != second.official {
            return first.official && !second.official
        }
        return first.size > second.size
    }
}

func getPosterURL(path: String?) -> String? {
    guard let path = path else { return nil }
    let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
    return "https://image.tmdb.org/t/p/w500\(cleanPath)"
}

func getBackdropURL(path: String?) -> String? {
    guard let path = path else { return nil }
    let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
    return "https://image.tmdb.org/t/p/w1280\(cleanPath)"
}

func getProfileURL(path: String?) -> String? {
    guard let path = path else { return nil }
    let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
    return "https://image.tmdb.org/t/p/w185\(cleanPath)"
}

func getRottenTomatoesScore(title: String, year: Int?) async throws -> Int? {
    var urlString = "\(omdbBaseURL)/?apikey=\(omdbAPIKey)&t=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    if let year = year {
        urlString += "&y=\(year)"
    }
    
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    let response = try JSONDecoder().decode(OMDBResponse.self, from: data)
    
    // Check for API errors
    if !response.isSuccess {
        if let error = response.Error {
            print("      ⚠️ OMDb error: \(error)")
        }
        return nil
    }
    
    if let ratings = response.Ratings {
        for rating in ratings {
            if rating.Source == "Rotten Tomatoes" {
                let scoreString = rating.Value.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
                if let score = Int(scoreString) {
                    return score
                }
            }
        }
    }
    
    return nil
}

func extractYearFromTitle(_ title: String) -> Int? {
    // Try to find year in parentheses like "Movie (1985)"
    let patterns = [
        "\\((\\d{4})\\)",  // (1985)
        "'(\\d{4})",       // '1985
        " (\\d{4})"        // space then 4 digits
    ]
    
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let yearRange = Range(match.range(at: 1), in: title),
           let year = Int(String(title[yearRange])),
           year >= 1900 && year <= 2030 {
            return year
        }
    }
    
    return nil
}

func cleanTitleForSearch(_ title: String) -> (cleanTitle: String, year: Int?) {
    var cleanTitle = title
    
    // Extract year if present
    let year = extractYearFromTitle(title)
    
    // Remove year patterns from title
    cleanTitle = cleanTitle.replacingOccurrences(of: #"\((\d{4})\)"#, with: "", options: .regularExpression)
    cleanTitle = cleanTitle.replacingOccurrences(of: #"'(\d{4})"#, with: "", options: .regularExpression)
    cleanTitle = cleanTitle.replacingOccurrences(of: #"\s+(\d{4})\s*$"#, with: "", options: .regularExpression)
    cleanTitle = cleanTitle.trimmingCharacters(in: CharacterSet(charactersIn: " '()").union(.whitespaces))
    
    return (cleanTitle, year)
}

func enhanceEpisode(_ episode: BootstrapEpisode) async -> BootstrapEpisode {
    guard let movieTitle = episode.movieTitle else { return episode }
    
    var enhanced = episode
    
    // Skip if already has all critical data (but still update if missing optional fields)
    let hasAllCritical = enhanced.year != nil && enhanced.genres != nil && enhanced.mpaaRating != nil && enhanced.tmdbId != nil && enhanced.rtScore != nil
    let hasAllOptional = enhanced.overview != nil && enhanced.posterPath != nil && enhanced.director != nil && enhanced.cast != nil && enhanced.applePodcastsUrl != nil && enhanced.spotifyUrl != nil && enhanced.trailer != nil
    
    if hasAllCritical && hasAllOptional {
        print("  ⏭️  Already has all data, skipping")
        return enhanced
    }
    
    let (cleanTitle, hintYear) = cleanTitleForSearch(movieTitle)
    print("  📡 Fetching data for: \(cleanTitle)\(hintYear != nil ? " (\(hintYear!))" : "")")
    
    // Generate podcast URLs if not present
    if enhanced.applePodcastsUrl == nil {
        enhanced.applePodcastsUrl = "https://podcasts.apple.com/us/podcast/the-rewatchables/id1268527882"
    }
    
    if enhanced.spotifyUrl == nil {
        let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        enhanced.spotifyUrl = "https://open.spotify.com/search/\(encodedTitle)%20rewatchables"
    }
    
    // Search TMDB with year hint if available
    do {
        if let tmdbMovie = try await searchTMDB(title: cleanTitle, year: hintYear) {
            enhanced.tmdbId = tmdbMovie.id
            print("    🔍 Found in TMDB: ID=\(tmdbMovie.id)")
            
            // Get detailed info - this has the actual releaseDate and other data
            do {
                if let details = try await getTMDBDetails(tmdbId: tmdbMovie.id) {
                    // Always update with details (more accurate)
                    if let year = details.year {
                        enhanced.year = year
                        print("    📅 Year: \(year)")
                    }
                    
                    if !details.genreNames.isEmpty {
                        enhanced.genres = details.genreNames
                        print("    🎭 Genres: \(details.genreNames.joined(separator: ", "))")
                    }
                    
                    if let mpaa = details.mpaaRating {
                        enhanced.mpaaRating = mpaa
                        print("    🎬 Rating: \(mpaa)")
                    }
                    
                    // Movie description/overview
                    if let overview = details.overview, !overview.isEmpty {
                        enhanced.overview = overview
                        print("    📝 Overview: \(overview.prefix(50))...")
                    }
                    
                    // Poster and backdrop paths
                    if let posterPath = details.posterPath {
                        enhanced.posterPath = getPosterURL(path: posterPath)
                        print("    🖼️  Poster: \(enhanced.posterPath ?? "N/A")")
                    }
                    
                    if let backdropPath = details.backdropPath {
                        enhanced.backdropPath = getBackdropURL(path: backdropPath)
                        print("    🎨 Backdrop: \(enhanced.backdropPath ?? "N/A")")
                    }
                    
                    // Director and cast
                    if let director = details.credits?.director {
                        enhanced.director = director
                        print("    🎬 Director: \(director)")
                    }
                    
                    if let cast = details.credits?.cast {
                        // Get top 5 cast members
                        let topCast = Array(cast.prefix(5).map { member in
                            BootstrapCastMember(
                                id: member.id,
                                name: member.name,
                                character: member.character,
                                profilePath: getProfileURL(path: member.profilePath)
                            )
                        })
                        if !topCast.isEmpty {
                            enhanced.cast = topCast
                            print("    👥 Cast: \(topCast.map { $0.name }.joined(separator: ", "))")
                        }
                    }
                    
                    // Get RT score with year if available (skip if OMDb key invalid)
                    let rtYear = enhanced.year ?? details.year ?? hintYear
                    do {
                        if let rtScore = try await getRottenTomatoesScore(title: cleanTitle, year: rtYear) {
                            enhanced.rtScore = rtScore
                            print("    🍅 RT Score: \(rtScore)%")
                        } else if rtYear != nil {
                            // Try without year if year search failed
                            if let rtScore = try? await getRottenTomatoesScore(title: cleanTitle, year: nil) {
                                enhanced.rtScore = rtScore
                                print("    🍅 RT Score: \(rtScore)% (without year)")
                            }
                        }
                    } catch {
                        // OMDb API might be invalid or rate-limited, continue anyway
                        print("    ⚠️  RT Score: Unable to fetch (API key may be invalid)")
                    }
                    
                    // Get trailer
                    do {
                        let videos = try await getTMDBVideos(tmdbId: tmdbMovie.id)
                        if let firstTrailer = videos.first {
                            enhanced.trailer = BootstrapTrailer(
                                id: firstTrailer.id,
                                name: firstTrailer.name,
                                youtubeKey: firstTrailer.key,
                                isOfficial: firstTrailer.official
                            )
                            print("    🎬 Trailer: \(firstTrailer.name)\(firstTrailer.official ? " (Official)" : "")")
                        }
                    } catch {
                        print("    ⚠️  Trailer: Unable to fetch (\(error.localizedDescription))")
                    }
                    
                    // Print summary
                    let hasOverview = enhanced.overview != nil
                    let hasPoster = enhanced.posterPath != nil
                    let hasDirector = enhanced.director != nil
                    let hasCast = enhanced.cast != nil && !enhanced.cast!.isEmpty
                    let hasTrailer = enhanced.trailer != nil
                    
                    if enhanced.rtScore != nil && hasOverview && hasPoster && hasDirector && hasCast && hasTrailer {
                        print("    ✅ Complete: Year=\(enhanced.year ?? 0), RT=\(enhanced.rtScore!)%, Rating=\(enhanced.mpaaRating ?? "N/A"), Genres=\(enhanced.genres?.joined(separator: ", ") ?? "N/A"), Has Art=\(hasPoster), Has Credits=\(hasDirector && hasCast), Has Trailer=\(hasTrailer)")
                    } else {
                        print("    ⚠️  Partial: Year=\(enhanced.year ?? 0), RT=\(enhanced.rtScore?.description ?? "N/A"), Rating=\(enhanced.mpaaRating ?? "N/A"), Genres=\(enhanced.genres?.joined(separator: ", ") ?? "N/A"), Has Art=\(hasPoster), Has Credits=\(hasDirector && hasCast), Has Trailer=\(hasTrailer)")
                    }
                } else {
                    print("    ⚠️  Could not get detailed info")
                }
            } catch {
                print("    ⚠️  Error getting details: \(error.localizedDescription)")
            }
        } else {
            print("    ❌ Not found in TMDB")
        }
    } catch {
        print("    ❌ Error searching TMDB: \(error.localizedDescription)")
        // Print more details if possible
        if let urlError = error as? URLError {
            print("       URL Error: \(urlError.localizedDescription)")
        }
    }
    
    // Add delay to avoid rate limiting
    try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
    
    return enhanced
}

// Main execution
Task {
    do {
        print("📂 Loading bootstrap_movies.json...")
        
        let bootstrapPath = "WatchedIt/bootstrap_movies.json"
        guard let bootstrapURL = URL(fileURLWithPath: bootstrapPath) as URL? else {
            print("❌ Could not find bootstrap_movies.json")
            exit(1)
        }
        
        let data = try Data(contentsOf: bootstrapURL)
        var episodes = try JSONDecoder().decode([BootstrapEpisode].self, from: data)
        
        print("✅ Loaded \(episodes.count) episodes")
        print("🔄 Enhancing with movie metadata...")
        print("")
        
        let episodesWithMovies = episodes.filter { $0.movieTitle != nil }
        let total = episodesWithMovies.count
        var processed = 0
        var updated = 0
        var skipped = 0
        
        for (index, episode) in episodesWithMovies.enumerated() {
            processed += 1
            print("[\(processed)/\(total)] Processing: \(episode.movieTitle ?? "Unknown")")
            
            let before = episode
            let enhanced = await enhanceEpisode(episode)
            
            // Check if any new data was added or improved
            let hadDataBefore = before.year != nil || before.genres != nil || before.rtScore != nil || before.mpaaRating != nil || before.tmdbId != nil || before.overview != nil || before.posterPath != nil || before.director != nil || before.trailer != nil
            let hasDataAfter = enhanced.year != nil || enhanced.genres != nil || enhanced.rtScore != nil || enhanced.mpaaRating != nil || enhanced.tmdbId != nil || enhanced.overview != nil || enhanced.posterPath != nil || enhanced.director != nil || enhanced.trailer != nil
            
            if !hadDataBefore && hasDataAfter {
                updated += 1
            } else if hadDataBefore && !hasDataAfter {
                skipped += 1
            } else if hasDataAfter {
                // Check if data improved
                let improved = (before.year == nil && enhanced.year != nil) ||
                              (before.rtScore == nil && enhanced.rtScore != nil) ||
                              (before.mpaaRating == nil && enhanced.mpaaRating != nil) ||
                              ((before.genres?.isEmpty ?? true) && !(enhanced.genres?.isEmpty ?? true)) ||
                              (before.overview == nil && enhanced.overview != nil) ||
                              (before.posterPath == nil && enhanced.posterPath != nil) ||
                              (before.director == nil && enhanced.director != nil) ||
                              ((before.cast?.isEmpty ?? true) && !(enhanced.cast?.isEmpty ?? true)) ||
                              (before.trailer == nil && enhanced.trailer != nil)
                if improved {
                    updated += 1
                } else {
                    skipped += 1
                }
            }
            
            // Update in array (always update even if no change, to save progress)
            if let episodeIndex = episodes.firstIndex(where: { $0.guid == episode.guid }) {
                episodes[episodeIndex] = enhanced
            }
            
            print("")
            
            // Save progress every 50 movies
            if processed % 50 == 0 {
                print("💾 Saving progress... (\(processed)/\(total))")
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                if let jsonData = try? encoder.encode(episodes) {
                    try? jsonData.write(to: bootstrapURL)
                }
            }
        }
        
        print("📊 Summary:")
        print("   ✅ Enhanced: \(updated)")
        print("   ⏭️  Skipped (already complete): \(skipped)")
        print("   📝 Total processed: \(processed)")
        print("💾 Saving enhanced bootstrap file...")
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(episodes)
        
        // Write to file
        try jsonData.write(to: bootstrapURL)
        
        print("✅ Enhanced bootstrap file saved: \(bootstrapPath)")
        print("   Total episodes: \(episodes.count)")
        print("   Enhanced: \(updated)")
        
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
    exit(0)
}

RunLoop.main.run()

