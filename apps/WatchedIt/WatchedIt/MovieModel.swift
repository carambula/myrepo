//
//  MovieModel.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import SwiftData

@Model
final class MovieModel {
    // Note: Removed @Attribute(.unique) - CloudKit doesn't support unique constraints
    // We'll handle uniqueness manually in code
    var id: String
    var title: String
    var year: Int?
    var tmdbId: Int?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var mpaaRating: String? // MPAA rating (G, PG, PG-13, R, NC-17, etc.)
    var genresData: Data? // Encoded [String] - SwiftData doesn't support Array<String> directly
    var streamingServicesData: Data? // Encoded [StreamingService]
    var podcastEpisodeData: Data? // Encoded PodcastEpisode
    var creditsData: Data? // Encoded MovieCredits
    var rewatchablesDiscussionData: Data? // Encoded RewatchablesDiscussion
    var trailerData: Data? // Encoded MovieTrailer
    var oscarAwardsData: Data? // Encoded OscarAwards
    var isRewatched: Bool = false
    var isListened: Bool = false
    var isSaved: Bool = false
    var lastUpdated: Date
    var cloudKitRecordID: String?
    
    init(
        id: String = UUID().uuidString,
        title: String = "",
        year: Int? = nil,
        tmdbId: Int? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        overview: String? = nil,
        mpaaRating: String? = nil,
        genres: [String] = [],
        streamingServices: [StreamingService] = [],
        podcastEpisode: PodcastEpisode? = nil,
        credits: MovieCredits? = nil,
        rewatchablesDiscussion: RewatchablesDiscussion? = nil,
        trailer: MovieTrailer? = nil,
        oscarAwards: OscarAwards? = nil,
        isRewatched: Bool = false,
        isListened: Bool = false,
        isSaved: Bool = false,
        lastUpdated: Date = Date(),
        cloudKitRecordID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbId = tmdbId
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.mpaaRating = mpaaRating
        self.isRewatched = isRewatched
        self.isListened = isListened
        self.isSaved = isSaved
        self.lastUpdated = lastUpdated
        self.cloudKitRecordID = cloudKitRecordID
        
        // Initializing Data properties directly to avoid MainActor isolation issues
        // The helper methods are MainActor-isolated but so is init since MovieModel is @Model
        
        if !genres.isEmpty {
            self.genresData = try? JSONEncoder().encode(genres)
        }
        
        if !streamingServices.isEmpty {
            self.streamingServicesData = try? JSONEncoder().encode(streamingServices)
        }
        
        if let episode = podcastEpisode {
            self.podcastEpisodeData = try? encodePodcastEpisode(episode)
        }
        
        if let credits = credits {
            self.creditsData = try? encodeCredits(credits)
        }
        
        if let discussion = rewatchablesDiscussion {
            self.rewatchablesDiscussionData = try? encodeRewatchablesDiscussion(discussion)
        }
        
        if let trailer = trailer {
            self.trailerData = try? encodeTrailer(trailer)
        }
        
        if let oscarAwards = oscarAwards {
            self.oscarAwardsData = try? encodeOscarAwards(oscarAwards)
        }
    }
    
    var genres: [String] {
        get {
            guard let data = genresData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            genresData = !newValue.isEmpty ? (try? JSONEncoder().encode(newValue)) : nil
        }
    }
    
    var streamingServices: [StreamingService] {
        get {
            guard let data = streamingServicesData else { return [] }
            return (try? JSONDecoder().decode([StreamingService].self, from: data)) ?? []
        }
        set {
            streamingServicesData = !newValue.isEmpty ? (try? JSONEncoder().encode(newValue)) : nil
        }
    }
    
    var podcastEpisode: PodcastEpisode? {
        get {
            guard let data = podcastEpisodeData else { return nil }
            return try? decodePodcastEpisode(from: data)
        }
        set {
            podcastEpisodeData = newValue != nil ? (try? encodePodcastEpisode(newValue!)) : nil
        }
    }
    
    var credits: MovieCredits? {
        get {
            guard let data = creditsData else { return nil }
            return try? decodeCredits(from: data)
        }
        set {
            creditsData = newValue != nil ? (try? encodeCredits(newValue!)) : nil
        }
    }
    
    var rewatchablesDiscussion: RewatchablesDiscussion? {
        get {
            guard let data = rewatchablesDiscussionData else { return nil }
            return try? decodeRewatchablesDiscussion(from: data)
        }
        set {
            rewatchablesDiscussionData = newValue != nil ? (try? encodeRewatchablesDiscussion(newValue!)) : nil
        }
    }
    
    var trailer: MovieTrailer? {
        get {
            guard let data = trailerData else { return nil }
            return try? decodeTrailer(from: data)
        }
        set {
            trailerData = newValue != nil ? (try? encodeTrailer(newValue!)) : nil
        }
    }
    
    var oscarAwards: OscarAwards? {
        get {
            guard let data = oscarAwardsData else { return nil }
            return try? decodeOscarAwards(from: data)
        }
        set {
            oscarAwardsData = newValue != nil ? (try? encodeOscarAwards(newValue!)) : nil
        }
    }
    
    // Encoding/decoding helpers
    // Moved to MovieDataHelper to avoid actor isolation issues
    
    func toMovie() -> Movie {
        // Clean title when converting to Movie
        let cleanedTitle = TitleCleaner.shared.cleanTitle(title)
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
            isRewatched: isRewatched,
            isListened: isListened,
            isSaved: isSaved,
            lastUpdated: lastUpdated
        )
    }
    
    static func fromMovie(_ movie: Movie, cloudKitRecordID: String? = nil) -> MovieModel {
        MovieModel(
            id: movie.id,
            title: movie.title,
            year: movie.year,
            tmdbId: movie.tmdbId,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            overview: movie.overview,
            mpaaRating: movie.mpaaRating,
            genres: movie.genres, // Will be encoded to genresData in init
            streamingServices: movie.streamingServices,
            podcastEpisode: movie.podcastEpisode,
            credits: movie.credits,
            rewatchablesDiscussion: movie.rewatchablesDiscussion,
            trailer: movie.trailer,
            oscarAwards: movie.oscarAwards,
            isRewatched: movie.isRewatched,
            isListened: movie.isListened,
            isSaved: movie.isSaved,
            lastUpdated: movie.lastUpdated,
            cloudKitRecordID: cloudKitRecordID
        )
    }
}

// Helper for encoding/decoding that avoids actor isolation issues
// Not needed anymore since we're encoding directly, but kept commented out for reference or future use if needed
/*
@MainActor
enum MovieDataHelper {
    static func encode<T: Encodable & Sendable>(_ value: T) -> Data? {
        return try? JSONEncoder().encode(value)
    }
    
    static func decode<T: Decodable & Sendable>(_ type: T.Type, from data: Data) -> T? {
        return try? JSONDecoder().decode(type, from: data)
    }
}
*/

// MARK: - Nonisolated Encoding/Decoding Helpers

extension MovieModel {
    nonisolated private static func encodePodcastEpisode(_ episode: PodcastEpisode) throws -> Data {
        return try JSONEncoder().encode(episode)
    }
    
    nonisolated private static func decodePodcastEpisode(from data: Data) throws -> PodcastEpisode {
        return try JSONDecoder().decode(PodcastEpisode.self, from: data)
    }
    
    nonisolated private static func encodeCredits(_ credits: MovieCredits) throws -> Data {
        return try JSONEncoder().encode(credits)
    }
    
    nonisolated private static func decodeCredits(from data: Data) throws -> MovieCredits {
        return try JSONDecoder().decode(MovieCredits.self, from: data)
    }
    
    nonisolated private static func encodeRewatchablesDiscussion(_ discussion: RewatchablesDiscussion) throws -> Data {
        return try JSONEncoder().encode(discussion)
    }
    
    nonisolated private static func decodeRewatchablesDiscussion(from data: Data) throws -> RewatchablesDiscussion {
        return try JSONDecoder().decode(RewatchablesDiscussion.self, from: data)
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
    
    private func encodePodcastEpisode(_ episode: PodcastEpisode) throws -> Data {
        return try Self.encodePodcastEpisode(episode)
    }
    
    private func decodePodcastEpisode(from data: Data) throws -> PodcastEpisode {
        return try Self.decodePodcastEpisode(from: data)
    }
    
    private func encodeCredits(_ credits: MovieCredits) throws -> Data {
        return try Self.encodeCredits(credits)
    }
    
    private func decodeCredits(from data: Data) throws -> MovieCredits {
        return try Self.decodeCredits(from: data)
    }
    
    private func encodeRewatchablesDiscussion(_ discussion: RewatchablesDiscussion) throws -> Data {
        return try Self.encodeRewatchablesDiscussion(discussion)
    }
    
    private func decodeRewatchablesDiscussion(from data: Data) throws -> RewatchablesDiscussion {
        return try Self.decodeRewatchablesDiscussion(from: data)
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
}
