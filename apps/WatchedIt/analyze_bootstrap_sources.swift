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

print("📊 Sources in Bootstrap Database:\n")

var totalMovies = 0
for source in sources {
    let identifier = source["identifier"] as? String ?? "unknown"
    let name = source["name"] as? String ?? "Unknown"
    let type = source["type"] as? String ?? "unknown"
    let isRanked = source["isRankedList"] as? Bool ?? false
    
    let movieCount = movies.filter { ($0["sourceIdentifier"] as? String) == identifier }.count
    totalMovies += movieCount
    
    let rankIndicator = isRanked ? " [Ranked]" : ""
    print("  \(name)")
    print("    Identifier: \(identifier)")
    print("    Type: \(type)\(rankIndicator)")
    print("    Movies: \(movieCount)")
    print()
}

print("📈 Summary:")
print("  Total Sources: \(sources.count)")
print("  Total Movies: \(totalMovies)")
print("  Average Movies per Source: \(totalMovies / sources.count)")

