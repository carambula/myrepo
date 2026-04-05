#!/usr/bin/env swift

import Foundation

/// Script to add podcast episode descriptions to bootstrap_data.json
/// Fetches descriptions from RSS feeds and matches them to existing bootstrap movies

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
    let sourceTitle: String?
    
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

struct RSSEpisode: Codable {
    let title: String
    let description: String?
    let guid: String?
    let publishDate: String?
}

// MARK: - RSS Parsing

func extractXMLTag(from xml: String, tag: String) -> String? {
    let pattern = #"<#(tag)[^>]*>(.*?)</#(tag)>"#.replacingOccurrences(of: "#(tag)", with: tag)
    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
        let nsRange = NSRange(xml.startIndex..., in: xml)
        if let match = regex.firstMatch(in: xml, range: nsRange),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: xml) {
            var text = String(xml[range])
            // Remove CDATA markers if present
            text = text.replacingOccurrences(of: "<![CDATA[", with: "")
            text = text.replacingOccurrences(of: "]]>", with: "")
            // Decode HTML entities
            text = text.replacingOccurrences(of: "&amp;", with: "&")
            text = text.replacingOccurrences(of: "&lt;", with: "<")
            text = text.replacingOccurrences(of: "&gt;", with: ">")
            text = text.replacingOccurrences(of: "&quot;", with: "\"")
            text = text.replacingOccurrences(of: "&#39;", with: "'")
            text = text.replacingOccurrences(of: "&apos;", with: "'")
            // Remove HTML tags
            text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

func extractXMLTagWithCDATA(from xml: String, tag: String) -> String? {
    let pattern = #"<#(tag)[^>]*><!\[CDATA\[(.*?)\]\]></#(tag)>"#.replacingOccurrences(of: "#(tag)", with: tag)
    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
        let nsRange = NSRange(xml.startIndex..., in: xml)
        if let match = regex.firstMatch(in: xml, range: nsRange),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: xml) {
            var text = String(xml[range])
            // Remove HTML tags
            text = text.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    return nil
}

func extractGUID(from xml: String) -> String? {
    // Try <guid> tag first
    if let guid = extractXMLTag(from: xml, tag: "guid") {
        return guid
    }
    // Try <link> tag as fallback
    if let link = extractXMLTag(from: xml, tag: "link") {
        return link
    }
    return nil
}

func cleanHTMLFromDescription(_ html: String) -> String {
    var cleaned = html
    // Remove HTML tags
    cleaned = cleaned.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    // Decode common HTML entities
    cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
    cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
    cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
    cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
    cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
    cleaned = cleaned.replacingOccurrences(of: "&apos;", with: "'")
    cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
    // Remove extra whitespace
    cleaned = cleaned.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

func parseRSSFeed(xmlString: String) -> [RSSEpisode] {
    var episodes: [RSSEpisode] = []
    
    // Split by <item> tags
    let items = xmlString.components(separatedBy: "<item>")
    
    for (index, item) in items.enumerated() {
        if index == 0 { continue } // Skip the first part before first <item>
        
        // Extract title
        guard let title = extractXMLTag(from: item, tag: "title") else { continue }
        
        // Extract description (try multiple tags and handle CDATA)
        var description: String? = nil
        if let desc = extractXMLTag(from: item, tag: "description") {
            description = cleanHTMLFromDescription(desc)
        } else if let desc = extractXMLTag(from: item, tag: "itunes:summary") {
            description = cleanHTMLFromDescription(desc)
        } else if let desc = extractXMLTagWithCDATA(from: item, tag: "description") {
            description = cleanHTMLFromDescription(desc)
        } else if let desc = extractXMLTagWithCDATA(from: item, tag: "itunes:summary") {
            description = cleanHTMLFromDescription(desc)
        }
        
        // Extract GUID
        let guid = extractGUID(from: item)
        
        // Extract publish date
        let publishDate = extractXMLTag(from: item, tag: "pubDate")
        
        episodes.append(RSSEpisode(
            title: title,
            description: description,
            guid: guid,
            publishDate: publishDate
        ))
    }
    
    return episodes
}

func fetchRSSFeed(url: String) async throws -> [RSSEpisode] {
    guard let urlObj = URL(string: url) else {
        throw URLError(.badURL)
    }
    
    var request = URLRequest(url: urlObj)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw URLError(.badServerResponse)
    }
    
    guard let xmlString = String(data: data, encoding: .utf8) else {
        throw URLError(.cannotDecodeContentData)
    }
    
    return parseRSSFeed(xmlString: xmlString)
}

// MARK: - Title Matching

func normalizeTitle(_ title: String) -> String {
    var normalized = title.lowercased()
    // Remove common prefixes/suffixes
    normalized = normalized.replacingOccurrences(of: #"^.*?:\s*"#, with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: #"\s*\(Part\s+\d+\)"#, with: "", options: [.regularExpression, .caseInsensitive])
    normalized = normalized.replacingOccurrences(of: #"\s*\(Part\s+[IVX]+\)"#, with: "", options: [.regularExpression, .caseInsensitive])
    normalized = normalized.replacingOccurrences(of: #"\s*\((\d{4})\)"#, with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: #"\s*With\s+.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
    // Remove quotes
    normalized = normalized.replacingOccurrences(of: #"^["']|["']$"#, with: "", options: .regularExpression)
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized
}

func titlesMatch(_ title1: String, _ title2: String) -> Bool {
    let norm1 = normalizeTitle(title1)
    let norm2 = normalizeTitle(title2)
    
    // Exact match
    if norm1 == norm2 {
        return true
    }
    
    // Check if one contains the other (for partial matches)
    if norm1.count > 10 && norm2.count > 10 {
        if norm1.contains(norm2) || norm2.contains(norm1) {
            return true
        }
    }
    
    return false
}

// MARK: - Main Function

func addPodcastDescriptions() async {
    let inputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    let outputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    
    print("📂 Loading bootstrap data...")
    
    guard let url = URL(fileURLWithPath: inputFile) as URL?,
          let data = try? Data(contentsOf: url),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Could not load bootstrap_data.json")
        return
    }
    
    print("✅ Loaded \(bootstrapData.movies.count) movies")
    print("📊 Found \(bootstrapData.dataSources.count) data sources")
    
    // Get podcast sources
    let podcastSources = bootstrapData.dataSources.filter { $0.type == "podcast" && $0.url != nil }
    print("\n🎙️ Found \(podcastSources.count) podcast sources")
    
    var totalUpdated = 0
    var totalSkipped = 0
    
    for source in podcastSources {
        print("\n📻 Processing: \(source.name)")
        print("   URL: \(source.url ?? "N/A")")
        
        guard let rssURL = source.url else {
            print("   ⚠️  No RSS URL, skipping")
            continue
        }
        
        do {
            print("   🔍 Fetching RSS feed...")
            let episodes = try await fetchRSSFeed(url: rssURL)
            print("   ✅ Found \(episodes.count) episodes in RSS feed")
            
            // Get movies for this source
            let sourceMovies = bootstrapData.movies.filter { $0.sourceIdentifier == source.identifier }
            let missingDesc = sourceMovies.filter { 
                let desc = $0.podcastEpisodeDescription
                return desc == nil || desc!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            print("   📋 Found \(sourceMovies.count) movies in bootstrap data (\(missingDesc.count) missing descriptions)")
            
            var updated = 0
            var skipped = 0
            
            // Match episodes to movies - only process those missing descriptions
            let moviesNeedingDescriptions = sourceMovies.filter { movie in
                let desc = movie.podcastEpisodeDescription
                return desc == nil || desc!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            print("   🎯 Processing \(moviesNeedingDescriptions.count) movies that need descriptions")
            
            for (index, movie) in moviesNeedingDescriptions.enumerated() {
                
                // Try to find matching episode
                let movieTitle = movie.sourceTitle ?? movie.title
                var matchedEpisode: RSSEpisode? = nil
                
                // First try exact title match with sourceTitle
                if let sourceTitle = movie.sourceTitle {
                matchedEpisode = episodes.first { episode in
                        titlesMatch(episode.title, sourceTitle)
                    }
                }
                
                // If no match, try matching against cleaned movie title
                if matchedEpisode == nil {
                    matchedEpisode = episodes.first { episode in
                        titlesMatch(episode.title, movieTitle)
                    }
                }
                
                // If still no match, try partial matching (episode title contains movie title or vice versa)
                if matchedEpisode == nil {
                    let normalizedMovieTitle = normalizeTitle(movieTitle)
                    matchedEpisode = episodes.first { episode in
                        let normalizedEpisodeTitle = normalizeTitle(episode.title)
                        // Check if episode title contains movie title (for cases like "Movie Title With Guest")
                        if normalizedEpisodeTitle.contains(normalizedMovieTitle) && normalizedMovieTitle.count > 5 {
                            return true
                        }
                        // Check if movie title contains episode title (for cases where episode is just the movie)
                        if normalizedMovieTitle.contains(normalizedEpisodeTitle) && normalizedEpisodeTitle.count > 5 {
                            return true
                        }
                        return false
                    }
                }
                
                // If still no match and we have a sourceTitle, try extracting movie title from episode titles
                if matchedEpisode == nil, let sourceTitle = movie.sourceTitle {
                    // Try to find episodes where the title contains key words from sourceTitle
                    let sourceWords = sourceTitle.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "'\"-—")))
                        .filter { $0.count > 3 && $0.lowercased() != "with" && $0.lowercased() != "the" && $0.lowercased() != "and" }
                    
                    if sourceWords.count >= 2 {
                        matchedEpisode = episodes.first { episode in
                            let episodeLower = episode.title.lowercased()
                            // Check if episode contains at least 2 key words from source title
                            let matchingWords = sourceWords.filter { episodeLower.contains($0.lowercased()) }
                            return matchingWords.count >= 2
                        }
                    }
                }
                
                // Last resort: try fuzzy matching by movie title only (ignore "With" parts)
                // For short titles like "Heat", "Alien", "Dune", search for them as whole words in episode titles
                if matchedEpisode == nil {
                    let movieTitleOnly = movie.title
                    let normalizedMovie = normalizeTitle(movieTitleOnly)
                    
                    // For very short titles (1-2 words), search as whole words
                    if normalizedMovie.split(separator: " ").count <= 2 && normalizedMovie.count >= 3 {
                        matchedEpisode = episodes.first { episode in
                            let normalizedEpisode = normalizeTitle(episode.title)
                            // Search for movie title as a whole word (with word boundaries)
                            let pattern = #"\b"# + normalizedMovie.replacingOccurrences(of: #"["']"#, with: "", options: .regularExpression) + #"\b"#
                            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                                let range = NSRange(normalizedEpisode.startIndex..., in: normalizedEpisode)
                                return regex.firstMatch(in: normalizedEpisode, range: range) != nil
                            }
                            // Fallback: simple contains check
                            return normalizedEpisode.contains(normalizedMovie)
                        }
                    } else {
                        // For longer titles, use similarity matching
                        matchedEpisode = episodes.first { episode in
                            let normalizedEpisode = normalizeTitle(episode.title)
                            // Check if normalized titles are similar (at least 70% match)
                            if normalizedMovie.count > 5 && normalizedEpisode.count > 5 {
                                // Simple similarity: check if one contains most of the other
                                let longer = normalizedMovie.count > normalizedEpisode.count ? normalizedMovie : normalizedEpisode
                                let shorter = normalizedMovie.count > normalizedEpisode.count ? normalizedEpisode : normalizedMovie
                                // If shorter is at least 70% of longer, consider it a match
                                if Double(shorter.count) / Double(longer.count) >= 0.7 && longer.contains(shorter) {
                                    return true
                                }
                            }
                            return false
                        }
                    }
                }
                
                if let episode = matchedEpisode, let description = episode.description, !description.isEmpty {
                    // Find the movie in bootstrapData and update it
                    if let movieIndex = bootstrapData.movies.firstIndex(where: { $0.title == movie.title && $0.sourceIdentifier == movie.sourceIdentifier }) {
                        bootstrapData.movies[movieIndex].podcastEpisodeDescription = description
                        updated += 1
                        if updated <= 10 {
                            print("   ✅ Matched: '\(movie.sourceTitle ?? movie.title)' -> '\(episode.title.prefix(60))...'")
                        }
                    }
                } else {
                    skipped += 1
                    if skipped <= 10 {
                        print("   ⚠️  No match for: '\(movie.sourceTitle ?? movie.title)' (movie: '\(movie.title)')")
                    }
                }
                
                if (index + 1) % 50 == 0 {
                    print("   📊 Progress: \(index + 1)/\(sourceMovies.count) (updated: \(updated), skipped: \(skipped))")
                }
            }
            
            print("   ✅ Updated: \(updated), Skipped: \(skipped)")
            totalUpdated += updated
            totalSkipped += skipped
            
            // Rate limiting
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second between sources
            
        } catch {
            print("   ❌ Error fetching RSS feed: \(error.localizedDescription)")
        }
    }
    
    // Save updated data
    print("\n💾 Saving updated bootstrap data...")
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: URL(fileURLWithPath: outputFile))
        
        print("\n✅ Update complete!")
        print("   Total updated: \(totalUpdated)")
        print("   Total skipped: \(totalSkipped)")
        print("   Output: \(outputFile)")
    } catch {
        print("❌ Error saving updated data: \(error)")
    }
}

// Run
Task {
    await addPodcastDescriptions()
    exit(0)
}

RunLoop.main.run()


