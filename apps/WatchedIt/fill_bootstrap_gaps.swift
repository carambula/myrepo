#!/usr/bin/env swift

import Foundation

/// Script to fill gaps in bootstrap_data.json by scraping missing data
/// and merging it with existing bootstrap data

// MARK: - Data Structures

struct BootstrapDataSource: Codable {
    var identifier: String
    var name: String
    var type: String
    var url: String?
    var isRankedList: Bool
    var movieCount: Int
}

struct BootstrapMovie: Codable {
    var title: String
    var sourceIdentifier: String
    var rank: Int?
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
    var version: String?
    var generatedDate: String?
    var dataSources: [BootstrapDataSource]
    var movies: [BootstrapMovie]
}

// MARK: - Scraped Movie

struct ScrapedMovie {
    let title: String
    let rank: Int?
    let sourceIdentifier: String
    let sourceTitle: String?
}

// MARK: - Scraping Service

class GapFillingScraper {
    
    // MARK: - Source Configuration
    
    struct SourceConfig {
        let identifier: String
        let name: String
        let url: String
        let type: String
        let isRanked: Bool
        let expectedCount: Int
        let minCount: Int?
    }
    
    let sourcesToFill: [SourceConfig] = [
        SourceConfig(
            identifier: "rt-christmas",
            name: "RT: Best Christmas Movies",
            url: "https://editorial.rottentomatoes.com/guide/best-christmas-movies/",
            type: "url",
            isRanked: true,
            expectedCount: 100,
            minCount: nil
        ),
        SourceConfig(
            identifier: "rt-best-all-time",
            name: "RT: Best Movies of All Time",
            url: "https://editorial.rottentomatoes.com/guide/best-movies-of-all-time/",
            type: "url",
            isRanked: true,
            expectedCount: 300,
            minCount: nil
        ),
        SourceConfig(
            identifier: "rt-oscars",
            name: "RT: Oscars Best and Worst",
            url: "https://editorial.rottentomatoes.com/guide/oscars-best-and-worst-best-pictures/",
            type: "url",
            isRanked: true,
            expectedCount: 98,
            minCount: nil
        ),
        SourceConfig(
            identifier: "criterion",
            name: "Criterion Collection",
            url: "https://en.wikipedia.org/wiki/Criterion_Closet#Criterion_Collection_40",
            type: "url",
            isRanked: true,
            expectedCount: 40,
            minCount: nil
        ),
        SourceConfig(
            identifier: "imdb-list-1",
            name: "IMDB Auteurs",
            url: "https://www.imdb.com/list/ls042702401/",
            type: "url",
            isRanked: true,
            expectedCount: 403,
            minCount: nil
        ),
        // Podcasts
        SourceConfig(
            identifier: "filmspotting",
            name: "Filmspotting",
            url: "https://feeds.megaphone.fm/filmspotting",
            type: "podcast",
            isRanked: false,
            expectedCount: 0,
            minCount: 800
        ),
        SourceConfig(
            identifier: "rewatchables",
            name: "The Rewatchables",
            url: "https://feeds.megaphone.fm/the-rewatchables",
            type: "podcast",
            isRanked: false,
            expectedCount: 0,
            minCount: 480
        ),
        SourceConfig(
            identifier: "blank-check",
            name: "Blank Check",
            url: "https://feeds.megaphone.fm/blank-check",
            type: "podcast",
            isRanked: false,
            expectedCount: 0,
            minCount: 500
        ),
    ]
    
    // MARK: - Rotten Tomatoes Scraping
    
    func scrapeRottenTomatoesGuide(url: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: url) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard let htmlString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        var movies: [ScrapedMovie] = []
        var movieCount = 0
        var seenTitles = Set<String>()
        
        // Pattern 1: Extract from RT movie links with rank
        let rtLinkPattern = #"<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/[^"']*["'][^>]*>([^<]+)</a>"#
        if let regex = try? NSRegularExpression(pattern: rtLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            
            for match in matches {
                if match.numberOfRanges > 1, let titleRange = Range(match.range(at: 1), in: htmlString) {
                    var title = String(htmlString[titleRange])
                    if title.contains("[More]") || title.trimmingCharacters(in: .whitespaces).isEmpty { continue }
                    
                    title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    title = title.replacingOccurrences(of: "&#039;", with: "'")
                    title = title.replacingOccurrences(of: "&#x27;", with: "'")
                    title = title.replacingOccurrences(of: "&amp;", with: "&")
                    
                    if !title.isEmpty && title.count > 2 && title.count < 200 {
                        let lowerTitle = title.lowercased()
                        if !seenTitles.contains(lowerTitle) {
                            seenTitles.insert(lowerTitle)
                            movieCount += 1
                            movies.append(ScrapedMovie(title: title, rank: movieCount, sourceIdentifier: "", sourceTitle: nil))
                        }
                    }
                }
            }
        }
        
        // Pattern 2: Extract from table rows with ranks
        let tableRowPattern = #"<tr[^>]*>.*?<td[^>]*>(\d+)</td>.*?<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/[^"']*["'][^>]*>([^<]+)</a>.*?</tr>"#
        if let regex = try? NSRegularExpression(pattern: tableRowPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            
            for match in matches {
                if match.numberOfRanges > 2 {
                    let rankRange = Range(match.range(at: 1), in: htmlString)
                    let titleRange = Range(match.range(at: 2), in: htmlString)
                    
                    if let titleRange = titleRange, let rankRange = rankRange,
                       let rank = Int(String(htmlString[rankRange])) {
                        var title = String(htmlString[titleRange])
                        title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        title = title.replacingOccurrences(of: "&#039;", with: "'")
                        title = title.replacingOccurrences(of: "&#x27;", with: "'")
                        title = title.replacingOccurrences(of: "&amp;", with: "&")
                        
                        if !title.isEmpty {
                            let lowerTitle = title.lowercased()
                            if !seenTitles.contains(lowerTitle) {
                                seenTitles.insert(lowerTitle)
                                movies.append(ScrapedMovie(title: title, rank: rank, sourceIdentifier: "", sourceTitle: nil))
                            }
                        }
                    }
                }
            }
        }
        
        // Sort by rank if ranks are available
        movies.sort { movie1, movie2 in
            if let rank1 = movie1.rank, let rank2 = movie2.rank {
                return rank1 < rank2
            }
            return false
        }
        
        return movies
    }
    
    // MARK: - IMDb Scraping
    
    func extractIMDbListId(from url: String) -> String? {
        let pattern = #"/list/ls(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              match.numberOfRanges > 1,
              let idRange = Range(match.range(at: 1), in: url) else {
            return nil
        }
        return String(url[idRange])
    }
    
    func scrapeIMDbListCSV(listId: String) async throws -> [ScrapedMovie] {
        let csvURLString = "https://www.imdb.com/list/\(listId)/export"
        guard let csvURL = URL(string: csvURLString) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: csvURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(httpResponse.statusCode) else { throw URLError(.badServerResponse) }
        guard let csvString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        var movies: [ScrapedMovie] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        // IMDb CSV format: Position,Const,Created,Modified,Description,Title,URL,Title Type,IMDb Rating,Runtime (mins),Year,Genres,Num Votes,Release Date,Directors
        // Position is at index 0, Title is at index 5
        for (index, line) in lines.enumerated() {
            if index == 0 { continue } // Skip header
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            
            // Parse CSV line handling quoted fields
            var columns: [String] = []
            var currentField = ""
            var inQuotes = false
            
            for char in line {
                if char == "\"" {
                    inQuotes.toggle()
                } else if char == "," && !inQuotes {
                    // Remove surrounding quotes from field
                    if currentField.hasPrefix("\"") && currentField.hasSuffix("\"") {
                        currentField = String(currentField.dropFirst().dropLast())
                        currentField = currentField.replacingOccurrences(of: "\"\"", with: "\"")
                    }
                    columns.append(currentField)
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            }
            
            // Add last field
            if !currentField.isEmpty {
                if currentField.hasPrefix("\"") && currentField.hasSuffix("\"") {
                    currentField = String(currentField.dropFirst().dropLast())
                    currentField = currentField.replacingOccurrences(of: "\"\"", with: "\"")
                }
                columns.append(currentField)
            }
            
            // Position is at index 0, Title is at index 5
            if columns.count > 5 {
                if let positionStr = columns[0].trimmingCharacters(in: .whitespaces).isEmpty ? nil : columns[0].trimmingCharacters(in: .whitespaces),
                   let position = Int(positionStr) {
                    var title = columns[5]
                    
                    // Remove year if in title (e.g., "Movie Title (2020)")
                    let yearPattern = #"\s*\(\d{4}\)\s*$"#
                    if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                        title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                    }
                    
                    title = title.trimmingCharacters(in: .whitespaces)
                    
                    if !title.isEmpty {
                        movies.append(ScrapedMovie(title: title, rank: position, sourceIdentifier: "", sourceTitle: nil))
                    }
                }
            }
        }
        
        return movies
    }
    
    func scrapeIMDbList(url: String) async throws -> [ScrapedMovie] {
        // Try CSV export first
        if let listId = extractIMDbListId(from: url) {
            do {
                let csvMovies = try await scrapeIMDbListCSV(listId: listId)
                if !csvMovies.isEmpty {
                    print("   ✅ Found \(csvMovies.count) movies via CSV export")
                    return csvMovies
                }
            } catch {
                print("   ⚠️ CSV export failed, trying HTML scraping...")
            }
        }
        
        // Fallback to HTML scraping
        guard let urlObj = URL(string: url) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard let htmlString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        var movies: [ScrapedMovie] = []
        var seenTitles = Set<String>()
        
        // Pattern 1: Extract from __NEXT_DATA__ JSON (most reliable for large lists)
        let scriptPattern = #"<script[^>]*id=["']__NEXT_DATA__["'][^>]*>(.*?)</script>"#
        if let regex = try? NSRegularExpression(pattern: scriptPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            
            for match in matches {
                if match.numberOfRanges > 1, let scriptRange = Range(match.range(at: 1), in: htmlString) {
                    let scriptContent = String(htmlString[scriptRange])
                    
                    if let jsonData = scriptContent.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        
                        // Navigate through Next.js structure: props.pageProps.contentData
                        if let props = jsonObject["props"] as? [String: Any],
                           let pageProps = props["pageProps"] as? [String: Any],
                           let contentData = pageProps["contentData"] as? [String: Any],
                           let entityMetadata = contentData["entityMetadata"] as? [[String: Any]] {
                            
                            for (index, item) in entityMetadata.enumerated() {
                                var title: String? = nil
                                
                                if let t = item["title"] as? String, !t.isEmpty {
                                    title = t
                                } else if let pt = item["primaryTitle"] as? String, !pt.isEmpty {
                                    title = pt
                                }
                                
                                if let movieTitle = title, !movieTitle.isEmpty {
                                    let rank = item["position"] as? Int ?? (index + 1)
                                    let normalized = movieTitle.lowercased()
                                    if !seenTitles.contains(normalized) {
                                        seenTitles.insert(normalized)
                                        movies.append(ScrapedMovie(title: movieTitle, rank: rank, sourceIdentifier: "", sourceTitle: nil))
                                    }
                                }
                            }
                        }
                        
                        // Fallback: recursively search JSON for title patterns
                        if movies.isEmpty {
                            var extractedTitles: [String] = []
                            extractTitlesFromJSON(jsonObject, seenTitles: &extractedTitles)
                            for (index, title) in extractedTitles.enumerated() {
                                if !seenTitles.contains(title.lowercased()) {
                                    seenTitles.insert(title.lowercased())
                                    movies.append(ScrapedMovie(title: title, rank: index + 1, sourceIdentifier: "", sourceTitle: nil))
                                }
                            }
                        }
                    } else {
                        // Fallback: extract titles using regex from JSON string
                        let titlePatterns = [
                            #""title"\s*:\s*"([^"]+)""#,
                            #""primaryTitle"\s*:\s*"([^"]+)""#,
                            #""name"\s*:\s*"([^"]+)""#
                        ]
                        
                        for pattern in titlePatterns {
                            if let titleRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                                let titleMatches = titleRegex.matches(in: scriptContent, range: NSRange(scriptContent.startIndex..., in: scriptContent))
                                for (index, titleMatch) in titleMatches.enumerated() {
                                    if titleMatch.numberOfRanges > 1, let titleRange = Range(titleMatch.range(at: 1), in: scriptContent) {
                                        var title = String(scriptContent[titleRange])
                                        title = title.replacingOccurrences(of: "\\\"", with: "\"")
                                        
                                        // Basic validation
                                        if title.count > 3 && title.count < 200 && !title.contains("http") {
                                            let normalized = title.lowercased()
                                            if !seenTitles.contains(normalized) && !normalized.contains("genre") && !normalized.contains("keyword") {
                                                seenTitles.insert(normalized)
                                                movies.append(ScrapedMovie(title: title, rank: index + 1, sourceIdentifier: "", sourceTitle: nil))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Pattern 2: Extract from title links (fallback)
        if movies.count < 50 {
            let titleLinkPattern = #"<a\s+href\s*=\s*["']?/title/tt\d+/["']?[^>]*>(.*?)</a>"#
            if let regex = try? NSRegularExpression(pattern: titleLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
                
                for (idx, match) in matches.enumerated() {
                    if match.numberOfRanges > 1, let titleRange = Range(match.range(at: 1), in: htmlString) {
                        var title = String(htmlString[titleRange])
                        title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Remove year patterns
                        let yearPattern = #"\s*\(\d{4}\)\s*$"#
                        if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                            title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                        }
                        
                        title = title.replacingOccurrences(of: "&#x27;", with: "'")
                        title = title.replacingOccurrences(of: "&amp;", with: "&")
                        
                        if !title.isEmpty && title.count < 200 {
                            let lowerTitle = title.lowercased()
                            if !seenTitles.contains(lowerTitle) {
                                seenTitles.insert(lowerTitle)
                                movies.append(ScrapedMovie(title: title, rank: idx + 1, sourceIdentifier: "", sourceTitle: nil))
                            }
                        }
                    }
                }
            }
        }
        
        // Sort by rank if available
        movies.sort { movie1, movie2 in
            if let rank1 = movie1.rank, let rank2 = movie2.rank {
                return rank1 < rank2
            }
            return false
        }
        
        return movies
    }
    
    // Helper to recursively extract titles from JSON
    private func extractTitlesFromJSON(_ obj: Any, seenTitles: inout [String]) {
        if let dict = obj as? [String: Any] {
            // Check for title fields
            if let title = dict["title"] as? String, !title.isEmpty && title.count > 3 && title.count < 200 {
                if !seenTitles.contains(title.lowercased()) {
                    seenTitles.append(title)
                }
            } else if let primaryTitle = dict["primaryTitle"] as? String, !primaryTitle.isEmpty && primaryTitle.count > 3 && primaryTitle.count < 200 {
                if !seenTitles.contains(primaryTitle.lowercased()) {
                    seenTitles.append(primaryTitle)
                }
            }
            
            // Recurse
            for (_, value) in dict {
                extractTitlesFromJSON(value, seenTitles: &seenTitles)
            }
        } else if let array = obj as? [Any] {
            for item in array {
                extractTitlesFromJSON(item, seenTitles: &seenTitles)
            }
        }
    }
    
    // MARK: - Wikipedia Criterion Scraping
    
    func scrapeWikipediaCriterion(url: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: url) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard let htmlString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        var movies: [ScrapedMovie] = []
        
        // Find the Criterion Collection 40 section
        let headingPattern = #"<h2[^>]*id=["']Criterion_Collection_40["'][^>]*>.*?</h2>"#
        if let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
           let headingMatch = headingRegex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)) {
            
            let sectionStart = htmlString.index(htmlString.startIndex, offsetBy: headingMatch.range.upperBound)
            let sectionEnd = htmlString.index(sectionStart, offsetBy: min(100000, htmlString.distance(from: sectionStart, to: htmlString.endIndex)), limitedBy: htmlString.endIndex) ?? htmlString.endIndex
            let section = String(htmlString[sectionStart..<sectionEnd])
            
            // Look for list items with movie titles in <i> tags
            let listItemPattern = #"<li[^>]*>.*?<i[^>]*>([^<]+)</i>.*?</li>"#
            if let regex = try? NSRegularExpression(pattern: listItemPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))
                
                for (index, match) in matches.enumerated() {
                    if match.numberOfRanges > 1, let titleRange = Range(match.range(at: 1), in: section) {
                        var title = String(section[titleRange])
                        title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Remove year patterns
                        let yearPattern = #"\s*\(\d{4}\)\s*$"#
                        if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                            title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                        }
                        
                        if !title.isEmpty && title.count > 1 && title.count < 200 && !title.contains("http") && index < 50 {
                            movies.append(ScrapedMovie(title: title, rank: index + 1, sourceIdentifier: "", sourceTitle: nil))
                        }
                    }
                }
            }
        }
        
        return movies
    }
    
    // MARK: - Podcast RSS Scraping
    
    func scrapePodcastRSS(rssURL: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: rssURL) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(httpResponse.statusCode) else { throw URLError(.badServerResponse) }
        guard let xmlString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        
        var movies: [ScrapedMovie] = []
        var seenTitles = Set<String>()
        
        // Parse RSS feed - split by <item> tags
        let items = xmlString.components(separatedBy: "<item>")
        
        for (index, item) in items.enumerated() {
            if index == 0 { continue } // Skip header
            
            // Extract episode title
            let titlePattern = #"<title[^>]*><!\[CDATA\[(.*?)\]\]></title>"#
            var episodeTitle: String? = nil
            
            // Try CDATA first
            if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)),
               match.numberOfRanges > 1,
               let titleRange = Range(match.range(at: 1), in: item) {
                episodeTitle = String(item[titleRange])
            } else {
                // Try regular title tag
                let simplePattern = #"<title[^>]*>([^<]+)</title>"#
                if let regex = try? NSRegularExpression(pattern: simplePattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: item, range: NSRange(item.startIndex..., in: item)),
                   match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: item) {
                    episodeTitle = String(item[titleRange])
                }
            }
            
            guard var title = episodeTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty else { continue }
            
            // Skip feed/podcast metadata
            if title.lowercased().contains("feed") || title.lowercased().contains("podcast") || title.count < 10 {
                continue
            }
            
            // Extract movie title from episode title
            let movieTitle = extractMovieTitleFromEpisode(title)
            
            if !movieTitle.isEmpty && movieTitle.count > 2 && movieTitle.count < 200 {
                let normalized = movieTitle.lowercased()
                if !seenTitles.contains(normalized) {
                    seenTitles.insert(normalized)
                    movies.append(ScrapedMovie(title: movieTitle, rank: nil, sourceIdentifier: "", sourceTitle: title))
                }
            }
        }
        
        return movies
    }
    
    func extractMovieTitleFromEpisode(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        
        // Pattern 1: Extract from quotes "'Movie Title'"
        let quotePattern = #"["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: quotePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1,
           let quoteRange = Range(match.range(at: 1), in: cleaned) {
            let quoted = String(cleaned[quoteRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            // Remove year if present
            let yearPattern = #"\s*\((\d{4})\)\s*$"#
            let withoutYear = (try? NSRegularExpression(pattern: yearPattern))?.stringByReplacingMatches(in: quoted, options: [], range: NSRange(quoted.startIndex..., in: quoted), withTemplate: "") ?? quoted
            if withoutYear.count > 3 && withoutYear.count < 100 {
                return withoutYear.trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Pattern 2: Remove common prefixes and suffixes
        let removePatterns = [
            #"^.*?:\s*"#,  // "Podcast Name: "
            #"\s*-\s*Episode.*$"#,  // " - Episode 123"
            #"\s*\(.*?\)\s*$"#,  // "(1999)" at end
            #"\s*\[.*?\]\s*$"#,  // "[Review]" at end
            #"\s*With\s+.*$"#,  // " With Bill Simmons"
        ]
        
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Final validation
        if cleaned.count < 3 || cleaned.count > 100 {
            return ""
        }
        
        // Skip if it's clearly not a movie title
        let skipKeywords = ["episode", "podcast", "with", "featuring", "guest"]
        let lowerCleaned = cleaned.lowercased()
        if skipKeywords.contains(where: { lowerCleaned.contains($0) }) && cleaned.count < 30 {
            return ""
        }
        
        return cleaned
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Main Script

func fillBootstrapGaps() async {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("📊 Filling Bootstrap Database Gaps\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          var bootstrapData = try? JSONDecoder().decode(BootstrapData.self, from: data) else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded existing bootstrap data")
    print("   Sources: \(bootstrapData.dataSources.count)")
    print("   Movies: \(bootstrapData.movies.count)")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup: bootstrap_data_backup.json")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    let scraper = GapFillingScraper()
    
    // Get existing movie titles per source
    var existingMoviesBySource: [String: Set<String>] = [:]
    for movie in bootstrapData.movies {
        let normalizedTitle = movie.title.lowercased().trimmingCharacters(in: .whitespaces)
        existingMoviesBySource[movie.sourceIdentifier, default: []].insert(normalizedTitle)
    }
    
    print("\n" + String(repeating: "=", count: 70))
    print("🔍 SCRAPING MISSING DATA")
    print(String(repeating: "=", count: 70))
    
    var newMoviesAdded = 0
    var sourcesUpdated = 0
    
    for config in scraper.sourcesToFill {
        print("\n📋 Processing: \(config.name)")
        print("   URL: \(config.url)")
        
        let existingCount = existingMoviesBySource[config.identifier]?.count ?? 0
        let targetCount = config.expectedCount > 0 ? config.expectedCount : (config.minCount ?? 0)
        let isComplete: Bool
        let gap: Int
        
        if let minCount = config.minCount {
            // For podcasts with minimum counts
            isComplete = existingCount >= minCount
            gap = max(0, minCount - existingCount)
            print("   Current: \(existingCount) | Minimum: \(minCount)")
        } else {
            // For exact counts
            isComplete = existingCount >= config.expectedCount
            gap = max(0, config.expectedCount - existingCount)
            print("   Current: \(existingCount) | Expected: \(config.expectedCount)")
        }
        
        if isComplete {
            print("   ✅ Already complete!")
            continue
        }
        
        print("   Scraping missing \(gap) entries...")
        
        do {
            var scrapedMovies: [ScrapedMovie] = []
            
            if config.type == "podcast" || config.url.contains("feeds.megaphone.fm") {
                scrapedMovies = try await scraper.scrapePodcastRSS(rssURL: config.url)
            } else if config.url.contains("rottentomatoes.com") {
                scrapedMovies = try await scraper.scrapeRottenTomatoesGuide(url: config.url)
            } else if config.url.contains("imdb.com/list/") {
                scrapedMovies = try await scraper.scrapeIMDbList(url: config.url)
            } else if config.url.contains("wikipedia.org") {
                scrapedMovies = try await scraper.scrapeWikipediaCriterion(url: config.url)
            }
            
            print("   ✅ Scraped \(scrapedMovies.count) movies")
            
            // Convert to BootstrapMovie and filter out duplicates
            var newMovies: [BootstrapMovie] = []
            let existingTitles = existingMoviesBySource[config.identifier] ?? []
            
            for scraped in scrapedMovies {
                let normalizedTitle = scraped.title.lowercased().trimmingCharacters(in: .whitespaces)
                
                // Check if we already have this movie from this source
                if !existingTitles.contains(normalizedTitle) {
                    let bootstrapMovie = BootstrapMovie(
                        title: scraped.title,
                        sourceIdentifier: config.identifier,
                        rank: scraped.rank,
                        sourceTitle: scraped.sourceTitle,
                        tmdbId: nil,
                        year: nil,
                        posterPath: nil,
                        backdropPath: nil,
                        overview: nil,
                        mpaaRating: nil,
                        genres: nil,
                        streamingServices: nil,
                        credits: nil,
                        trailer: nil,
                        podcastEpisodeDescription: nil
                    )
                    newMovies.append(bootstrapMovie)
                    existingMoviesBySource[config.identifier, default: []].insert(normalizedTitle)
                }
            }
            
            if !newMovies.isEmpty {
                bootstrapData.movies.append(contentsOf: newMovies)
                newMoviesAdded += newMovies.count
                print("   ✅ Added \(newMovies.count) new movies")
            } else {
                print("   ℹ️  No new movies to add (all duplicates)")
            }
            
            // Update or create source
            if let sourceIndex = bootstrapData.dataSources.firstIndex(where: { $0.identifier == config.identifier }) {
                let newCount = existingMoviesBySource[config.identifier]?.count ?? 0
                bootstrapData.dataSources[sourceIndex].movieCount = newCount
                sourcesUpdated += 1
                print("   ✅ Updated source: \(newCount) movies")
            } else {
                // Create new source
                let newSource = BootstrapDataSource(
                    identifier: config.identifier,
                    name: config.name,
                    type: config.type,
                    url: config.url,
                    isRankedList: config.isRanked,
                    movieCount: newMovies.count
                )
                bootstrapData.dataSources.append(newSource)
                sourcesUpdated += 1
                print("   ✅ Created new source")
            }
            
        } catch {
            print("   ❌ Error scraping: \(error.localizedDescription)")
        }
    }
    
    // Update generated date
    bootstrapData.generatedDate = ISO8601DateFormatter().string(from: Date())
    
    // Save updated bootstrap data
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING UPDATED DATA")
    print(String(repeating: "=", count: 70))
    
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved updated bootstrap_data.json")
        print("   Sources: \(bootstrapData.dataSources.count)")
        print("   Total Movies: \(bootstrapData.movies.count)")
        print("   New Movies Added: \(newMoviesAdded)")
        print("   Sources Updated: \(sourcesUpdated)")
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

// Run
Task {
    await fillBootstrapGaps()
    exit(0)
}

RunLoop.main.run()

