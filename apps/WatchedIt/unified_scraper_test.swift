#!/usr/bin/env swift

import Foundation

/// Structure to hold a movie title with its rank in a ranked list
struct ScrapedMovie {
    let title: String
    let rank: Int?
}

/// Unified scraping service for IMDb lists and RT editorial guide pages
class UnifiedScrapingService {
    
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
    
    func extractRankAndCleanTitle(from rawTitle: String, index: Int) -> (cleanedTitle: String, rank: Int?) {
        // Extract rank - look for patterns like "1. ", "#2 ", "2) ", "(2) "
        var rank: Int? = nil
        
        let patterns = [
            (#"^(\d+)\.\s+"#, 1),  // "1. "
            (#"^#(\d+)\s+"#, 1),   // "#2 "
            (#"^(\d+)\)\s+"#, 1),  // "2) "
            (#"^\((\d+)\)\s+"#, 1), // "(2) "
            (#"^(\d+)[:–\-\s]+\s*([A-Z])"#, 1), // "1: " or "1 - "
        ]
        
        for (pattern, group) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: rawTitle, range: NSRange(rawTitle.startIndex..., in: rawTitle)),
               match.numberOfRanges > group,
               let rankRange = Range(match.range(at: group), in: rawTitle),
               let extractedRank = Int(String(rawTitle[rankRange])) {
                rank = extractedRank
                break
            }
        }
        
        // Clean title - remove list numbering patterns
        var cleaned = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let removePatterns = [
            #"^(\d+)\.\s+"#,
            #"^#(\d+)\s+"#,
            #"^(\d+)\)\s+"#,
            #"^\((\d+)\)\s+"#,
            #"^(\d+)[:–\-]\s+"#,
        ]
        
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
               let range = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[range.upperBound...])
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        
        // Decode HTML entities
        cleaned = cleaned.replacingOccurrences(of: "&#x27;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        
        return (cleaned, rank)
    }
    
    func scrapeIMDbList(url: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 IMDb: HTTP Status: \(httpResponse.statusCode), Size: \(data.count) bytes")
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        print("📄 IMDb: HTML length: \(htmlString.count) characters")
        
        var allTitles: Set<String> = []
        var movies: [ScrapedMovie] = []
        
        // Pattern 1: Extract from title links (/title/tt...)
        print("\n🔍 Pattern 1: Title links (/title/tt...)")
        let titleLinkPattern = #"<a\s+href\s*=\s*["']?/title/tt\d+/["']?[^>]*>(.*?)</a>"#
        if let regex = try? NSRegularExpression(pattern: titleLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) matches")
            
            for (idx, match) in matches.enumerated() {
                if match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: htmlString) {
                    var title = String(htmlString[titleRange])
                    title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove year
                    let yearPattern = #"\s*\(\d{4}\)\s*$"#
                    if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                        title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                    }
                    
                    let (cleanedTitle, rank) = extractRankAndCleanTitle(from: title, index: idx + 1)
                    
                    if !cleanedTitle.isEmpty && cleanedTitle.count < 200 && !allTitles.contains(cleanedTitle.lowercased()) {
                        allTitles.insert(cleanedTitle.lowercased())
                        movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                        if movies.count <= 5 || movies.count % 20 == 0 {
                            print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " (rank: \(rank!))" : "")")
                        }
                    }
                }
            }
            print("   ✅ Pattern 1 total: \(movies.count) movies")
        }
        
        // Pattern 5: Extract ALL movie titles from __NEXT_DATA__ JSON (they're scattered throughout)
        print("\n🔍 Pattern 2: __NEXT_DATA__ script tags (extracting all titles from JSON)")
        let scriptPattern = #"<script[^>]*id=["']__NEXT_DATA__["'][^>]*>(.*?)</script>"#
        if let regex = try? NSRegularExpression(pattern: scriptPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) __NEXT_DATA__ script tags")
            
            for match in matches {
                if match.numberOfRanges > 1,
                   let scriptRange = Range(match.range(at: 1), in: htmlString) {
                    let scriptContent = String(htmlString[scriptRange])
                    
                    // Try to parse as JSON and extract ALL titles recursively
                    if let jsonData = scriptContent.data(using: .utf8) {
                        do {
                            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                // Check totalItems first
                                var totalItems = 0
                                if let props = jsonObject["props"] as? [String: Any],
                                   let pageProps = props["pageProps"] as? [String: Any] {
                                    totalItems = pageProps["totalItems"] as? Int ?? 0
                                    if totalItems > 0 {
                                        print("   📊 Total items in list: \(totalItems)")
                                    }
                                }
                                
                                // Extract all titles recursively from the JSON
                                var extractedTitles: [(title: String, rank: Int?)] = []
                                var seenTitles = Set<String>()
                                extractTitlesFromJSON(jsonObject, seenTitles: &seenTitles, extractedTitles: &extractedTitles)
                                
                                print("   🔍 Found \(extractedTitles.count) titles in JSON structure")
                                
                                // Sort by rank if available
                                extractedTitles.sort { (a, b) in
                                    if let rankA = a.rank, let rankB = b.rank {
                                        return rankA < rankB
                                    } else if a.rank != nil {
                                        return true
                                    } else if b.rank != nil {
                                        return false
                                    }
                                    return false
                                }
                                
                                var pattern2Count = 0
                                for (titleStr, rank) in extractedTitles {
                                    if !titleStr.isEmpty && titleStr.count > 3 && titleStr.count < 200 {
                                        let (cleanedTitle, extractedRank) = extractRankAndCleanTitle(from: titleStr, index: rank ?? 0)
                                        
                                        if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                                            // Filter out obvious non-movie titles
                                            let lowerTitle = cleanedTitle.lowercased()
                                            if !lowerTitle.contains("loadads") &&
                                               !lowerTitle.contains("clickto") &&
                                               !lowerTitle.contains("helvetica") &&
                                               !lowerTitle.hasPrefix("{") &&
                                               !lowerTitle.hasPrefix("}") &&
                                               cleanedTitle != "0" && cleanedTitle != "255" &&
                                               !lowerTitle.contains("genre") &&
                                               !lowerTitle.contains("keyword") {
                                                allTitles.insert(cleanedTitle.lowercased())
                                                movies.append(ScrapedMovie(title: cleanedTitle, rank: extractedRank ?? rank))
                                                pattern2Count += 1
                                                if pattern2Count <= 10 || pattern2Count % 25 == 0 {
                                                    print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " [Rank: \(rank!)]" : "")")
                                                }
                                            }
                                        }
                                    }
                                }
                                print("   ✅ Pattern 2 added: \(pattern2Count) new movies (total: \(movies.count))")
                            }
                        } catch {
                            print("   ⚠️ JSON parsing failed: \(error)")
                        }
                    }
                }
            }
        }
        
        return movies
    }
    
    /// Recursively extract movie titles from JSON structure
    private func extractTitlesFromJSON(_ obj: Any, seenTitles: inout Set<String>, extractedTitles: inout [(title: String, rank: Int?)], currentRank: Int? = nil) {
        if let dict = obj as? [String: Any] {
            // Check for title fields
            var foundTitle: String? = nil
            var foundRank: Int? = currentRank
            
            if let title = dict["title"] as? String, !title.isEmpty {
                foundTitle = title
            } else if let titleText = dict["titleText"] as? [String: Any],
                      let text = titleText["text"] as? String, !text.isEmpty {
                foundTitle = text
            } else if let primaryTitle = dict["primaryTitle"] as? String, !primaryTitle.isEmpty {
                foundTitle = primaryTitle
            } else if let name = dict["name"] as? String, !name.isEmpty {
                // Only treat as title if it looks like a movie title (not a genre/keyword)
                if name.count > 5 && name.count < 100 && !name.contains(",") {
                    foundTitle = name
                }
            }
            
            // Check for rank/position
            if foundRank == nil {
                foundRank = dict["position"] as? Int ?? dict["rank"] as? Int
            }
            
            if let title = foundTitle, !seenTitles.contains(title.lowercased()) {
                seenTitles.insert(title.lowercased())
                extractedTitles.append((title: title, rank: foundRank))
            }
            
            // Recurse into all values
            for (_, value) in dict {
                extractTitlesFromJSON(value, seenTitles: &seenTitles, extractedTitles: &extractedTitles, currentRank: foundRank)
            }
        } else if let array = obj as? [Any] {
            for (index, item) in array.enumerated() {
                let rank = currentRank ?? (index + 1)
                extractTitlesFromJSON(item, seenTitles: &seenTitles, extractedTitles: &extractedTitles, currentRank: rank)
            }
        }
    }
    
    // MARK: - Rotten Tomatoes Scraping
    
    func scrapeRottenTomatoesGuide(url: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 RT: HTTP Status: \(httpResponse.statusCode), Size: \(data.count) bytes")
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        print("📄 RT: HTML length: \(htmlString.count) characters")
        
        var allTitles: Set<String> = []
        var movies: [ScrapedMovie] = []
        
        // Pattern 1: Extract from RT movie links (href contains /m/ and link text is the movie title)
        print("\n🔍 RT Pattern 1: Movie links (rottentomatoes.com/m/...)")
        let rtMovieLinkPattern = #"<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/[^"']*["'][^>]*>([^<]+)</a>"#
        if let regex = try? NSRegularExpression(pattern: rtMovieLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) matches")
            
            var movieCount = 0
            for match in matches {
                if match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: htmlString) {
                    var title = String(htmlString[titleRange])
                    
                    // Skip "[More]" links and navigation
                    if title.contains("[More]") || title.trimmingCharacters(in: .whitespaces).isEmpty {
                        continue
                    }
                    
                    // Remove HTML tags if any
                    title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Decode HTML entities
                    title = title.replacingOccurrences(of: "&#039;", with: "'")
                    title = title.replacingOccurrences(of: "&#x27;", with: "'")
                    title = title.replacingOccurrences(of: "&amp;", with: "&")
                    title = title.replacingOccurrences(of: "&quot;", with: "\"")
                    
                    // Check if title looks valid
                    if !title.isEmpty && title.count > 2 && title.count < 200 {
                        // Try to find rank from context - look backwards for numbered patterns
                        var rank: Int? = nil
                        let matchStart = htmlString.index(htmlString.startIndex, offsetBy: match.range.location)
                        let contextStart = htmlString.index(matchStart, offsetBy: -200, limitedBy: htmlString.startIndex) ?? htmlString.startIndex
                        let context = String(htmlString[contextStart..<matchStart])
                        
                        // Look for number patterns before the link
                        let rankPatterns = [
                            #"(\d+)\.\s*<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/"#,
                            #"#(\d+).*?<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/"#,
                            #"\((\d+)\).*?<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/"#,
                        ]
                        
                        for pattern in rankPatterns {
                            if let rankRegex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                               let rankMatch = rankRegex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
                               rankMatch.numberOfRanges > 1,
                               let rankRange = Range(rankMatch.range(at: 1), in: context),
                               let rankValue = Int(String(context[rankRange])) {
                                rank = rankValue
                                break
                            }
                        }
                        
                        // If no rank found, use order of appearance
                        if rank == nil {
                            movieCount += 1
                            rank = movieCount
                        }
                        
                        let (cleanedTitle, extractedRank) = extractRankAndCleanTitle(from: title, index: rank ?? 0)
                        
                        if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                            allTitles.insert(cleanedTitle.lowercased())
                            movies.append(ScrapedMovie(title: cleanedTitle, rank: extractedRank ?? rank))
                            if movies.count <= 5 || movies.count % 10 == 0 {
                                print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " [Rank: \(rank!)]" : "")")
                            }
                        }
                    }
                }
            }
            print("   ✅ Pattern 1 total: \(movies.count) movies")
        }
        
        // Pattern 2: Look for numbered headings (h1, h2, h3) in article body
        print("\n🔍 RT Pattern 2: Numbered headings in article body")
        let headingPattern = #"<h[1-6][^>]*>\s*(\d+)\.\s*([^<]+)</h[1-6]>"#
        if let regex = try? NSRegularExpression(pattern: headingPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) numbered headings")
            
            var pattern2Count = 0
            for match in matches {
                if match.numberOfRanges > 2,
                   let rankRange = Range(match.range(at: 1), in: htmlString),
                   let titleRange = Range(match.range(at: 2), in: htmlString) {
                    let rankStr = String(htmlString[rankRange])
                    let title = String(htmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let rank = Int(rankStr), !title.isEmpty && title.count > 2 && title.count < 200 {
                        let (cleanedTitle, _) = extractRankAndCleanTitle(from: title, index: rank)
                        
                        if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                            allTitles.insert(cleanedTitle.lowercased())
                            movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                            pattern2Count += 1
                            if pattern2Count <= 5 {
                                print("   \(movies.count). \(cleanedTitle) [Rank: \(rank)]")
                            }
                        }
                    }
                }
            }
            print("   ✅ Pattern 2 added: \(pattern2Count) new movies (total: \(movies.count))")
        }
        
        return movies
    }
    
    // MARK: - Netflix Scraping
    
    func scrapeNetflixTop10(url: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 Netflix: HTTP Status: \(httpResponse.statusCode), Size: \(data.count) bytes")
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        print("📄 Netflix: HTML length: \(htmlString.count) characters")
        
        var allTitles: Set<String> = []
        var movies: [ScrapedMovie] = []
        
        // Pattern 1: Extract from Netflix Top 10 table rows
        // Structure: <tr><td class="title"><span class="rank">01</span>...<button>Title</button></td>
        print("\n🔍 Netflix Pattern 1: Top 10 table rows")
        let netflixRowPattern = #"<tr[^>]*>.*?<span[^>]*class=["']rank["'][^>]*>(\d+)</span>.*?<button[^>]*>([^<]+)</button>"#
        if let regex = try? NSRegularExpression(pattern: netflixRowPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) matches")
            
            for match in matches {
                if match.numberOfRanges > 2,
                   let rankRange = Range(match.range(at: 1), in: htmlString),
                   let titleRange = Range(match.range(at: 2), in: htmlString) {
                    let rankStr = String(htmlString[rankRange])
                    var title = String(htmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Decode HTML entities
                    title = title.replacingOccurrences(of: "&#039;", with: "'")
                    title = title.replacingOccurrences(of: "&#x27;", with: "'")
                    title = title.replacingOccurrences(of: "&amp;", with: "&")
                    title = title.replacingOccurrences(of: "&quot;", with: "\"")
                    
                    if let rank = Int(rankStr), !title.isEmpty && title.count > 2 && title.count < 200 {
                        let (cleanedTitle, _) = extractRankAndCleanTitle(from: title, index: rank)
                        
                        if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                            allTitles.insert(cleanedTitle.lowercased())
                            movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                            if movies.count <= 5 || movies.count % 5 == 0 {
                                print("   \(movies.count). \(cleanedTitle) [Rank: \(rank)]")
                            }
                        }
                    }
                }
            }
            print("   ✅ Pattern 1 total: \(movies.count) movies")
        }
        
        // Pattern 2: Alternative pattern - data-uia="top10-table-row-title" with rank and title
        if movies.isEmpty {
            print("\n🔍 Netflix Pattern 2: data-uia table rows")
            let netflixDataUiaPattern = #"data-uia=["']top10-table-row-title["'][^>]*>.*?<span[^>]*class=["']rank["'][^>]*>(\d+)</span>.*?<button[^>]*>([^<]+)</button>"#
            if let regex = try? NSRegularExpression(pattern: netflixDataUiaPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
                print("   Found \(matches.count) matches")
                
                for match in matches {
                    if match.numberOfRanges > 2,
                       let rankRange = Range(match.range(at: 1), in: htmlString),
                       let titleRange = Range(match.range(at: 2), in: htmlString) {
                        let rankStr = String(htmlString[rankRange])
                        var title = String(htmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Decode HTML entities
                        title = title.replacingOccurrences(of: "&#039;", with: "'")
                        title = title.replacingOccurrences(of: "&#x27;", with: "'")
                        title = title.replacingOccurrences(of: "&amp;", with: "&")
                        title = title.replacingOccurrences(of: "&quot;", with: "\"")
                        
                        if let rank = Int(rankStr), !title.isEmpty && title.count > 2 && title.count < 200 {
                            let (cleanedTitle, _) = extractRankAndCleanTitle(from: title, index: rank)
                            
                            if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                                allTitles.insert(cleanedTitle.lowercased())
                                movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                            }
                        }
                    }
                }
                print("   ✅ Pattern 2 added: \(movies.count) new movies (total: \(movies.count))")
            }
        }
        
        return movies
    }
    
    // MARK: - Unified Entry Point
    
    func scrapeURL(url: String) async throws -> [ScrapedMovie] {
        print("🚀 Starting unified scraping service...")
        print("📍 URL: \(url)")
        print(String(repeating: "=", count: 80) + "\n")
        
        if url.contains("imdb.com/list/") || url.contains("imdb.com/chart/") {
            print("🎬 Detected IMDb list/chart URL")
            return try await scrapeIMDbList(url: url)
        } else if url.contains("rottentomatoes.com") && url.contains("/guide/") {
            print("🍅 Detected Rotten Tomatoes editorial guide URL")
            return try await scrapeRottenTomatoesGuide(url: url)
        } else if url.contains("netflix.com") && url.contains("top10") {
            print("📺 Detected Netflix Top 10 URL")
            return try await scrapeNetflixTop10(url: url)
        } else {
            throw URLError(.unsupportedURL)
        }
    }
    
    func saveResults(_ movies: [ScrapedMovie], to filePath: String) throws {
        var output = "Total movies found: \(movies.count)\n\n"
        
        for (index, movie) in movies.enumerated() {
            output += "\(index + 1). \(movie.title)"
            if let rank = movie.rank {
                output += " [Rank: \(rank)]"
            }
            output += "\n"
        }
        
        try output.write(toFile: filePath, atomically: true, encoding: .utf8)
        print("\n💾 Results saved to: \(filePath)")
    }
}

// Main execution
let url = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "https://www.imdb.com/list/ls058479560/"
let outputFile = "/Users/carambula/Documents/WatchedIt/scrape_results.txt"

let service = UnifiedScrapingService()

Task {
    do {
        let movies = try await service.scrapeURL(url: url)
        
        print("\n" + String(repeating: "=", count: 80))
        print("📊 FINAL RESULTS:")
        print("   Total movies found: \(movies.count)")
        
        let withRanks = movies.filter { $0.rank != nil }.count
        print("   Movies with ranks: \(withRanks)")
        
        if !movies.isEmpty {
            print("\n📋 Sample movies:")
            for (index, movie) in movies.prefix(10).enumerated() {
                print("   \(index + 1). \(movie.title)\(movie.rank != nil ? " [Rank: \(movie.rank!)]" : "")")
            }
            
            try service.saveResults(movies, to: outputFile)
        } else {
            print("❌ No movies found!")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()

