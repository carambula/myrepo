#!/usr/bin/env swift

import Foundation

// Load bootstrap JSON
let jsonURL = URL(fileURLWithPath: "WatchedIt/bootstrap_data.json")
guard let data = try? Data(contentsOf: jsonURL),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let movies = json["movies"] as? [[String: Any]] else {
    print("❌ Failed to load bootstrap data")
    exit(1)
}

print("🔍 Checking for duplicates in bootstrap data...\n")

// Group by TMDB ID
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

// Check for duplicates by TMDB ID
var duplicateCount = 0
for (tmdbId, duplicates) in moviesByTmdbId where duplicates.count > 1 {
    duplicateCount += duplicates.count - 1
    print("⚠️ TMDB ID \(tmdbId): \(duplicates.count) entries")
    for dup in duplicates {
        let title = dup["title"] as? String ?? "unknown"
        let source = dup["sourceIdentifier"] as? String ?? "unknown"
        print("   - '\(title)' (source: \(source))")
    }
    print()
}

// Group by cleaned title for movies without TMDB ID
func cleanTitle(_ title: String) -> String {
    var cleaned = title
    // Remove list numbering
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
    // Remove quotes
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

// Check for duplicates by title
for (title, duplicates) in moviesByTitle where duplicates.count > 1 {
    duplicateCount += duplicates.count - 1
    print("⚠️ Title '\(title)': \(duplicates.count) entries")
    for dup in duplicates {
        let source = dup["sourceIdentifier"] as? String ?? "unknown"
        let tmdbId = dup["tmdbId"] as? Int
        print("   - Source: \(source), TMDB: \(tmdbId?.description ?? "nil")")
    }
    print()
}

if duplicateCount == 0 {
    print("✅ No duplicates found in bootstrap data!")
} else {
    print("⚠️ Found \(duplicateCount) duplicate entries")
}





