#!/usr/bin/env swift

import Foundation

// Load bootstrap JSON
let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
guard let data = try? Data(contentsOf: jsonURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let sources = json["dataSources"] as? [[String: Any]],
      let movies = json["movies"] as? [[String: Any]] else {
    print("❌ Failed to load bootstrap data")
    exit(1)
}

print("🔍 Checking for gaps in ranked lists...\n")

// Find ranked sources
let rankedSources = sources.filter { ($0["isRankedList"] as? Bool) == true }

for source in rankedSources {
    let identifier = source["identifier"] as? String ?? "unknown"
    let name = source["name"] as? String ?? "unknown"
    
    // Get all movies for this source with ranks
    let sourceMovies = movies.filter { ($0["sourceIdentifier"] as? String) == identifier }
        .compactMap { movie -> (rank: Int, title: String)? in
            guard let rank = movie["rank"] as? Int else { return nil }
            let title = movie["title"] as? String ?? "unknown"
            return (rank: rank, title: title)
        }
        .sorted { $0.rank < $1.rank }
    
    if sourceMovies.isEmpty {
        continue
    }
    
    let maxRank = sourceMovies.map { $0.rank }.max() ?? 0
    let expectedRanks = Set(1...maxRank)
    let actualRanks = Set(sourceMovies.map { $0.rank })
    let missingRanks = expectedRanks.subtracting(actualRanks).sorted()
    
    if !missingRanks.isEmpty {
        print("⚠️ \(name) (\(identifier))")
        print("   Total entries: \(sourceMovies.count)")
        print("   Expected ranks: 1-\(maxRank)")
        print("   Missing ranks: \(missingRanks.prefix(20).map { String($0) }.joined(separator: ", "))\(missingRanks.count > 20 ? " ... (\(missingRanks.count) total)" : "")")
        print()
    } else {
        print("✅ \(name): Complete (1-\(maxRank))")
    }
}





