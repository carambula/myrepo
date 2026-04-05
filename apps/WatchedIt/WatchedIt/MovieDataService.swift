//
//  MovieDataService.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation

public class MovieDataService {
    public static let shared = MovieDataService()
    
    // Note: You'll need to get a free API key from https://www.themoviedb.org/
    // For now, using a placeholder - replace with your actual API key
    private let apiKey = "4f6ab1dde752aedd41093bab21f383c7"
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p" // Format: https://image.tmdb.org/t/p/{size}{path}
    
    // Image sizes for different contexts
    public enum ImageSize: String {
        case thumbnail = "w185"      // For list thumbnails
        case small = "w342"          // For list items
        case medium = "w500"         // Default
        case large = "w780"          // For detail views
        case backdrop = "w1280"      // For backdrops
        case original = "original"   // Full resolution
    }
    
    private init() {}

    private func fetchDataIgnoringTaskCancellation(from url: URL) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            URLSession.shared.dataTask(with: url) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, let response else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data, response))
            }.resume()
        }
    }
    
    func searchMovies(title: String, year: Int? = nil) async throws -> [TMDBMovie] {
        var urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let year = year {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for search: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB Search: Searching for '\(title)'\(year != nil ? " (\(year!))" : "")")
        
        do {
            let startTime = Date()
            let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ TMDB: Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for '\(title)' (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
            
            // Check for API errors
            if httpResponse.statusCode == 401 {
                print("❌ TMDB: Unauthorized - API key may be invalid")
                throw URLError(.userAuthenticationRequired)
            }
            
            if httpResponse.statusCode == 429 {
                print("⚠️ TMDB: Rate limited")
                throw URLError(.userCancelledAuthentication) // Use as rate limit indicator
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB Error (\(httpResponse.statusCode)): \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            // Try to decode response
            do {
                let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
                print("✅ TMDB: Found \(response.results.count) result(s) for '\(title)'")
                return response.results
            } catch {
                // If decoding fails, try to see what we got
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB: Decode error. Response: \(responseString.prefix(500))")
                }
                throw error
            }
        } catch {
            print("❌ TMDB Search error for '\(title)': \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Searches for a movie and returns the best match based on year, title similarity, cast/crew validation, and popularity
    func searchMovieBestMatch(title: String, year: Int? = nil, preferredYear: Int? = nil, expectedPersonNames: [String]? = nil) async throws -> TMDBMovie? {
        // Get all search results
        let results = try await searchMovies(title: title, year: year)
        guard !results.isEmpty else { return nil }
        
        // If only one result, return it
        if results.count == 1 {
            return results.first
        }
        
        // If we have expected person names, fetch details for validation
        var movieCreditsMap: [Int: TMDBCredits] = [:]
        if let expectedNames = expectedPersonNames, !expectedNames.isEmpty {
            print("🎬 TMDB: Validating matches using expected person names: \(expectedNames.joined(separator: ", "))")
            // Fetch credits for top results (limit to first 5 to avoid too many API calls)
            for movie in results.prefix(5) {
                if let details = try? await getMovieDetails(tmdbId: movie.id),
                   let credits = details.credits {
                    movieCreditsMap[movie.id] = credits
                }
            }
        }
        
        // Score each result and pick the best
        let scoredResults = results.map { movie -> (movie: TMDBMovie, score: Double) in
            var score: Double = 0.0
            
            // Year matching (highest priority if year is specified)
            if let preferredYear = preferredYear ?? year, let movieYear = movie.year {
                if movieYear == preferredYear {
                    score += 100.0 // Exact year match
                } else {
                    let yearDiff = abs(movieYear - preferredYear)
                    if yearDiff == 1 {
                        score += 50.0 // Within 1 year
                    } else if yearDiff <= 5 {
                        score += 25.0 - Double(yearDiff) * 5.0 // Decreasing score for further years
                    } else {
                        score -= 50.0 // Penalty for very different years
                    }
                }
            }
            
            // Person name validation (if we have expected names and credits)
            if let expectedNames = expectedPersonNames, !expectedNames.isEmpty,
               let credits = movieCreditsMap[movie.id] {
                // Check if any expected names match cast or crew
                let allPersonNames = ([credits.director].compactMap { $0 } + credits.cast.map { $0.name })
                    .map { $0.lowercased() }
                
                for expectedName in expectedNames {
                    let normalizedExpected = expectedName.lowercased()
                    // Check for exact match or if the expected name contains the person's name
                    if allPersonNames.contains(where: { personName in
                        personName == normalizedExpected || 
                        normalizedExpected.contains(personName) ||
                        personName.contains(normalizedExpected)
                    }) {
                        score += 75.0 // Strong boost for person name match
                        print("   ✅ Person match found: '\(expectedName)' in '\(movie.title)' (\(movie.year?.description ?? "N/A"))")
                    }
                }
            }
            
            // Title similarity (case-insensitive)
            let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
            let normalizedMovieTitle = movie.title.lowercased().trimmingCharacters(in: .whitespaces)
            
            if normalizedTitle == normalizedMovieTitle {
                score += 50.0 // Exact title match
            } else if normalizedMovieTitle.contains(normalizedTitle) || normalizedTitle.contains(normalizedMovieTitle) {
                score += 30.0 // Partial match
            }
            
            // Prefer results with posters (more likely to be the main release)
            if movie.posterPath != nil {
                score += 10.0
            }
            
            return (movie: movie, score: score)
        }
        
        // Sort by score (highest first) and return best match
        let bestMatch = scoredResults.max(by: { $0.score < $1.score })
        
        if let best = bestMatch {
            print("🎯 TMDB: Selected best match '\(best.movie.title)' (ID: \(best.movie.id), Year: \(best.movie.year?.description ?? "N/A"), Score: \(String(format: "%.1f", best.score)))")
        }
        
        return bestMatch?.movie
    }
    
    func searchMovie(title: String, year: Int? = nil) async throws -> TMDBMovie? {
        var urlString = "\(baseURL)/search/movie?api_key=\(apiKey)&query=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let year = year {
            urlString += "&year=\(year)"
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for search: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB Search: Searching for '\(title)'\(year != nil ? " (\(year!))" : "")")
        
        do {
            let startTime = Date()
            let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ TMDB: Invalid response type")
                throw URLError(.badServerResponse)
            }
            
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for '\(title)' (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
            
            // Check for API errors
            if httpResponse.statusCode == 401 {
                print("❌ TMDB: Unauthorized - API key may be invalid")
                throw URLError(.userAuthenticationRequired)
            }
            
            if httpResponse.statusCode == 429 {
                print("⚠️ TMDB: Rate limited")
                throw URLError(.userCancelledAuthentication) // Use as rate limit indicator
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB Error (\(httpResponse.statusCode)): \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            // Try to decode response
            do {
                let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
                print("✅ TMDB: Found \(response.results.count) result(s) for '\(title)'")
                
                // If year was specified, prefer exact year match
                if let year = year, !response.results.isEmpty {
                    // First try exact year match
                    if let exactMatch = response.results.first(where: { $0.year == year }) {
                        print("   📽️ Selected exact year match: '\(exactMatch.title)' (ID: \(exactMatch.id), Year: \(exactMatch.year?.description ?? "N/A"))")
                        return exactMatch
                    }
                    // Then try year within 1 year (handles re-releases, different regions)
                    if let closeMatch = response.results.first(where: { 
                        if let resultYear = $0.year {
                            return abs(resultYear - year) <= 1
                        }
                        return false
                    }) {
                        print("   📽️ Selected close year match: '\(closeMatch.title)' (ID: \(closeMatch.id), Year: \(closeMatch.year?.description ?? "N/A"))")
                        return closeMatch
                    }
                }
                
                // If no year specified or no year match, return first result (TMDB orders by relevance)
                if let first = response.results.first {
                    print("   📽️ Top result: '\(first.title)' (ID: \(first.id), Year: \(first.year?.description ?? "N/A"))")
                }
                return response.results.first
            } catch {
                // If decoding fails, try to see what we got
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB: Decode error. Response: \(responseString.prefix(500))")
                }
                throw error
            }
        } catch {
            print("❌ TMDB Search error for '\(title)': \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get basic movie details without additional data (faster, for simple fields like year, title, overview)
    func getMovieBasicInfo(tmdbId: Int) async throws -> TMDBMovieDetails? {
        let urlString = "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for movie basic info: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB: Fetching basic info for movie ID \(tmdbId)")
        
        do {
            let startTime = Date()
            let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ TMDB: Invalid response type for movie \(tmdbId)")
                throw URLError(.badServerResponse)
            }
            
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for movie basic info \(tmdbId) (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 404 {
                    print("⚠️ TMDB: Movie \(tmdbId) not found")
                    return nil
                }
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB Error (\(httpResponse.statusCode)) for movie \(tmdbId): \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            do {
                let movieDetails = try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
                print("✅ TMDB: Retrieved basic info for '\(movieDetails.title)' (ID: \(tmdbId))")
                print("   releaseDate: '\(movieDetails.releaseDate ?? "nil")'")
                print("   year (computed): \(movieDetails.year?.description ?? "nil")")
                // Debug: Log raw JSON if releaseDate is nil
                if movieDetails.releaseDate == nil {
                    if let jsonString = String(data: data, encoding: .utf8) {
                        // Try to find release_date in the raw JSON
                        if let range = jsonString.range(of: "\"release_date\"") {
                            let snippet = String(jsonString[range.lowerBound..<jsonString.index(range.upperBound, offsetBy: 20)])
                            print("   ⚠️ releaseDate is nil, but found 'release_date' in JSON: \(snippet)...")
                        } else {
                            print("   ⚠️ releaseDate is nil and 'release_date' not found in JSON response")
                        }
                    }
                }
                return movieDetails
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB: Decode error for movie \(tmdbId). Response: \(responseString.prefix(500))")
                }
                throw error
            }
        } catch {
            print("❌ TMDB Basic Info error for movie \(tmdbId): \(error.localizedDescription)")
            throw error
        }
    }
    
    func getMovieDetails(tmdbId: Int) async throws -> TMDBMovieDetails? {
        let urlString = "\(baseURL)/movie/\(tmdbId)?api_key=\(apiKey)&append_to_response=credits,release_dates"
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for movie details: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB: Fetching details for movie ID \(tmdbId)")
        
        do {
            let startTime = Date()
            let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ TMDB: Invalid response type for movie \(tmdbId)")
                throw URLError(.badServerResponse)
            }
            
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for movie \(tmdbId) (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
            
            // Check for API errors
            if httpResponse.statusCode == 401 {
                print("❌ TMDB: Unauthorized - API key may be invalid")
                throw URLError(.userAuthenticationRequired)
            }
            
            if httpResponse.statusCode == 404 {
                print("⚠️ TMDB: Movie \(tmdbId) not found")
                return nil
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB Error (\(httpResponse.statusCode)) for movie \(tmdbId): \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            do {
                let movieDetails = try JSONDecoder().decode(TMDBMovieDetails.self, from: data)
                print("✅ TMDB: Retrieved details for '\(movieDetails.title)' (ID: \(tmdbId))")
                print("🖼️ TMDB: Raw posterPath='\(movieDetails.posterPath ?? "nil")', backdropPath='\(movieDetails.backdropPath ?? "nil")'")
                return movieDetails
            } catch {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB: Decode error for movie \(tmdbId). Response: \(responseString.prefix(500))")
                }
                throw error
            }
        } catch {
            print("❌ TMDB Details error for movie \(tmdbId): \(error.localizedDescription)")
            throw error
        }
    }
    
    func getMPAARating(tmdbId: Int) async throws -> String? {
        let urlString = "\(baseURL)/movie/\(tmdbId)/release_dates?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for release dates: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB: Fetching MPAA rating for movie ID \(tmdbId)")
        
        do {
            let startTime = Date()
            let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for release dates (movie \(tmdbId)) (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("⚠️ TMDB: Release dates API returned status \(httpResponse.statusCode) for movie \(tmdbId)")
                return nil
            }
            
            let releaseDatesResponse = try JSONDecoder().decode(TMDBReleaseDatesResponse.self, from: data)
            
            print("🔍 TMDB: Decoded release dates response - \(releaseDatesResponse.results.count) countries")
            for country in releaseDatesResponse.results {
                print("   Country: \(country.iso31661), \(country.releaseDates.count) release dates")
                for (idx, rd) in country.releaseDates.enumerated() {
                    print("     [\(idx)] Type: \(rd.type), Certification: '\(rd.certification)'")
                }
            }
            
            // Find US certification - prioritize type 3 (theatrical), then type 2 (premiere), then any
            for country in releaseDatesResponse.results {
                if country.iso31661 == "US" {
                    print("🔍 TMDB: Found US release dates - checking for MPAA rating...")
                    
                    // First, try to find type 3 (theatrical) with non-empty certification
                    if let releaseDate = country.releaseDates.first(where: { $0.type == 3 && !$0.certification.isEmpty }) {
                        print("✅ TMDB: Found MPAA rating '\(releaseDate.certification)' from type 3 (theatrical) for movie \(tmdbId)")
                        return releaseDate.certification
                    }
                    
                    // If no type 3 with certification, try type 2 (premiere) with non-empty certification
                    if let releaseDate = country.releaseDates.first(where: { $0.type == 2 && !$0.certification.isEmpty }) {
                        print("✅ TMDB: Found MPAA rating '\(releaseDate.certification)' from type 2 (premiere) for movie \(tmdbId)")
                        return releaseDate.certification
                    }
                    
                    // Fallback: find any release date with non-empty certification
                    if let releaseDate = country.releaseDates.first(where: { !$0.certification.isEmpty }) {
                        print("✅ TMDB: Found MPAA rating '\(releaseDate.certification)' from type \(releaseDate.type) for movie \(tmdbId)")
                        return releaseDate.certification
                    }
                    
                    print("   ⚠️ No release date with non-empty certification found")
                }
            }
            
            print("⚠️ TMDB: No MPAA rating found for movie \(tmdbId) in any country")
            return nil
        } catch {
            print("❌ TMDB MPAA rating error for movie \(tmdbId): \(error.localizedDescription)")
            throw error
        }
    }
    
    func getStreamingProviders(tmdbId: Int) async throws -> [StreamingService] {
        let urlString = "\(baseURL)/movie/\(tmdbId)/watch/providers?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for watch providers: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB: Fetching streaming providers for movie ID \(tmdbId)")
        
        let startTime = Date()
        let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
        let duration = Date().timeIntervalSince(startTime)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for streaming providers (movie \(tmdbId)) (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
        }
        
        // Decode with error handling for malformed country data
        // The custom decoder will skip countries with invalid structures
        let providersResponse: TMDBWatchProvidersResponse
        do {
            providersResponse = try JSONDecoder().decode(TMDBWatchProvidersResponse.self, from: data)
        } catch {
            print("⚠️ TMDB: Error decoding watch providers for movie \(tmdbId): \(error.localizedDescription)")
            // Return empty array if decoding fails completely
            return []
        }
        
        guard let usProviders = providersResponse.results["US"] else {
            print("⚠️ TMDB: No US providers found for movie \(tmdbId)")
            return []
        }
        
        var seenProviderIds = Set<String>()
        var services: [StreamingService] = []
        
        func appendProviders(_ list: [TMDBProvider]?) {
            guard let list else { return }
            for provider in list {
                let pid = String(provider.providerId)
                guard seenProviderIds.insert(pid).inserted else { continue }
                services.append(StreamingService(
                    id: pid,
                    name: provider.providerName,
                    logoPath: provider.logoPath != nil ? getPosterURL(path: provider.logoPath, size: .small) : nil,
                    url: nil
                ))
            }
        }
        
        // Order: subscription, then rent/buy/digital purchase, then free/ad-supported.
        appendProviders(usProviders.flatrate)
        appendProviders(usProviders.rent)
        appendProviders(usProviders.buy)
        appendProviders(usProviders.free)
        appendProviders(usProviders.ads)
        
        print("✅ TMDB: Found \(services.count) streaming service(s) for movie \(tmdbId)")
        return services
    }
    
    public func getPosterURL(path: String?, size: ImageSize = .medium) -> String? {
        guard let path = path, !path.isEmpty else {
            return nil
        }
        
        // If already a full URL, return as-is
        if path.hasPrefix("http") {
            return path
        }
        
        // TMDB paths already include leading slash, but ensure it's there
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        // Format: https://image.tmdb.org/t/p/{size}{path}
        // Result: https://image.tmdb.org/t/p/w185/abc123.jpg
        let url = "\(imageBaseURL)/\(size.rawValue)\(cleanPath)"
        return url
    }
    
    public func getBackdropURL(path: String?, size: ImageSize = .backdrop) -> String? {
        guard let path = path, !path.isEmpty else {
            return nil
        }
        
        // If already a full URL, return as-is
        if path.hasPrefix("http") {
            return path
        }
        
        // TMDB paths already include leading slash, but ensure it's there
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        // Format: https://image.tmdb.org/t/p/{size}{path}
        let url = "\(imageBaseURL)/\(size.rawValue)\(cleanPath)"
        return url
    }
    
    public func getThumbnailURL(path: String?) -> String? {
        return getPosterURL(path: path, size: .thumbnail)
    }
    
    public func getLargePosterURL(path: String?) -> String? {
        return getPosterURL(path: path, size: .large)
    }
    
    func getMovieVideos(tmdbId: Int) async throws -> [TMDBVideo] {
        let urlString = "\(baseURL)/movie/\(tmdbId)/videos?api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for videos: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB: Fetching videos for movie ID \(tmdbId)")
        
        let startTime = Date()
        let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
        let duration = Date().timeIntervalSince(startTime)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 TMDB Response: Status \(httpResponse.statusCode) for videos (movie \(tmdbId)) (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
        }
        
        let responseData = try JSONDecoder().decode(TMDBVideosResponse.self, from: data)
        
        // Filter for trailers and teasers, prefer official trailers
        let trailers = responseData.results.filter { video in
            (video.type == "Trailer" || video.type == "Teaser") && video.site == "YouTube"
        }
        
        print("✅ TMDB: Found \(trailers.count) trailer(s) out of \(responseData.results.count) total video(s) for movie \(tmdbId)")
        
        // Sort: official trailers first, then by size (prefer larger)
        return trailers.sorted { first, second in
            if first.official != second.official {
                return first.official && !second.official
            }
            return first.size > second.size
        }
    }
    
    /// Fetches all available images for a movie from TMDB
    /// Reference: https://developer.themoviedb.org/reference/movie-images
    func getMovieImages(tmdbId: Int, language: String? = nil, includeImageLanguage: String? = nil) async throws -> TMDBImagesResponse? {
        var urlString = "\(baseURL)/movie/\(tmdbId)/images?api_key=\(apiKey)"
        
        if let language = language {
            urlString += "&language=\(language)"
        }
        
        if let includeImageLanguage = includeImageLanguage {
            urlString += "&include_image_language=\(includeImageLanguage)"
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ TMDB: Invalid URL for images: \(urlString)")
            throw URLError(.badURL)
        }
        
        // Log API call with masked API key for security
        let maskedURL = urlString.replacingOccurrences(of: apiKey, with: "***")
        print("🌐 TMDB API CALL: GET \(maskedURL)")
        print("🔍 TMDB: Fetching images for movie ID \(tmdbId)")
        
        do {
            let startTime = Date()
            let (data, response) = try await fetchDataIgnoringTaskCancellation(from: url)
            let duration = Date().timeIntervalSince(startTime)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            print("📡 TMDB Images Response: Status \(httpResponse.statusCode) for movie \(tmdbId) (Size: \(data.count) bytes, Duration: \(String(format: "%.2f", duration))s)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ TMDB Images Error (\(httpResponse.statusCode)): \(errorString)")
                }
                throw URLError(.badServerResponse)
            }
            
            let imagesResponse = try JSONDecoder().decode(TMDBImagesResponse.self, from: data)
            print("✅ TMDB: Retrieved images for movie \(tmdbId) - \(imagesResponse.posters.count) posters, \(imagesResponse.backdrops.count) backdrops")
            return imagesResponse
        } catch {
            print("❌ TMDB Images error for movie \(tmdbId): \(error.localizedDescription)")
            throw error
        }
    }
}

struct TMDBSearchResponse: Codable {
    let results: [TMDBMovie]
}

struct TMDBMovie: Codable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    
    // TMDB API uses snake_case, Swift uses camelCase
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case overview
    }
    
    var year: Int? {
        guard let releaseDate = releaseDate,
              !releaseDate.isEmpty,
              let yearString = releaseDate.components(separatedBy: "-").first,
              !yearString.isEmpty,
              yearString.count == 4 else {
            return nil
        }
        return Int(yearString)
    }
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
    
    // TMDB API uses snake_case, Swift uses camelCase
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
    
    var year: Int? {
        guard let releaseDate = releaseDate,
              !releaseDate.isEmpty,
              let yearString = releaseDate.components(separatedBy: "-").first,
              !yearString.isEmpty,
              yearString.count == 4 else {
            return nil
        }
        return Int(yearString)
    }
    
    var genreNames: [String] {
        genres?.map { $0.name } ?? []
    }
    
    var mpaaRating: String? {
        // Find US certification from release dates - prioritize type 3 (theatrical), then type 2 (premiere), then any
        guard let releaseDates = releaseDates?.results else { return nil }
        for country in releaseDates {
            if country.iso31661 == "US" {
                // First, try to find type 3 (theatrical) with non-empty certification
                if let releaseDate = country.releaseDates.first(where: { $0.type == 3 && !$0.certification.isEmpty }) {
                    return releaseDate.certification
                }
                
                // If no type 3 with certification, try type 2 (premiere) with non-empty certification
                if let releaseDate = country.releaseDates.first(where: { $0.type == 2 && !$0.certification.isEmpty }) {
                    return releaseDate.certification
                }
                
                // Fallback: find any release date with non-empty certification
                if let releaseDate = country.releaseDates.first(where: { !$0.certification.isEmpty }) {
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

struct TMDBCredits: Codable {
    let cast: [TMDBCastMember]
    let crew: [TMDBCrewMember]
    
    var director: String? {
        crew.first { $0.job == "Director" }?.name
    }
}

struct TMDBCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    
    // TMDB API uses snake_case
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

// Helper to handle dynamic keys for country codes
private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

struct TMDBWatchProvidersResponse: Codable {
    let results: [String: TMDBWatchProviders]
    
    enum CodingKeys: String, CodingKey {
        case results
    }
    
    // Custom decoding to only decode valid countries and skip malformed ones
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let resultsContainer = try container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: .results)
        var decodedResults: [String: TMDBWatchProviders] = [:]
        
        for key in resultsContainer.allKeys {
            do {
                let providers = try resultsContainer.decode(TMDBWatchProviders.self, forKey: key)
                decodedResults[key.stringValue] = providers
            } catch {
                print("⚠️ TMDB: Skipping country '\(key.stringValue)' - invalid provider structure: \(error.localizedDescription)")
            }
        }
        
        results = decodedResults
    }
}

struct TMDBWatchProviders: Codable {
    let flatrate: [TMDBProvider]?
    let buy: [TMDBProvider]?
    let rent: [TMDBProvider]?
    /// Ad-supported / free-with-ads tiers (when present for a region)
    let free: [TMDBProvider]?
    let ads: [TMDBProvider]?
}

struct TMDBProvider: Codable {
    let providerId: Int
    let providerName: String
    let logoPath: String?
    
    // TMDB API uses snake_case
    enum CodingKeys: String, CodingKey {
        case providerId = "provider_id"
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
    
    // Custom decoding to handle missing or differently named fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // provider_id is required - if missing, throw error so the provider can be filtered out
        providerId = try container.decode(Int.self, forKey: .providerId)
        providerName = try container.decode(String.self, forKey: .providerName)
        logoPath = try container.decodeIfPresent(String.self, forKey: .logoPath)
    }
}

struct TMDBReleaseDatesResponse: Codable {
    let id: Int
    let results: [TMDBReleaseDateCountry]
}

struct TMDBReleaseDatesInfo: Codable {
    let results: [TMDBReleaseDateCountry]
    
    // Handle nested structure when appended to movie details
    enum CodingKeys: String, CodingKey {
        case results
    }
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
    let type: Int // 1 = Premiere, 2 = Limited, 3 = Theatrical, 4 = Digital, 5 = Physical, 6 = TV
}

struct TMDBVideosResponse: Codable {
    let results: [TMDBVideo]
}

struct TMDBVideo: Codable {
    let id: String
    let key: String // YouTube video key
    let name: String
    let site: String // "YouTube", "Vimeo", etc.
    let type: String // "Trailer", "Teaser", "Clip", etc.
    let official: Bool
    let size: Int // Video quality indicator
}

// MARK: - TMDB Images Response
// Reference: https://developer.themoviedb.org/reference/movie-images

struct TMDBImagesResponse: Codable {
    let id: Int
    let backdrops: [TMDBImage]
    let logos: [TMDBImage]
    let posters: [TMDBImage]
}

struct TMDBImage: Codable {
    let aspectRatio: Double
    let height: Int
    let iso6391: String?
    let filePath: String
    let voteAverage: Double
    let voteCount: Int
    let width: Int
    
    enum CodingKeys: String, CodingKey {
        case aspectRatio = "aspect_ratio"
        case height
        case iso6391 = "iso_639_1"
        case filePath = "file_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case width
    }
}

