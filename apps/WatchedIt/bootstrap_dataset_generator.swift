#!/usr/bin/env swift

import Foundation

/// Structure to hold a movie title with its rank in a ranked list
struct ScrapedMovie {
    let title: String
    let rank: Int?
    let source: String
}

/// Bootstrap dataset generator - scrapes multiple sources and aggregates results
class BootstrapDatasetGenerator {
    
    // MARK: - Source Lists
    
    let podcastSources: [(name: String, rssURL: String)] = [
        ("Rewatchables", "https://feeds.megaphone.fm/the-rewatchables"),
        ("Blank Check", "https://feeds.megaphone.fm/blank-check"),
        ("The Big Picture", "https://feeds.megaphone.fm/the-big-picture"),
        ("Filmspotting", "https://feeds.megaphone.fm/filmspotting"),
        ("The Confused Breakfast", "https://feeds.megaphone.fm/CTL8333955564"),
    ]
    
    let listSources: [(name: String, url: String)] = [
        ("RT: Best Movies of All Time", "https://editorial.rottentomatoes.com/guide/best-movies-of-all-time/"),
        ("RT: Best Christmas Movies", "https://editorial.rottentomatoes.com/guide/best-christmas-movies/"),
        ("RT: Essential Movies for Kids", "https://editorial.rottentomatoes.com/guide/essential-movies-for-kids/"),
        ("RT: Oscars Best and Worst", "https://editorial.rottentomatoes.com/guide/oscars-best-and-worst-best-pictures/"),
        ("IMDb List 1", "https://www.imdb.com/list/ls042702401/"),
        ("IMDb List 2", "https://www.imdb.com/list/ls058479560/"),
        ("Criterion Collection", "https://en.wikipedia.org/wiki/Criterion_Closet#Criterion_Collection_40"),
    ]
    
    // MARK: - Unified Scraper (embedded)
    
    class UnifiedScraper {
        func scrapeURL(url: String) async throws -> [ScrapedMovie] {
            if url.contains("imdb.com/list/") || url.contains("imdb.com/chart/") {
                return try await scrapeIMDbList(url: url)
            } else if url.contains("rottentomatoes.com") && url.contains("/guide/") {
                return try await scrapeRottenTomatoesGuide(url: url)
            } else {
                throw URLError(.unsupportedURL)
            }
        }
        
        func scrapeIMDbList(url: String) async throws -> [ScrapedMovie] {
            guard let urlObj = URL(string: url) else { throw URLError(.badURL) }
            
            var request = URLRequest(url: urlObj)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard let htmlString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            
            var allTitles: Set<String> = []
            var movies: [ScrapedMovie] = []
            
            // Pattern 1: Title links
            let titleLinkPattern = #"<a\s+href\s*=\s*["']?/title/tt\d+/["']?[^>]*>(.*?)</a>"#
            if let regex = try? NSRegularExpression(pattern: titleLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
                for (idx, match) in matches.enumerated() {
                    if match.numberOfRanges > 1, let titleRange = Range(match.range(at: 1), in: htmlString) {
                        var title = String(htmlString[titleRange])
                        title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let yearPattern = #"\s*\(\d{4}\)\s*$"#
                        if let yearRegex = try? NSRegularExpression(pattern: yearPattern) {
                            title = yearRegex.stringByReplacingMatches(in: title, options: [], range: NSRange(title.startIndex..., in: title), withTemplate: "")
                        }
                        
                        title = title.replacingOccurrences(of: "&#x27;", with: "'")
                        title = title.replacingOccurrences(of: "&amp;", with: "&")
                        
                        if !title.isEmpty && title.count < 200 && !allTitles.contains(title.lowercased()) {
                            allTitles.insert(title.lowercased())
                            movies.append(ScrapedMovie(title: title, rank: idx + 1, source: "IMDb"))
                        }
                    }
                }
            }
            
            // Pattern 2: __NEXT_DATA__ JSON
            let scriptPattern = #"<script[^>]*id=["']__NEXT_DATA__["'][^>]*>(.*?)</script>"#
            if let regex = try? NSRegularExpression(pattern: scriptPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let matches = regex.matches(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString))
                for match in matches {
                    if match.numberOfRanges > 1, let scriptRange = Range(match.range(at: 1), in: htmlString) {
                        let scriptContent = String(htmlString[scriptRange])
                        if let jsonData = scriptContent.data(using: .utf8) {
                            do {
                                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                                    var extractedTitles: [(title: String, rank: Int?)] = []
                                    var seenTitles = Set<String>()
                                    extractTitlesFromJSON(jsonObject, seenTitles: &seenTitles, extractedTitles: &extractedTitles)
                                    
                                    for (titleStr, rank) in extractedTitles {
                                        if !titleStr.isEmpty && titleStr.count > 3 && titleStr.count < 200 {
                                            var cleaned = titleStr.replacingOccurrences(of: "&#x27;", with: "'")
                                            cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
                                            
                                            let lowerTitle = cleaned.lowercased()
                                            if !lowerTitle.contains("loadads") && !lowerTitle.contains("clickto") &&
                                               !lowerTitle.contains("helvetica") && !lowerTitle.hasPrefix("{") &&
                                               cleaned != "0" && cleaned != "255" &&
                                               !lowerTitle.contains("genre") && !lowerTitle.contains("keyword") &&
                                               !allTitles.contains(lowerTitle) {
                                                allTitles.insert(lowerTitle)
                                                movies.append(ScrapedMovie(title: cleaned, rank: rank, source: "IMDb"))
                                            }
                                        }
                                    }
                                }
                            } catch {}
                        }
                    }
                }
            }
            
            return movies
        }
        
        private func extractTitlesFromJSON(_ obj: Any, seenTitles: inout Set<String>, extractedTitles: inout [(title: String, rank: Int?)], currentRank: Int? = nil) {
            if let dict = obj as? [String: Any] {
                var foundTitle: String? = nil
                var foundRank: Int? = currentRank
                
                if let title = dict["title"] as? String, !title.isEmpty {
                    foundTitle = title
                } else if let titleText = dict["titleText"] as? [String: Any], let text = titleText["text"] as? String, !text.isEmpty {
                    foundTitle = text
                } else if let primaryTitle = dict["primaryTitle"] as? String, !primaryTitle.isEmpty {
                    foundTitle = primaryTitle
                }
                
                if foundRank == nil {
                    foundRank = dict["position"] as? Int ?? dict["rank"] as? Int
                }
                
                if let title = foundTitle, !seenTitles.contains(title.lowercased()) {
                    seenTitles.insert(title.lowercased())
                    extractedTitles.append((title: title, rank: foundRank))
                }
                
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
        
        func scrapeRottenTomatoesGuide(url: String) async throws -> [ScrapedMovie] {
            guard let urlObj = URL(string: url) else { throw URLError(.badURL) }
            
            var request = URLRequest(url: urlObj)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard let htmlString = String(data: data, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
            
            var allTitles: Set<String> = []
            var movies: [ScrapedMovie] = []
            var movieCount = 0
            
            let rtMovieLinkPattern = #"<a[^>]*href\s*=\s*["']https?://[^"']*rottentomatoes\.com/m/[^"']*["'][^>]*>([^<]+)</a>"#
            if let regex = try? NSRegularExpression(pattern: rtMovieLinkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
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
                            movieCount += 1
                            if !allTitles.contains(title.lowercased()) {
                                allTitles.insert(title.lowercased())
                                movies.append(ScrapedMovie(title: title, rank: movieCount, source: "Rotten Tomatoes"))
                            }
                        }
                    }
                }
            }
            
            return movies
        }
    }
    
    let scraper = UnifiedScraper()
    
    // MARK: - Scraping Functions
    
    func scrapePodcast(name: String, rssURL: String) async -> (success: Bool, movies: [ScrapedMovie], error: String?) {
        print("\n🎙️ Scraping podcast: \(name)")
        print("   RSS URL: \(rssURL)")
        
        do {
            guard let url = URL(string: rssURL) else {
                return (false, [], "Invalid URL")
            }
            
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, [], "Invalid response")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return (false, [], "HTTP \(httpResponse.statusCode)")
            }
            
            guard let xmlString = String(data: data, encoding: .utf8) else {
                return (false, [], "Could not decode XML")
            }
            
            var movies: [ScrapedMovie] = []
            
            // Extract from episode titles
            let titlePattern = #"<title[^>]*>([^<]+)</title>"#
            if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive) {
                let matches = regex.matches(in: xmlString, range: NSRange(xmlString.startIndex..., in: xmlString))
                
                for match in matches {
                    if match.numberOfRanges > 1, let titleRange = Range(match.range(at: 1), in: xmlString) {
                        let episodeTitle = String(xmlString[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        if episodeTitle.lowercased().contains("feed") || episodeTitle.lowercased().contains("podcast") {
                            continue
                        }
                        
                        let movieTitle = extractMovieTitleFromEpisode(episodeTitle)
                        if !movieTitle.isEmpty && movieTitle.count > 2 && movieTitle.count < 200 {
                            movies.append(ScrapedMovie(title: movieTitle, rank: nil, source: name))
                        }
                    }
                }
            }
            
            // Deduplicate
            var seenTitles = Set<String>()
            var uniqueMovies: [ScrapedMovie] = []
            for movie in movies {
                let lowerTitle = movie.title.lowercased()
                if !seenTitles.contains(lowerTitle) {
                    seenTitles.insert(lowerTitle)
                    uniqueMovies.append(movie)
                }
            }
            
            print("   ✅ Found \(uniqueMovies.count) unique movies")
            return (true, uniqueMovies, nil)
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            return (false, [], error.localizedDescription)
        }
    }
    
    private func normalizePodcastMovieCandidate(_ rawTitle: String) -> String {
        var cleaned = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove wrapping quotes if present.
        cleaned = cleaned.replacingOccurrences(of: #"^["'`´“”‘’]+|["'`´“”‘’]+$"#, with: "", options: .regularExpression)
        
        // Remove trailing release year markers (e.g. "(1996)", "[1996]").
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*[\(\[]\s*(?:19|20)\d{2}\s*[\)\]]\s*$"#,
            with: "",
            options: .regularExpression
        )
        
        // Remove trailing episode-style suffixes that can follow a clean movie title.
        cleaned = cleaned.replacingOccurrences(
            of: #"\s*[-–—:|]\s*(?:with|w\/|featuring|feat\.?)\b.*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractMovieTitleFromEpisode(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        
        // Skip if it's clearly not a movie title
        let skipPatterns = [
            "rewatchables", "blank check", "big picture", "filmspotting", "confused breakfast",
            "episode", "podcast", "with bill", "with sean", "with chris", "rss feed",
            "megaphone", "feed", "subscribe"
        ]
        
        let lowerText = cleaned.lowercased()
        for skip in skipPatterns {
            if lowerText.contains(skip) && lowerText.count < 50 {
                return "" // Skip short titles that contain podcast keywords
            }
        }
        
        // Extract movie title patterns
        // Pattern 1: "Movie Title (1999)" or "Movie Title" with quotes
        let quotePattern = #"["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: quotePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
           match.numberOfRanges > 1,
           let quoteRange = Range(match.range(at: 1), in: cleaned) {
            let quoted = normalizePodcastMovieCandidate(String(cleaned[quoteRange]))
            if quoted.count > 3 && quoted.count < 100 {
                return quoted
            }
        }
        
        // Pattern 2: Remove common prefixes
        let removePatterns = [
            #"^.*?:\s*"#,  // "Podcast Name: "
            #"^.*?With\s+[^:]+:\s*"#,  // "With Guest: "
            #"\s*-\s*Episode.*$"#,  // " - Episode 123"
            #"\s*\(.*?\)\s*$"#,  // "(1999)" at end
            #"\s*\[.*?\]\s*$"#,  // "[Review]" at end
            #"^'([^']+)'$"#,  // Extract from single quotes
        ]
        
        for pattern in removePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if pattern.hasPrefix("^'") && pattern.hasSuffix("'$") {
                    // Extract from quotes
                    if let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
                       match.numberOfRanges > 1,
                       let quoteRange = Range(match.range(at: 1), in: cleaned) {
                        return String(cleaned[quoteRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } else {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
                }
            }
        }
        
        cleaned = normalizePodcastMovieCandidate(cleaned)
        
        // Final validation - must look like a movie title
        if cleaned.count < 3 || cleaned.count > 100 {
            return ""
        }
        
        // Skip if it's clearly a podcast episode title, not a movie
        if lowerText.contains("with ") && cleaned.count < 30 {
            return ""
        }
        
        return cleaned
    }
    
    func scrapeList(name: String, url: String) async -> (success: Bool, movies: [ScrapedMovie], error: String?) {
        print("\n📋 Scraping list: \(name)")
        print("   URL: \(url)")
        
        do {
            let scrapedMovies = try await scraper.scrapeURL(url: url)
            let movies = scrapedMovies.map { ScrapedMovie(title: $0.title, rank: $0.rank, source: name) }
            print("   ✅ Found \(movies.count) movies")
            return (true, movies, nil)
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            return (false, [], error.localizedDescription)
        }
    }
    
    func scrapeWikipediaCriterion(url: String) async -> (success: Bool, movies: [ScrapedMovie], error: String?) {
        print("\n📚 Scraping Wikipedia: Criterion Collection")
        print("   URL: \(url)")
        
        do {
            guard let urlObj = URL(string: url) else {
                return (false, [], "Invalid URL")
            }
            
            var request = URLRequest(url: urlObj)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, [], "Invalid response")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return (false, [], "HTTP \(httpResponse.statusCode)")
            }
            
            guard let htmlString = String(data: data, encoding: .utf8) else {
                return (false, [], "Could not decode HTML")
            }
            
            var movies: [ScrapedMovie] = []
            
            // Look for the Criterion Collection 40 section - find titles after "Titles" heading
            // The structure is: <h2>Criterion Collection 40</h2>...<p><b>Titles</b>...<ul><li>...
            
            // Find the section starting from "Criterion Collection 40" heading
            let headingPattern = #"<h2[^>]*id=["']Criterion_Collection_40["'][^>]*>.*?</h2>"#
            if let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                if let headingMatch = headingRegex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)) {
                    let sectionStart = htmlString.index(htmlString.startIndex, offsetBy: headingMatch.range.upperBound)
                    let sectionEnd = htmlString.index(sectionStart, offsetBy: min(100000, htmlString.distance(from: sectionStart, to: htmlString.endIndex)), limitedBy: htmlString.endIndex) ?? htmlString.endIndex
                    let section = String(htmlString[sectionStart..<sectionEnd])
                    
                    // Look for list items with movie titles (often in <i> tags or links)
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
                                
                                if !title.isEmpty && title.count > 1 && title.count < 200 && !title.contains("http") {
                                    movies.append(ScrapedMovie(title: title, rank: index + 1, source: "Criterion Collection"))
                                }
                            }
                        }
                    }
                    
                    // Also try links in list items
                    if movies.isEmpty {
                        let linkPattern = #"<li[^>]*>.*?<a[^>]*href=["']/wiki/[^"']+["'][^>]*>([^<]+)</a>.*?</li>"#
                        if let regex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                            let matches = regex.matches(in: section, range: NSRange(section.startIndex..., in: section))
                            
                            for (index, match) in matches.enumerated() {
                                if match.numberOfRanges > 1, let titleRange = Range(match.range(at: 1), in: section) {
                                    var title = String(section[titleRange])
                                    title = title.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                                    title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                                    
                                    if !title.isEmpty && title.count > 1 && title.count < 200 && !title.contains("http") && index < 50 {
                                        movies.append(ScrapedMovie(title: title, rank: index + 1, source: "Criterion Collection"))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            print("   ✅ Found \(movies.count) movies")
            return (true, movies, nil)
            
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
            return (false, [], error.localizedDescription)
        }
    }
    
    // MARK: - Main Bootstrap Function
    
    func generateBootstrapDataset() async {
        print("🚀 Starting Bootstrap Dataset Generation")
        print(String(repeating: "=", count: 80))
        print("📊 Sources to scrape:")
        print("   Podcasts: \(podcastSources.count)")
        print("   Lists: \(listSources.count)")
        print(String(repeating: "=", count: 80) + "\n")
        
        var allMovies: [ScrapedMovie] = []
        var results: [(source: String, success: Bool, count: Int, error: String?)] = []
        
        // Scrape podcasts
        print("\n" + String(repeating: "=", count: 80))
        print("🎙️ SCRAPING PODCASTS")
        print(String(repeating: "=", count: 80))
        
        for podcast in podcastSources {
            let result = await scrapePodcast(name: podcast.name, rssURL: podcast.rssURL)
            allMovies.append(contentsOf: result.movies)
            results.append((source: podcast.name, success: result.success, count: result.movies.count, error: result.error))
        }
        
        // Scrape lists
        print("\n" + String(repeating: "=", count: 80))
        print("📋 SCRAPING LISTS")
        print(String(repeating: "=", count: 80))
        
        for list in listSources {
            if list.url.contains("wikipedia.org") {
                let result = await scrapeWikipediaCriterion(url: list.url)
                allMovies.append(contentsOf: result.movies)
                results.append((source: list.name, success: result.success, count: result.movies.count, error: result.error))
            } else {
                let result = await scrapeList(name: list.name, url: list.url)
                allMovies.append(contentsOf: result.movies)
                results.append((source: list.name, success: result.success, count: result.movies.count, error: result.error))
            }
        }
        
        // Deduplicate final dataset
        print("\n" + String(repeating: "=", count: 80))
        print("🔄 DEDUPLICATING RESULTS")
        print(String(repeating: "=", count: 80))
        
        var seenTitles = Set<String>()
        var uniqueMovies: [ScrapedMovie] = []
        var sourceCounts: [String: Int] = [:]
        
        for movie in allMovies {
            let lowerTitle = movie.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !seenTitles.contains(lowerTitle) {
                seenTitles.insert(lowerTitle)
                uniqueMovies.append(movie)
                sourceCounts[movie.source, default: 0] += 1
            }
        }
        
        // Report results
        print("\n" + String(repeating: "=", count: 80))
        print("📊 FINAL RESULTS")
        print(String(repeating: "=", count: 80))
        print("\n✅ SUCCESSFUL SCRAPES:")
        var successCount = 0
        for result in results {
            if result.success {
                print("   ✅ \(result.source): \(result.count) movies")
                successCount += 1
            }
        }
        
        print("\n❌ FAILED SCRAPES:")
        var failCount = 0
        for result in results {
            if !result.success {
                print("   ❌ \(result.source): \(result.error ?? "Unknown error")")
                failCount += 1
            }
        }
        
        print("\n📈 SUMMARY:")
        print("   Total sources: \(results.count)")
        print("   Successful: \(successCount)")
        print("   Failed: \(failCount)")
        print("   Raw movies found: \(allMovies.count)")
        print("   Unique movies: \(uniqueMovies.count)")
        
        print("\n📊 MOVIES BY SOURCE:")
        for (source, count) in sourceCounts.sorted(by: { $0.value > $1.value }) {
            print("   \(source): \(count)")
        }
        
        // Save to file
        let outputFile = "/Users/carambula/Documents/WatchedIt/bootstrap_dataset.txt"
        var output = "Bootstrap Dataset - Generated \(Date())\n"
        output += String(repeating: "=", count: 80) + "\n\n"
        output += "Total Unique Movies: \(uniqueMovies.count)\n"
        output += "Sources: \(results.count) (Success: \(successCount), Failed: \(failCount))\n\n"
        output += "MOVIES BY SOURCE:\n"
        for (source, count) in sourceCounts.sorted(by: { $0.value > $1.value }) {
            output += "  \(source): \(count)\n"
        }
        output += "\n" + String(repeating: "=", count: 80) + "\n"
        output += "ALL MOVIES:\n\n"
        
        for (index, movie) in uniqueMovies.enumerated() {
            output += "\(index + 1). \(movie.title)"
            if let rank = movie.rank {
                output += " [Rank: \(rank)]"
            }
            output += " (Source: \(movie.source))\n"
        }
        
        do {
            try output.write(toFile: outputFile, atomically: true, encoding: .utf8)
            print("\n💾 Dataset saved to: \(outputFile)")
        } catch {
            print("\n❌ Failed to save dataset: \(error)")
        }
        
        // Save detailed results
        let resultsFile = "/Users/carambula/Documents/WatchedIt/bootstrap_results.txt"
        var resultsOutput = "Bootstrap Scraping Results - Generated \(Date())\n"
        resultsOutput += String(repeating: "=", count: 80) + "\n\n"
        
        for result in results {
            resultsOutput += "\(result.success ? "✅" : "❌") \(result.source)\n"
            resultsOutput += "   Count: \(result.count)\n"
            if let error = result.error {
                resultsOutput += "   Error: \(error)\n"
            }
            resultsOutput += "\n"
        }
        
        do {
            try resultsOutput.write(toFile: resultsFile, atomically: true, encoding: .utf8)
            print("💾 Detailed results saved to: \(resultsFile)")
        } catch {
            print("❌ Failed to save results: \(error)")
        }
    }
}

// Main execution
let generator = BootstrapDatasetGenerator()

Task {
    await generator.generateBootstrapDataset()
    exit(0)
}

RunLoop.main.run()
