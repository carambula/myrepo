#!/usr/bin/env swift

import Foundation

/// Generates a comprehensive bootstrap JSON file from bootstrap_dataset.txt
/// This creates DataSource entries and MovieData entries that match the app's data model

struct BootstrapDataSource: Codable {
    let identifier: String
    let name: String
    let type: String // "podcast" or "url"
    let url: String?
    let isRankedList: Bool
    let movieCount: Int
}

struct BootstrapMovie: Codable {
    let title: String
    let sourceIdentifier: String
    let rank: Int?
    let sourceTitle: String? // Original title from source (e.g., episode title)
}

struct BootstrapData: Codable {
    let version: String
    let generatedDate: String
    let dataSources: [BootstrapDataSource]
    let movies: [BootstrapMovie]
}

func generateBootstrapJSON() {
    let inputFile = "/Users/carambula/Documents/WatchedIt/bootstrap_dataset.txt"
    let outputFile = "/Users/carambula/Documents/WatchedIt/WatchedIt/bootstrap_data.json"
    
    print("📂 Reading bootstrap dataset...")
    
    guard let content = try? String(contentsOfFile: inputFile, encoding: .utf8) else {
        print("❌ Could not read \(inputFile)")
        return
    }
    
    let lines = content.components(separatedBy: .newlines)
    
    // Parse data sources from header
    var dataSources: [String: (name: String, type: String, url: String?, isRanked: Bool, count: Int)] = [:]
    var currentSection: String? = nil
    
    // Define source mappings
    let sourceMappings: [String: (identifier: String, name: String, type: String, url: String?, isRanked: Bool)] = [
        "Rewatchables": ("rewatchables", "The Rewatchables", "podcast", "https://feeds.megaphone.fm/the-rewatchables", false),
        "Blank Check": ("blank-check", "Blank Check", "podcast", "https://feeds.megaphone.fm/blank-check", false),
        "The Big Picture": ("big-picture", "The Big Picture", "podcast", "https://feeds.megaphone.fm/the-big-picture", false),
        "Filmspotting": ("filmspotting", "Filmspotting", "podcast", "https://feeds.megaphone.fm/filmspotting", false),
        "The Confused Breakfast": ("confused-breakfast", "The Confused Breakfast", "podcast", "https://feeds.megaphone.fm/CTL8333955564", false),
        "RT: Best Movies of All Time": ("rt-best-all-time", "RT: Best Movies of All Time", "url", "https://editorial.rottentomatoes.com/guide/best-movies-of-all-time/", true),
        "RT: Best Christmas Movies": ("rt-christmas", "RT: Best Christmas Movies", "url", "https://editorial.rottentomatoes.com/guide/best-christmas-movies/", true),
        "RT: Essential Movies for Kids": ("rt-kids", "RT: Essential Movies for Kids", "url", "https://editorial.rottentomatoes.com/guide/essential-movies-for-kids/", true),
        "RT: Oscars Best and Worst": ("rt-oscars", "RT: Oscars Best and Worst", "url", "https://editorial.rottentomatoes.com/guide/oscars-best-and-worst-best-pictures/", true),
        "IMDb List 1": ("imdb-list-1", "IMDb List 1", "url", "https://www.imdb.com/list/ls042702401/", true),
        "IMDb List 2": ("imdb-list-2", "IMDb List 2", "url", "https://www.imdb.com/list/ls058479560/", true),
        "Criterion Collection": ("criterion", "Criterion Collection", "url", "https://en.wikipedia.org/wiki/Criterion_Closet#Criterion_Collection_40", true),
    ]
    
    // Parse movies
    var movies: [BootstrapMovie] = []
    var sourceCounts: [String: Int] = [:]
    
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip empty lines and headers
        if trimmed.isEmpty || trimmed.hasPrefix("=") || trimmed.hasPrefix("Bootstrap") || 
           trimmed.hasPrefix("Total") || trimmed.hasPrefix("Sources") || trimmed.hasPrefix("MOVIES") ||
           trimmed.hasPrefix("ALL") {
            continue
        }
        
        // Parse movie line: "1. Title [Rank: X] (Source: Source Name)"
        if let match = try? NSRegularExpression(pattern: #"^\d+\.\s+(.+?)(?:\s+\[Rank:\s*(\d+)\])?\s+\(Source:\s*(.+?)\)$"#),
           let result = match.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           result.numberOfRanges >= 3 {
            
            let titleRange = Range(result.range(at: 1), in: trimmed)!
            var title = String(trimmed[titleRange]).trimmingCharacters(in: .whitespaces)
            
            var rank: Int? = nil
            if result.numberOfRanges > 2 {
                let rankRange = Range(result.range(at: 2), in: trimmed)
                if let rankRange = rankRange, !rankRange.isEmpty {
                    rank = Int(String(trimmed[rankRange]))
                }
            }
            
            let sourceRange = Range(result.range(at: 3), in: trimmed)!
            let sourceName = String(trimmed[sourceRange]).trimmingCharacters(in: .whitespaces)
            
            // Find source mapping
            if let mapping = sourceMappings[sourceName] {
                let identifier = mapping.identifier
                sourceCounts[identifier, default: 0] += 1
                
                movies.append(BootstrapMovie(
                    title: title,
                    sourceIdentifier: identifier,
                    rank: rank,
                    sourceTitle: nil
                ))
            }
        }
    }
    
    // Build data sources
    var bootstrapDataSources: [BootstrapDataSource] = []
    for (sourceName, mapping) in sourceMappings {
        let count = sourceCounts[mapping.identifier] ?? 0
        if count > 0 {
            bootstrapDataSources.append(BootstrapDataSource(
                identifier: mapping.identifier,
                name: mapping.name,
                type: mapping.type,
                url: mapping.url,
                isRankedList: mapping.isRanked,
                movieCount: count
            ))
        }
    }
    
    // Sort data sources by movie count
    bootstrapDataSources.sort { $0.movieCount > $1.movieCount }
    
    // Create bootstrap data
    let bootstrapData = BootstrapData(
        version: "1.0",
        generatedDate: ISO8601DateFormatter().string(from: Date()),
        dataSources: bootstrapDataSources,
        movies: movies
    )
    
    // Encode to JSON
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let jsonData = try encoder.encode(bootstrapData)
        try jsonData.write(to: URL(fileURLWithPath: outputFile))
        
        print("✅ Generated bootstrap_data.json")
        print("   Data Sources: \(bootstrapDataSources.count)")
        print("   Movies: \(movies.count)")
        print("   Output: \(outputFile)")
        
        // Print summary
        print("\n📊 Data Sources Summary:")
        for source in bootstrapDataSources {
            print("   \(source.name): \(source.movieCount) movies (\(source.type))")
        }
        
    } catch {
        print("❌ Error encoding JSON: \(error)")
    }
}

// Run
generateBootstrapJSON()





