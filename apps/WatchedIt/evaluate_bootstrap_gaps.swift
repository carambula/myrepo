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

print("📊 Bootstrap Database Gap Analysis\n")
print(String(repeating: "=", count: 70))

// Define expected counts based on user requirements
struct ExpectedCount {
    let min: Int?
    let exact: Int?
    
    init(exact: Int) {
        self.exact = exact
        self.min = nil
    }
    
    init(min: Int) {
        self.min = min
        self.exact = nil
    }
}

let expectedCounts: [String: (url: String, expected: ExpectedCount)] = [
    "rt-best-all-time": (
        url: "https://editorial.rottentomatoes.com/guide/best-movies-of-all-time/",
        expected: ExpectedCount(exact: 300)
    ),
    "rt-christmas": (
        url: "https://editorial.rottentomatoes.com/guide/best-christmas-movies/",
        expected: ExpectedCount(exact: 100)
    ),
    "rt-oscars": (
        url: "https://editorial.rottentomatoes.com/guide/oscars-best-and-worst-best-pictures/",
        expected: ExpectedCount(exact: 98)
    ),
    "imdb-list-1": (
        url: "https://www.imdb.com/list/ls042702401/",
        expected: ExpectedCount(exact: 403)
    ),
    "imdb-list-2": (
        url: "https://www.imdb.com/list/ls058479560/",
        expected: ExpectedCount(exact: 105)
    ),
    "criterion": (
        url: "https://en.wikipedia.org/wiki/Criterion_Closet#Criterion_Collection_40",
        expected: ExpectedCount(exact: 40)
    ),
    "rewatchables": (
        url: "https://feeds.megaphone.fm/the-rewatchables",
        expected: ExpectedCount(min: 480)
    ),
    "confused-breakfast": (
        url: "https://feeds.megaphone.fm/CTL8333955564",
        expected: ExpectedCount(min: 300)
    ),
    "blank-check": (
        url: "https://feeds.megaphone.fm/blank-check",
        expected: ExpectedCount(min: 500)
    ),
    "filmspotting": (
        url: "https://feeds.megaphone.fm/filmspotting",
        expected: ExpectedCount(min: 800)
    ),
    "big-picture": (
        url: "https://feeds.megaphone.fm/the-big-picture",
        expected: ExpectedCount(min: 800)
    )
]

// Count movies per source
var movieCounts: [String: Int] = [:]
for movie in movies {
    if let sourceIdentifier = movie["sourceIdentifier"] as? String {
        movieCounts[sourceIdentifier, default: 0] += 1
    }
}

// Create a map of source identifiers to source info
var sourceMap: [String: [String: Any]] = [:]
for source in sources {
    if let identifier = source["identifier"] as? String {
        sourceMap[identifier] = source
    }
}

// All source identifiers found
let allSourceIdentifiers = Set(sources.compactMap { $0["identifier"] as? String })

print("\n📋 Source Analysis:\n")

var totalGaps = 0
var missingSources: [String] = []
var sourcesWithGaps: [(identifier: String, name: String, actual: Int, expected: ExpectedCount, gap: Int)] = []

// Check each expected source
for (identifier, (url, expected)) in expectedCounts {
    let actualCount = movieCounts[identifier] ?? 0
    let sourceName = sourceMap[identifier]?["name"] as? String ?? identifier
    let metadataCount = sourceMap[identifier]?["movieCount"] as? Int
    
    var gap: Int?
    var status: String
    
    if let exact = expected.exact {
        gap = exact - actualCount
        if actualCount < exact {
            status = "❌ MISSING \(gap!) entries"
            totalGaps += gap!
            sourcesWithGaps.append((identifier: identifier, name: sourceName, actual: actualCount, expected: expected, gap: gap!))
        } else if actualCount > exact {
            status = "⚠️  HAS \(actualCount - exact) EXTRA entries"
        } else {
            status = "✅ COMPLETE"
        }
    } else if let min = expected.min {
        gap = min - actualCount
        if actualCount < min {
            status = "❌ MISSING \(gap!) entries (below minimum)"
            totalGaps += max(0, gap!)
            sourcesWithGaps.append((identifier: identifier, name: sourceName, actual: actualCount, expected: expected, gap: gap!))
        } else {
            status = "✅ COMPLETE (above minimum)"
        }
    } else {
        status = "❓ UNKNOWN"
    }
    
    // Check if source exists
    if !allSourceIdentifiers.contains(identifier) {
        missingSources.append(identifier)
        status += " (SOURCE NOT FOUND)"
    }
    
    let expectedStr = expected.exact != nil ? "\(expected.exact!)" : "≥\(expected.min!)"
    print("\(status)")
    print("   Source: \(sourceName)")
    print("   Identifier: \(identifier)")
    print("   URL: \(url)")
    if let metaCount = metadataCount, metaCount != actualCount {
        print("   Actual in JSON: \(actualCount) | Metadata says: \(metaCount) | Expected: \(expectedStr)")
        print("   ⚠️  Note: Metadata count differs from actual count!")
    } else {
        print("   Actual: \(actualCount) | Expected: \(expectedStr)")
    }
    print()
}

// Check for sources that exist but aren't in expected list
print("\n📌 Other Sources Found (not in expected list):\n")
for source in sources {
    if let identifier = source["identifier"] as? String,
       expectedCounts[identifier] == nil {
        let name = source["name"] as? String ?? identifier
        let count = movieCounts[identifier] ?? 0
        let url = source["url"] as? String ?? "N/A"
        print("   • \(name) (\(identifier)): \(count) movies")
        print("     URL: \(url)")
        print()
    }
}

// Summary
print("\n" + String(repeating: "=", count: 70))
print("📊 SUMMARY\n")

if missingSources.isEmpty && sourcesWithGaps.isEmpty {
    print("✅ All sources are complete!")
} else {
    if !missingSources.isEmpty {
        print("❌ Missing Sources (\(missingSources.count)):")
        for identifier in missingSources {
            if let info = expectedCounts[identifier] {
                print("   • \(identifier) - \(info.url)")
            }
        }
        print()
    }
    
    if !sourcesWithGaps.isEmpty {
        print("⚠️  Sources with Gaps (\(sourcesWithGaps.count)):")
        for gapInfo in sourcesWithGaps.sorted(by: { $0.gap > $1.gap }) {
            let expectedStr = gapInfo.expected.exact != nil ? "\(gapInfo.expected.exact!)" : "≥\(gapInfo.expected.min!)"
            print("   • \(gapInfo.name) (\(gapInfo.identifier))")
            print("     Actual: \(gapInfo.actual) | Expected: \(expectedStr) | Gap: \(gapInfo.gap)")
        }
        print()
    }
    
    print("Total missing entries: \(totalGaps)")
}

print("\n" + String(repeating: "=", count: 70))
print("Detailed breakdown by source:\n")

// Detailed breakdown
for source in sources.sorted(by: { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }) {
    guard let identifier = source["identifier"] as? String,
          let name = source["name"] as? String else { continue }
    
    let count = movieCounts[identifier] ?? 0
    let url = source["url"] as? String ?? "N/A"
    let type = source["type"] as? String ?? "unknown"
    let isRanked = (source["isRankedList"] as? Bool) == true
    let metadataCount = source["movieCount"] as? Int
    
    print("• \(name)")
    print("  Identifier: \(identifier)")
    print("  Type: \(type)\(isRanked ? " (Ranked)" : "")")
    print("  URL: \(url)")
    if let metaCount = metadataCount {
        if metaCount != count {
            print("  Movie Count: \(count) (metadata says: \(metaCount) - ⚠️  MISMATCH)")
        } else {
            print("  Movie Count: \(count) (matches metadata)")
        }
    } else {
        print("  Movie Count: \(count)")
    }
    
    if let expected = expectedCounts[identifier] {
        let expectedStr = expected.expected.exact != nil ? "\(expected.expected.exact!)" : "≥\(expected.expected.min!)"
        print("  Expected: \(expectedStr)")
        
        if let exact = expected.expected.exact {
            let diff = exact - count
            if diff > 0 {
                print("  ⚠️  Missing: \(diff)")
            } else if diff < 0 {
                print("  ℹ️  Extra: \(-diff)")
            }
        } else if let min = expected.expected.min, count < min {
            print("  ⚠️  Missing: \(min - count) (below minimum)")
        }
    }
    print()
}

