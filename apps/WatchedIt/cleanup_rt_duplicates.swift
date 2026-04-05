#!/usr/bin/env swift

import Foundation

/// Script to clean up duplicate entries in RT Kids and RT Christmas sources
/// Keeps the entry with the most complete TMDB data

func cleanupRTDuplicates() {
    let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
    let backupURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data_backup.json")
    
    print("🧹 Cleaning up RT Kids and RT Christmas duplicates\n")
    print(String(repeating: "=", count: 70))
    
    // Load existing bootstrap data
    guard let data = try? Data(contentsOf: jsonURL),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          var movies = json["movies"] as? [[String: Any]] else {
        print("❌ Failed to load bootstrap_data.json")
        return
    }
    
    print("\n✅ Loaded bootstrap data")
    print("   Total movies: \(movies.count)")
    
    // Create backup
    do {
        try data.write(to: backupURL)
        print("✅ Created backup")
    } catch {
        print("⚠️ Failed to create backup: \(error)")
    }
    
    // Clean titles - remove year from comparison
    func normalizeTitle(_ title: String) -> String {
        var cleaned = title.lowercased().trimmingCharacters(in: .whitespaces)
        // Remove year in parentheses
        let yearPattern = #"\s*\(\d{4}\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: yearPattern) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // Score entry completeness
    func completenessScore(_ movie: [String: Any]) -> Int {
        var score = 0
        if movie["tmdbId"] != nil { score += 10 }
        if movie["posterPath"] != nil { score += 5 }
        if movie["backdropPath"] != nil { score += 5 }
        if movie["overview"] != nil { score += 5 }
        if movie["genres"] != nil { score += 3 }
        if movie["credits"] != nil { score += 2 }
        if movie["year"] != nil { score += 1 }
        return score
    }
    
    let sourcesToClean = ["rt-kids", "rt-christmas"]
    var totalRemoved = 0
    
    for sourceId in sourcesToClean {
        print("\n📋 Cleaning: \(sourceId)")
        
        // Get all movies for this source
        let sourceMovies = movies.filter { ($0["sourceIdentifier"] as? String) == sourceId }
        print("   Found \(sourceMovies.count) entries")
        
        // Group by normalized title
        var moviesByTitle: [String: [[String: Any]]] = [:]
        for movie in sourceMovies {
            if let title = movie["title"] as? String {
                let normalized = normalizeTitle(title)
                moviesByTitle[normalized, default: []].append(movie)
            }
        }
        
        print("   Unique titles: \(moviesByTitle.count)")
        
        // Find duplicates
        var duplicates: [[String: Any]] = []
        var keepers: [[String: Any]] = []
        
        for (_, titleMovies) in moviesByTitle {
            if titleMovies.count > 1 {
                // Sort by completeness score, then by rank
                let sorted = titleMovies.sorted { movie1, movie2 in
                    let score1 = completenessScore(movie1)
                    let score2 = completenessScore(movie2)
                    if score1 != score2 {
                        return score1 > score2
                    }
                    // If scores equal, prefer lower rank
                    let rank1 = (movie1["rank"] as? Int) ?? Int.max
                    let rank2 = (movie2["rank"] as? Int) ?? Int.max
                    return rank1 < rank2
                }
                
                // Keep the best one
                keepers.append(sorted[0])
                
                // Mark rest as duplicates
                duplicates.append(contentsOf: Array(sorted.dropFirst()))
            } else {
                keepers.append(titleMovies[0])
            }
        }
        
        print("   Duplicates to remove: \(duplicates.count)")
        
        // Remove duplicates from movies array
        let duplicateIndices = Set(duplicates.compactMap { dup in
            movies.firstIndex { movie in
                if let title1 = movie["title"] as? String,
                   let title2 = dup["title"] as? String,
                   let id1 = movie["sourceIdentifier"] as? String,
                   let id2 = dup["sourceIdentifier"] as? String {
                    return title1 == title2 && id1 == id2
                }
                return false
            }
        })
        
        movies = movies.enumerated().compactMap { index, movie in
            if duplicateIndices.contains(index) {
                totalRemoved += 1
                return nil
            }
            return movie
        }
        
        print("   ✅ Removed \(duplicates.count) duplicates")
    }
    
    // Update data sources
    guard var dataSources = json["dataSources"] as? [[String: Any]] else {
        print("❌ Failed to get data sources")
        return
    }
    
    // Update counts
    for sourceId in sourcesToClean {
        let sourceMovies = movies.filter { ($0["sourceIdentifier"] as? String) == sourceId }
        if let index = dataSources.firstIndex(where: { ($0["identifier"] as? String) == sourceId }) {
            dataSources[index]["movieCount"] = sourceMovies.count
        }
    }
    
    // Rebuild JSON
    var updatedJson = json
    updatedJson["movies"] = movies
    updatedJson["dataSources"] = dataSources
    updatedJson["generatedDate"] = ISO8601DateFormatter().string(from: Date())
    
    // Save
    print("\n" + String(repeating: "=", count: 70))
    print("💾 SAVING CLEANED DATA")
    print(String(repeating: "=", count: 70))
    
    do {
        let jsonData = try JSONSerialization.data(withJSONObject: updatedJson, options: [.prettyPrinted, .sortedKeys])
        try jsonData.write(to: jsonURL)
        
        print("\n✅ Saved cleaned bootstrap_data.json")
        print("   Total movies after cleanup: \(movies.count)")
        print("   Duplicates removed: \(totalRemoved)")
        
        for sourceId in sourcesToClean {
            let count = movies.filter { ($0["sourceIdentifier"] as? String) == sourceId }.count
            print("   \(sourceId): \(count) movies")
        }
        
    } catch {
        print("\n❌ Failed to save: \(error)")
    }
}

cleanupRTDuplicates()

