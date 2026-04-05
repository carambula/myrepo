#!/usr/bin/env swift

import Foundation

/// Structure to hold a movie title with its rank in a ranked list
struct ScrapedMovie {
    let title: String
    let rank: Int?
}

/// Debug script to test IMDb list scraping
class IMDbScraperDebugger {
    
    func extractIMDbListId(from url: String) -> String? {
        // IMDb list URLs: https://www.imdb.com/list/ls058479560/
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
        // Try CSV export - IMDb list export endpoint
        // Try multiple URL formats
        let csvURLs = [
            "https://www.imdb.com/list/export?list_id=\(listId)",
            "https://www.imdb.com/list/export?list_id=\(listId)&author_id=",
            "https://www.imdb.com/list/ls\(listId)/export",
        ]
        
        for csvURLString in csvURLs {
            guard let csvURL = URL(string: csvURLString) else { continue }
            
            var request = URLRequest(url: csvURL)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }
                
                print("   📄 CSV URL: \(csvURLString)")
                print("   📡 Status: \(httpResponse.statusCode), Size: \(data.count) bytes")
                
                // Check if it's actually CSV
                if let contentDisposition = httpResponse.value(forHTTPHeaderField: "Content-Disposition"),
                   contentDisposition.contains(".csv") || contentDisposition.contains("attachment") {
                    // This looks like a CSV download
                }
                
                guard let csvString = String(data: data, encoding: .utf8), !csvString.isEmpty else {
                    continue
                }
                
                // Check if it's actually CSV (starts with Position and has proper CSV structure)
                // Must start with "Position" and have at least 2 lines with comma separation
                let isCSV = csvString.hasPrefix("Position") || 
                           (csvString.contains("Position,") && csvString.components(separatedBy: "\n").count > 2)
                
                if isCSV && !csvString.contains("<!DOCTYPE") && !csvString.contains("<html") {
                    print("   ✅ Found CSV content!")
                    
                    var movies: [ScrapedMovie] = []
                    let lines = csvString.components(separatedBy: .newlines)
                    
                    print("   📄 CSV has \(lines.count) lines")
                    
                    // Skip header line if present
                    let startIndex = lines.first?.lowercased().contains("position") == true ? 1 : 0
                    
                    for (index, line) in lines[startIndex...].enumerated() {
                        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                        
                        // Parse CSV - handle quoted fields properly
                        var fields: [String] = []
                        var currentField = ""
                        var inQuotes = false
                        
                        for char in line {
                            if char == "\"" {
                                inQuotes.toggle()
                            } else if char == "," && !inQuotes {
                                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                                currentField = ""
                            } else {
                                currentField.append(char)
                            }
                        }
                        fields.append(currentField.trimmingCharacters(in: .whitespaces)) // Last field
                        
                        if fields.count >= 2 {
                            // Position is usually first column, title is usually second
                            let positionStr = fields[0].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            let title = fields[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            
                            if !title.isEmpty && title.count > 1 && title.count < 200 {
                                let position = Int(positionStr) ?? (index + 1)
                                movies.append(ScrapedMovie(title: title, rank: position))
                            }
                        }
                    }
                    
                    if !movies.isEmpty {
                        return movies
                    }
                } else {
                    print("   ⚠️ Response doesn't look like CSV")
                }
            } catch {
                // Try next URL
                continue
            }
        }
        
        throw URLError(.cannotDecodeContentData)
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
        
        return (cleaned, rank)
    }
    
    func scrapeIMDbList(url: String) async throws -> [ScrapedMovie] {
        guard let urlObj = URL(string: url) else {
            throw URLError(.badURL)
        }
        
        // Try CSV export first - it might work for getting all items
        if let listId = extractIMDbListId(from: url) {
            print("📋 Trying CSV export for list ID: \(listId)")
            do {
                let csvMovies = try await scrapeIMDbListCSV(listId: listId)
                if csvMovies.count > 25 { // Only use CSV if it gives us more than HTML
                    print("✅ CSV export found \(csvMovies.count) movies (more than HTML)")
                    return csvMovies
                } else {
                    print("⚠️ CSV export only found \(csvMovies.count) movies, using HTML scraping instead")
                }
            } catch {
                print("⚠️ CSV export failed: \(error), using HTML scraping instead")
            }
        }
        
        // Create a request with proper headers
        var request = URLRequest(url: urlObj)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("📡 HTTP Status: \(httpResponse.statusCode), Size: \(data.count) bytes")
        
        guard let htmlString = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        print("📄 HTML length: \(htmlString.count) characters")
        
        var allTitles: Set<String> = [] // Use Set to track unique titles
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
        
        // Pattern 2: Extract from h3 tags with class "lister-item-header"
        print("\n🔍 Pattern 2: h3.lister-item-header")
        let h3Pattern = #"<h3[^>]*class=["'][^"']*lister-item-header[^"']*["'][^>]*>.*?<a[^>]*>([^<]+)</a>"#
        if let regex = try? NSRegularExpression(pattern: h3Pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) matches")
            
            var pattern2Count = 0
            for (idx, match) in matches.enumerated() {
                if match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: htmlString) {
                    var title = String(htmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove year
                    let yearPattern = #"\s*\(\d{4}\)\s*$"#
                    if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                        title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                    }
                    
                    let (cleanedTitle, rank) = extractRankAndCleanTitle(from: title, index: movies.count + pattern2Count + 1)
                    
                    if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                        allTitles.insert(cleanedTitle.lowercased())
                        movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                        pattern2Count += 1
                        if pattern2Count <= 5 {
                            print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " (rank: \(rank!))" : "")")
                        }
                    }
                }
            }
            print("   ✅ Pattern 2 added: \(pattern2Count) new movies (total: \(movies.count))")
        }
        
        // Pattern 3: Extract from div with data-testid="title-link"
        print("\n🔍 Pattern 3: data-testid=\"title-link\"")
        let dataTestIdPattern = #"<a[^>]*data-testid=["']title-link["'][^>]*>([^<]+)</a>"#
        if let regex = try? NSRegularExpression(pattern: dataTestIdPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) matches")
            
            var pattern3Count = 0
            for (idx, match) in matches.enumerated() {
                if match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: htmlString) {
                    var title = String(htmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove year
                    let yearPattern = #"\s*\(\d{4}\)\s*$"#
                    if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                        title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                    }
                    
                    let (cleanedTitle, rank) = extractRankAndCleanTitle(from: title, index: movies.count + pattern3Count + 1)
                    
                    if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                        allTitles.insert(cleanedTitle.lowercased())
                        movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                        pattern3Count += 1
                        if pattern3Count <= 5 {
                            print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " (rank: \(rank!))" : "")")
                        }
                    }
                }
            }
            print("   ✅ Pattern 3 added: \(pattern3Count) new movies (total: \(movies.count))")
        }
        
        // Pattern 4: Look for ordered list items
        print("\n🔍 Pattern 4: Ordered list items (<ol> or <li>)")
        let liPattern = #"<li[^>]*>.*?<a[^>]*href\s*=\s*["']?/title/tt\d+[^>]*>([^<]+)</a>"#
        if let regex = try? NSRegularExpression(pattern: liPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) matches")
            
            var pattern4Count = 0
            for (idx, match) in matches.enumerated() {
                if match.numberOfRanges > 1,
                   let titleRange = Range(match.range(at: 1), in: htmlString) {
                    var title = String(htmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    
                    let (cleanedTitle, rank) = extractRankAndCleanTitle(from: title, index: movies.count + pattern4Count + 1)
                    
                    if !cleanedTitle.isEmpty && !allTitles.contains(cleanedTitle.lowercased()) {
                        allTitles.insert(cleanedTitle.lowercased())
                        movies.append(ScrapedMovie(title: cleanedTitle, rank: rank))
                        pattern4Count += 1
                        if pattern4Count <= 5 {
                            print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " (rank: \(rank!))" : "")")
                        }
                    }
                }
            }
            print("   ✅ Pattern 4 added: \(pattern4Count) new movies (total: \(movies.count))")
        }
        
        // Pattern 5: Extract ALL movie titles from __NEXT_DATA__ JSON (they're scattered throughout)
        print("\n🔍 Pattern 5: __NEXT_DATA__ script tags (extracting all titles from JSON)")
        let scriptPattern = #"<script[^>]*id=["']__NEXT_DATA__["'][^>]*>(.*?)</script>"#
        if let regex = try? NSRegularExpression(pattern: scriptPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
            print("   Found \(matches.count) __NEXT_DATA__ script tags")
            
            for match in matches {
                if match.numberOfRanges > 1,
                   let scriptRange = Range(match.range(at: 1), in: htmlString) {
                    let scriptContent = String(htmlString[scriptRange])
                    
                    // Save JSON to file for inspection
                    let jsonFile = "/Users/carambula/Documents/WatchedIt/imdb_next_data.json"
                    try? scriptContent.write(toFile: jsonFile, atomically: true, encoding: .utf8)
                    print("   💾 Saved JSON to: \(jsonFile)")
                    
                    // Try to parse as JSON and extract ALL titles recursively
                    if let jsonData = scriptContent.data(using: .utf8) {
                        do {
                            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                // Check totalItems first
                                var totalItems = 0
                                if let props = jsonObject["props"] as? [String: Any],
                                   let pageProps = props["pageProps"] as? [String: Any] {
                                    totalItems = pageProps["totalItems"] as? Int ?? 0
                                    print("   📊 Total items in list: \(totalItems)")
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
                                
                                var pattern5Count = 0
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
                                               cleanedTitle != "0" && cleanedTitle != "255" {
                                                allTitles.insert(cleanedTitle.lowercased())
                                                movies.append(ScrapedMovie(title: cleanedTitle, rank: extractedRank ?? rank))
                                                pattern5Count += 1
                                                if pattern5Count <= 10 || pattern5Count % 25 == 0 {
                                                    print("   \(movies.count). \(cleanedTitle)\(rank != nil ? " [Rank: \(rank!)]" : "")")
                                                }
                                            }
                                        }
                                    }
                                }
                                print("   ✅ Pattern 5 added: \(pattern5Count) new movies (total: \(movies.count))")
                            }
                        } catch {
                            print("   ⚠️ JSON parsing failed: \(error)")
                        }
                    }
                }
            }
        }
        
        // If we didn't get all items, try pagination
        if movies.count < 105 {
            print("\n🔄 Attempting pagination to fetch all items...")
            print("   Currently have \(movies.count) movies, trying to fetch more...")
            
            // IMDb lists load 25 items per page
            let itemsPerPage = 25
            let estimatedTotal = 105
            let totalPages = (estimatedTotal + itemsPerPage - 1) / itemsPerPage
            let startPage = (movies.count / itemsPerPage) + 1
            
            if startPage <= totalPages {
                print("   Fetching pages \(startPage)-\(totalPages)...")
                
                for page in startPage...totalPages {
                    let pageURL = "\(url)?page=\(page)&mode=detail"
                    print("   📄 Fetching page \(page)...")
                    
                    do {
                        var pageRequest = URLRequest(url: URL(string: pageURL)!)
                        pageRequest.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
                        
                        let (pageData, _) = try await URLSession.shared.data(for: pageRequest)
                        if let pageHTML = String(data: pageData, encoding: .utf8) {
                            // Extract titles from this page using Pattern 1
                            let titleLinkPattern = #"<a\s+href\s*=\s*["']?/title/tt\d+/["']?[^>]*>(.*?)</a>"#
                            if let regex = try? NSRegularExpression(pattern: titleLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                                let matches = regex.matches(in: pageHTML, range: NSRange(pageHTML.startIndex..., in: pageHTML))
                                var pageCount = 0
                                
                                for (idx, match) in matches.enumerated() {
                                    if match.numberOfRanges > 1,
                                       let titleRange = Range(match.range(at: 1), in: pageHTML) {
                                        var title = String(pageHTML[titleRange])
                                        title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                                        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                        
                                        // Remove year
                                        let yearPattern = #"\s*\(\d{4}\)\s*$"#
                                        if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                                            title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                                        }
                                        
                                        let rank = (page - 1) * itemsPerPage + idx + 1
                                        let (cleanedTitle, extractedRank) = extractRankAndCleanTitle(from: title, index: rank)
                                        
                                        if !cleanedTitle.isEmpty && cleanedTitle.count < 200 && !allTitles.contains(cleanedTitle.lowercased()) {
                                            allTitles.insert(cleanedTitle.lowercased())
                                            movies.append(ScrapedMovie(title: cleanedTitle, rank: extractedRank ?? rank))
                                            pageCount += 1
                                        }
                                    }
                                }
                                print("      ✅ Page \(page): Found \(pageCount) new movies (total: \(movies.count))")
                                
                                // Small delay to avoid rate limiting
                                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            }
                        }
                    } catch {
                        print("      ⚠️ Failed to fetch page \(page): \(error)")
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
let outputFile = "/Users/carambula/Documents/WatchedIt/imdb_scrape_results.txt"

let debugger = IMDbScraperDebugger()

Task {
    do {
        print("🚀 Starting IMDb list scraping debug...")
        print("📍 URL: \(url)")
        print(String(repeating: "=", count: 80) + "\n")
        
        let movies = try await debugger.scrapeIMDbList(url: url)
        
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
            
            try debugger.saveResults(movies, to: outputFile)
        } else {
            print("❌ No movies found!")
        }
        
    } catch {
        print("❌ Error: \(error)")
    }
    
    exit(0)
}

RunLoop.main.run()

