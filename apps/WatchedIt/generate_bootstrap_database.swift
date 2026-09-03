#!/usr/bin/env swift

//
//  generate_bootstrap_database.swift
//  Generates a pre-populated SwiftData database from bootstrap_data.json
//
//  Usage: swift generate_bootstrap_database.swift
//
//  Note: This script must be run from the project root directory
//

import Foundation
import SQLite3
import SwiftData

// This script needs to be run as a standalone Swift script
// It will create a pre-populated SwiftData database that can be bundled with the app

// MARK: - Data Structures (matching BootstrapDataService)

struct BootstrapDataSource: Codable {
    let identifier: String
    let name: String
    let type: String
    let url: String?
    let isRankedList: Bool
    let movieCount: Int
}

struct BootstrapOscarWin: Codable {
    let id: String
    let category: String
    let year: Int?
    let recipient: String?
}

struct BootstrapOscarNomination: Codable {
    let id: String
    let category: String
    let year: Int?
    let nominee: String?
}

struct BootstrapOscarAwards: Codable {
    let wins: [BootstrapOscarWin]?
    let nominations: [BootstrapOscarNomination]?
    let totalWins: Int
    let totalNominations: Int
    let rawAwardsText: String?
}

struct BootstrapPhysicalEdition: Codable {
    let id: String?
    let label: String
    let format: String
    let spineNumber: String?
    let notes: String?
}

struct BootstrapPhysicalMedia: Codable {
    let editions: [BootstrapPhysicalEdition]?
    let hasCriterion: Bool?
    let has4K: Bool?
    let hasBluRay: Bool?
    let manualOverride: Bool?
}

struct PhysicalMediaOverlayFile: Codable {
    let byTmdbId: [String: BootstrapPhysicalMedia]
}

struct BootstrapMovie: Codable {
    var title: String
    let sourceIdentifier: String
    let rank: Int?
    let sourceTitle: String?
    let episodeDate: String?
    
    // Enriched fields
    let tmdbId: Int?
    let year: Int?
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let mpaaRating: String?
    let genres: [String]?
    let streamingServices: [BootstrapStreamingService]?
    let credits: BootstrapCredits?
    let trailer: BootstrapTrailer?
    let podcastEpisodeDescription: String?
    let oscarAwards: BootstrapOscarAwards?
    let physicalMedia: BootstrapPhysicalMedia?
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
    let movies: [BootstrapMovie]
}

// MARK: - Models (simplified versions matching MovieDataModel)

@Model
final class MovieData {
    var id: String
    var title: String
    var year: Int?
    var tmdbId: Int?
    var imdbId: String?
    var originalTitle: String?
    var releaseDate: Date?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var tagline: String?
    var mpaaRating: String?
    var runtime: Int?
    var genresData: Data?
    var streamingServicesData: Data?
    var creditsData: Data?
    var trailerData: Data?
    var oscarAwardsData: Data?
    var physicalMediaData: Data?
    var keywordsData: Data?
    var lastUpdated: Date
    var createdAt: Date
    var cloudKitRecordID: String?
    
    @Relationship(deleteRule: .cascade, inverse: \MovieState.movie)
    var states: [MovieState]?

    @Relationship(deleteRule: .cascade, inverse: \MovieDataSource.movie)
    var dataSources: [MovieDataSource]?

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
        oscarAwards: BootstrapOscarAwards? = nil,
        physicalMedia: BootstrapPhysicalMedia? = nil,
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
        
        if !genres.isEmpty {
            self.genresData = try? JSONEncoder().encode(genres)
        }
        
        if !streamingServices.isEmpty {
            self.streamingServicesData = try? JSONEncoder().encode(streamingServices)
        }
        
        if let credits = credits {
            self.creditsData = try? JSONEncoder().encode(credits)
        }
        
        if let trailer = trailer {
            self.trailerData = try? JSONEncoder().encode(trailer)
        }

        if let oscarAwards = oscarAwards {
            self.oscarAwardsData = try? JSONEncoder().encode(oscarAwards)
        }

        if let physicalMedia = physicalMedia {
            self.physicalMediaData = try? JSONEncoder().encode(physicalMedia)
        }

        if !keywords.isEmpty {
            self.keywordsData = try? JSONEncoder().encode(keywords)
        }
    }

    var keywords: [String] {
        get {
            guard let data = keywordsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            keywordsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var genres: [String] {
        get {
            guard let data = genresData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            genresData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var streamingServices: [StreamingService] {
        get {
            guard let data = streamingServicesData else { return [] }
            return (try? JSONDecoder().decode([StreamingService].self, from: data)) ?? []
        }
        set {
            streamingServicesData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var credits: MovieCredits? {
        get {
            guard let data = creditsData else { return nil }
            return try? JSONDecoder().decode(MovieCredits.self, from: data)
        }
        set {
            creditsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    var trailer: MovieTrailer? {
        get {
            guard let data = trailerData else { return nil }
            return try? JSONDecoder().decode(MovieTrailer.self, from: data)
        }
        set {
            trailerData = try? JSONEncoder().encode(newValue)
        }
    }
}

@Model
final class DataSource {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isEnabled: Bool
    var lastUpdated: Date
    var lastChecked: Date?
    var createdAt: Date
    var isRankedList: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \MovieDataSource.dataSource)
    var movieDataSources: [MovieDataSource]?

    @Relationship(deleteRule: .cascade, inverse: \SourceContent.source)
    var sourceContents: [SourceContent]?
    
    init(
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
}

@Model
final class MovieDataSource {
    var lastUpdated: Date
    var podcastEpisodeData: Data?
    var rewatchablesDiscussionData: Data?
    var sourceUrl: String?
    var sourceTitle: String?
    var rank: Int?
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
        self.podcastEpisodeData = nil
        self.rewatchablesDiscussionData = nil
    }
}

@Model
final class MovieModel {
    var id: String
    var title: String
    var year: Int?
    var tmdbId: Int?
    var posterPath: String?
    var backdropPath: String?
    var overview: String?
    var mpaaRating: String?
    var genresData: Data?
    var streamingServicesData: Data?
    var podcastEpisodeData: Data?
    var creditsData: Data?
    var rewatchablesDiscussionData: Data?
    var trailerData: Data?
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
        genresData: Data? = nil,
        streamingServicesData: Data? = nil,
        podcastEpisodeData: Data? = nil,
        creditsData: Data? = nil,
        rewatchablesDiscussionData: Data? = nil,
        trailerData: Data? = nil,
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
        self.genresData = genresData
        self.streamingServicesData = streamingServicesData
        self.podcastEpisodeData = podcastEpisodeData
        self.creditsData = creditsData
        self.rewatchablesDiscussionData = rewatchablesDiscussionData
        self.trailerData = trailerData
        self.isRewatched = isRewatched
        self.isListened = isListened
        self.isSaved = isSaved
        self.lastUpdated = lastUpdated
        self.cloudKitRecordID = cloudKitRecordID
    }
}

@Model
final class MovieState {
    var isRewatched: Bool = false
    var isListened: Bool = false
    var isSaved: Bool = false
    var lastUpdated: Date
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

@Model
final class UserMovieData {
    var movie: MovieData?
    var isSaved: Bool = false
    var isRewatched: Bool = false
    var isListened: Bool = false
    var isWatched: Bool = false
    var userRating: Int?
    var userNotes: String?
    var watchedDate: Date?
    var rewatchedDate: Date?
    var listenedDate: Date?
    var tagsData: Data?
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
        tagsData: Data? = nil,
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
        self.tagsData = tagsData
        self.lastUpdated = lastUpdated
        self.createdAt = createdAt
    }
}

@Model
final class BootstrapVersion {
    var version: String
    var buildNumber: Int
    var appliedDate: Date
    var sourceCount: Int
    var movieCount: Int
    var checksum: String?
    
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

@Model
final class SourceContent {
    var movie: MovieData?
    var source: DataSource?
    var sourceTitle: String?
    var sourceDescription: String?
    var sourceDate: Date?
    var rank: Int?
    var podcastEpisodeData: Data?
    var rewatchablesDiscussionData: Data?
    var listEntryData: Data?
    var sourceUrl: String?
    var applePodcastsUrl: String?
    var spotifyUrl: String?
    var lastUpdated: Date
    var discoveredAt: Date
    
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

// MARK: - Supporting Types

struct StreamingService: Codable {
    let id: String
    let name: String
    let logoPath: String?
    let url: String?
}

struct MovieCredits: Codable {
    let director: String?
    let cast: [CastMember]
}

struct CastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
}

struct MovieTrailer: Codable {
    let id: String
    let name: String
    let youtubeKey: String
    let isOfficial: Bool
}

// Podcast episode structure (matching Movie.swift)
struct PodcastEpisode: Codable {
    let title: String
    let episodeId: String
    let publishDate: Date?
    let description: String?
    let applePodcastsUrl: String?
    let spotifyUrl: String?
    let overcastUrl: String?
    let pocketCastsUrl: String?
    
    init(
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

struct RewatchablesDiscussion: Codable {}

// MARK: - Title Cleaning

/// Cleans movie titles by removing list numbering, quotes, and other extraneous characters
func cleanTitle(_ title: String) -> String {
    var cleaned = title
    
    // Remove list numbering patterns at the start (e.g., "7. ", "#2 ", "1: ")
    // Only remove if it has punctuation - preserve numbers that are part of title
    let listNumberingPatterns = [
        #"^(\d+)\.\s+"#,           // "7. "
        #"^#(\d+)\s+"#,            // "#2 "
        #"^(\d+)\)\s+"#,           // "2) "
        #"^\((\d+)\)\s+"#,         // "(2) "
        #"^(\d+)[:–\-]\s+"#,      // "1: " or "1 - "
    ]
    
    for pattern in listNumberingPatterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
            if match.numberOfRanges > 1,
               let numberRange = Range(match.range(at: 1), in: cleaned),
               let number = Int(String(cleaned[numberRange])),
               number <= 999 {
                // This is list numbering - remove it
                if let fullRange = Range(match.range, in: cleaned) {
                    cleaned = String(cleaned[fullRange.upperBound...])
                    cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }
    }
    
    // Remove leading/trailing quotes (but preserve apostrophes in contractions)
    let quoteChars: [Character] = ["'", "'", "'", "'", "\"", "\"", "\"", "\""]
    
    // Remove leading quotes
    while !cleaned.isEmpty, let first = cleaned.first, quoteChars.contains(first) {
        cleaned = String(cleaned.dropFirst())
    }
    
    // Remove trailing quotes
    while !cleaned.isEmpty, let last = cleaned.last, quoteChars.contains(last) {
        cleaned = String(cleaned.dropLast())
    }
    
    // Remove quotes that wrap entire phrases
    let wrappedQuotePattern = #"^["'""'`´](.*)["'""'`´]$"#
    if let regex = try? NSRegularExpression(pattern: wrappedQuotePattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
       match.numberOfRanges > 1,
       let contentRange = Range(match.range(at: 1), in: cleaned) {
        cleaned = String(cleaned[contentRange])
    }
    
    // Remove "Live From [Location]" patterns
    let liveFromPattern = #"(?i)\s*(?:LIVE|Live)\s+From\s+[A-Za-z\s]+"#
    if let regex = try? NSRegularExpression(pattern: liveFromPattern) {
        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
        if let match = regex.firstMatch(in: cleaned, range: nsRange) {
            if let range = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[..<range.lowerBound]) + String(cleaned[range.upperBound...])
            }
        }
    }
    
    // Remove trailing year markers from podcast/list entries (e.g. "The Cable Guy (1996)").
    cleaned = cleaned.replacingOccurrences(
        of: #"\s*[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$"#,
        with: "",
        options: .regularExpression
    )
    
    // Remove leading/trailing commas and spaces
    cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
    
    // Remove multiple consecutive spaces
    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }
    
    // Final trim
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return cleaned
}

// MARK: - SQLite Helpers

private func finalizeSQLiteStore(at url: URL) {
    var db: OpaquePointer?
    guard sqlite3_open(url.path, &db) == SQLITE_OK else {
        print("⚠️ Could not open SQLite store for finalization: \(url.lastPathComponent)")
        return
    }
    defer { sqlite3_close(db) }
    
    let statements = [
        "PRAGMA wal_checkpoint(TRUNCATE);",
        "PRAGMA journal_mode=DELETE;"
    ]
    
    for sql in statements {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let error = String(cString: sqlite3_errmsg(db))
            print("⚠️ SQLite finalize failed: \(sql) -> \(error)")
        }
    }
}

private func removeSidecarFiles(for storeURL: URL) {
    let walURL = storeURL.appendingPathExtension("wal")
    let shmURL = storeURL.appendingPathExtension("shm")
    try? FileManager.default.removeItem(at: walURL)
    try? FileManager.default.removeItem(at: shmURL)
}

/// Extracts better title from podcast episode titles
func extractBetterTitle(from sourceTitle: String) -> String? {
    func normalizePodcastCandidate(_ raw: String) -> String {
        var value = cleanTitle(raw)
        value = value.replacingOccurrences(
            of: #"\s*[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$"#,
            with: "",
            options: .regularExpression
        )
        value = value.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // First try basic cleaning
    let cleaned = normalizePodcastCandidate(sourceTitle)
    
    // Try to extract from quotes
    let quotePatterns = [
        #"'([^']+)'"#,
        #""([^"]+)""#,
    ]
    
    for pattern in quotePatterns {
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1,
           let titleRange = Range(match.range(at: 1), in: cleaned) {
            let extracted = normalizePodcastCandidate(String(cleaned[titleRange]))
            if extracted.count > 3 && extracted.count < 60 && !extracted.contains(" with ") {
                return extracted
            }
        }
    }
    
    // Try to extract before "With" or " - "
    let separators = [" With ", " with ", " WITH ", " - ", " – ", " — "]
    for separator in separators {
        if let range = cleaned.range(of: separator, options: .caseInsensitive) {
            let beforeSeparator = String(cleaned[..<range.lowerBound])
            if beforeSeparator.count > 3 && beforeSeparator.count < 60 {
                return normalizePodcastCandidate(beforeSeparator)
            }
        }
    }
    
    // If cleaned title is reasonable, return it
    if cleaned.count > 3 && cleaned.count < 60 && !cleaned.contains(" with ") {
        return cleaned
    }
    
    return nil
}

// MARK: - Bootstrap Movie Merge Helpers

func movieScore(_ movie: BootstrapMovie) -> Int {
    var score = 0
    if movie.posterPath != nil { score += 2 }
    if movie.backdropPath != nil { score += 1 }
    if let overview = movie.overview, !overview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 2 }
    if movie.mpaaRating != nil { score += 1 }
    score += min(movie.genres?.count ?? 0, 4)
    score += min(movie.streamingServices?.count ?? 0, 4)
    if let credits = movie.credits {
        if let director = credits.director, !director.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 2
        }
        score += min(credits.cast?.count ?? 0, 4)
    }
    if movie.trailer != nil { score += 1 }
    return score
}

func firstNonEmptyString(_ values: [String?]) -> String? {
    for value in values {
        guard let value else { continue }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return nil
}

func bestOverview(from movies: [BootstrapMovie]) -> String? {
    movies
        .compactMap { $0.overview?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .max(by: { $0.count < $1.count })
}

func bestGenres(from movies: [BootstrapMovie]) -> [String]? {
    movies
        .compactMap { $0.genres }
        .max(by: { $0.count < $1.count })
}

func bestStreamingServices(from movies: [BootstrapMovie]) -> [BootstrapStreamingService]? {
    movies
        .compactMap { $0.streamingServices }
        .max(by: { $0.count < $1.count })
}

func bestCredits(from movies: [BootstrapMovie]) -> BootstrapCredits? {
    let candidates = movies.compactMap { $0.credits }
    return candidates.max(by: { left, right in
        let leftScore = (left.director?.isEmpty == false ? 2 : 0) + (left.cast?.count ?? 0)
        let rightScore = (right.director?.isEmpty == false ? 2 : 0) + (right.cast?.count ?? 0)
        return leftScore < rightScore
    })
}

func bestTrailer(from movies: [BootstrapMovie]) -> BootstrapTrailer? {
    if let official = movies.compactMap({ $0.trailer }).first(where: { $0.isOfficial }) {
        return official
    }
    return movies.compactMap { $0.trailer }.first
}

func bestOscarAwards(from movies: [BootstrapMovie]) -> BootstrapOscarAwards? {
    movies
        .compactMap { $0.oscarAwards }
        .max(by: { ($0.totalWins + $0.totalNominations) < ($1.totalWins + $1.totalNominations) })
}

func bestPhysicalMedia(from movies: [BootstrapMovie]) -> BootstrapPhysicalMedia? {
    movies.compactMap { $0.physicalMedia }.max(by: { lhs, rhs in
        let leftScore = (lhs.hasCriterion == true ? 2 : 0) + (lhs.has4K == true ? 2 : 0) + (lhs.editions?.count ?? 0)
        let rightScore = (rhs.hasCriterion == true ? 2 : 0) + (rhs.has4K == true ? 2 : 0) + (rhs.editions?.count ?? 0)
        return leftScore < rightScore
    })
}

func overlayPhysicalMedia(tmdbId: Int?, stored: BootstrapPhysicalMedia?) -> BootstrapPhysicalMedia? {
    guard let tmdbId, let overlay = physicalMediaOverlayByTmdbId[String(tmdbId)] else {
        return stored
    }
    if stored?.manualOverride == true {
        return stored
    }
    return BootstrapPhysicalMedia(
        editions: {
            let storedEditions = stored?.editions ?? []
            let overlayEditions = overlay.editions ?? []
            return storedEditions.isEmpty ? overlayEditions : storedEditions + overlayEditions
        }(),
        hasCriterion: (stored?.hasCriterion == true) || (overlay.hasCriterion == true),
        has4K: (stored?.has4K == true) || (overlay.has4K == true),
        hasBluRay: (stored?.hasBluRay == true) || (overlay.hasBluRay == true),
        manualOverride: stored?.manualOverride == true
    )
}

var physicalMediaOverlayByTmdbId: [String: BootstrapPhysicalMedia] = [:]

func loadPhysicalMediaOverlay() {
    let urls = [
        URL(fileURLWithPath: "WatchedIt/physical_media.json"),
        URL(fileURLWithPath: "physical_media.json")
    ]
    for url in urls {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PhysicalMediaOverlayFile.self, from: data) else {
            continue
        }
        physicalMediaOverlayByTmdbId = file.byTmdbId
        print("📀 Loaded physical media overlay (\(file.byTmdbId.count) titles)")
        return
    }
}

private func parseEpisodeDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.date(from: value)
}

private func bootstrapMovieMatchKey(
    _ movie: BootstrapMovie,
    includeYear: Bool,
    includeSourceTitle: Bool
) -> String {
    let titleKey = cleanTitle(movie.title).lowercased()
    let sourceTitleKey = includeSourceTitle ? cleanTitle(movie.sourceTitle ?? "").lowercased() : ""
    let yearKey = includeYear ? (movie.year.map(String.init) ?? "") : ""
    let rankKey = movie.rank.map(String.init) ?? ""
    return [movie.sourceIdentifier, yearKey, rankKey, titleKey, sourceTitleKey].joined(separator: "|")
}

private func mergeBootstrapMovie(base: BootstrapMovie, enriched: BootstrapMovie) -> BootstrapMovie {
    let hasStreaming = (base.streamingServices?.isEmpty == false)
    return BootstrapMovie(
        title: base.title,
        sourceIdentifier: base.sourceIdentifier,
        rank: base.rank,
        sourceTitle: base.sourceTitle,
        episodeDate: base.episodeDate,
        tmdbId: base.tmdbId ?? enriched.tmdbId,
        year: base.year ?? enriched.year,
        posterPath: base.posterPath ?? enriched.posterPath,
        backdropPath: base.backdropPath ?? enriched.backdropPath,
        overview: base.overview ?? enriched.overview,
        mpaaRating: base.mpaaRating ?? enriched.mpaaRating,
        genres: (base.genres?.isEmpty == false) ? base.genres : enriched.genres,
        streamingServices: hasStreaming ? base.streamingServices : enriched.streamingServices,
        credits: base.credits ?? enriched.credits,
        trailer: base.trailer ?? enriched.trailer,
        podcastEpisodeDescription: base.podcastEpisodeDescription ?? enriched.podcastEpisodeDescription,
        oscarAwards: base.oscarAwards ?? enriched.oscarAwards,
        physicalMedia: base.physicalMedia ?? enriched.physicalMedia
    )
}

private func mergeBootstrapData(base: BootstrapData, enriched: BootstrapData?) -> BootstrapData {
    guard let enriched else {
        return base
    }
    
    var enrichedByTmdbId: [Int: [BootstrapMovie]] = [:]
    var enrichedByKey: [String: [BootstrapMovie]] = [:]
    var enrichedByKeyNoYear: [String: [BootstrapMovie]] = [:]
    
    for movie in enriched.movies {
        if let tmdbId = movie.tmdbId {
            enrichedByTmdbId[tmdbId, default: []].append(movie)
        }
        let key = bootstrapMovieMatchKey(movie, includeYear: true, includeSourceTitle: true)
        enrichedByKey[key, default: []].append(movie)
        let keyNoYear = bootstrapMovieMatchKey(movie, includeYear: false, includeSourceTitle: true)
        enrichedByKeyNoYear[keyNoYear, default: []].append(movie)
    }
    
    func bestMatch(from candidates: [BootstrapMovie]) -> BootstrapMovie {
        candidates.max(by: { movieScore($0) < movieScore($1) }) ?? candidates[0]
    }
    
    let mergedMovies = base.movies.map { baseMovie in
        if let tmdbId = baseMovie.tmdbId,
           let candidates = enrichedByTmdbId[tmdbId],
           !candidates.isEmpty {
            return mergeBootstrapMovie(base: baseMovie, enriched: bestMatch(from: candidates))
        }
        
        let key = bootstrapMovieMatchKey(baseMovie, includeYear: true, includeSourceTitle: true)
        if let candidates = enrichedByKey[key], !candidates.isEmpty {
            return mergeBootstrapMovie(base: baseMovie, enriched: bestMatch(from: candidates))
        }
        
        let keyNoYear = bootstrapMovieMatchKey(baseMovie, includeYear: false, includeSourceTitle: true)
        if let candidates = enrichedByKeyNoYear[keyNoYear], !candidates.isEmpty {
            return mergeBootstrapMovie(base: baseMovie, enriched: bestMatch(from: candidates))
        }
        
        return baseMovie
    }
    
    return BootstrapData(
        version: base.version ?? enriched.version,
        generatedDate: base.generatedDate ?? enriched.generatedDate,
        dataSources: base.dataSources,
        movies: mergedMovies
    )
}

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

// MARK: - Main Script

@MainActor
func generateBootstrapDatabase() async throws {
    print("📦 Generating pre-populated SwiftData database...")
    
    // Prefer a just-pulled Min Cloud catalog when present.
    let cloudURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.cloud.json")
    let committedURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let baseURL = FileManager.default.fileExists(atPath: cloudURL.path) ? cloudURL : committedURL
    let enrichedURL = URL(fileURLWithPath: "bootstrap_data_enriched.json")
    let baseExists = FileManager.default.fileExists(atPath: baseURL.path)
    let enrichedExists = FileManager.default.fileExists(atPath: enrichedURL.path)
    guard baseExists else {
        print("❌ Error: bootstrap JSON not found at \(baseURL.path)")
        exit(1)
    }
    
    print("📂 Loading bootstrap JSON from \(baseURL.lastPathComponent)...")
    let baseData = try Data(contentsOf: baseURL)
    let baseBootstrapData = try JSONDecoder().decode(BootstrapData.self, from: baseData)
    
    var enrichedBootstrapData: BootstrapData? = nil
    if enrichedExists {
        let enrichedData = try Data(contentsOf: enrichedURL)
        enrichedBootstrapData = try JSONDecoder().decode(BootstrapData.self, from: enrichedData)
    }
    
    let bootstrapData = mergeBootstrapData(base: baseBootstrapData, enriched: enrichedBootstrapData)
    loadPhysicalMediaOverlay()
    
    print("✅ Loaded \(bootstrapData.dataSources.count) sources and \(bootstrapData.movies.count) movies")
    
    // Create temporary database
    let tempDir = FileManager.default.temporaryDirectory
    let tempDBURL = tempDir.appendingPathComponent("bootstrap_database.store")
    
    // Remove existing temp database if it exists
    if FileManager.default.fileExists(atPath: tempDBURL.path) {
        try? FileManager.default.removeItem(at: tempDBURL)
    }
    
    print("🗄️ Creating SwiftData database...")
    let schema = Schema([
        MovieModel.self,
        MovieData.self,
        MovieState.self,
        DataSource.self,
        MovieDataSource.self,
        UserMovieData.self,
        SourceContent.self,
        BootstrapVersion.self
    ])
    let config = ModelConfiguration(
        url: tempDBURL,
        allowsSave: true,
        cloudKitDatabase: .none
    )
    
    var moviesCreated = 0
    var linksCreated = 0
    var duplicatesSkipped = 0
    var dataSourceCount = 0
    
    do {
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        // Step 1: Create DataSource entries
        print("📋 Creating \(bootstrapData.dataSources.count) data sources...")
        var dataSourceMap: [String: DataSource] = [:]
        
        for bootstrapSource in bootstrapData.dataSources {
            let dataSource = DataSource(
                identifier: bootstrapSource.identifier,
                name: bootstrapSource.name,
                type: bootstrapSource.type,
                url: bootstrapSource.url,
                isEnabled: true,
                lastUpdated: Date(),
                lastChecked: nil,
                createdAt: Date(),
                isRankedList: bootstrapSource.isRankedList
            )
            context.insert(dataSource)
            dataSourceMap[bootstrapSource.identifier] = dataSource
        }
        
        try context.save()
        dataSourceCount = dataSourceMap.count
        print("✅ Created \(dataSourceMap.count) data sources")
        
        // Step 2: Deduplicate movies by TMDB ID and cleaned title
        print("🎬 Processing \(bootstrapData.movies.count) movies...")
        
        // First, clean all titles and extract better titles from podcast episode titles
        var processedMovies: [BootstrapMovie] = []
        for movie in bootstrapData.movies {
            var processedMovie = movie
            var cleanedTitle = cleanTitle(movie.title)
            
            // If title looks like a podcast episode title, try to extract better title from sourceTitle
            let hasPodcastPatterns = cleanedTitle.contains(" with ") || 
                                     cleanedTitle.contains(" With ") ||
                                     cleanedTitle.contains("Bill Simmons") ||
                                     cleanedTitle.contains("Sean Fennessey") ||
                                     cleanedTitle.contains("Juliet Litman") ||
                                     cleanedTitle.contains("Amanda Dobbins") ||
                                     cleanedTitle.contains("Katey Rich") ||
                                     cleanedTitle.count > 60
            
            if hasPodcastPatterns, let sourceTitle = movie.sourceTitle {
                // Try to extract better title from source title
                let extracted = extractBetterTitle(from: sourceTitle)
                if let betterTitle = extracted, betterTitle.count < 60 && !betterTitle.contains(" with ") {
                    cleanedTitle = betterTitle
                }
            }
            
            // Persist cleaned title so all downstream grouping/merging uses normalized values.
            processedMovie.title = cleanedTitle
            processedMovies.append(processedMovie)
        }
        
        // Group by TMDB ID (most reliable)
        var moviesByTmdbId: [Int: [BootstrapMovie]] = [:]
        var moviesWithoutTmdb: [BootstrapMovie] = []
        
        for movie in processedMovies {
            if let tmdbId = movie.tmdbId {
                if moviesByTmdbId[tmdbId] == nil {
                    moviesByTmdbId[tmdbId] = []
                }
                moviesByTmdbId[tmdbId]?.append(movie)
            } else {
                moviesWithoutTmdb.append(movie)
            }
        }
        
        // Build a title-based lookup for all movies (used for cross-source merging)
        var moviesByCleanedTitle: [String: [BootstrapMovie]] = [:]
        for movie in processedMovies {
            var cleanedTitle = cleanTitle(movie.title).lowercased()
            
            // If still has podcast patterns, try source title
            if cleanedTitle.contains(" with ") || cleanedTitle.contains("bill simmons"),
               let sourceTitle = movie.sourceTitle {
                if let extracted = extractBetterTitle(from: sourceTitle) {
                    cleanedTitle = cleanTitle(extracted).lowercased()
                }
            }
            
            if moviesByCleanedTitle[cleanedTitle] == nil {
                moviesByCleanedTitle[cleanedTitle] = []
            }
            moviesByCleanedTitle[cleanedTitle]?.append(movie)
        }

        // Build a title-based lookup only for movies without TMDB IDs
        var moviesByCleanedTitleNoTmdb: [String: [BootstrapMovie]] = [:]
        for movie in moviesWithoutTmdb {
            var cleanedTitle = cleanTitle(movie.title).lowercased()
            if cleanedTitle.contains(" with ") || cleanedTitle.contains("bill simmons"),
               let sourceTitle = movie.sourceTitle {
                if let extracted = extractBetterTitle(from: sourceTitle) {
                    cleanedTitle = cleanTitle(extracted).lowercased()
                }
            }
            if moviesByCleanedTitleNoTmdb[cleanedTitle] == nil {
                moviesByCleanedTitleNoTmdb[cleanedTitle] = []
            }
            moviesByCleanedTitleNoTmdb[cleanedTitle]?.append(movie)
        }
        
        // Process movies with TMDB IDs (deduplicated by ID)
        for (tmdbId, movies) in moviesByTmdbId {
        // Use the best movie (prefer one with most data, cleanest title)
        let baseMovie = movies.max(by: { m1, m2 in
            let score1 = movieScore(m1)
            let score2 = movieScore(m2)
            if score1 != score2 {
                return score1 < score2
            }
            // Prefer cleaner title (no "with", no host names, shorter)
            let title1 = cleanTitle(m1.title)
            let title2 = cleanTitle(m2.title)
            let clean1 = !title1.contains(" with ") && !title1.contains("Bill Simmons") && title1.count < 60
            let clean2 = !title2.contains(" with ") && !title2.contains("Bill Simmons") && title2.count < 60
            if clean1 != clean2 {
                return !clean1 // Prefer clean title
            }
            return title1.count > title2.count // Prefer shorter
        }) ?? movies.first!
        
        // Get cleaned title, trying source title if main title has podcast patterns
        var cleanedTitle = cleanTitle(baseMovie.title)
        if cleanedTitle.contains(" with ") || cleanedTitle.contains("Bill Simmons") || cleanedTitle.contains("Juliet Litman") || cleanedTitle.contains("Amanda Dobbins"),
           let sourceTitle = baseMovie.sourceTitle {
            if let extracted = extractBetterTitle(from: sourceTitle) {
                cleanedTitle = extracted
                print("   📝 Extracted better title: '\(baseMovie.title)' -> '\(cleanedTitle)'")
            }
        }
        let movieId = "tmdb-\(tmdbId)"
        let titleKey = cleanedTitle.lowercased()
        let titleMergeCandidates = moviesByCleanedTitle[titleKey] ?? []
        let mergeCandidates = movies + titleMergeCandidates
        
        duplicatesSkipped += movies.count - 1
        
        let mergedPosterPath = firstNonEmptyString(mergeCandidates.map { $0.posterPath })
        let mergedBackdropPath = firstNonEmptyString(mergeCandidates.map { $0.backdropPath })
        let mergedOverview = bestOverview(from: mergeCandidates)
        let mergedMPAARating = firstNonEmptyString(mergeCandidates.map { $0.mpaaRating })
        let mergedGenres = bestGenres(from: mergeCandidates)
        let mergedStreamingServices = bestStreamingServices(from: mergeCandidates)
        let mergedCredits = bestCredits(from: mergeCandidates)
        let mergedTrailer = bestTrailer(from: mergeCandidates)
        let mergedOscarAwards = bestOscarAwards(from: mergeCandidates)
        let mergedPhysicalMedia = overlayPhysicalMedia(
            tmdbId: baseMovie.tmdbId,
            stored: bestPhysicalMedia(from: mergeCandidates)
        )
        let mergedYear = baseMovie.year ?? mergeCandidates.compactMap { $0.year }.first

        // Convert streaming services
        let streamingServices = (mergedStreamingServices ?? []).map { service in
            StreamingService(
                id: String(service.providerId),
                name: service.providerName,
                logoPath: service.logoPath,
                url: nil
            )
        }
        
        // Convert credits
        let credits: MovieCredits? = {
            guard let bootstrapCredits = mergedCredits else { return nil }
            return MovieCredits(
                director: bootstrapCredits.director,
                cast: (bootstrapCredits.cast ?? []).map { member in
                    CastMember(
                        id: member.id,
                        name: member.name,
                        character: member.character,
                        profilePath: member.profilePath
                    )
                }
            )
        }()
        
        // Convert trailer
        let trailer: MovieTrailer? = {
            guard let bootstrapTrailer = mergedTrailer else { return nil }
            return MovieTrailer(
                id: bootstrapTrailer.id,
                name: bootstrapTrailer.name,
                youtubeKey: bootstrapTrailer.youtubeKey,
                isOfficial: bootstrapTrailer.isOfficial
            )
        }()
        
        // Create MovieData
        let movie = MovieData(
            id: movieId,
            title: cleanedTitle,
            year: mergedYear,
            tmdbId: baseMovie.tmdbId,
            posterPath: mergedPosterPath ?? baseMovie.posterPath,
            backdropPath: mergedBackdropPath ?? baseMovie.backdropPath,
            overview: mergedOverview ?? baseMovie.overview,
            mpaaRating: mergedMPAARating ?? baseMovie.mpaaRating,
            genres: mergedGenres ?? baseMovie.genres ?? [],
            streamingServices: streamingServices,
            credits: credits,
            trailer: trailer,
            oscarAwards: mergedOscarAwards,
            physicalMedia: mergedPhysicalMedia,
            lastUpdated: Date()
        )
        
        context.insert(movie)
        moviesCreated += 1
        
        // Create links for all sources this movie appears in (from all movies with this TMDB ID)
        for bootstrapMovie in movies {
            guard let dataSource = dataSourceMap[bootstrapMovie.sourceIdentifier] else {
                print("⚠️ Warning: Source '\(bootstrapMovie.sourceIdentifier)' not found for movie '\(cleanedTitle)'")
                continue
            }
            
            // Get episode title for this source
            let episodeTitle = bootstrapMovie.sourceTitle ?? cleanedTitle
            let episodeDate = parseEpisodeDate(bootstrapMovie.episodeDate)
            
            // Create podcast episode if this is a podcast source
            var podcastEpisode: PodcastEpisode? = nil
            if dataSource.type == "podcast" {
                let episodeId = "bootstrap-\(movie.id)-\(episodeTitle.prefix(50))".replacingOccurrences(of: " ", with: "-").lowercased()
                
                // Get podcast URLs based on source identifier
                let (appleUrl, spotifyUrl) = getKnownPodcastUrls(
                    for: dataSource.identifier,
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
            
            // Create SourceContent (new schema - primary)
            // Only assign rank if this source is marked as ranked
            let rank = dataSource.isRankedList ? bootstrapMovie.rank : nil
            let sourceContent = SourceContent(
                movie: movie,
                source: dataSource,
                sourceTitle: bootstrapMovie.sourceTitle ?? episodeTitle,
                sourceDescription: nil,
                sourceDate: episodeDate,
                rank: rank,
                podcastEpisode: podcastEpisode,
                rewatchablesDiscussion: nil,
                sourceUrl: dataSource.url,
                applePodcastsUrl: podcastEpisode?.applePodcastsUrl,
                spotifyUrl: podcastEpisode?.spotifyUrl,
                lastUpdated: Date(),
                discoveredAt: Date()
            )
            context.insert(sourceContent)
            
            // Also create MovieDataSource (old schema for backward compatibility)
            let link = MovieDataSource(
                movie: movie,
                dataSource: dataSource,
                podcastEpisode: podcastEpisode,
                rewatchablesDiscussion: nil,
                sourceUrl: dataSource.url,
                sourceTitle: bootstrapMovie.sourceTitle ?? episodeTitle,
                rank: rank,
                lastUpdated: Date()
            )
            context.insert(link)
            linksCreated += 1
        }
        
        // Save periodically
        if moviesCreated % 100 == 0 {
            try context.save()
            print("   Progress: \(moviesCreated) movies, \(linksCreated) links...")
        }
    }
    
    // Process movies without TMDB ID, grouped by cleaned title
    for (cleanedTitleKey, movies) in moviesByCleanedTitleNoTmdb {
        // Use the best movie
        let baseMovie = movies.max(by: { m1, m2 in
            let score1 = movieScore(m1)
            let score2 = movieScore(m2)
            if score1 != score2 {
                return score1 < score2
            }
            let title1 = cleanTitle(m1.title)
            let title2 = cleanTitle(m2.title)
            let clean1 = !title1.contains(" with ") && !title1.contains("Bill Simmons") && title1.count < 60
            let clean2 = !title2.contains(" with ") && !title2.contains("Bill Simmons") && title2.count < 60
            if clean1 != clean2 {
                return !clean1 // Prefer clean title
            }
            return title1.count > title2.count // Prefer shorter
        }) ?? movies.first!
        
        // Get cleaned title, trying source title if main title has podcast patterns
        var cleanedTitle = cleanTitle(baseMovie.title)
        if cleanedTitle.contains(" with ") || cleanedTitle.contains("Bill Simmons") || cleanedTitle.contains("Juliet Litman") || cleanedTitle.contains("Amanda Dobbins"),
           let sourceTitle = baseMovie.sourceTitle {
            if let extracted = extractBetterTitle(from: sourceTitle) {
                cleanedTitle = extracted
                print("   📝 Extracted better title: '\(baseMovie.title)' -> '\(cleanedTitle)'")
            }
        }
        let movieId = UUID().uuidString
        let titleKey = cleanTitle(baseMovie.title).lowercased()
        let titleMergeCandidates = moviesByCleanedTitle[titleKey] ?? []
        let mergeCandidates = movies + titleMergeCandidates
        
        duplicatesSkipped += movies.count - 1
        
        let mergedPosterPath = firstNonEmptyString(mergeCandidates.map { $0.posterPath })
        let mergedBackdropPath = firstNonEmptyString(mergeCandidates.map { $0.backdropPath })
        let mergedOverview = bestOverview(from: mergeCandidates)
        let mergedMPAARating = firstNonEmptyString(mergeCandidates.map { $0.mpaaRating })
        let mergedGenres = bestGenres(from: mergeCandidates)
        let mergedStreamingServices = bestStreamingServices(from: mergeCandidates)
        let mergedCredits = bestCredits(from: mergeCandidates)
        let mergedTrailer = bestTrailer(from: mergeCandidates)
        let mergedOscarAwards = bestOscarAwards(from: mergeCandidates)
        let mergedPhysicalMedia = overlayPhysicalMedia(
            tmdbId: baseMovie.tmdbId,
            stored: bestPhysicalMedia(from: mergeCandidates)
        )
        let mergedYear = baseMovie.year ?? mergeCandidates.compactMap { $0.year }.first

        // Convert streaming services
        let streamingServices = (mergedStreamingServices ?? []).map { service in
            StreamingService(
                id: String(service.providerId),
                name: service.providerName,
                logoPath: service.logoPath,
                url: nil
            )
        }
        
        // Convert credits
        let credits: MovieCredits? = {
            guard let bootstrapCredits = mergedCredits else { return nil }
            return MovieCredits(
                director: bootstrapCredits.director,
                cast: (bootstrapCredits.cast ?? []).map { member in
                    CastMember(
                        id: member.id,
                        name: member.name,
                        character: member.character,
                        profilePath: member.profilePath
                    )
                }
            )
        }()
        
        // Convert trailer
        let trailer: MovieTrailer? = {
            guard let bootstrapTrailer = mergedTrailer else { return nil }
            return MovieTrailer(
                id: bootstrapTrailer.id,
                name: bootstrapTrailer.name,
                youtubeKey: bootstrapTrailer.youtubeKey,
                isOfficial: bootstrapTrailer.isOfficial
            )
        }()
        
        // Create MovieData with cleaned title
        let movie = MovieData(
            id: movieId,
            title: cleanedTitle,
            year: mergedYear,
            tmdbId: baseMovie.tmdbId,
            posterPath: mergedPosterPath ?? baseMovie.posterPath,
            backdropPath: mergedBackdropPath ?? baseMovie.backdropPath,
            overview: mergedOverview ?? baseMovie.overview,
            mpaaRating: mergedMPAARating ?? baseMovie.mpaaRating,
            genres: mergedGenres ?? baseMovie.genres ?? [],
            streamingServices: streamingServices,
            credits: credits,
            trailer: trailer,
            oscarAwards: mergedOscarAwards,
            physicalMedia: mergedPhysicalMedia,
            lastUpdated: Date()
        )
        
        context.insert(movie)
        moviesCreated += 1
        
        // Create links for all sources
        for bootstrapMovie in movies {
            guard let dataSource = dataSourceMap[bootstrapMovie.sourceIdentifier] else {
                print("⚠️ Warning: Source '\(bootstrapMovie.sourceIdentifier)' not found for movie '\(cleanedTitle)'")
                continue
            }
            
            // Get episode title for this source
            let episodeTitle = bootstrapMovie.sourceTitle ?? cleanedTitle
            let episodeDate = parseEpisodeDate(bootstrapMovie.episodeDate)
            
            // Create podcast episode if this is a podcast source
            var podcastEpisode: PodcastEpisode? = nil
            if dataSource.type == "podcast" {
                let episodeId = "bootstrap-\(movie.id)-\(episodeTitle.prefix(50))".replacingOccurrences(of: " ", with: "-").lowercased()
                
                // Get podcast URLs based on source identifier
                let (appleUrl, spotifyUrl) = getKnownPodcastUrls(
                    for: dataSource.identifier,
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
            
            // Create SourceContent (new schema - primary)
            // Only assign rank if this source is marked as ranked
            let rank = dataSource.isRankedList ? bootstrapMovie.rank : nil
            let sourceContent = SourceContent(
                movie: movie,
                source: dataSource,
                sourceTitle: bootstrapMovie.sourceTitle ?? episodeTitle,
                sourceDescription: nil,
                sourceDate: episodeDate,
                rank: rank,
                podcastEpisode: podcastEpisode,
                rewatchablesDiscussion: nil,
                sourceUrl: dataSource.url,
                applePodcastsUrl: podcastEpisode?.applePodcastsUrl,
                spotifyUrl: podcastEpisode?.spotifyUrl,
                lastUpdated: Date(),
                discoveredAt: Date()
            )
            context.insert(sourceContent)
            
            // Also create MovieDataSource (old schema for backward compatibility)
            let link = MovieDataSource(
                movie: movie,
                dataSource: dataSource,
                podcastEpisode: podcastEpisode,
                rewatchablesDiscussion: nil,
                sourceUrl: dataSource.url,
                sourceTitle: bootstrapMovie.sourceTitle ?? episodeTitle,
                rank: rank,
                lastUpdated: Date()
            )
            context.insert(link)
            linksCreated += 1
        }
        
        // Save periodically
        if moviesCreated % 100 == 0 {
            try context.save()
            print("   Progress: \(moviesCreated) movies, \(linksCreated) links...")
        }
    }
    
    // Final save
    try context.save()
    
        print("✅ Created \(moviesCreated) movies and \(linksCreated) links")
        if duplicatesSkipped > 0 {
            print("   Skipped \(duplicatesSkipped) duplicate entries")
        }
    }
    
    // Ensure all WAL data is checkpointed into the main store before copying
    finalizeSQLiteStore(at: tempDBURL)
    removeSidecarFiles(for: tempDBURL)
    
    // Copy to output location
    let outputURL = URL(fileURLWithPath: "WatchedIt/bootstrap_database.store")
    
    // Remove existing output if it exists
    if FileManager.default.fileExists(atPath: outputURL.path) {
        try? FileManager.default.removeItem(at: outputURL)
    }
    
    try FileManager.default.copyItem(at: tempDBURL, to: outputURL)
    
    // Remove any sidecars on the output store
    removeSidecarFiles(for: outputURL)
    
    // Get file size
    let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
    let fileSize = attributes[.size] as! Int64
    let fileSizeMB = Double(fileSize) / (1024 * 1024)
    
    print("✅ Database generated successfully!")
    print("   Location: \(outputURL.path)")
    print("   Size: \(String(format: "%.2f", fileSizeMB)) MB")
    print("   Movies: \(moviesCreated)")
    print("   Sources: \(dataSourceCount)")
    print("   Links: \(linksCreated)")
    
    // Clean up temp file
    try? FileManager.default.removeItem(at: tempDBURL)
}

// Run the script
Task {
    do {
        try await generateBootstrapDatabase()
        exit(0)
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
}

// Keep the script running
RunLoop.main.run()

