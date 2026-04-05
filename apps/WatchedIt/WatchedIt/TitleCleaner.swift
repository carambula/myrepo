//
//  TitleCleaner.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation

class TitleCleaner {
    static let shared = TitleCleaner()
    private let movieDataService = MovieDataService.shared
    
    private init() {}
    
    /// Cleans movie titles by removing extraneous quotes, commas, and other characters
    func cleanTitle(_ title: String) -> String {
        var cleaned = title
        
        // Remove "Live From [Location]" patterns (e.g., "Live From Boston", "LIVE From Broadway")
        let liveFromPattern = #"(?i)\s*(?:LIVE|Live)\s+From\s+[A-Za-z\s]+"#
        if let regex = try? NSRegularExpression(pattern: liveFromPattern) {
            let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
            if let match = regex.firstMatch(in: cleaned, range: nsRange) {
                if let range = Range(match.range, in: cleaned) {
                    cleaned = String(cleaned[..<range.lowerBound]) + String(cleaned[range.upperBound...])
                }
            }
        }
        
        // Remove list numbering patterns at the start (e.g., "7. How to lose a guy", "#2 Movie Title")
        // CRITICAL: Only remove if it has punctuation (period, colon, dash, paren) - preserve numbers that are part of title
        // Patterns that ARE list numbering (remove):
        // - "7. Movie Title" (number, period, space)
        // - "#2 Movie Title" (hash, number, space)
        // - "2) Movie Title" (number, closing paren, space)
        // - "(2) Movie Title" (opening paren, number, closing paren, space)
        // - "1: Movie Title" or "1 - Movie Title" (number, colon/dash, space)
        // Patterns that are NOT list numbering (preserve):
        // - "10 Things I Hate About You" (number, space, capital letter - no punctuation)
        // - "27 Dresses" (number, space, capital letter - no punctuation)
        let listNumberingPatterns = [
            #"^(\d+)\.\s+"#,           // "7. " - number, period, space
            #"^#(\d+)\s+"#,            // "#2 " - hash, number, space
            #"^(\d+)\)\s+"#,           // "2) " - number, closing paren, space
            #"^\((\d+)\)\s+"#,         // "(2) " - opening paren, number, closing paren, space
            #"^(\d+)[:–\-]\s+"#,      // "1: " or "1 - " - number, colon/dash, space
        ]
        
        for pattern in listNumberingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                // Check if the number is reasonable for list numbering (1-999)
                if match.numberOfRanges > 1,
                   let numberRange = Range(match.range(at: 1), in: cleaned),
                   let number = Int(String(cleaned[numberRange])),
                   number <= 999 {
                    // This is list numbering - remove it
                    if let fullRange = Range(match.range, in: cleaned) {
                        cleaned = String(cleaned[fullRange.upperBound...])
                        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                        break // Only remove one pattern
                    }
                }
            }
        }
        
        // Remove episode/part markers like "(Part 1)", "(Part 2)", "Part I", "Part II", etc.
        // But preserve year patterns like "(1999)"
        let partPatterns = [
            #"(?i)\s*\(Part\s+\d+\)"#,           // (Part 1), (Part 2), etc.
            #"(?i)\s*\(Part\s+[IVX]+\)"#,        // (Part I), (Part II), etc.
            #"(?i)\s*Part\s+\d+"#,                // Part 1, Part 2 (without parentheses)
            #"(?i)\s*Part\s+[IVX]+"#,             // Part I, Part II (without parentheses)
            #"(?i)\s*\(Episode\s+\d+\)"#,         // (Episode 1)
            #"(?i)\s*Episode\s+\d+"#              // Episode 1
        ]
        for pattern in partPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        // Remove quotes that wrap the title (leading/trailing), but preserve apostrophes in the middle (contractions)
        // First, remove leading/trailing quotes - iterate until no more quotes at edges
        let leadingTrailingQuotes: [String] = [
            "'", "'", "'", "'",  // Single quotes (straight and curly)
            "\"", "\"", "\"", "\"",  // Double quotes (straight and curly)
            "′", "″", "‴", "⁗",  // Prime marks
            "`", "´"  // Grave and acute accents that might be used as quotes
        ]
        
        // Remove leading/trailing quotes - keep removing until none left
        var changed = true
        while changed {
            changed = false
        for quote in leadingTrailingQuotes {
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
        
        // Remove quotes that wrap entire phrases (e.g., "Movie Title" -> Movie Title)
        // But preserve apostrophes in contractions (e.g., "don't", "you've")
        // Pattern: quote at start, quote at end (with optional whitespace)
        let wrappedQuotePattern = #"^["'""'`´](.*)["'""'`´]$"#
        if let regex = try? NSRegularExpression(pattern: wrappedQuotePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1,
           let contentRange = Range(match.range(at: 1), in: cleaned) {
            cleaned = String(cleaned[contentRange])
        }
        
        // Final pass: Remove any remaining trailing apostrophes/quotes that might have been missed
        // This handles cases like "AxelF'" or "Believer'" where the quote wasn't properly matched
        // Include Unicode curly quotes
        let allQuoteChars = "'\"'\"'\"`´′″\u{2019}\u{2018}\u{201B}\u{201C}\u{201D}\u{201F}"
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: allQuoteChars).union(.whitespaces))
        
        // Remove leading/trailing commas and spaces
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        
        // Remove multiple consecutive spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Remove leading/trailing whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Cleans a title and finds the best match from TMDB, returning the official title
    /// Note: This makes an API call - use sparingly. Prefer cleanTitle() for basic cleaning.
    func cleanTitleWithTMDB(_ title: String) async -> String {
        // First, do basic cleaning (no API call)
        let basicCleaned = cleanTitle(title)
        
        // Only search TMDB if the title looks problematic (contains quotes, extra text, etc.)
        // This reduces API calls for already-clean titles
        let needsTMDBLookup = basicCleaned.contains("'") || 
                             basicCleaned.contains("\"") ||
                             basicCleaned.contains("Part") ||
                             basicCleaned.count > 50
        
        if needsTMDBLookup {
            // Try to find the movie in TMDB
            do {
                if let tmdbMovie = try await movieDataService.searchMovie(title: basicCleaned) {
                    // Use the official title from TMDB
                    return tmdbMovie.title
                }
            } catch {
                print("⚠️ Error searching TMDB for title '\(basicCleaned)': \(error)")
            }
        }
        
        // If no match found or lookup not needed, return the basic cleaned version
        return basicCleaned
    }
    
    /// Cleans an array of movie titles
    func cleanTitles(_ titles: [String]) -> [String] {
        return titles.map { cleanTitle($0) }
    }
}

