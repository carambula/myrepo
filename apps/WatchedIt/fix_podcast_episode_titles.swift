#!/usr/bin/env swift

import Foundation

/// Script to fix bootstrap data by identifying podcast episode titles that should be
/// associated with existing movies rather than being separate movie entries

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

// MARK: - Title Extraction

func extractMovieTitleFromEpisodeTitle(_ episodeTitle: String) -> String? {
    let cleaned = episodeTitle
    
    // Remove common podcast patterns
    let patterns = [
        #"^\s*['""]?([^'"]+)['"]?\s*With\s+.*$"#,  // "'Movie Title' With Bill Simmons..."
        #"^\s*['""]?([^'"]+)['"]?\s*with\s+.*$"#,  // "'Movie Title' with Bill Simmons..."
        #"^\s*['""]?([^'"]+)['"]?\s*-\s*.*$"#,     // "Movie Title - ReIssue"
        #"^\s*['""]?([^'"]+)['"]?\s*\(.*\)\s*-\s*.*$"#, // "Movie Title (Year) - ReIssue"
        #"^\s*['""]?([^'"]+)['"]?\s*\(.*\)\s*With\s+.*$"#, // "Movie Title (Year) With..."
        #"^\s*['""]?([^'"]+)['"]?\s*\(.*\)\s*with\s+.*$"#, // "Movie Title (Year) with..."
    ]
    
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .anchorsMatchLines]) {
            let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
            if let match = regex.firstMatch(in: cleaned, range: nsRange),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: cleaned) {
                let extracted = String(cleaned[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if extracted.count > 2 && extracted.count < 100 {
                    return extracted
                }
            }
        }
    }
    
    // Try to extract from quotes
    let quotePattern = #"['""]([^'"]+)['"]"#
    if let regex = try? NSRegularExpression(pattern: quotePattern, options: .caseInsensitive) {
        let nsRange = NSRange(cleaned.startIndex..., in: cleaned)
        if let match = regex.firstMatch(in: cleaned, range: nsRange),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: cleaned) {
            let extracted = String(cleaned[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if extracted.count > 2 && extracted.count < 100 {
                return extracted
            }
        }
    }
    
    // Remove "With [names]" suffix
    if let withRange = cleaned.range(of: " With ", options: .caseInsensitive) {
        let beforeWith = String(cleaned[..<withRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        if beforeWith.count > 2 {
            // Remove quotes if present
            var result = beforeWith
            if result.hasPrefix("'") || result.hasPrefix("\"") {
                result = String(result.dropFirst())
            }
            if result.hasSuffix("'") || result.hasSuffix("\"") {
                result = String(result.dropLast())
            }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    // Remove " - ReIssue" or similar suffixes (with or without space)
    let dashPatterns = [" - ", "- ", " -", "-"]
    for dashPattern in dashPatterns {
        if let dashRange = cleaned.range(of: dashPattern, options: .caseInsensitive) {
            let beforeDash = String(cleaned[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if beforeDash.count > 2 {
                // Remove quotes if present
                var result = beforeDash
                if result.hasPrefix("'") || result.hasPrefix("\"") {
                    result = String(result.dropFirst())
                }
                if result.hasSuffix("'") || result.hasSuffix("\"") {
                    result = String(result.dropLast())
                }
                result = result.trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove year if present at the end
                result = result.replacingOccurrences(of: #"\s*\(\d{4}\)\s*$"#, with: "", options: .regularExpression)
                if result.count > 2 {
                    return result
                }
            }
        }
    }
    
    return nil
}

func normalizeTitle(_ title: String) -> String {
    var normalized = title.lowercased()
    // Remove year patterns
    normalized = normalized.replacingOccurrences(of: #"\s*\(\d{4}\)\s*"#, with: "", options: .regularExpression)
    // Remove quotes
    normalized = normalized.replacingOccurrences(of: #"['"]"#, with: "", options: .regularExpression)
    // Remove extra whitespace
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized
}

func titlesMatch(_ title1: String, _ title2: String) -> Bool {
    let norm1 = normalizeTitle(title1)
    let norm2 = normalizeTitle(title2)
    return norm1 == norm2
}

// MARK: - Main Function

func fixPodcastEpisodeTitles() {
    let inputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    let outputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    let reportFile = "/Users/carambula/Documents/WatchedIt/podcast_episode_fixes.txt"
    
    print("📂 Loading bootstrap data...")
    
    let url = URL(fileURLWithPath: inputFile)
    guard let data = try? Data(contentsOf: url),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Could not load bootstrap_data.json")
        return
    }
    
    print("✅ Loaded \(bootstrapData.movies.count) movies")
    
    // Get podcast sources
    let podcastSources = Set(bootstrapData.dataSources.filter { $0.type == "podcast" }.map { $0.identifier })
    print("🎙️ Found \(podcastSources.count) podcast sources")
    
    // Identify problematic entries (podcast episode titles that should be associated with movies)
    var problematicEntries: [(index: Int, movie: BootstrapMovie, extractedTitle: String?)] = []
    var fixes: [String] = []
    
    for (index, movie) in bootstrapData.movies.enumerated() {
        // Only check podcast sources
        guard podcastSources.contains(movie.sourceIdentifier) else { continue }
        
        let title = movie.title
        let sourceTitle = movie.sourceTitle ?? title
        
        // Check if this looks like a podcast episode title
        let isEpisodeTitle = title.contains(" with ") || 
                            title.contains(" With ") ||
                            title.contains("ReIssue") ||
                            title.contains("Re-issue") ||
                            title.contains("Re Issue") ||
                            title.contains("Bill Simmons") ||
                            title.contains("Sean Fennessey") ||
                            title.contains("Chris Ryan") ||
                            title.contains("Amanda Dobbins") ||
                            title.contains("Juliet Litman") ||
                            title.contains("Van Lathan") ||
                            title.contains("Joanna Robinson") ||
                            title.hasPrefix("'") ||
                            title.hasPrefix("\"")
        
        if isEpisodeTitle {
            // Try to extract the actual movie title
            if let extractedTitle = extractMovieTitleFromEpisodeTitle(title) {
                problematicEntries.append((index: index, movie: movie, extractedTitle: extractedTitle))
            } else if let extractedTitle = extractMovieTitleFromEpisodeTitle(sourceTitle) {
                problematicEntries.append((index: index, movie: movie, extractedTitle: extractedTitle))
            }
        }
    }
    
    print("\n🔍 Found \(problematicEntries.count) potential podcast episode titles")
    
    // Find matching movies
    var moviesToRemove: Set<Int> = []
    var moviesToUpdate: [(index: Int, newTitle: String, sourceTitle: String)] = []
    var moviesToMerge: [(episodeIndex: Int, movieIndex: Int)] = []
    
    for (episodeIndex, episodeEntry) in problematicEntries.enumerated() {
        let episode = episodeEntry.movie
        guard let extractedTitle = episodeEntry.extractedTitle else { continue }
        
        // Find matching movie by title
        var matchedMovie: (index: Int, movie: BootstrapMovie)? = nil
        
        // First try exact match
        for (index, movie) in bootstrapData.movies.enumerated() {
            if titlesMatch(movie.title, extractedTitle) {
                // Don't match to itself
                if index != episodeEntry.index {
                    matchedMovie = (index: index, movie: movie)
                    break
                }
            }
        }
        
        // If no exact match, try matching by TMDB ID (if episode has one)
        if matchedMovie == nil, let episodeTmdbId = episode.tmdbId {
            for (index, movie) in bootstrapData.movies.enumerated() {
                if movie.tmdbId == episodeTmdbId && index != episodeEntry.index {
                    matchedMovie = (index: index, movie: movie)
                    break
                }
            }
        }
        
        if let match = matchedMovie {
            // We found a matching movie - merge the episode into it
            moviesToMerge.append((episodeIndex: episodeEntry.index, movieIndex: match.index))
            moviesToRemove.insert(episodeEntry.index)
            
            fixes.append("✅ MERGE: '\(episode.title)' → '\(match.movie.title)'")
            fixes.append("   Episode: \(episode.title)")
            fixes.append("   Extracted: \(extractedTitle)")
            fixes.append("   Matched to: \(match.movie.title)")
            fixes.append("")
        } else {
            // No match found - update the title to the extracted title
            moviesToUpdate.append((index: episodeEntry.index, newTitle: extractedTitle, sourceTitle: episode.title))
            
            fixes.append("📝 UPDATE: '\(episode.title)' → '\(extractedTitle)'")
            fixes.append("   Original: \(episode.title)")
            fixes.append("   New title: \(extractedTitle)")
            fixes.append("   Source title: \(episode.title)")
            fixes.append("")
        }
    }
    
    print("\n📊 Summary:")
    print("   Movies to merge: \(moviesToMerge.count)")
    print("   Movies to update: \(moviesToUpdate.count)")
    print("   Movies to remove: \(moviesToRemove.count)")
    
    // Apply updates
    print("\n🔧 Applying fixes...")
    
    // Update titles
    for update in moviesToUpdate {
        bootstrapData.movies[update.index].title = update.newTitle
        if bootstrapData.movies[update.index].sourceTitle == nil {
            bootstrapData.movies[update.index].sourceTitle = update.sourceTitle
        }
    }
    
    // For merged movies, we need to ensure the episode title is preserved in sourceTitle
    // and merge any metadata
    for merge in moviesToMerge {
        let episodeIndex = merge.episodeIndex
        let movieIndex = merge.movieIndex
        
        let episode = bootstrapData.movies[episodeIndex]
        var movie = bootstrapData.movies[movieIndex]
        
        // Preserve episode title in sourceTitle if not already set
        if movie.sourceTitle == nil {
            movie.sourceTitle = episode.title
        }
        
        // Merge metadata (episode might have better data)
        if movie.podcastEpisodeDescription == nil && episode.podcastEpisodeDescription != nil {
            movie.podcastEpisodeDescription = episode.podcastEpisodeDescription
        }
        if movie.tmdbId == nil && episode.tmdbId != nil {
            movie.tmdbId = episode.tmdbId
        }
        if movie.year == nil && episode.year != nil {
            movie.year = episode.year
        }
        
        bootstrapData.movies[movieIndex] = movie
    }
    
    // Remove merged movies (in reverse order to maintain indices)
    let sortedIndices = moviesToRemove.sorted(by: >)
    for index in sortedIndices {
        bootstrapData.movies.remove(at: index)
    }
    
    // Save updated data
    print("💾 Saving updated bootstrap data...")
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: URL(fileURLWithPath: outputFile))
        
        // Save report
        let report = """
        Podcast Episode Title Fixes Report
        Generated: \(Date())
        
        Summary:
        - Movies merged: \(moviesToMerge.count)
        - Movies updated: \(moviesToUpdate.count)
        - Movies removed: \(moviesToRemove.count)
        - Total fixes: \(moviesToMerge.count + moviesToUpdate.count)
        
        Details:
        \(fixes.joined(separator: "\n"))
        """
        try report.write(toFile: reportFile, atomically: true, encoding: .utf8)
        
        print("\n✅ Fixes complete!")
        print("   Movies merged: \(moviesToMerge.count)")
        print("   Movies updated: \(moviesToUpdate.count)")
        print("   Movies removed: \(moviesToRemove.count)")
        print("   Output: \(outputFile)")
        print("   Report: \(reportFile)")
    } catch {
        print("❌ Error saving updated data: \(error)")
    }
}

// Run
fixPodcastEpisodeTitles()

