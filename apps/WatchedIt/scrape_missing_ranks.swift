#!/usr/bin/env swift

import Foundation

// Load bootstrap JSON
let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
guard var json = try? JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String: Any],
      let sources = json["dataSources"] as? [[String: Any]],
      var movies = json["movies"] as? [[String: Any]] else {
    print("❌ Failed to load bootstrap data")
    exit(1)
}

print("🔍 Finding missing ranked entries...\n")

// Find ranked sources with URLs
let rankedSources = sources.filter { 
    ($0["isRankedList"] as? Bool) == true && 
    ($0["url"] as? String) != nil 
}

for source in rankedSources {
    let identifier = source["identifier"] as? String ?? "unknown"
    let name = source["name"] as? String ?? "unknown"
    let url = source["url"] as? String ?? ""
    
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
        print("   URL: \(url)")
        print("   Missing ranks: \(missingRanks.prefix(20).map { String($0) }.joined(separator: ", "))\(missingRanks.count > 20 ? " ... (\(missingRanks.count) total)" : "")")
        print("   ⚠️  Manual scraping needed for missing ranks")
        print()
    }
}

print("\n📝 Note: To fix missing ranks, you'll need to:")
print("   1. Visit the source URL")
print("   2. Find the missing rank numbers")
print("   3. Add them to bootstrap_data.json")
print("   4. Regenerate the bootstrap database")





