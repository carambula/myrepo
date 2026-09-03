#!/usr/bin/env swift

import Foundation

// Load bootstrap JSON
let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
guard var json = try? JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String: Any],
      var movies = json["movies"] as? [[String: Any]] else {
    print("❌ Failed to load bootstrap data")
    exit(1)
}

print("🔧 Fixing bootstrap data...\n")

// Step 1: Deduplicate by TMDB ID
print("Step 1: Deduplicating by TMDB ID...")
var moviesByTmdbId: [Int: [[String: Any]]] = [:]
var moviesWithoutTmdb: [[String: Any]] = []

for movie in movies {
    if let tmdbId = movie["tmdbId"] as? Int {
        if moviesByTmdbId[tmdbId] == nil {
            moviesByTmdbId[tmdbId] = []
        }
        moviesByTmdbId[tmdbId]?.append(movie)
    } else {
        moviesWithoutTmdb.append(movie)
    }
}

var deduplicatedMovies: [[String: Any]] = []
var duplicatesRemoved = 0

// Keep one movie per TMDB ID (prefer one with most data, cleanest title)
for (tmdbId, duplicates) in moviesByTmdbId {
    if duplicates.count > 1 {
        // Find best movie
        let best = duplicates.max(by: { m1, m2 in
            let score1 = (m1["posterPath"] != nil ? 1 : 0) + (m1["overview"] != nil ? 1 : 0) + ((m1["genres"] as? [String])?.count ?? 0)
            let score2 = (m2["posterPath"] != nil ? 1 : 0) + (m2["overview"] != nil ? 1 : 0) + ((m2["genres"] as? [String])?.count ?? 0)
            if score1 != score2 {
                return score1 < score2
            }
            let title1 = (m1["title"] as? String ?? "").lowercased()
            let title2 = (m2["title"] as? String ?? "").lowercased()
            let clean1 = !title1.contains(" with ") && title1.count < 60
            let clean2 = !title2.contains(" with ") && title2.count < 60
            if clean1 != clean2 {
                return !clean1
            }
            return title1.count > title2.count
        }) ?? duplicates.first!
        
        // Merge all sources into the best movie
        var mergedSources: Set<String> = []
        var mergedRanks: [String: Int] = [:]
        var mergedSourceTitles: [String: String] = [:]
        
        for dup in duplicates {
            if let sourceId = dup["sourceIdentifier"] as? String {
                mergedSources.insert(sourceId)
                if let rank = dup["rank"] as? Int {
                    mergedRanks[sourceId] = rank
                }
                if let sourceTitle = dup["sourceTitle"] as? String {
                    mergedSourceTitles[sourceId] = sourceTitle
                }
            }
        }
        
        // Create one movie per source (to preserve all associations)
        for sourceId in mergedSources {
            var movie = best
            movie["sourceIdentifier"] = sourceId
            if let rank = mergedRanks[sourceId] {
                movie["rank"] = rank
            }
            if let sourceTitle = mergedSourceTitles[sourceId] {
                movie["sourceTitle"] = sourceTitle
            }
            deduplicatedMovies.append(movie)
        }
        
        duplicatesRemoved += duplicates.count - mergedSources.count
    } else {
        deduplicatedMovies.append(duplicates.first!)
    }
}

// Add movies without TMDB ID (deduplicate by cleaned title)
print("Step 2: Deduplicating movies without TMDB ID by title...")
func cleanTitle(_ title: String) -> String {
    var cleaned = title
    let patterns = [
        #"^(\d+)\.\s+"#,
        #"^#(\d+)\s+"#,
        #"^(\d+)\)\s+"#,
    ]
    for pattern in patterns {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
            if let fullRange = Range(match.range, in: cleaned) {
                cleaned = String(cleaned[fullRange.upperBound...])
            }
        }
    }
    while cleaned.hasPrefix("'") || cleaned.hasPrefix("\"") {
        cleaned = String(cleaned.dropFirst())
    }
    while cleaned.hasSuffix("'") || cleaned.hasSuffix("\"") {
        cleaned = String(cleaned.dropLast())
    }
    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}

var moviesByTitle: [String: [[String: Any]]] = [:]
for movie in moviesWithoutTmdb {
    let title = movie["title"] as? String ?? ""
    let normalizedTitle = cleanTitle(title).lowercased()
    if moviesByTitle[normalizedTitle] == nil {
        moviesByTitle[normalizedTitle] = []
    }
    moviesByTitle[normalizedTitle]?.append(movie)
}

for (_, duplicates) in moviesByTitle {
    if duplicates.count > 1 {
        // Merge similar to TMDB ID deduplication
        var mergedSources: Set<String> = []
        for dup in duplicates {
            if let sourceId = dup["sourceIdentifier"] as? String {
                mergedSources.insert(sourceId)
            }
        }
        // Use first movie as base, create one per source
        for sourceId in mergedSources {
            var movie = duplicates.first!
            movie["sourceIdentifier"] = sourceId
            if let dup = duplicates.first(where: { ($0["sourceIdentifier"] as? String) == sourceId }),
               let rank = dup["rank"] as? Int {
                movie["rank"] = rank
            }
            deduplicatedMovies.append(movie)
        }
        duplicatesRemoved += duplicates.count - mergedSources.count
    } else {
        deduplicatedMovies.append(duplicates.first!)
    }
}

print("✅ Removed \(duplicatesRemoved) duplicate entries")
print("   Before: \(movies.count) movies")
print("   After: \(deduplicatedMovies.count) movies")

// Update JSON
json["movies"] = deduplicatedMovies

// Save updated JSON
let outputURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
let outputData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
try outputData.write(to: outputURL)

print("\n✅ Updated bootstrap_data.json")
print("   Saved to: \(outputURL.path)")





