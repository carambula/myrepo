//
//  MovieDataModel.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import SwiftData

/// Core movie data - shared across all data sources
@Model
final class MovieData {
    var id: String // Deterministic ID (tmdb-{id} or imdb-{id} or episode-{id})
    var title: String
    var year: Int?
    var tmdbId: Int?
    var imdbId: String? // Added for better deduplication
    var originalTitle: String? // Original title before cleaning
    var releaseDate: Date? // Release date
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var tagline: String? // Added for future use
    var mpaaRating: String?
    var runtime: Int? // Runtime in minutes
    var genresData: Data? // Encoded [String]
    var streamingServicesData: Data? // Encoded [StreamingService]
    var creditsData: Data? // Encoded MovieCredits
    var trailerData: Data? // Encoded MovieTrailer
    var oscarAwardsData: Data? // Encoded OscarAwards
    var physicalMediaData: Data? // Encoded PhysicalMedia
    var keywordsData: Data? // Encoded [String] - for future use
    var lastUpdated: Date
    var createdAt: Date // When movie was first added
    var cloudKitRecordID: String?
    
    // Relationships - Old (kept for backward compatibility during migration)
    @Relationship(deleteRule: .cascade, inverse: \MovieState.movie)
    var states: [MovieState]?
    
    @Relationship(deleteRule: .cascade, inverse: \MovieDataSource.movie)
    var dataSources: [MovieDataSource]?
    
    // Relationships - New (ideal schema)
    @Relationship(deleteRule: .nullify, inverse: \UserMovieData.movie)
    var userData: UserMovieData?
    
    @Relationship(deleteRule: .cascade, inverse: \SourceContent.movie)
    var sourceContents: [SourceContent]?
    
    init(
        id: String = UUID().uuidString,
        title: String = "",
        year: Int? = nil,
        tmdbId: Int? = nil,
        imdbId: String? = nil,
        originalTitle: String? = nil,
        releaseDate: Date? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        overview: String? = nil,
        tagline: String? = nil,
        mpaaRating: String? = nil,
        runtime: Int? = nil,
        genres: [String] = [],
        streamingServices: [StreamingService] = [],
        credits: MovieCredits? = nil,
        trailer: MovieTrailer? = nil,
        oscarAwards: OscarAwards? = nil,
        physicalMedia: PhysicalMedia? = nil,
        keywords: [String] = [],
        lastUpdated: Date = Date(),
        createdAt: Date = Date(),
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbId = tmdbId
        self.imdbId = imdbId
        self.originalTitle = originalTitle
        self.releaseDate = releaseDate
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.tagline = tagline
        self.mpaaRating = mpaaRating
        self.runtime = runtime
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
        self.cloudKitRecordID = cloudKitRecordID
        
        // Initializing Data properties directly to avoid MainActor isolation issues
        // The helper methods are MainActor-isolated but so is init since MovieData is @Model
        
        if !genres.isEmpty {
            do {
                self.genresData = try JSONEncoder().encode(genres)
                print("✅ Successfully encoded \(genres.count) genres in init for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode genres in init for '\(title)': \(error.localizedDescription)")
                self.genresData = nil
            }
        }
        
        if !streamingServices.isEmpty {
            do {
                self.streamingServicesData = try JSONEncoder().encode(streamingServices)
                print("✅ Successfully encoded \(streamingServices.count) streaming services in init for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode streaming services in init for '\(title)': \(error.localizedDescription)")
                self.streamingServicesData = nil
            }
        }
        
        if let credits = credits {
            do {
                self.creditsData = try encodeCredits(credits)
                print("✅ Successfully encoded credits in init for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode credits in init for '\(title)': \(error.localizedDescription)")
                self.creditsData = nil
            }
        }
        
        if let trailer = trailer {
            do {
                self.trailerData = try encodeTrailer(trailer)
                print("✅ Successfully encoded trailer in init for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode trailer in init for '\(title)': \(error.localizedDescription)")
                self.trailerData = nil
            }
        }
        
        if let oscarAwards = oscarAwards {
            do {
                self.oscarAwardsData = try encodeOscarAwards(oscarAwards)
                print("✅ Successfully encoded Oscar awards in init for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode Oscar awards in init for '\(title)': \(error.localizedDescription)")
                self.oscarAwardsData = nil
            }
        }

        if let physicalMedia = physicalMedia {
            do {
                self.physicalMediaData = try encodePhysicalMedia(physicalMedia)
            } catch {
                print("❌ CRITICAL: Failed to encode physical media in init for '\(title)': \(error.localizedDescription)")
                self.physicalMediaData = nil
            }
        }
        
        if !keywords.isEmpty {
            do {
                self.keywordsData = try JSONEncoder().encode(keywords)
            } catch {
                print("❌ Failed to encode keywords for '\(title)': \(error.localizedDescription)")
                self.keywordsData = nil
            }
        }
    }
    
    var keywords: [String] {
        get {
            guard let data = keywordsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                keywordsData = nil
            } else {
                keywordsData = try? JSONEncoder().encode(newValue)
            }
        }
    }
    
    var genres: [String] {
        get {
            guard let data = genresData else { return [] }
            do {
                return try JSONDecoder().decode([String].self, from: data)
            } catch {
                print("❌ Error decoding genres for movie '\(title)': \(error.localizedDescription)")
                return []
            }
        }
        set {
            if newValue.isEmpty {
                genresData = nil
                return
            }
            do {
                genresData = try JSONEncoder().encode(newValue)
                print("✅ Successfully encoded \(newValue.count) genres for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode genres for movie '\(title)': \(error.localizedDescription)")
                print("   Genres that failed to encode: \(newValue)")
                genresData = nil
            }
        }
    }
    
    var streamingServices: [StreamingService] {
        get {
            guard let data = streamingServicesData else { return [] }
            do {
                return try JSONDecoder().decode([StreamingService].self, from: data)
            } catch {
                print("❌ Error decoding streaming services for movie '\(title)': \(error.localizedDescription)")
                return []
            }
        }
        set {
            if newValue.isEmpty {
                streamingServicesData = nil
                return
            }
            do {
                streamingServicesData = try JSONEncoder().encode(newValue)
                print("✅ Successfully encoded \(newValue.count) streaming services for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode streaming services for movie '\(title)': \(error.localizedDescription)")
                streamingServicesData = nil
            }
        }
    }
    
    var credits: MovieCredits? {
        get {
            guard let data = creditsData else { return nil }
            do {
                return try decodeCredits(from: data)
            } catch {
                print("❌ Error decoding credits for movie '\(title)': \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                creditsData = nil
                return
            }
            do {
                creditsData = try encodeCredits(newValue)
                print("✅ Successfully encoded credits for '\(title)' (director: \(newValue.director ?? "none"), cast: \(newValue.cast.count))")
            } catch {
                print("❌ CRITICAL: Failed to encode credits for movie '\(title)': \(error.localizedDescription)")
                creditsData = nil
            }
        }
    }
    
    var trailer: MovieTrailer? {
        get {
            guard let data = trailerData else { return nil }
            do {
                return try decodeTrailer(from: data)
            } catch {
                print("❌ Error decoding trailer for movie '\(title)': \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                trailerData = nil
                return
            }
            do {
                trailerData = try encodeTrailer(newValue)
                print("✅ Successfully encoded trailer for '\(title)' (key: \(newValue.youtubeKey))")
            } catch {
                print("❌ CRITICAL: Failed to encode trailer for movie '\(title)': \(error.localizedDescription)")
                trailerData = nil
            }
        }
    }
    
    var oscarAwards: OscarAwards? {
        get {
            guard let data = oscarAwardsData else { return nil }
            do {
                return try decodeOscarAwards(from: data)
            } catch {
                print("❌ Error decoding Oscar awards for movie '\(title)': \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                oscarAwardsData = nil
                return
            }
            do {
                oscarAwardsData = try encodeOscarAwards(newValue)
                print("✅ Successfully encoded Oscar awards for '\(title)'")
            } catch {
                print("❌ CRITICAL: Failed to encode Oscar awards for movie '\(title)': \(error.localizedDescription)")
                oscarAwardsData = nil
            }
        }
    }

    var physicalMedia: PhysicalMedia? {
        get {
            guard let data = physicalMediaData else { return nil }
            do {
                return try decodePhysicalMedia(from: data)
            } catch {
                print("❌ Error decoding physical media for movie '\(title)': \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                physicalMediaData = nil
                return
            }
            do {
                physicalMediaData = try encodePhysicalMedia(newValue)
            } catch {
                print("❌ CRITICAL: Failed to encode physical media for movie '\(title)': \(error.localizedDescription)")
                physicalMediaData = nil
            }
        }
    }
    
    /// Returns nil if this instance was invalidated (e.g. deleted from the store).
    /// Use this when iterating over a fetch result that may have been invalidated by catalog refresh or deletes.
    func toMovieIfValid() -> Movie? {
        guard modelContext != nil else { return nil }
        return toMovie()
    }

    func toMovie() -> Movie {
        let cleanedTitle = TitleCleaner.shared.cleanTitle(title)
        
        // Get user data - prefer new UserMovieData, fall back to old MovieState
        let isRewatched: Bool
        let isListened: Bool
        let isSaved: Bool
        
        if let userData = userData {
            // Use new schema
            isRewatched = userData.isRewatched
            isListened = userData.isListened
            isSaved = userData.isSaved
        } else if let state = states?.first {
            // Fall back to old schema for backward compatibility
            isRewatched = state.isRewatched
            isListened = state.isListened
            isSaved = state.isSaved
        } else {
            // Default values
            isRewatched = false
            isListened = false
            isSaved = false
        }
        
        // Get source content - prefer new SourceContent, fall back to old MovieDataSource
        var podcastEpisode: PodcastEpisode? = nil
        var rewatchablesDiscussion: RewatchablesDiscussion? = nil
        
        // Rewatchables discussion only comes from the Rewatchables source
        if let rewatchablesContent = sourceContents?.first(where: { $0.source?.identifier == "rewatchables" }) {
            rewatchablesDiscussion = rewatchablesContent.rewatchablesDiscussion
            podcastEpisode = rewatchablesContent.podcastEpisode
        } else if let rewatchablesDataSource = dataSources?.first(where: { $0.dataSource?.identifier == "rewatchables" }) {
            // Fall back to old schema
            rewatchablesDiscussion = rewatchablesDataSource.rewatchablesDiscussion
            podcastEpisode = rewatchablesDataSource.podcastEpisode
        }
        
        // If we still don't have a podcast episode, pick one from any podcast source
        if podcastEpisode == nil {
            if let podcastContent = sourceContents?.first(where: { $0.source?.type == "podcast" && $0.podcastEpisode != nil }) {
                podcastEpisode = podcastContent.podcastEpisode
            } else if let podcastDataSource = dataSources?.first(where: { $0.dataSource?.type == "podcast" && $0.podcastEpisode != nil }) {
                podcastEpisode = podcastDataSource.podcastEpisode
            }
        }
        
        return Movie(
            id: id,
            title: cleanedTitle,
            year: year,
            tmdbId: tmdbId,
            posterPath: posterPath,
            backdropPath: backdropPath,
            overview: overview,
            mpaaRating: mpaaRating,
            genres: genres,
            streamingServices: streamingServices,
            podcastEpisode: podcastEpisode,
            credits: credits,
            rewatchablesDiscussion: rewatchablesDiscussion,
            trailer: trailer,
            oscarAwards: oscarAwards,
            physicalMedia: PhysicalMediaCatalog.shared.resolvedMedia(stored: physicalMedia, tmdbId: tmdbId),
            isRewatched: isRewatched,
            isListened: isListened,
            isSaved: isSaved,
            lastUpdated: lastUpdated
        )
    }
    
    static func fromMovie(_ movie: Movie, cloudKitRecordID: String? = nil) -> MovieData {
        // Clean title before creating MovieData to ensure consistency
        let cleanedTitle = TitleCleaner.shared.cleanTitle(movie.title)
        return MovieData(
            id: movie.id,
            title: cleanedTitle,
            year: movie.year,
            tmdbId: movie.tmdbId,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            overview: movie.overview,
            mpaaRating: movie.mpaaRating,
            genres: movie.genres,
            streamingServices: movie.streamingServices,
            credits: movie.credits,
            trailer: movie.trailer,
            oscarAwards: movie.oscarAwards,
            physicalMedia: movie.physicalMedia,
            lastUpdated: movie.lastUpdated,
            cloudKitRecordID: cloudKitRecordID
        )
    }
}

/// User tracking states for movies
@Model
final class MovieState {
    var isRewatched: Bool = false
    var isListened: Bool = false
    var isSaved: Bool = false
    var lastUpdated: Date
    
    // Relationship to movie
    var movie: MovieData?
    
    init(
        isRewatched: Bool = false,
        isListened: Bool = false,
        isSaved: Bool = false,
        lastUpdated: Date = Date(),
        movie: MovieData? = nil
    ) {
        self.isRewatched = isRewatched
        self.isListened = isListened
        self.isSaved = isSaved
        self.lastUpdated = lastUpdated
        self.movie = movie
    }
}

/// Unified list/source definition - can be external sources (podcasts, URLs) or local lists
@Model
public final class DataSource {
    public var identifier: String // e.g., "rewatchables" or UUID for local lists
    public var name: String // e.g., "The Rewatchables" or "My Watchlist"
    public var type: String // e.g., "podcast", "url", "local" (for user-created lists)
    public var url: String? // RSS feed URL for podcasts, or arbitrary URL for external lists, nil for local lists
    public var isEnabled: Bool = true // Whether this list/source is active (for syncing external sources)
    public var lastUpdated: Date
    public var lastChecked: Date? // When we last checked this source for updates (nil for local lists)
    public var createdAt: Date // When this list was created (for local lists)
    public var isRankedList: Bool = false // Whether this is a ranked list (movies have ranking numbers)
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \MovieDataSource.dataSource)
    var movieDataSources: [MovieDataSource]? // Old schema
    
    @Relationship(deleteRule: .cascade, inverse: \SourceContent.source)
    var sourceContents: [SourceContent]? // New schema
    
    public init(
        identifier: String,
        name: String,
        type: String,
        url: String? = nil,
        isEnabled: Bool = true,
        lastUpdated: Date = Date(),
        lastChecked: Date? = nil,
        createdAt: Date = Date(),
        isRankedList: Bool = false
    ) {
        self.identifier = identifier
        self.name = name
        self.type = type
        self.url = url
        self.isEnabled = isEnabled
        self.lastUpdated = lastUpdated
        self.lastChecked = lastChecked
        self.createdAt = createdAt
        self.isRankedList = isRankedList
    }
    
    // Helper to check if this is a local list
    public var isLocalList: Bool {
        type == "local"
    }
    
    // Helper to get movies in this list (works with both old and new schemas)
    // Note: This relies on relationships being loaded - for filtering use the cache in MovieListView
    var movies: [MovieData] {
        var result: [MovieData] = []
        
        // Use new schema relationship (SourceContent)
        if let sourceContents = sourceContents {
            result.append(contentsOf: sourceContents.compactMap { $0.movie })
        }
        
        // Also use old schema relationship (MovieDataSource)
        if let movieDataSources = movieDataSources {
            for movieDataSource in movieDataSources {
                if let movie = movieDataSource.movie, !result.contains(where: { $0.id == movie.id }) {
                    result.append(movie)
                }
            }
        }
        
        return result
    }
}

/// Junction table linking movies to data sources with source-specific data
@Model
final class MovieDataSource {
    var lastUpdated: Date
    
    // Source-specific data (for Rewatchables podcast)
    var podcastEpisodeData: Data? // Encoded PodcastEpisode
    var rewatchablesDiscussionData: Data? // Encoded RewatchablesDiscussion
    
    // For arbitrary URL sources
    var sourceUrl: String? // The URL where this movie was found
    var sourceTitle: String? // Title/description from the source (e.g., episode title, list entry)
    var rank: Int? // Ranking number in a ranked list (e.g., 1, 2, 3...)
    
    // Relationships
    var movie: MovieData?
    
    var dataSource: DataSource?
    
    init(
        movie: MovieData? = nil,
        dataSource: DataSource? = nil,
        podcastEpisode: PodcastEpisode? = nil,
        rewatchablesDiscussion: RewatchablesDiscussion? = nil,
        sourceUrl: String? = nil,
        sourceTitle: String? = nil,
        rank: Int? = nil,
        lastUpdated: Date = Date()
    ) {
        self.movie = movie
        self.dataSource = dataSource
        self.sourceUrl = sourceUrl
        self.sourceTitle = sourceTitle
        self.rank = rank
        self.lastUpdated = lastUpdated
        
        // Initializing Data properties directly to avoid MainActor isolation issues
        
        if let episode = podcastEpisode {
            do {
                self.podcastEpisodeData = try encodePodcastEpisode(episode)
                print("✅ Successfully encoded podcast episode in init")
            } catch {
                print("❌ CRITICAL: Failed to encode podcast episode in init: \(error.localizedDescription)")
                self.podcastEpisodeData = nil
            }
        }
        
        if let discussion = rewatchablesDiscussion {
            do {
                self.rewatchablesDiscussionData = try encodeRewatchablesDiscussion(discussion)
                print("✅ Successfully encoded rewatchables discussion in init")
            } catch {
                print("❌ CRITICAL: Failed to encode rewatchables discussion in init: \(error.localizedDescription)")
                self.rewatchablesDiscussionData = nil
            }
        }
    }
    
    var podcastEpisode: PodcastEpisode? {
        get {
            guard let data = podcastEpisodeData else { return nil }
            do {
                return try decodePodcastEpisode(from: data)
            } catch {
                print("❌ Error decoding podcast episode: \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                podcastEpisodeData = nil
                return
            }
            do {
                podcastEpisodeData = try encodePodcastEpisode(newValue)
                print("✅ Successfully encoded podcast episode")
            } catch {
                print("❌ CRITICAL: Failed to encode podcast episode: \(error.localizedDescription)")
                podcastEpisodeData = nil
            }
        }
    }
    
    var rewatchablesDiscussion: RewatchablesDiscussion? {
        get {
            guard let data = rewatchablesDiscussionData else { return nil }
            do {
                return try decodeRewatchablesDiscussion(from: data)
            } catch {
                print("❌ Error decoding rewatchables discussion: \(error.localizedDescription)")
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                rewatchablesDiscussionData = nil
                return
            }
            do {
                rewatchablesDiscussionData = try encodeRewatchablesDiscussion(newValue)
                print("✅ Successfully encoded rewatchables discussion")
            } catch {
                print("❌ CRITICAL: Failed to encode rewatchables discussion: \(error.localizedDescription)")
                rewatchablesDiscussionData = nil
            }
        }
    }
}

// MARK: - Nonisolated Encoding/Decoding Helpers

extension MovieData {
    nonisolated private static func encodeCredits(_ credits: MovieCredits) throws -> Data {
        return try JSONEncoder().encode(credits)
    }
    
    nonisolated private static func decodeCredits(from data: Data) throws -> MovieCredits {
        return try JSONDecoder().decode(MovieCredits.self, from: data)
    }
    
    nonisolated private static func encodeTrailer(_ trailer: MovieTrailer) throws -> Data {
        return try JSONEncoder().encode(trailer)
    }
    
    nonisolated private static func decodeTrailer(from data: Data) throws -> MovieTrailer {
        return try JSONDecoder().decode(MovieTrailer.self, from: data)
    }
    
    nonisolated private static func encodeOscarAwards(_ awards: OscarAwards) throws -> Data {
        return try JSONEncoder().encode(awards)
    }
    
    nonisolated private static func decodeOscarAwards(from data: Data) throws -> OscarAwards {
        return try JSONDecoder().decode(OscarAwards.self, from: data)
    }

    nonisolated private static func encodePhysicalMedia(_ media: PhysicalMedia) throws -> Data {
        return try JSONEncoder().encode(media)
    }

    nonisolated private static func decodePhysicalMedia(from data: Data) throws -> PhysicalMedia {
        return try JSONDecoder().decode(PhysicalMedia.self, from: data)
    }
    
    nonisolated private static func encodePodcastEpisode(_ episode: PodcastEpisode) throws -> Data {
        return try JSONEncoder().encode(episode)
    }
    
    nonisolated private static func decodePodcastEpisode(from data: Data) throws -> PodcastEpisode {
        return try JSONDecoder().decode(PodcastEpisode.self, from: data)
    }
    
    nonisolated private static func encodeRewatchablesDiscussion(_ discussion: RewatchablesDiscussion) throws -> Data {
        return try JSONEncoder().encode(discussion)
    }
    
    nonisolated private static func decodeRewatchablesDiscussion(from data: Data) throws -> RewatchablesDiscussion {
        return try JSONDecoder().decode(RewatchablesDiscussion.self, from: data)
    }
    
    private func encodeCredits(_ credits: MovieCredits) throws -> Data {
        return try Self.encodeCredits(credits)
    }
    
    private func decodeCredits(from data: Data) throws -> MovieCredits {
        return try Self.decodeCredits(from: data)
    }
    
    private func encodeTrailer(_ trailer: MovieTrailer) throws -> Data {
        return try Self.encodeTrailer(trailer)
    }
    
    private func decodeTrailer(from data: Data) throws -> MovieTrailer {
        return try Self.decodeTrailer(from: data)
    }
    
    private func encodeOscarAwards(_ awards: OscarAwards) throws -> Data {
        return try Self.encodeOscarAwards(awards)
    }
    
    private func decodeOscarAwards(from data: Data) throws -> OscarAwards {
        return try Self.decodeOscarAwards(from: data)
    }

    private func encodePhysicalMedia(_ media: PhysicalMedia) throws -> Data {
        return try Self.encodePhysicalMedia(media)
    }

    private func decodePhysicalMedia(from data: Data) throws -> PhysicalMedia {
        return try Self.decodePhysicalMedia(from: data)
    }
    
    private func encodePodcastEpisode(_ episode: PodcastEpisode) throws -> Data {
        return try Self.encodePodcastEpisode(episode)
    }
    
    private func decodePodcastEpisode(from data: Data) throws -> PodcastEpisode {
        return try Self.decodePodcastEpisode(from: data)
    }
    
    private func encodeRewatchablesDiscussion(_ discussion: RewatchablesDiscussion) throws -> Data {
        return try Self.encodeRewatchablesDiscussion(discussion)
    }
    
    private func decodeRewatchablesDiscussion(from data: Data) throws -> RewatchablesDiscussion {
        return try Self.decodeRewatchablesDiscussion(from: data)
    }
}

// MARK: - MovieDataSource Nonisolated Encoding/Decoding Helpers

extension MovieDataSource {
    nonisolated private static func encodePodcastEpisode(_ episode: PodcastEpisode) throws -> Data {
        return try JSONEncoder().encode(episode)
    }
    
    nonisolated private static func decodePodcastEpisode(from data: Data) throws -> PodcastEpisode {
        return try JSONDecoder().decode(PodcastEpisode.self, from: data)
    }
    
    nonisolated private static func encodeRewatchablesDiscussion(_ discussion: RewatchablesDiscussion) throws -> Data {
        return try JSONEncoder().encode(discussion)
    }
    
    nonisolated private static func decodeRewatchablesDiscussion(from data: Data) throws -> RewatchablesDiscussion {
        return try JSONDecoder().decode(RewatchablesDiscussion.self, from: data)
    }
    
    private func encodePodcastEpisode(_ episode: PodcastEpisode) throws -> Data {
        return try Self.encodePodcastEpisode(episode)
    }
    
    private func decodePodcastEpisode(from data: Data) throws -> PodcastEpisode {
        return try Self.decodePodcastEpisode(from: data)
    }
    
    private func encodeRewatchablesDiscussion(_ discussion: RewatchablesDiscussion) throws -> Data {
        return try Self.encodeRewatchablesDiscussion(discussion)
    }
    
    private func decodeRewatchablesDiscussion(from data: Data) throws -> RewatchablesDiscussion {
        return try Self.decodeRewatchablesDiscussion(from: data)
    }
}

// CustomList and MovieListEntry removed - using DataSource with type "local" for lists
// All lists (both external sources and local lists) are now DataSource objects

// MARK: - Ideal Schema Entities

/// Source type enumeration for type safety
enum SourceType: String, Codable, CaseIterable {
    case podcast = "podcast"
    case rankedList = "rankedList"
    case urlList = "urlList"
    case userList = "userList"
    
    var displayName: String {
        switch self {
        case .podcast: return "Podcast"
        case .rankedList: return "Ranked List"
        case .urlList: return "URL List"
        case .userList: return "User List"
        }
    }
    
    init?(from string: String) {
        switch string {
        case "podcast": self = .podcast
        case "rankedList", "ranked": self = .rankedList
        case "urlList", "url": self = .urlList
        case "local", "userList": self = .userList
        default: return nil
        }
    }
}

/// User-specific data for movies - replaces MovieState
@Model
final class UserMovieData {
    // Relationship (one-to-one with Movie)
    var movie: MovieData?
    
    // Status flags
    var isSaved: Bool = false
    var isRewatched: Bool = false
    var isListened: Bool = false
    var isWatched: Bool = false // For future: general "watched" status
    
    // User ratings & notes
    var userRating: Int? // 1-10 or 1-5 scale (nullable)
    var userNotes: String? // Free-form notes
    var watchedDate: Date?
    var rewatchedDate: Date?
    var listenedDate: Date?
    
    // Tags/Categories (for future)
    var tagsData: Data? // Encoded [String]
    
    // Timestamps
    var lastUpdated: Date
    var createdAt: Date
    
    init(
        movie: MovieData? = nil,
        isSaved: Bool = false,
        isRewatched: Bool = false,
        isListened: Bool = false,
        isWatched: Bool = false,
        userRating: Int? = nil,
        userNotes: String? = nil,
        watchedDate: Date? = nil,
        rewatchedDate: Date? = nil,
        listenedDate: Date? = nil,
        tags: [String] = [],
        lastUpdated: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.movie = movie
        self.isSaved = isSaved
        self.isRewatched = isRewatched
        self.isListened = isListened
        self.isWatched = isWatched
        self.userRating = userRating
        self.userNotes = userNotes
        self.watchedDate = watchedDate
        self.rewatchedDate = rewatchedDate
        self.listenedDate = listenedDate
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
        
        if !tags.isEmpty {
            self.tagsData = try? JSONEncoder().encode(tags)
        }
    }
    
    var tags: [String] {
        get {
            guard let data = tagsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                tagsData = nil
            } else {
                tagsData = try? JSONEncoder().encode(newValue)
            }
        }
    }
}

/// Source content linking movies to sources with source-specific metadata
/// Replaces MovieDataSource with better naming and structure
@Model
final class SourceContent {
    // Relationships
    var movie: MovieData?
    var source: DataSource? // Keep reference to DataSource for now (will migrate to Source later)
    
    // Source-specific metadata
    var sourceTitle: String? // Episode title, list entry title, etc.
    var sourceDescription: String? // Episode description, list entry description
    var sourceDate: Date? // Publish date, list date, etc.
    var rank: Int? // Ranking in list (if isRankedList)
    
    // Source-specific structured data (encoded as JSON)
    var podcastEpisodeData: Data? // PodcastEpisode
    var rewatchablesDiscussionData: Data? // RewatchablesDiscussion
    var listEntryData: Data? // Generic list entry data (for future extensibility)
    
    // URLs
    var sourceUrl: String? // Direct URL to this content item
    var applePodcastsUrl: String?
    var spotifyUrl: String?
    
    // Timestamps
    var lastUpdated: Date
    var discoveredAt: Date // When this content was first discovered
    
    init(
        movie: MovieData? = nil,
        source: DataSource? = nil,
        sourceTitle: String? = nil,
        sourceDescription: String? = nil,
        sourceDate: Date? = nil,
        rank: Int? = nil,
        podcastEpisode: PodcastEpisode? = nil,
        rewatchablesDiscussion: RewatchablesDiscussion? = nil,
        sourceUrl: String? = nil,
        applePodcastsUrl: String? = nil,
        spotifyUrl: String? = nil,
        lastUpdated: Date = Date(),
        discoveredAt: Date = Date()
    ) {
        self.movie = movie
        self.source = source
        self.sourceTitle = sourceTitle
        self.sourceDescription = sourceDescription
        self.sourceDate = sourceDate
        self.rank = rank
        self.sourceUrl = sourceUrl
        self.applePodcastsUrl = applePodcastsUrl
        self.spotifyUrl = spotifyUrl
        self.lastUpdated = lastUpdated
        self.discoveredAt = discoveredAt
        
        if let episode = podcastEpisode {
            self.podcastEpisodeData = try? JSONEncoder().encode(episode)
        }
        
        if let discussion = rewatchablesDiscussion {
            self.rewatchablesDiscussionData = try? JSONEncoder().encode(discussion)
        }
    }
    
    var podcastEpisode: PodcastEpisode? {
        get {
            guard let data = podcastEpisodeData else { return nil }
            return try? JSONDecoder().decode(PodcastEpisode.self, from: data)
        }
        set {
            if let episode = newValue {
                podcastEpisodeData = try? JSONEncoder().encode(episode)
            } else {
                podcastEpisodeData = nil
            }
        }
    }
    
    var rewatchablesDiscussion: RewatchablesDiscussion? {
        get {
            guard let data = rewatchablesDiscussionData else { return nil }
            return try? JSONDecoder().decode(RewatchablesDiscussion.self, from: data)
        }
        set {
            if let discussion = newValue {
                rewatchablesDiscussionData = try? JSONEncoder().encode(discussion)
            } else {
                rewatchablesDiscussionData = nil
            }
        }
    }
}

/// Bootstrap version tracking
@Model
final class BootstrapVersion {
    var version: String // Semantic version: "1.0.0"
    var buildNumber: Int // Build number
    var appliedDate: Date // When this version was applied
    var sourceCount: Int // Number of sources in this version
    var movieCount: Int // Number of movies in this version
    var checksum: String? // Optional: checksum of bootstrap data
    
    init(
        version: String,
        buildNumber: Int,
        appliedDate: Date = Date(),
        sourceCount: Int = 0,
        movieCount: Int = 0,
        checksum: String? = nil
    ) {
        self.version = version
        self.buildNumber = buildNumber
        self.appliedDate = appliedDate
        self.sourceCount = sourceCount
        self.movieCount = movieCount
        self.checksum = checksum
    }
}

