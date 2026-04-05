#!/usr/bin/env swift

import Foundation

/// Script to enrich bootstrap_data.json with complete TMDB metadata
/// Uses the same MovieDataService that the app uses to fetch all movie details

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
    
    // Enriched fields (added by this script)
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
    let version: String
    let generatedDate: String
    let dataSources: [BootstrapDataSource]
    var movies: [BootstrapMovie]
}

func needsEnrichment(_ movie: BootstrapMovie) -> Bool {
    let missingTmdb = movie.tmdbId == nil
    let missingYear = movie.year == nil
    let missingPoster = movie.posterPath == nil || movie.posterPath?.isEmpty == true
    let missingBackdrop = movie.backdropPath == nil || movie.backdropPath?.isEmpty == true
    let missingOverview = movie.overview == nil || movie.overview?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    let missingMpaa = movie.mpaaRating == nil || movie.mpaaRating?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
    let missingGenres = movie.genres?.isEmpty ?? true
    let missingStreaming = movie.streamingServices?.isEmpty ?? true
    let missingCredits = movie.credits == nil || movie.credits?.cast?.isEmpty == true
    let missingTrailer = movie.trailer == nil
    
    return missingTmdb
        || missingYear
        || missingPoster
        || missingBackdrop
        || missingOverview
        || missingMpaa
        || missingGenres
        || missingStreaming
        || missingCredits
        || missingTrailer
}

// MARK: - TMDB API Structures

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let genreIds: [Int]?
}

struct TMDBSearchResponse: Codable {
    let results: [TMDBMovie]
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let genres: [TMDBGenre]?
    let credits: TMDBCredits?
    let releaseDates: TMDBReleaseDatesInfo?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
        case genres
        case credits
        case releaseDates = "release_dates"
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBCredits: Codable {
    let cast: [TMDBCastMember]?
    let crew: [TMDBCrewMember]?
    
    var director: String? {
        crew?.first(where: { $0.job == "Director" })?.name
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
    let job: String?
    let profilePath: String?
}

struct TMDBReleaseDatesInfo: Codable {
    let results: [TMDBReleaseDateCountry]?
}

struct TMDBReleaseDateCountry: Codable {
    let iso31661: String
    let releaseDates: [TMDBReleaseDate]?
    
    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case releaseDates = "release_dates"
    }
}

struct TMDBReleaseDate: Codable {
    let certification: String
    let type: Int
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Certification can be empty string, so decode as String and handle empty
        certification = try container.decode(String.self, forKey: .certification)
        type = try container.decode(Int.self, forKey: .type)
    }
    
    enum CodingKeys: String, CodingKey {
        case certification
        case type
    }
}

struct TMDBStreamingProviders: Codable {
    let results: TMDBStreamingResults?
}

struct TMDBStreamingResults: Codable {
    let US: TMDBStreamingCountry?
}

struct TMDBStreamingCountry: Codable {
    let flatrate: [TMDBProvider]?
    let buy: [TMDBProvider]?
    let rent: [TMDBProvider]?
}

struct TMDBProvider: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    let displayPriority: Int
    
    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
        case displayPriority = "display_priority"
    }
}

struct TMDBVideoResponse: Codable {
    let results: [TMDBVideo]?
}

struct TMDBVideo: Codable {
    let id: String
    let name: String
    let key: String
    let official: Bool
    let type: String
}

// MARK: - TMDB Service

class TMDBService {
    private let apiKey = "4f6ab1dde752aedd41093bab21f383c7"
    private let baseURL = "https://api.themoviedb.org/3"
    
    func searchMovie(title: String, year: Int? = nil) async throws -> TMDBMovie? {
        var urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let year = year {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        
        let searchResponse = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return searchResponse.results.first
    }
    
    func getMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
        let urlString = "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)&append_to_response=credits,release_dates"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        
        return try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
    }
    
    func getStreamingProviders(tmdbId: Int) async throws -> [BootstrapStreamingService] {
        let urlString = "\(baseURL)/movie/\(tmdbId)/watch/providers?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let providersResponse = try JSONDecoder().decode(TMDBStreamingProviders.self, from: data)
        
        var allProviders: [BootstrapStreamingService] = []
        
        if let us = providersResponse.results?.US {
            let flatrate = us.flatrate ?? []
            let buy = us.buy ?? []
            let rent = us.rent ?? []
            
            for provider in flatrate + buy + rent {
                allProviders.append(BootstrapStreamingService(
                    providerId: provider.providerId,
                    providerName: provider.providerName,
                    logoPath: provider.logoPath,
                    displayPriority: provider.displayPriority
                ))
            }
        }
        
        // Deduplicate by providerId
        var seen = Set<Int>()
        return allProviders.filter { provider in
            if seen.contains(provider.providerId) {
                return false
            }
            seen.insert(provider.providerId)
            return true
        }
    }
    
    func getMPAARating(tmdbId: Int) async throws -> String? {
        let details = try await getMovieDetails(tmdbId: tmdbId)
        
        // Extract MPAA rating from release dates
        if let results = details?.releaseDates?.results {
            // Find US release dates
            if let usCountry = results.first(where: { $0.iso31661 == "US" }),
               let releaseDates = usCountry.releaseDates {
                // First try type 3 (theatrical)
                if let releaseDate = releaseDates.first(where: { $0.type == 3 && !$0.certification.isEmpty }) {
                    return releaseDate.certification
                }
                // Then try type 2 (premiere)
                if let releaseDate = releaseDates.first(where: { $0.type == 2 && !$0.certification.isEmpty }) {
                    return releaseDate.certification
                }
                // Fallback: any with certification
                if let releaseDate = releaseDates.first(where: { !$0.certification.isEmpty }) {
                    return releaseDate.certification
                }
            }
        }
        
        return nil
    }
    
    func getMovieVideos(tmdbId: Int) async throws -> [BootstrapTrailer] {
        let urlString = "\(baseURL)/movie/\(tmdbId)/videos?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let videoResponse = try JSONDecoder().decode(TMDBVideoResponse.self, from: data)
        
        return (videoResponse.results ?? [])
            .filter { $0.type == "Trailer" }
            .map { video in
                BootstrapTrailer(
                    id: video.id,
                    name: video.name,
                    youtubeKey: video.key,
                    isOfficial: video.official
                )
            }
    }
}

// MARK: - Main Script

func enrichBootstrapData() async {
    let rootPath = FileManager.default.currentDirectoryPath
    let baseFile = "\(rootPath)/WatchedIt/bootstrap_data.json"
    let enrichedFile = "\(rootPath)/bootstrap_data_enriched.json"
    let inputFile = FileManager.default.fileExists(atPath: enrichedFile) ? enrichedFile : baseFile
    let outputFile = enrichedFile
    
    print("📂 Loading bootstrap data from \(inputFile)...")
    
    guard let url = URL(fileURLWithPath: inputFile) as URL?,
          let data = try? Data(contentsOf: url),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Could not load bootstrap_data.json")
        return
    }
    
    print("✅ Loaded \(bootstrapData.movies.count) movies")
    print("🔄 Starting enrichment process...")
    print("⚠️  This will make many TMDB API calls. Please be patient.\n")
    
    let tmdbService = TMDBService()
    var enriched = 0
    var failed = 0
    var skipped = 0
    
    // Only process movies that are missing any enriched fields
    let moviesToEnrich = bootstrapData.movies.enumerated().filter { (_, movie) in
        needsEnrichment(movie)
    }
    
    print("🎯 Found \(moviesToEnrich.count) movies to enrich\n")
    
    for (index, movie) in moviesToEnrich {
        
        let progress = Double(index + 1) / Double(bootstrapData.movies.count) * 100
        
        // Clean the title using the same logic as TitleCleaner
        var cleanedTitle = movie.title
        
        // Remove "Live From [Location]" patterns
        let liveFromPattern = #"(?i)\s*(?:LIVE|Live)\s+From\s+[A-Za-z\s]+"#
        if let regex = try? NSRegularExpression(pattern: liveFromPattern) {
            let nsRange = NSRange(cleanedTitle.startIndex..., in: cleanedTitle)
            if let match = regex.firstMatch(in: cleanedTitle, range: nsRange),
               let range = Range(match.range, in: cleanedTitle) {
                cleanedTitle = String(cleanedTitle[..<range.lowerBound]) + String(cleanedTitle[range.upperBound...])
            }
        }
        
        // Remove part markers
        let partPatterns = [
            #"(?i)\s*\(Part\s+\d+\)"#,
            #"(?i)\s*\(Part\s+[IVX]+\)"#,
            #"(?i)\s*Part\s+\d+"#,
            #"(?i)\s*Part\s+[IVX]+"#,
        ]
        for pattern in partPatterns {
            cleanedTitle = cleanedTitle.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove "With [guests]" pattern
        if let withRange = cleanedTitle.range(of: " With ", options: .caseInsensitive) {
            cleanedTitle = String(cleanedTitle[..<withRange.lowerBound])
        }
        
        // Remove leading/trailing quotes (keep removing until none left)
        let quotes = ["'", "'", "'", "'", "\"", "\"", "\"", "\"", "`", "´"]
        var changed = true
        while changed {
            changed = false
            for quote in quotes {
                if cleanedTitle.hasPrefix(quote) {
                    cleanedTitle = String(cleanedTitle.dropFirst())
                    changed = true
                }
                if cleanedTitle.hasSuffix(quote) {
                    cleanedTitle = String(cleanedTitle.dropLast())
                    changed = true
                }
            }
        }
        
        // Extract year from original title if available (before removing it)
        let yearPattern = #"\((\d{4})\)"#
        var searchYear: Int? = nil
        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: movie.title, range: NSRange(movie.title.startIndex..., in: movie.title)),
           let yearRange = Range(match.range(at: 1), in: movie.title),
           let year = Int(String(movie.title[yearRange])) {
            searchYear = year
        }
        
        // Remove year from cleaned title
        if let regex = try? NSRegularExpression(pattern: yearPattern) {
            cleanedTitle = regex.stringByReplacingMatches(in: cleanedTitle, options: [], range: NSRange(cleanedTitle.startIndex..., in: cleanedTitle), withTemplate: "")
        }
        
        cleanedTitle = cleanedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip if title is too short or empty after cleaning
        if cleanedTitle.isEmpty || cleanedTitle.count < 2 {
            print("[\(String(format: "%.1f", progress))%] Skipping: '\(movie.title)' (empty after cleaning)")
            skipped += 1
            continue
        }
        
        print("[\(String(format: "%.1f", progress))%] Processing: '\(cleanedTitle)'\(searchYear != nil ? " (\(searchYear!))" : "")")
        
        do {
            // Search for movie
            let tmdbMovie: TMDBMovie
            do {
                guard let found = try await tmdbService.searchMovie(title: cleanedTitle, year: searchYear) else {
                    print("   ⚠️  Not found in TMDB")
                    failed += 1
                    continue
                }
                tmdbMovie = found
            } catch {
                print("   ❌ Search error: \(error.localizedDescription)")
                failed += 1
                continue
            }
            
            // Fetch full details
            let details: TMDBMovieDetails
            do {
                guard let fetched = try await tmdbService.getMovieDetails(tmdbId: tmdbMovie.id) else {
                    print("   ⚠️  Could not fetch details")
                    failed += 1
                    continue
                }
                details = fetched
            } catch {
                print("   ❌ Details error: \(error.localizedDescription)")
                failed += 1
                continue
            }
            
            // Extract year from release date
            let year: Int? = {
                if let releaseDate = details.releaseDate {
                    let components = releaseDate.components(separatedBy: "-")
                    if let yearStr = components.first, let year = Int(yearStr) {
                        return year
                    }
                }
                return nil
            }()
            
            // Fetch additional data in parallel
            var services: [BootstrapStreamingService] = []
            var rating: String? = nil
            var trailers: [BootstrapTrailer] = []
            
            do {
                async let streamingServicesTask = tmdbService.getStreamingProviders(tmdbId: tmdbMovie.id)
                async let mpaaRatingTask = tmdbService.getMPAARating(tmdbId: tmdbMovie.id)
                async let videosTask = tmdbService.getMovieVideos(tmdbId: tmdbMovie.id)
                
                services = try await streamingServicesTask
                rating = try await mpaaRatingTask
                trailers = try await videosTask
            } catch {
                print("   ⚠️  Error fetching additional data: \(error.localizedDescription)")
                // Continue with empty data (already initialized above)
            }
            
            // Build credits
            let credits: BootstrapCredits? = {
                guard let tmdbCredits = details.credits else { return nil }
                return BootstrapCredits(
                    director: tmdbCredits.director,
                    cast: tmdbCredits.cast?.prefix(10).map { member in
                        BootstrapCastMember(
                            id: member.id,
                            name: member.name,
                            character: member.character,
                            profilePath: member.profilePath
                        )
                    }
                )
            }()
            
            // Update movie
            bootstrapData.movies[index].tmdbId = tmdbMovie.id
            bootstrapData.movies[index].year = year
            bootstrapData.movies[index].posterPath = details.posterPath
            bootstrapData.movies[index].backdropPath = details.backdropPath
            bootstrapData.movies[index].overview = details.overview
            bootstrapData.movies[index].mpaaRating = rating
            bootstrapData.movies[index].genres = details.genres?.map { $0.name }
            if !services.isEmpty {
                bootstrapData.movies[index].streamingServices = services
            } else if (bootstrapData.movies[index].streamingServices?.isEmpty ?? true) {
                bootstrapData.movies[index].streamingServices = nil
            }
            bootstrapData.movies[index].credits = credits
            bootstrapData.movies[index].trailer = trailers.first
            
            enriched += 1
            print("   ✅ Enriched (TMDB ID: \(tmdbMovie.id))")
            
            // Rate limiting - be nice to TMDB API
            try await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds between requests
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            failed += 1
        }
        
        // Save progress every 50 movies
        if (index + 1) % 50 == 0 {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(bootstrapData)
                try jsonData.write(to: URL(fileURLWithPath: outputFile))
                print("💾 Progress saved to \(outputFile)")
            } catch {
                print("⚠️  Could not save progress: \(error)")
            }
        }
    }
    
    // Final save
    print("\n💾 Saving enriched data...")
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: URL(fileURLWithPath: outputFile))
        
        print("\n✅ Enrichment complete!")
        print("   Total movies: \(bootstrapData.movies.count)")
        print("   Enriched: \(enriched)")
        print("   Skipped (already had data): \(skipped)")
        print("   Failed: \(failed)")
        print("   Output: \(outputFile)")
    } catch {
        print("❌ Error saving enriched data: \(error)")
    }
}

// Run
Task {
    await enrichBootstrapData()
    exit(0)
}

RunLoop.main.run()

