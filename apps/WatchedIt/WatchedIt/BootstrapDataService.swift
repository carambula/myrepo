import Foundation
import SwiftData

// MARK: - Data Structures

extension BootstrapDataService {
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
        let episodeDate: String?
        
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
        var podcastEpisodeDescription: String?
        var physicalMedia: PhysicalMedia?
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
}

// MARK: - BootstrapDataService

class BootstrapDataService {
    static let shared = BootstrapDataService()
    
    // MARK: - Bootstrap Source Identifiers
    // These are the known bootstrap source identifiers - query database directly instead of loading JSON
    static let bootstrapSourceIdentifiers: Set<String> = [
        "rewatchables",
        "big-picture",
        "blank-check",
        "confused-breakfast",
        "rt-best-all-time",
        "rt-christmas",
        "rt-kids",
        "rt-oscars",
        "imdb-list-1",
        "imdb-list-2",
        "criterion",
        "afi-100-1998"
    ]
    
    private let lastBootstrapImportDateKey = "lastBootstrapImportDate"
    private let appliedBootstrapSignatureKey = "appliedBootstrapSignature"
    private let bootstrapBannerDismissedSignatureKey = "bootstrapUpgradeBannerDismissedSignature"
    
    private init() {}
    
    private static let podcastDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private func parseEpisodeDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return Self.podcastDateFormatter.date(from: value)
    }

    private func mapStreamingServices(_ services: [BootstrapStreamingService]?) -> [StreamingService] {
        guard let services else { return [] }
        return services.map { service in
            StreamingService(
                id: String(service.providerId),
                name: service.providerName,
                logoPath: service.logoPath,
                url: nil
            )
        }
    }

    private func mapCredits(_ credits: BootstrapCredits?) -> MovieCredits? {
        guard let credits else { return nil }
        let castMembers = credits.cast?.map { member in
            CastMember(
                id: member.id,
                name: member.name,
                character: member.character,
                profilePath: member.profilePath
            )
        } ?? []
        if credits.director == nil && castMembers.isEmpty {
            return nil
        }
        return MovieCredits(director: credits.director, cast: castMembers)
    }

    private func mapTrailer(_ trailer: BootstrapTrailer?) -> MovieTrailer? {
        guard let trailer else { return nil }
        return MovieTrailer(
            id: trailer.id,
            name: trailer.name,
            youtubeKey: trailer.youtubeKey,
            isOfficial: trailer.isOfficial
        )
    }
    
    // MARK: - Bootstrap Version Helpers
    
    /// Stable signature for the bundled bootstrap database.
    /// Uses file modification date + size to avoid relying on store mtime alone.
    func bootstrapDatabaseSignature() -> String? {
        guard let bootstrapDBURL = Bundle.main.url(forResource: "bootstrap_database", withExtension: "store") else {
            return nil
        }
        let attributes = try? FileManager.default.attributesOfItem(atPath: bootstrapDBURL.path)
        let modDate = (attributes?[.modificationDate] as? Date) ?? Date.distantPast
        let size = (attributes?[.size] as? Int64) ?? 0
        return "\(Int64(modDate.timeIntervalSince1970))-\(size)"
    }
    
    func bootstrapDatabaseModificationDate() -> Date? {
        guard let bootstrapDBURL = Bundle.main.url(forResource: "bootstrap_database", withExtension: "store") else {
            return nil
        }
        let bootstrapAttributes = try? FileManager.default.attributesOfItem(atPath: bootstrapDBURL.path)
        return bootstrapAttributes?[.modificationDate] as? Date
    }
    
    func isBootstrapDatabaseNewerThanLastImport() -> Bool {
        let signature = bootstrapDatabaseSignature()
        let appliedSignature = appliedBootstrapSignature()
        if signature != nil || appliedSignature != nil {
            return signature != appliedSignature
        }
        let bootstrapModDate = bootstrapDatabaseModificationDate() ?? Date.distantPast
        let lastImportedDate = UserDefaults.standard.object(forKey: lastBootstrapImportDateKey) as? Date ?? Date.distantPast
        return bootstrapModDate > lastImportedDate
    }
    
    @discardableResult
    func recordBootstrapImportDate() -> Date {
        let bootstrapModDate = bootstrapDatabaseModificationDate() ?? Date()
        UserDefaults.standard.set(bootstrapModDate, forKey: lastBootstrapImportDateKey)
        _ = recordBootstrapAppliedSignature()
        return bootstrapModDate
    }
    
    @discardableResult
    func recordBootstrapAppliedSignature() -> String? {
        guard let signature = bootstrapDatabaseSignature() else {
            return nil
        }
        UserDefaults.standard.set(signature, forKey: appliedBootstrapSignatureKey)
        return signature
    }
    
    func appliedBootstrapSignature() -> String? {
        UserDefaults.standard.string(forKey: appliedBootstrapSignatureKey)
    }
    
    func isBootstrapUpdateAvailable() -> Bool {
        guard let signature = bootstrapDatabaseSignature() else {
            return false
        }
        return signature != appliedBootstrapSignature()
    }
    
    func recordBootstrapBannerDismissedSignature() -> String? {
        guard let signature = bootstrapDatabaseSignature() else {
            return nil
        }
        UserDefaults.standard.set(signature, forKey: bootstrapBannerDismissedSignatureKey)
        return signature
    }
    
    func dismissedBootstrapBannerSignature() -> String? {
        UserDefaults.standard.string(forKey: bootstrapBannerDismissedSignatureKey)
    }
    
    // MARK: - Data Loading
    // 
    // IMPORTANT: Use Database Queries at Runtime, Not JSON
    // ====================================================
    // 
    // The app uses a pre-populated SwiftData database (bootstrap_database.store) for runtime data access.
    // The JSON file (bootstrap_data.json) should ONLY be used for:
    //   1. Importing/migrating data from JSON to database (importBootstrapData)
    //   2. Development/build-time scripts that generate the database
    //
    // For all runtime queries (checking source completeness, missing sources, etc.),
    // use the database query methods below that query SwiftData directly.
    //
    // Why?
    // - Database is faster (no JSON parsing)
    // - Database is already loaded in memory
    // - Database reflects actual current state
    // - JSON is only a build-time source file
    
    private func loadBootstrapData(allowRuntime: Bool) -> BootstrapData? {
        // ⚠️ WARNING: This loads JSON from bundle - only use for importing/migration!
        // For runtime queries, use the database query methods instead.
        guard allowRuntime else {
            print("❌ CRITICAL: Bootstrap JSON load blocked (runtime usage is not allowed)")
            return nil
        }
        guard let url = Bundle.main.url(forResource: "bootstrap_data", withExtension: "json") else {
            print("⚠️ Bootstrap data file not found")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let bootstrapData = try JSONDecoder().decode(BootstrapData.self, from: data)
            return bootstrapData
        } catch {
            print("❌ Error loading bootstrap data: \(error)")
            return nil
        }
    }
    
    // MARK: - Import Methods
    
    func importBootstrapData(
        modelContext: ModelContext,
        skipExisting: Bool = false,
        disableNewSources: Bool = false,
        progressCallback: ((String) -> Void)? = nil
    ) async throws -> (sourcesCreated: Int, moviesCreated: Int, moviesLinked: Int) {
        progressCallback?("Loading bootstrap data...")
        
        guard let bootstrapData = loadBootstrapData(allowRuntime: true) else {
            throw NSError(domain: "BootstrapDataService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not load bootstrap data"])
        }
        
        var sourcesCreated = 0
        var moviesCreated = 0
        var moviesLinked = 0
        
        progressCallback?("Creating sources...")
        
        // Create or update sources
        let sourceDescriptor = FetchDescriptor<DataSource>()
        let existingSources = try? modelContext.fetch(sourceDescriptor)
        let existingSourceIdentifiers = Set(existingSources?.map { $0.identifier } ?? [])
        
        var sourceMap: [String: DataSource] = [:]
        for existingSource in existingSources ?? [] {
            sourceMap[existingSource.identifier] = existingSource
        }
        
        for bootstrapSource in bootstrapData.dataSources {
            if let existingSource = sourceMap[bootstrapSource.identifier] {
                // Update existing source
                if !skipExisting && !existingSource.isLocalList {
                    existingSource.name = bootstrapSource.name
                    existingSource.type = bootstrapSource.type
                    existingSource.url = bootstrapSource.url
                    existingSource.isRankedList = bootstrapSource.isRankedList
                }
            } else {
                // Create new source
                let newSource = DataSource(
                    identifier: bootstrapSource.identifier,
                    name: bootstrapSource.name,
                    type: bootstrapSource.type,
                    url: bootstrapSource.url,
                    isEnabled: !disableNewSources,
                    lastUpdated: Date(),
                    lastChecked: nil,
                    createdAt: Date(),
                    isRankedList: bootstrapSource.isRankedList
                )
                modelContext.insert(newSource)
                sourceMap[bootstrapSource.identifier] = newSource
                sourcesCreated += 1
            }
        }
        
        try modelContext.save()
        progressCallback?("Processing movies...")
        
        // Process movies
        let movieDescriptor = FetchDescriptor<MovieData>()
        let existingMovies = (try? modelContext.fetch(movieDescriptor)) ?? []
        let existingMovieIds = Set(existingMovies.map { $0.id })
        
        // Build lookup maps for faster finding
        var moviesByTmdbId: [Int: MovieData] = [:]
        var moviesByTitle: [String: MovieData] = [:]
        for movie in existingMovies {
            if let tmdbId = movie.tmdbId {
                moviesByTmdbId[tmdbId] = movie
            }
            let normalizedTitle = TitleCleaner.shared.cleanTitle(movie.title).lowercased()
            if moviesByTitle[normalizedTitle] == nil {
                moviesByTitle[normalizedTitle] = movie
            }
        }
        
        var processedMovieCount = 0
        let totalMovies = bootstrapData.movies.count
        
        for bootstrapMovie in bootstrapData.movies {
            processedMovieCount += 1
            if processedMovieCount % 100 == 0 {
                progressCallback?("Processing movies... \(processedMovieCount)/\(totalMovies)")
            }
            
            // Clean title
            let cleanedTitle = TitleCleaner.shared.cleanTitle(bootstrapMovie.title)
            
            // Find existing movie by TMDB ID first (most reliable), then by title
            var movie: MovieData? = nil
            
            // Try to find by TMDB ID
            if let tmdbId = bootstrapMovie.tmdbId {
                movie = moviesByTmdbId[tmdbId]
            }
            
            // If not found by TMDB ID, try by cleaned title
            if movie == nil {
                let normalizedTitle = cleanedTitle.lowercased()
                movie = moviesByTitle[normalizedTitle]
            }
            
            // If still not found, try by exact ID match
            if movie == nil {
                let movieId: String
                if let tmdbId = bootstrapMovie.tmdbId {
                    movieId = "tmdb-\(tmdbId)"
                } else {
                    movieId = "bootstrap-\(UUID().uuidString)"
                }
                movie = existingMovies.first(where: { $0.id == movieId })
            }
            
            // Create movie if it doesn't exist (unless skipExisting is true)
            if movie == nil {
                if skipExisting {
                    continue // Skip creating new movies if skipExisting is true
                }
                
                // Generate movie ID
                let movieId: String
                if let tmdbId = bootstrapMovie.tmdbId {
                    movieId = "tmdb-\(tmdbId)"
                } else {
                    movieId = "bootstrap-\(UUID().uuidString)"
                }
                
                movie = MovieData(
                    id: movieId,
                    title: cleanedTitle,
                    year: bootstrapMovie.year,
                    tmdbId: bootstrapMovie.tmdbId,
                    posterPath: bootstrapMovie.posterPath,
                    backdropPath: bootstrapMovie.backdropPath,
                    overview: bootstrapMovie.overview,
                    mpaaRating: bootstrapMovie.mpaaRating,
                    genres: bootstrapMovie.genres ?? [],
                    streamingServices: mapStreamingServices(bootstrapMovie.streamingServices),
                    credits: mapCredits(bootstrapMovie.credits),
                    trailer: mapTrailer(bootstrapMovie.trailer),
                    lastUpdated: Date()
                )
                modelContext.insert(movie!)
                moviesCreated += 1
                
                // Update lookup maps
                if let tmdbId = bootstrapMovie.tmdbId {
                    moviesByTmdbId[tmdbId] = movie!
                }
                let normalizedTitle = cleanedTitle.lowercased()
                if moviesByTitle[normalizedTitle] == nil {
                    moviesByTitle[normalizedTitle] = movie!
                }
            }
            
            guard let movie = movie else { continue }

            if movie.posterPath == nil {
                movie.posterPath = bootstrapMovie.posterPath
            }
            if movie.backdropPath == nil {
                movie.backdropPath = bootstrapMovie.backdropPath
            }
            if movie.overview == nil || movie.overview?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                movie.overview = bootstrapMovie.overview
            }
            if movie.mpaaRating == nil || movie.mpaaRating?.isEmpty == true {
                movie.mpaaRating = bootstrapMovie.mpaaRating
            }
            if movie.genres.isEmpty, let genres = bootstrapMovie.genres {
                movie.genres = genres
            }
            if movie.streamingServices.isEmpty {
                movie.streamingServices = mapStreamingServices(bootstrapMovie.streamingServices)
            }
            if movie.credits == nil {
                movie.credits = mapCredits(bootstrapMovie.credits)
            }
            if movie.trailer == nil {
                movie.trailer = mapTrailer(bootstrapMovie.trailer)
            }
            
            // Create link to source (ALWAYS create link, even if movie exists)
            guard let source = sourceMap[bootstrapMovie.sourceIdentifier] else {
                continue
            }
            
            // Check if link already exists using the actual movie object
            let allLinksDescriptor = FetchDescriptor<MovieDataSource>()
            let allLinks = (try? modelContext.fetch(allLinksDescriptor)) ?? []
            let existingLink = allLinks.first(where: { link in
                link.movie?.id == movie.id && link.dataSource?.identifier == bootstrapMovie.sourceIdentifier
            })
            
            if existingLink == nil {
                let episodeTitle = bootstrapMovie.sourceTitle ?? cleanedTitle
                
                // Create podcast episode if this is a podcast source
                var podcastEpisode: PodcastEpisode? = nil
                let episodeDate = parseEpisodeDate(bootstrapMovie.episodeDate)
                if source.type == "podcast" {
                    let episodeId = "bootstrap-\(movie.id)-\(episodeTitle.prefix(50))".replacingOccurrences(of: " ", with: "-").lowercased()
                    
                    // Get podcast URLs based on source identifier
                    let (appleUrl, spotifyUrl) = getKnownPodcastUrls(
                        for: source.identifier,
                        episodeTitle: episodeTitle,
                        movieTitle: cleanedTitle
                    )
                    
                    podcastEpisode = PodcastEpisode(
                        title: episodeTitle,
                        episodeId: episodeId,
                        publishDate: episodeDate,
                        description: bootstrapMovie.podcastEpisodeDescription,
                        applePodcastsUrl: appleUrl,
                        spotifyUrl: spotifyUrl,
                        overcastUrl: nil,
                        pocketCastsUrl: nil
                    )
                }
                
                // Create SourceContent (new schema)
                // Only assign rank if this source is marked as ranked
                let rank = source.isRankedList ? bootstrapMovie.rank : nil
                let sourceContent = SourceContent(
                    movie: movie,
                    source: source,
                    sourceTitle: episodeTitle,
                    sourceDescription: nil,
                    sourceDate: episodeDate,
                    rank: rank,
                    podcastEpisode: podcastEpisode,
                    rewatchablesDiscussion: nil,
                    sourceUrl: source.url,
                    applePodcastsUrl: podcastEpisode?.applePodcastsUrl,
                    spotifyUrl: podcastEpisode?.spotifyUrl,
                    lastUpdated: Date(),
                    discoveredAt: Date()
                )
                modelContext.insert(sourceContent)
                
                // Also create MovieDataSource (old schema for backward compatibility)
                let link = MovieDataSource(
                    movie: movie,
                    dataSource: source,
                    podcastEpisode: podcastEpisode,
                    rewatchablesDiscussion: nil,
                    sourceUrl: source.url,
                    sourceTitle: episodeTitle,
                    rank: rank,
                    lastUpdated: Date()
                )
                modelContext.insert(link)
                moviesLinked += 1
            }
        }
        
        try modelContext.save()
        progressCallback?("Import complete!")
        
        return (sourcesCreated, moviesCreated, moviesLinked)
    }
    
    // MARK: - Query Methods
    
    func hasBootstrapData(modelContext: ModelContext) -> Bool {
        // Query database directly - check if any bootstrap sources exist
        let descriptor = FetchDescriptor<DataSource>()
        let allSources = (try? modelContext.fetch(descriptor)) ?? []
        let existingIdentifiers = Set(allSources.map { $0.identifier })
        
        // Check if any bootstrap sources exist in database
        return !Self.bootstrapSourceIdentifiers.intersection(existingIdentifiers).isEmpty
    }
    
    func getBootstrapSourceCount(modelContext: ModelContext) -> Int {
        // Query database directly - don't load JSON
        return Self.bootstrapSourceIdentifiers.count
    }
    
    func hasAllBootstrapSources(modelContext: ModelContext) -> Bool {
        // Query database directly - don't load JSON
        let descriptor = FetchDescriptor<DataSource>()
        let existingSources = (try? modelContext.fetch(descriptor)) ?? []
        let existingIdentifiers = Set(existingSources.map { $0.identifier })
        
        return Self.bootstrapSourceIdentifiers.isSubset(of: existingIdentifiers)
    }
    
    func getBootstrapSourceCompleteness(modelContext: ModelContext) -> (complete: Int, incomplete: Int, missing: Int, total: Int) {
        // Query database directly - don't load JSON
        let descriptor = FetchDescriptor<DataSource>()
        let existingSources = (try? modelContext.fetch(descriptor)) ?? []
        let existingIdentifiers = Set(existingSources.map { $0.identifier })
        
        let total = Self.bootstrapSourceIdentifiers.count
        let missing = Self.bootstrapSourceIdentifiers.subtracting(existingIdentifiers).count
        
        // Count source links from database
        let allLinksDescriptor = FetchDescriptor<SourceContent>()
        let allLinks = (try? modelContext.fetch(allLinksDescriptor)) ?? []
        
        var sourceLinkCounts: [String: Int] = [:]
        for link in allLinks {
            if let sourceId = link.source?.identifier, Self.bootstrapSourceIdentifiers.contains(sourceId) {
                sourceLinkCounts[sourceId, default: 0] += 1
            }
        }
        
        // Also check old schema
        let oldLinksDescriptor = FetchDescriptor<MovieDataSource>()
        let oldLinks = (try? modelContext.fetch(oldLinksDescriptor)) ?? []
        for link in oldLinks {
            if let sourceId = link.dataSource?.identifier, Self.bootstrapSourceIdentifiers.contains(sourceId) {
                // Only count if not already counted in new schema
                if sourceLinkCounts[sourceId] == nil {
                    sourceLinkCounts[sourceId, default: 0] += 1
                }
            }
        }
        
        // Categorize sources
        var incomplete = 0
        var complete = 0
        
        for sourceId in Self.bootstrapSourceIdentifiers {
            if existingIdentifiers.contains(sourceId) {
                let linkCount = sourceLinkCounts[sourceId] ?? 0
                // Consider a source complete if it has at least some links
                // We don't need exact counts from JSON - just check if source exists and has movies
                if linkCount > 0 {
                    complete += 1
                } else {
                    incomplete += 1
                }
            }
        }
        
        return (complete, incomplete, missing, total)
    }
    
    func hasUserMovieData(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<UserMovieData>()
        let count = (try? modelContext.fetch(descriptor).count) ?? 0
        return count > 0
    }
    
    func getMissingBootstrapSources(modelContext: ModelContext) -> [BootstrapDataSource] {
        // Query database directly - return minimal info without loading JSON
        let descriptor = FetchDescriptor<DataSource>()
        let existingSources = (try? modelContext.fetch(descriptor)) ?? []
        let existingIdentifiers = Set(existingSources.map { $0.identifier })
        
        let missingIdentifiers = Self.bootstrapSourceIdentifiers.subtracting(existingIdentifiers)
        
        // Return minimal BootstrapDataSource objects for missing sources
        // These are just used for display - actual source creation happens during import
        return missingIdentifiers.map { identifier in
            BootstrapDataSource(
                identifier: identifier,
                name: identifier.replacingOccurrences(of: "-", with: " ").capitalized,
                type: identifier.contains("rt-") || identifier.contains("imdb-") || identifier == "criterion" ? "url" : "podcast",
                url: nil,
                isRankedList: identifier.contains("rt-") || identifier.contains("imdb-"),
                movieCount: 0
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Returns known podcast URLs for a given podcast identifier
    func getKnownPodcastUrls(for identifier: String, episodeTitle: String?, movieTitle: String?) -> (applePodcastsUrl: String?, spotifyUrl: String?) {
        switch identifier {
        case "rewatchables":
            let appleUrl = "https://podcasts.apple.com/us/podcast/the-rewatchables/id1268527882"
            let spotifyShowUrl = "https://open.spotify.com/show/4rOoJ6Egrf8K2IrywzwOMk"
            // Generate search URL with movie title if available
            let spotifyUrl = movieTitle.map { title in
                let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "https://open.spotify.com/search/\(encoded)%20rewatchables"
            } ?? spotifyShowUrl
            return (appleUrl, spotifyUrl)
            
        case "big-picture":
            let appleUrl = "https://podcasts.apple.com/us/podcast/the-big-picture/id1441925782"
            let spotifyShowUrl = "https://open.spotify.com/show/2rPwR0FyI5ra7YlhqWCq7N"
            let spotifyUrl = movieTitle.map { title in
                let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "https://open.spotify.com/search/\(encoded)%20big%20picture"
            } ?? spotifyShowUrl
            return (appleUrl, spotifyUrl)
            
        case "blank-check":
            let appleUrl = "https://podcasts.apple.com/us/podcast/blank-check-with-griffin-and-david/id1048424828"
            let spotifyShowUrl = "https://open.spotify.com/show/4Vr3yJpWUxhpkJRmz1gQdq"
            let spotifyUrl = movieTitle.map { title in
                let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "https://open.spotify.com/search/\(encoded)%20blank%20check"
            } ?? spotifyShowUrl
            return (appleUrl, spotifyUrl)
            
        case "confused-breakfast":
            let appleUrl = "https://podcasts.apple.com/us/podcast/the-confused-breakfast/id1494516409"
            let spotifyShowUrl = "https://open.spotify.com/show/0rCQKgwBj2F3VLqjK8Jb4x"
            let spotifyUrl = movieTitle.map { title in
                let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "https://open.spotify.com/search/\(encoded)%20confused%20breakfast"
            } ?? spotifyShowUrl
            return (appleUrl, spotifyUrl)
            
        default:
            return (nil, nil)
        }
    }
}