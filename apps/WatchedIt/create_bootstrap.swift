#!/usr/bin/env swift

// Script to create bootstrap data file with all Rewatchables episodes
// Run this script to generate bootstrap_movies.json before building the app

import Foundation

let rssFeedURL = "https://feeds.megaphone.fm/the-rewatchables"

struct BootstrapEpisode: Codable {
    var title: String
    var movieTitle: String?
    var publishDate: String?
    var guid: String
    var description: String?
}

func fetchEpisodes() async throws -> [BootstrapEpisode] {
    guard let url = URL(string: rssFeedURL) else {
        throw URLError(.badURL)
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let xmlString = String(data: data, encoding: .utf8) else {
        throw URLError(.cannotDecodeContentData)
    }
    
    return parseRSSFeed(xmlString: xmlString)
}

func parseRSSFeed(xmlString: String) -> [BootstrapEpisode] {
    var episodes: [BootstrapEpisode] = []
    let items = xmlString.components(separatedBy: "<item>")
    
    for (index, item) in items.enumerated() {
        if index == 0 { continue }
        
        guard let title = extractXMLTag(from: item, tag: "title") else { continue }
        let pubDateString = extractXMLTag(from: item, tag: "pubDate")
        let guid = extractGUID(from: item) ?? UUID().uuidString
        let description = extractXMLTag(from: item, tag: "description") ?? extractXMLTag(from: item, tag: "itunes:summary")
        let movieTitle = extractMovieTitle(from: title)
        
        episodes.append(BootstrapEpisode(
            title: title,
            movieTitle: movieTitle,
            publishDate: pubDateString,
            guid: guid,
            description: description
        ))
    }
    
    return episodes
}

func extractXMLTag(from xml: String, tag: String) -> String? {
    let openTag = "<\(tag)>"
    let closeTag = "</\(tag)>"
    
    guard let startRange = xml.range(of: openTag),
          let endRange = xml.range(of: closeTag, range: startRange.upperBound..<xml.endIndex) else {
        return nil
    }
    
    let content = String(xml[startRange.upperBound..<endRange.lowerBound])
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    return content.isEmpty ? nil : content
}

func extractGUID(from xml: String) -> String? {
    guard let guidRange = xml.range(of: "<guid") else { return nil }
    guard let guidTagEnd = xml.range(of: ">", range: guidRange.upperBound..<xml.endIndex) else { return nil }
    guard let guidEnd = xml.range(of: "</guid>", range: guidTagEnd.upperBound..<xml.endIndex) else { return nil }
    
    var guid = String(xml[guidTagEnd.upperBound..<guidEnd.lowerBound])
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    if guid.hasPrefix("<![CDATA[") && guid.hasSuffix("]]>") {
        guid = String(guid.dropFirst(9).dropLast(3))
    }
    
    return guid.isEmpty ? nil : guid
}

func extractMovieTitle(from episodeTitle: String) -> String? {
    var title = episodeTitle.trimmingCharacters(in: .whitespaces)
    let quoteChars: [Character] = ["'", "'", "'", "'"]
    
    for startQuote in quoteChars {
        if let startIndex = title.firstIndex(of: startQuote) {
            let afterStart = title.index(after: startIndex)
            if afterStart < title.endIndex {
                for endQuote in quoteChars {
                    if let endIndex = title[afterStart...].firstIndex(of: endQuote) {
                        let movieTitle = String(title[afterStart..<endIndex])
                        if !movieTitle.isEmpty {
                            return cleanTitle(movieTitle)
                        }
                    }
                }
            }
        }
    }
    
    if let withRange = title.range(of: " With ", options: .caseInsensitive) {
        title = String(title[..<withRange.lowerBound])
    }
    
    let result = title.isEmpty ? nil : title.trimmingCharacters(in: .whitespaces)
    return result.map { cleanTitle($0) }
}

func cleanTitle(_ title: String) -> String {
    var cleaned = title
    
    // Remove all types of quotes (straight and curly)
    let quotes: [String] = ["'", "'", "'", "'", "\"", "\"", "\"", "\""]
    for quote in quotes {
        cleaned = cleaned.replacingOccurrences(of: quote, with: "")
    }
    
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

// Main execution
Task {
    do {
        print("📡 Fetching Rewatchables episodes...")
        let episodes = try await fetchEpisodes()
        print("✅ Found \(episodes.count) episodes")
        
        // Filter to only episodes with movie titles and clean them
        var episodesWithMovies = episodes.filter { $0.movieTitle != nil }
        
        // Clean all movie titles
        episodesWithMovies = episodesWithMovies.map { episode in
            var cleaned = episode
            if let movieTitle = episode.movieTitle {
                cleaned = BootstrapEpisode(
                    title: episode.title,
                    movieTitle: cleanTitle(movieTitle),
                    publishDate: episode.publishDate,
                    guid: episode.guid,
                    description: episode.description
                )
            }
            return cleaned
        }
        
        print("✅ Found \(episodesWithMovies.count) episodes with movie titles")
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(episodesWithMovies)
        
        // Write to file
        let outputPath = "WatchedIt/bootstrap_movies.json"
        let outputURL = URL(fileURLWithPath: outputPath)
        try jsonData.write(to: outputURL)
        
        print("✅ Bootstrap file created: \(outputPath)")
        print("   Contains \(episodesWithMovies.count) movies")
        print("\n📋 First 10 movies:")
        for (index, episode) in episodesWithMovies.prefix(10).enumerated() {
            if let movieTitle = episode.movieTitle {
                print("   \(index + 1). \(movieTitle)")
            }
        }
        
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
    exit(0)
}

RunLoop.main.run()

