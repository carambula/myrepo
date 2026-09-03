#!/usr/bin/env swift

// Bootstrap script to populate local database with Rewatchables episodes
// Run this before building the app to pre-populate the database

import Foundation

let rssFeedURL = "https://feeds.megaphone.fm/the-rewatchables"

struct Episode {
    let title: String
    let movieTitle: String?
    let publishDate: Date?
    let guid: String
}

func fetchEpisodes() async throws -> [Episode] {
    guard let url = URL(string: rssFeedURL) else {
        throw URLError(.badURL)
    }
    
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let xmlString = String(data: data, encoding: .utf8) else {
        throw URLError(.cannotDecodeContentData)
    }
    
    return parseRSSFeed(xmlString: xmlString)
}

func parseRSSFeed(xmlString: String) -> [Episode] {
    var episodes: [Episode] = []
    let items = xmlString.components(separatedBy: "<item>")
    
    for (index, item) in items.enumerated() {
        if index == 0 { continue }
        
        guard let title = extractXMLTag(from: item, tag: "title") else { continue }
        let pubDateString = extractXMLTag(from: item, tag: "pubDate")
        let publishDate = parseRFC822Date(pubDateString)
        let guid = extractGUID(from: item) ?? UUID().uuidString
        let movieTitle = extractMovieTitle(from: title)
        
        episodes.append(Episode(
            title: title,
            movieTitle: movieTitle,
            publishDate: publishDate,
            guid: guid
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

func parseRFC822Date(_ dateString: String?) -> Date? {
    guard let dateString = dateString else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
    return formatter.date(from: dateString)
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
                            return movieTitle
                        }
                    }
                }
            }
        }
    }
    
    if let withRange = title.range(of: " With ", options: .caseInsensitive) {
        title = String(title[..<withRange.lowerBound])
    }
    
    return title.isEmpty ? nil : title.trimmingCharacters(in: .whitespaces)
}

// Main execution
Task {
    do {
        let episodes = try await fetchEpisodes()
        print("Found \(episodes.count) episodes")
        print("\nFirst 20 movies:")
        for (index, episode) in episodes.prefix(20).enumerated() {
            if let movieTitle = episode.movieTitle {
                print("\(index + 1). \(movieTitle)")
            } else {
                print("\(index + 1). (Could not extract from: \(episode.title))")
            }
        }
        print("\n✅ Bootstrap data ready. Episodes will be loaded into the app on first launch.")
    } catch {
        print("❌ Error: \(error)")
        exit(1)
    }
    exit(0)
}

RunLoop.main.run()

