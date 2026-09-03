//
//  MovieTitleExtractionService.swift
//  WatchedIt
//
//  Created by Aaron Carámbula on 11/16/25.
//

import Foundation
import NaturalLanguage

/// Service that uses Apple's Natural Language framework to intelligently extract and clean movie titles from text
@MainActor
class MovieTitleExtractionService {
    static let shared = MovieTitleExtractionService()
    
    private let titleCleaner = TitleCleaner.shared
    
    private init() {}
    
    /// Extracts movie titles from a list of potentially messy text entries
    /// Uses Apple's Natural Language framework for intelligent extraction
    func extractMovieTitles(from texts: [String]) async -> [String] {
        var extractedTitles: [String] = []
        
        for text in texts {
            // First, clean basic formatting issues
            var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove HTML tags if any remain
            cleanedText = cleanedText.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            
            // Remove list numbering patterns
            cleanedText = removeListNumbering(cleanedText)
            
            // Skip if too short or obviously not a movie title
            guard cleanedText.count >= 2 && cleanedText.count < 200 else { continue }
            
            // Use Natural Language framework to identify if this looks like a movie title
            if await isLikelyMovieTitle(cleanedText) {
                // Further clean using TitleCleaner
                let finalTitle = titleCleaner.cleanTitle(cleanedText)
                
                if !finalTitle.isEmpty && isValidMovieTitle(finalTitle) {
                    extractedTitles.append(finalTitle)
                }
            }
        }
        
        return extractedTitles
    }
    
    /// Intelligently extracts a single movie title from potentially messy text
    /// Uses Apple's Natural Language framework
    func extractMovieTitle(from text: String) async -> String? {
        // Step 1: Basic cleaning
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove HTML tags
        cleaned = cleaned.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        
        // Remove list numbering
        cleaned = removeListNumbering(cleaned)
        
        // Remove year from end if present
        let yearPattern = #"\s*\(\d{4}\)\s*$"#
        if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
            cleaned = yearRegex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 2: Use Natural Language framework to validate it's likely a movie title
        if await isLikelyMovieTitle(cleaned) {
            // Step 3: Use TitleCleaner for final cleaning
            let finalTitle = titleCleaner.cleanTitle(cleaned)
            return finalTitle.isEmpty ? nil : finalTitle
        }
        
        return nil
    }
    
    /// Uses Apple's Natural Language framework to determine if text is likely a movie title
    private func isLikelyMovieTitle(_ text: String) async -> Bool {
        // Basic heuristics first (fast, no AI needed)
        guard text.count >= 2 && text.count < 200 else { return false }
        guard text.rangeOfCharacter(from: .letters) != nil else { return false }
        
        // Filter out obvious non-movie text
        let excludedPatterns = [
            "click here", "read more", "subscribe", "follow us", 
            "share", "comment", "http://", "https://", "@", 
            "home", "about", "contact", "privacy", "terms"
        ]
        let lowercased = text.lowercased()
        for pattern in excludedPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        // Use Natural Language framework for Named Entity Recognition
        // This can help identify proper nouns (which movie titles typically are)
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        var hasProperNoun = false
        var hasOrganizationOrPerson = false
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .organizationName || tag == .personalName || tag == .placeName {
                hasOrganizationOrPerson = true
                return false // Stop enumeration
            }
            return true // Continue
        }
        
        // Movie titles often contain proper nouns
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            if tag == .noun, let word = String(text[tokenRange]).first, word.isUppercase {
                hasProperNoun = true
                return false // Stop enumeration
            }
            return true
        }
        
        // If it has proper nouns or named entities, it's more likely to be a movie title
        // Also check if it starts with a capital letter or number (common for movie titles like "27 Dresses", "10 Things")
        let firstChar = text.first
        let startsWithCapital = firstChar?.isUppercase ?? false
        let startsWithNumber = firstChar?.isNumber ?? false
        let hasReasonableLength = text.count >= 3 && text.count < 100
        
        // More sophisticated check: Movie titles typically have 1-6 words
        let wordCount = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        let reasonableWordCount = wordCount >= 1 && wordCount <= 6
        
        // Accept titles that start with numbers (like "27 Dresses", "10 Things I Hate About You")
        // Only reject if it looks like list numbering (e.g., "1. Title" or "1) Title" with punctuation)
        let hasListNumberingPattern = text.range(of: #"^\d+[\.\)\:\-]\s+"#, options: .regularExpression) != nil
        
        return hasReasonableLength && 
               reasonableWordCount &&
               (startsWithCapital || startsWithNumber || hasProperNoun || hasOrganizationOrPerson) &&
               !hasListNumberingPattern &&
               reasonableWordCount
    }
    
    /// Removes list numbering patterns from the beginning of titles
    /// IMPORTANT: Only removes if it's clearly list numbering, not part of the title (e.g., "27 Dresses" should keep "27")
    private func removeListNumbering(_ title: String) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // CRITICAL: Only remove numbers if they have clear list numbering punctuation
        // Patterns that indicate list numbering (require punctuation):
        // 1. "1. Movie Title" - number, period, space (list numbering)
        // 2. "#2 Movie Title" - hash, number, space (list numbering)
        // 3. "2) Movie Title" - number, closing paren, space (list numbering)
        // 4. "(2) Movie Title" - opening paren, number, closing paren, space (list numbering)
        // 5. "1: Movie Title" or "1 - Movie Title" - number, colon/dash, space (list numbering)
        // 
        // Patterns that are NOT list numbering (preserve these):
        // - "27 Dresses" - number, space, capital letter (part of title, no punctuation)
        // - "10 Things I Hate About You" - number, space, capital letter (part of title, no punctuation)
        
        // Pattern 1: "1. Movie Title" - number, period, space
        if let regex = try? NSRegularExpression(pattern: #"^(\d+)\.\s+"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1 {
            if let numberRange = Range(match.range(at: 1), in: cleaned),
               let number = Int(String(cleaned[numberRange])),
               number <= 999 {
                // This is list numbering (has period), remove it
                if let fullRange = Range(match.range, in: cleaned) {
                    cleaned = String(cleaned[fullRange.upperBound...])
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    return cleaned
                }
            }
        }
        
        // Pattern 2: "#2 Movie Title" - hash, number, space
        if let regex = try? NSRegularExpression(pattern: #"^#(\d+)\s+"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1 {
            if let fullRange = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[fullRange.upperBound...])
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned
            }
        }
        
        // Pattern 3: "2) Movie Title" - number, closing paren, space
        if let regex = try? NSRegularExpression(pattern: #"^(\d+)\)\s+"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1 {
            if let fullRange = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[fullRange.upperBound...])
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned
            }
        }
        
        // Pattern 4: "(2) Movie Title" - opening paren, number, closing paren, space
        if let regex = try? NSRegularExpression(pattern: #"^\((\d+)\)\s+"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1 {
            if let fullRange = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[fullRange.upperBound...])
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned
            }
        }
        
        // Pattern 5: "1: Movie Title" or "1 - Movie Title" - number, colon/dash, space
        if let regex = try? NSRegularExpression(pattern: #"^(\d+)[:–\-]\s+"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1 {
            if let numberRange = Range(match.range(at: 1), in: cleaned),
               let number = Int(String(cleaned[numberRange])),
               number <= 999 {
                // This is list numbering (has colon/dash), remove it
                if let fullRange = Range(match.range, in: cleaned) {
                    cleaned = String(cleaned[fullRange.upperBound...])
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    return cleaned
                }
            }
        }
        
        // Pattern 6: Roman numerals "I. ", "II. ", "XVIII. "
        if let regex = try? NSRegularExpression(pattern: #"^[IVX]+\.\s+"#, options: .caseInsensitive) {
            let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
            if let match = regex.firstMatch(in: cleaned, range: nsRange) {
                if let range = Range(match.range, in: cleaned) {
                    cleaned = String(cleaned[range.upperBound...])
                    cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                    return cleaned
                }
            }
        }
        
        // IMPORTANT: If we get here, the title doesn't have clear list numbering punctuation
        // This means it's likely part of the title (e.g., "27 Dresses", "10 Things")
        // Do NOT remove anything - return the title as-is
        return cleaned
    }
    
    /// Validates if a title is likely a valid movie title
    private func isValidMovieTitle(_ title: String) -> Bool {
        guard title.count >= 2 && title.count < 100 else { return false }
        guard title.rangeOfCharacter(from: .letters) != nil else { return false }
        guard !title.contains("http://") && !title.contains("https://") && !title.contains("@") else { return false }
        
        // Filter out common non-movie text
        let excludedPatterns = ["click here", "read more", "subscribe", "follow us", "share", "comment"]
        let lowercased = title.lowercased()
        for pattern in excludedPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        return true
    }
}

