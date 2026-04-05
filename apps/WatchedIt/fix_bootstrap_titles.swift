#!/usr/bin/env swift

/// Script to fix title issues in the bootstrap database
/// Fixes:
/// - Trailing apostrophes (e.g., "AxelF'" -> "Axel F")
/// - Broken titles from The Big Picture podcast
/// - Duplicate movies with different titles
/// - Missing prefixes (e.g., "Chapter 3—Parabellum'" -> "John Wick: Chapter 3—Parabellum")

import Foundation
import SwiftData

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
    var sourceTitle: String?
    
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

// MARK: - Title Cleaning

func cleanTitle(_ title: String) -> String {
    var cleaned = title
    
    // Remove "Live From [Location]" patterns
    let liveFromPattern = #"(?i)\s*(?:LIVE|Live)\s+From\s+[A-Za-z\s]+"#
    if let regex = try? NSRegularExpression(pattern: liveFromPattern) {
        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
        if let match = regex.firstMatch(in: cleaned, range: nsRange),
           let range = Range(match.range, in: cleaned) {
            cleaned = String(cleaned[..<range.lowerBound]) + String(cleaned[range.upperBound...])
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
        cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
    
    // Remove "With [guests]" pattern - but only if it looks like a podcast episode
    // Don't remove "With" from legitimate movie titles like "Gone With the Wind"
    let withPattern = #"\s+With\s+(?:Bill|Sean|Chris|Juliet|Amanda|Katey|Craig|Mallory|Wesley|Van|Joanna|and|featuring)"#
    if let regex = try? NSRegularExpression(pattern: withPattern, options: .caseInsensitive),
       let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
       let range = Range(match.range, in: cleaned) {
        cleaned = String(cleaned[..<range.lowerBound])
    }
    
    // Remove leading/trailing quotes (keep removing until none left)
    // Include Unicode curly quotes that appear in podcast titles
    let quotes: [String] = [
        "'", "'", "'", "'",  // Straight and curly single quotes
        "\"", "\"", "\"", "\"",  // Straight and curly double quotes
        "`", "´",  // Grave and acute accents
        "′", "″", "‴", "⁗",  // Prime marks
        "\u{2019}", "\u{2018}", "\u{201B}", "\u{201C}", "\u{201D}", "\u{201F}"  // Unicode quotes
    ]
    var changed = true
    while changed {
        changed = false
        for quote in quotes {
            if cleaned.hasPrefix(quote) {
                cleaned = String(cleaned.dropFirst())
                changed = true
            }
            if cleaned.hasSuffix(quote) {
                cleaned = String(cleaned.dropLast())
                changed = true
            }
        }
    }
    
    // Remove year from title
    let yearPattern = #"\s*\((\d{4})\)\s*$"#
    cleaned = (try? NSRegularExpression(pattern: yearPattern))?.stringByReplacingMatches(
        in: cleaned,
        options: [],
        range: NSRange(cleaned.startIndex..., in: cleaned),
        withTemplate: ""
    ) ?? cleaned
    
    // Final trim of quotes and whitespace
    cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "'\"'\"'\"`´′″").union(.whitespaces))
    
    // Remove multiple consecutive spaces
    while cleaned.contains("  ") {
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
    }
    
    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    
    return cleaned
}

// MARK: - Title Fixes

/// Fixes known problematic titles
func fixKnownTitleIssues(_ title: String, sourceIdentifier: String) -> String {
    var fixed = title
    
    // Fix "AxelF'" -> "Axel F" (should be "Axel F" or "Axel Foley")
    if fixed.lowercased() == "axelf'" || fixed.lowercased() == "axelf" {
        fixed = "Axel F"
    }
    
    // Fix "Believer'" -> "Believer" (handle any trailing apostrophe)
    if fixed.lowercased().hasSuffix("'") && fixed.lowercased().hasPrefix("believer") {
        fixed = "Believer"
    }
    
    // Fix any title ending with just an apostrophe (common issue from The Big Picture)
    if fixed.hasSuffix("'") && fixed.count > 1 {
        fixed = String(fixed.dropLast())
    }
    
    // Fix "Chapter 3—Parabellum'" -> "John Wick: Chapter 3—Parabellum"
    if fixed.contains("Chapter 3—Parabellum") || fixed.contains("Chapter 3-Parabellum") {
        fixed = "John Wick: Chapter 3—Parabellum"
    }
    
    // Fix other "Chapter X" titles that are missing "John Wick:" prefix
    if fixed.hasPrefix("Chapter ") && !fixed.contains("John Wick") {
        if let chapterMatch = fixed.range(of: #"^Chapter\s+(\d+)"#, options: .regularExpression) {
            fixed = "John Wick: " + fixed
        }
    }
    
    // Fix titles from The Big Picture that have trailing apostrophes
    if sourceIdentifier == "big-picture" && fixed.hasSuffix("'") {
        fixed = String(fixed.dropLast())
    }
    
    // Final pass: Remove any trailing apostrophes/quotes (handle all quote types)
    let trailingQuotes: [String] = ["'", "'", "'", "'", "`", "´", "′", "″"]
    for quote in trailingQuotes {
        while fixed.hasSuffix(quote) {
            fixed = String(fixed.dropLast())
        }
    }
    
    return fixed
}

/// Extracts better title from source title for podcast episodes
func extractBetterTitle(from sourceTitle: String) -> String? {
    var cleaned = cleanTitle(sourceTitle)
    
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
            let extracted = String(cleaned[titleRange])
            let cleanedExtracted = cleanTitle(extracted)
            if cleanedExtracted.count > 3 && cleanedExtracted.count < 60 && !cleanedExtracted.contains(" with ") {
                return cleanedExtracted
            }
        }
    }
    
    // Try to extract before "With" or " - "
    let separators = [" With ", " with ", " WITH ", " - ", " – ", " — "]
    for separator in separators {
        if let range = cleaned.range(of: separator, options: .caseInsensitive) {
            let beforeSeparator = String(cleaned[..<range.lowerBound])
            let cleanedBefore = cleanTitle(beforeSeparator)
            if cleanedBefore.count > 3 && cleanedBefore.count < 60 {
                return cleanedBefore
            }
        }
    }
    
    return nil
}

// MARK: - Main Script

func fixBootstrapTitles() {
    let inputFile = "WatchedIt/bootstrap_data.json"
    let outputFile = "WatchedIt/bootstrap_data.json"
    
    print("📂 Reading bootstrap data...")
    
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: inputFile)),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Could not read or decode \(inputFile)")
        return
    }
    
    print("✅ Loaded \(bootstrapData.movies.count) movies")
    
    var fixedCount = 0
    var duplicatesFound: [String: [BootstrapMovie]] = [:]
    
    // Group movies by normalized title to find duplicates
    var moviesByNormalizedTitle: [String: [Int]] = [:]
    for (index, movie) in bootstrapData.movies.enumerated() {
        let normalized = cleanTitle(movie.title).lowercased()
        if moviesByNormalizedTitle[normalized] == nil {
            moviesByNormalizedTitle[normalized] = []
        }
        moviesByNormalizedTitle[normalized]?.append(index)
    }
    
    // Fix titles
    for (index, movie) in bootstrapData.movies.enumerated() {
        let originalTitle = movie.title
        var fixedTitle = cleanTitle(originalTitle)
        
        // Apply known fixes
        fixedTitle = fixKnownTitleIssues(fixedTitle, sourceIdentifier: movie.sourceIdentifier)
        
        // If title looks like a podcast episode, try to extract better title from sourceTitle
        let hasPodcastPatterns = fixedTitle.contains(" with ") ||
                                 fixedTitle.contains(" With ") ||
                                 fixedTitle.contains("Bill Simmons") ||
                                 fixedTitle.contains("Sean Fennessey") ||
                                 fixedTitle.contains("Juliet Litman") ||
                                 fixedTitle.contains("Amanda Dobbins") ||
                                 fixedTitle.contains("Katey Rich") ||
                                 fixedTitle.count > 60
        
        if hasPodcastPatterns, let sourceTitle = movie.sourceTitle {
            if let extracted = extractBetterTitle(from: sourceTitle) {
                fixedTitle = extracted
                print("📝 Fixed: '\(originalTitle)' -> '\(fixedTitle)' (extracted from source)")
            }
        }
        
        // Apply final cleaning
        fixedTitle = cleanTitle(fixedTitle)
        
        if fixedTitle != originalTitle {
            bootstrapData.movies[index].title = fixedTitle
            fixedCount += 1
            print("✅ Fixed: '\(originalTitle)' -> '\(fixedTitle)'")
        }
    }
    
    // Find and report duplicates
    print("\n🔍 Checking for duplicates...")
    var duplicateGroups: [String: [BootstrapMovie]] = [:]
    for movie in bootstrapData.movies {
        let normalized = cleanTitle(movie.title).lowercased()
        if duplicateGroups[normalized] == nil {
            duplicateGroups[normalized] = []
        }
        duplicateGroups[normalized]?.append(movie)
    }
    
    var duplicateCount = 0
    for (normalized, movies) in duplicateGroups {
        if movies.count > 1 {
            duplicateCount += movies.count - 1
            print("⚠️ Found \(movies.count) duplicates for '\(movies.first!.title)':")
            for movie in movies {
                print("   - '\(movie.title)' (source: \(movie.sourceIdentifier))")
            }
        }
    }
    
    // Deduplicate by keeping the best version of each movie
    print("\n🔧 Deduplicating...")
    var deduplicatedMovies: [BootstrapMovie] = []
    var seenNormalized: Set<String> = []
    
    for movie in bootstrapData.movies {
        let normalized = cleanTitle(movie.title).lowercased()
        
        if seenNormalized.contains(normalized) {
            // Already have this movie - keep the one with more data
            if let existingIndex = deduplicatedMovies.firstIndex(where: { cleanTitle($0.title).lowercased() == normalized }) {
                let existing = deduplicatedMovies[existingIndex]
                let existingScore = (existing.tmdbId != nil ? 1 : 0) + (existing.posterPath != nil ? 1 : 0) + (existing.overview != nil ? 1 : 0)
                let newScore = (movie.tmdbId != nil ? 1 : 0) + (movie.posterPath != nil ? 1 : 0) + (movie.overview != nil ? 1 : 0)
                
                if newScore > existingScore {
                    deduplicatedMovies[existingIndex] = movie
                    print("🔄 Replaced duplicate '\(movie.title)' with better version")
                } else {
                    print("⏭️  Skipped duplicate '\(movie.title)' (keeping existing)")
                }
            }
        } else {
            deduplicatedMovies.append(movie)
            seenNormalized.insert(normalized)
        }
    }
    
    bootstrapData.movies = deduplicatedMovies
    
    print("\n📊 Summary:")
    print("   Fixed titles: \(fixedCount)")
    print("   Duplicates found: \(duplicateCount)")
    print("   Movies after deduplication: \(bootstrapData.movies.count)")
    
    // Write fixed data
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    guard let outputData = try? encoder.encode(bootstrapData) else {
        print("❌ Could not encode fixed data")
        return
    }
    
    do {
        try outputData.write(to: URL(fileURLWithPath: outputFile))
        print("✅ Fixed bootstrap data written to \(outputFile)")
    } catch {
        print("❌ Could not write fixed data: \(error)")
    }
}

// Run the script
fixBootstrapTitles()

