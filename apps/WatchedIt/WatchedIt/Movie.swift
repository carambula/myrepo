//
//  Movie.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import CloudKit

public struct Movie: Identifiable, Codable, Hashable {
    public let id: String
    public let title: String
    public let year: Int?
    public let tmdbId: Int?
    public let posterPath: String?
    public let backdropPath: String?
    public let overview: String?
    public let mpaaRating: String? // MPAA rating (G, PG, PG-13, R, NC-17, etc.)
    public let genres: [String] // Movie genres/categories
    public let streamingServices: [StreamingService]
    public let podcastEpisode: PodcastEpisode?
    public let credits: MovieCredits?
    public var rewatchablesDiscussion: RewatchablesDiscussion?
    public let trailer: MovieTrailer?
    public let oscarAwards: OscarAwards?
    public let physicalMedia: PhysicalMedia?
    public var isRewatched: Bool
    public var isListened: Bool
    public var isSaved: Bool
    public let lastUpdated: Date
    
    public init(
        id: String = UUID().uuidString,
        title: String,
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
        physicalMedia: PhysicalMedia? = nil,
        isRewatched: Bool = false,
        isListened: Bool = false,
        isSaved: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.tmdbId = tmdbId
        self.posterPath = posterPath
        self.backdropPath = backdropPath
        self.overview = overview
        self.mpaaRating = mpaaRating
        self.genres = genres
        self.streamingServices = streamingServices
        self.podcastEpisode = podcastEpisode
        self.credits = credits
        self.rewatchablesDiscussion = rewatchablesDiscussion
        self.trailer = trailer
        self.oscarAwards = oscarAwards
        self.physicalMedia = physicalMedia
        self.isRewatched = isRewatched
        self.isListened = isListened
        self.isSaved = isSaved
        self.lastUpdated = lastUpdated
    }

    /// Newest-first lists use episode date when the catalog/RSS link has one,
    /// otherwise the row's lastUpdated so admin additions are not buried.
    public var episodeSortDate: Date {
        podcastEpisode?.publishDate ?? lastUpdated
    }
    
    public static func == (lhs: Movie, rhs: Movie) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    /// Generates a deterministic ID for a movie based on TMDB ID or episode ID
    /// This ensures the same movie always gets the same ID, preventing duplicates
    public static func idFromEpisode(episodeId: String, tmdbId: Int?) -> String {
        if let tmdbId = tmdbId {
            return "tmdb-\(tmdbId)"
        }
        // Fallback to episode-based ID if no TMDB ID
        return "episode-\(episodeId)"
    }
}

public struct StreamingService: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let logoPath: String?
    public let url: String?
    
    public init(id: String, name: String, logoPath: String? = nil, url: String? = nil) {
        self.id = id
        self.name = name
        self.logoPath = logoPath
        self.url = url
    }
}

public struct PodcastEpisode: Codable, Hashable, Sendable {
    public let title: String
    public let episodeId: String
    public let publishDate: Date?
    public let description: String?
    public let applePodcastsUrl: String?
    public let spotifyUrl: String?
    public let overcastUrl: String?
    public let pocketCastsUrl: String?
    
    public init(
        title: String,
        episodeId: String,
        publishDate: Date? = nil,
        description: String? = nil,
        applePodcastsUrl: String? = nil,
        spotifyUrl: String? = nil,
        overcastUrl: String? = nil,
        pocketCastsUrl: String? = nil
    ) {
        self.title = title
        self.episodeId = episodeId
        self.publishDate = publishDate
        self.description = description
        self.applePodcastsUrl = applePodcastsUrl
        self.spotifyUrl = spotifyUrl
        self.overcastUrl = overcastUrl
        self.pocketCastsUrl = pocketCastsUrl
    }
}

public struct MovieCredits: Codable, Hashable, Sendable {
    public let director: String?
    public let cast: [CastMember]
    
    public init(director: String? = nil, cast: [CastMember] = []) {
        self.director = director
        self.cast = cast
    }
}

public struct CastMember: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let character: String?
    public let profilePath: String?
    
    public init(id: Int, name: String, character: String? = nil, profilePath: String? = nil) {
        self.id = id
        self.name = name
        self.character = character
        self.profilePath = profilePath
    }
}

public struct MovieTrailer: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let youtubeKey: String
    public let isOfficial: Bool
    
    public var youtubeURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(youtubeKey)")
    }

    public var youtubeAppURL: URL? {
        URL(string: "youtube://www.youtube.com/watch?v=\(youtubeKey)")
    }
    
    public var embedURL: URL? {
        URL(string: "https://www.youtube.com/embed/\(youtubeKey)?playsinline=1")
    }
}

// CloudKit Record Extension
extension Movie {
    init?(from record: CKRecord) {
        guard let title = record["title"] as? String else { return nil }
        
        let id = record.recordID.recordName
        let year = record["year"] as? Int
        let tmdbId = record["tmdbId"] as? Int
        let posterPath = record["posterPath"] as? String
        let backdropPath = record["backdropPath"] as? String
        let overview = record["overview"] as? String
        let mpaaRating = record["mpaaRating"] as? String
        let isRewatched = false
        let isListened = false
        let isSaved = false
        let lastUpdated = record.modificationDate ?? record.creationDate ?? Date()
        
        // Decode genres
        var genres: [String] = []
        if let genresArray = record["genres"] as? [String] {
            genres = genresArray
        }
        
        // Decode streaming services
        var streamingServices: [StreamingService] = []
        if let servicesData = record["streamingServices"] as? Data,
           let services = try? JSONDecoder().decode([StreamingService].self, from: servicesData) {
            streamingServices = services
        }
        
        // Decode podcast episode
        var podcastEpisode: PodcastEpisode? = nil
        if let episodeData = record["podcastEpisode"] as? Data,
           let episode = try? JSONDecoder().decode(PodcastEpisode.self, from: episodeData) {
            podcastEpisode = episode
        }
        
        // Decode credits
        var credits: MovieCredits? = nil
        if let creditsData = record["credits"] as? Data,
           let decodedCredits = try? JSONDecoder().decode(MovieCredits.self, from: creditsData) {
            credits = decodedCredits
        }
        
        // Decode rewatchables discussion
        var rewatchablesDiscussion: RewatchablesDiscussion? = nil
        if let discussionData = record["rewatchablesDiscussion"] as? Data,
           let discussion = try? JSONDecoder().decode(RewatchablesDiscussion.self, from: discussionData) {
            rewatchablesDiscussion = discussion
        }
        
        // Decode trailer
        var trailer: MovieTrailer? = nil
        if let trailerData = record["trailer"] as? Data,
           let decodedTrailer = try? JSONDecoder().decode(MovieTrailer.self, from: trailerData) {
            trailer = decodedTrailer
        }
        
        // Decode Oscar awards
        var oscarAwards: OscarAwards? = nil
        if let awardsData = record["oscarAwards"] as? Data,
           let decodedAwards = try? JSONDecoder().decode(OscarAwards.self, from: awardsData) {
            oscarAwards = decodedAwards
        }

        var physicalMedia: PhysicalMedia? = nil
        if let mediaData = record["physicalMedia"] as? Data,
           let decodedMedia = try? JSONDecoder().decode(PhysicalMedia.self, from: mediaData) {
            physicalMedia = decodedMedia
        }
        
        self.init(
            id: id,
            title: title,
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
            physicalMedia: physicalMedia,
            isRewatched: isRewatched,
            isListened: isListened,
            isSaved: isSaved,
            lastUpdated: lastUpdated
        )
    }
    
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: id)
        let record = CKRecord(recordType: "Movie", recordID: recordID)
        
        record["title"] = title
        record["year"] = year
        record["tmdbId"] = tmdbId
        record["posterPath"] = posterPath
        record["backdropPath"] = backdropPath
        record["overview"] = overview
        record["mpaaRating"] = mpaaRating
        record["genres"] = genres
        record["isRewatched"] = isRewatched
        record["isListened"] = isListened
        record["isSaved"] = isSaved
        record["lastUpdated"] = lastUpdated
        
        // Encode rewatchables discussion
        if let discussion = rewatchablesDiscussion,
           let discussionData = try? JSONEncoder().encode(discussion) {
            record["rewatchablesDiscussion"] = discussionData
        }
        
        // Encode streaming services
        if let servicesData = try? JSONEncoder().encode(streamingServices) {
            record["streamingServices"] = servicesData
        }
        
        // Encode podcast episode
        if let episode = podcastEpisode,
           let episodeData = try? JSONEncoder().encode(episode) {
            record["podcastEpisode"] = episodeData
        }
        
        // Encode credits
        if let credits = credits,
           let creditsData = try? JSONEncoder().encode(credits) {
            record["credits"] = creditsData
        }
        
        // Encode trailer
        if let trailer = trailer,
           let trailerData = try? JSONEncoder().encode(trailer) {
            record["trailer"] = trailerData
        }
        
        // Encode Oscar awards
        if let oscarAwards = oscarAwards,
           let awardsData = try? JSONEncoder().encode(oscarAwards) {
            record["oscarAwards"] = awardsData
        }

        if let physicalMedia = physicalMedia,
           let mediaData = try? JSONEncoder().encode(physicalMedia) {
            record["physicalMedia"] = mediaData
        }
        
        return record
    }
}

