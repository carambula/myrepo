#!/usr/bin/env swift

import Foundation
import SQLite3

/// Script to ensure ALL movies have ALL their source associations
/// Cross-references JSON to find every association that should exist

let dbPath = "WatchedIt/bootstrap_database.store"
let jsonPath = "WatchedIt/bootstrap_data.json"

guard FileManager.default.fileExists(atPath: dbPath) else {
    print("❌ Error: bootstrap_database.store not found")
    exit(1)
}

guard FileManager.default.fileExists(atPath: jsonPath) else {
    print("❌ Error: bootstrap_data.json not found")
    exit(1)
}

print("🔧 Fixing All Missing Movie Associations\n")
print(String(repeating: "=", count: 70))

// Load JSON
print("\n📂 Loading bootstrap_data.json...")
let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
let jsonMovies = jsonDict?["movies"] as? [[String: Any]] ?? []

print("✅ Loaded \(jsonMovies.count) movie entries")

// Build map: For each movie (by TMDB ID), track ALL sources it should be in
var movieToAllSources: [Int: [(source: String, rank: Int?, sourceTitle: String?, title: String, year: Int?)]] = [:]
var titleToAllSources: [String: [(source: String, rank: Int?, sourceTitle: String?, title: String, year: Int?, tmdbId: Int?)]] = [:]

for movie in jsonMovies {
    let title = (movie["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
    let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
    let sourceIdentifier = movie["sourceIdentifier"] as? String ?? ""
    let tmdbId = movie["tmdbId"] as? Int
    let year = movie["year"] as? Int
    let rank = movie["rank"] as? Int
    let sourceTitle = movie["sourceTitle"] as? String
    
    let entry = (source: sourceIdentifier, rank: rank, sourceTitle: sourceTitle, title: title, year: year)
    
    if let tmdbId = tmdbId {
        if movieToAllSources[tmdbId] == nil {
            movieToAllSources[tmdbId] = []
        }
        movieToAllSources[tmdbId]?.append(entry)
    }
    
    // Also track by title for movies without TMDB ID
    let titleKey = "\(normalizedTitle)-\(year ?? 0)"
    if titleToAllSources[titleKey] == nil {
        titleToAllSources[titleKey] = []
    }
    titleToAllSources[titleKey]?.append((source: sourceIdentifier, rank: rank, sourceTitle: sourceTitle, title: title, year: year, tmdbId: tmdbId))
}

print("✅ Built associations map")

// Open database
var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ Error: Could not open database")
    exit(1)
}

defer {
    sqlite3_close(db)
}

// Get source map
var sourceMap: [String: (pk: Int, isRanked: Bool)] = [:]
let getSourcesSQL = "SELECT Z_PK, ZIDENTIFIER, ZISRANKEDLIST FROM ZDATASOURCE"
var stmt: OpaquePointer?

if sqlite3_prepare_v2(db, getSourcesSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = Int(sqlite3_column_int(stmt, 0))
        let identifier = String(cString: sqlite3_column_text(stmt, 1))
        let isRanked = sqlite3_column_int(stmt, 2) != 0
        sourceMap[identifier] = (pk: pk, isRanked: isRanked)
    }
}
sqlite3_finalize(stmt)

print("✅ Found \(sourceMap.count) sources in database")

// Get all movies and check against expected associations
let getMoviesSQL = """
    SELECT 
        m.Z_PK, m.ZTITLE, m.ZYEAR, m.ZTMDBID,
        GROUP_CONCAT(DISTINCT s.ZIDENTIFIER) as current_sources
    FROM ZMOVIEDATA m
    LEFT JOIN ZSOURCECONTENT sc ON sc.ZMOVIE = m.Z_PK
    LEFT JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
    GROUP BY m.Z_PK
"""

var moviesToFix: [(pk: Int, title: String, year: Int?, tmdbId: Int?, expectedSources: [(source: String, rank: Int?, sourceTitle: String?)], currentSources: Set<String>)] = []

if sqlite3_prepare_v2(db, getMoviesSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let year = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
        let tmdbId = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
        let currentSourcesStr = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : ""
        
        let currentSources = Set(currentSourcesStr.split(separator: ",").compactMap { $0.isEmpty ? nil : String($0) })
        
        // Find expected sources
        var expectedSources: [(source: String, rank: Int?, sourceTitle: String?)] = []
        
        if let tmdbId = tmdbId, let expected = movieToAllSources[tmdbId] {
            expectedSources = expected.map { (source: $0.source, rank: $0.rank, sourceTitle: $0.sourceTitle) }
        }
        
        // If no TMDB match, try by title+year
        if expectedSources.isEmpty {
            let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
            let titleKey = "\(normalizedTitle)-\(year ?? 0)"
            if let expected = titleToAllSources[titleKey] {
                expectedSources = expected.map { (source: $0.source, rank: $0.rank, sourceTitle: $0.sourceTitle) }
            }
        }
        
        let missingSources = expectedSources.filter { !currentSources.contains($0.source) }
        
        if !missingSources.isEmpty {
            moviesToFix.append((
                pk: pk,
                title: title,
                year: year,
                tmdbId: tmdbId,
                expectedSources: expectedSources,
                currentSources: currentSources
            ))
        }
    }
}
sqlite3_finalize(stmt)

if moviesToFix.isEmpty {
    print("\n✅ All movies have all their expected associations!")
    exit(0)
}

print("\n⚠️  Found \(moviesToFix.count) movies missing some associations\n")

// Show first 20
for (index, movie) in moviesToFix.prefix(20).enumerated() {
    print("\(index + 1). \(movie.title) (\(movie.year ?? 0))")
    let missing = movie.expectedSources.filter { !movie.currentSources.contains($0.source) }
    print("   Has: \(movie.currentSources.isEmpty ? "NONE" : movie.currentSources.joined(separator: ", "))")
    print("   Missing: \(missing.map { $0.source }.joined(separator: ", "))")
    print()
}

if moviesToFix.count > 20 {
    print("   ... and \(moviesToFix.count - 20) more\n")
}

print("\n🔧 Adding missing associations...")
print(String(repeating: "-", count: 70))

var addedCount = 0

for movie in moviesToFix {
    let missing = movie.expectedSources.filter { !movie.currentSources.contains($0.source) }
    
    for missingSource in missing {
        guard let sourceInfo = sourceMap[missingSource.source] else {
            continue
        }
        
        // Check if link already exists
        let checkSQL = "SELECT COUNT(*) FROM ZSOURCECONTENT WHERE ZMOVIE = ? AND ZSOURCE = ?"
        var checkStmt: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStmt, 1, Int32(movie.pk))
            sqlite3_bind_int(checkStmt, 2, Int32(sourceInfo.pk))
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                exists = sqlite3_column_int(checkStmt, 0) > 0
            }
        }
        sqlite3_finalize(checkStmt)
        
        if exists {
            continue
        }
        
        // Insert SourceContent
        let insertSQL = """
            INSERT INTO ZSOURCECONTENT (ZMOVIE, ZSOURCE, ZSOURCETITLE, ZRANK, ZLASTUPDATED, ZDISCOVEREDAT)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        var insertStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(insertStmt, 1, Int32(movie.pk))
            sqlite3_bind_int(insertStmt, 2, Int32(sourceInfo.pk))
            
            let sourceTitle = missingSource.sourceTitle ?? movie.title
            sqlite3_bind_text(insertStmt, 3, (sourceTitle as NSString).utf8String, -1, nil)
            
            let rank = sourceInfo.isRanked ? missingSource.rank : nil
            if let rank = rank {
                sqlite3_bind_int(insertStmt, 4, Int32(rank))
            } else {
                sqlite3_bind_null(insertStmt, 4)
            }
            
            let now = Date().timeIntervalSince1970
            sqlite3_bind_double(insertStmt, 5, now)
            sqlite3_bind_double(insertStmt, 6, now)
            
            if sqlite3_step(insertStmt) == SQLITE_DONE {
                addedCount += 1
                if addedCount <= 30 {
                    print("   ✅ \(movie.title) -> \(missingSource.source)")
                }
            }
        }
        
        sqlite3_finalize(insertStmt)
    }
}

if addedCount > 30 {
    print("   ... and \(addedCount - 30) more")
}

print("\n" + String(repeating: "=", count: 70))
print("✅ Added \(addedCount) missing source associations")
print("✅ Database updated successfully!")





