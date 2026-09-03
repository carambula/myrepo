#!/usr/bin/env swift

import Foundation
import SQLite3

/// Comprehensive script to ensure ALL movies in database have associations
/// Cross-references JSON to find and fix any missing associations

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

print("🔧 Comprehensive Association Fix\n")
print(String(repeating: "=", count: 70))

// Load JSON
print("\n📂 Loading bootstrap_data.json...")
let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
let jsonMovies = jsonDict?["movies"] as? [[String: Any]] ?? []

print("✅ Loaded \(jsonMovies.count) movie entries from JSON")

// Build comprehensive association map
// Key format: "tmdb-{id}" or "title-{normalized}"
var associationsMap: [String: [(source: String, rank: Int?, sourceTitle: String?, title: String, year: Int?)]] = [:]

for movie in jsonMovies {
    let title = (movie["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
    let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
    let sourceIdentifier = movie["sourceIdentifier"] as? String ?? ""
    let tmdbId = movie["tmdbId"] as? Int
    let year = movie["year"] as? Int
    let rank = movie["rank"] as? Int
    let sourceTitle = movie["sourceTitle"] as? String
    
    // Create keys - both TMDB and title-based
    var keys: [String] = []
    if let tmdbId = tmdbId {
        keys.append("tmdb-\(tmdbId)")
    }
    keys.append("title-\(normalizedTitle)")
    if let year = year {
        keys.append("title-\(normalizedTitle)-\(year)")
    }
    
    for key in keys {
        if associationsMap[key] == nil {
            associationsMap[key] = []
        }
        associationsMap[key]?.append((
            source: sourceIdentifier,
            rank: rank,
            sourceTitle: sourceTitle,
            title: title,
            year: year
        ))
    }
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

print("\n🔍 Analyzing database...")

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
print("✅ Found \(sourceMap.count) sources")

// Get all movies and their current associations
let getMoviesSQL = """
    SELECT 
        m.Z_PK, m.ZTITLE, m.ZYEAR, m.ZTMDBID,
        GROUP_CONCAT(DISTINCT s.ZIDENTIFIER) as current_sources
    FROM ZMOVIEDATA m
    LEFT JOIN ZSOURCECONTENT sc ON sc.ZMOVIE = m.Z_PK
    LEFT JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
    GROUP BY m.Z_PK
"""

var moviesNeedingAssociations: [(pk: Int, title: String, year: Int?, tmdbId: Int?, missing: [(source: String, rank: Int?, sourceTitle: String?)])] = []

if sqlite3_prepare_v2(db, getMoviesSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let year = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
        let tmdbId = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
        let currentSourcesStr = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : ""
        
        let currentSources = Set(currentSourcesStr.split(separator: ",").compactMap { $0.isEmpty ? nil : String($0) })
        
        // Find expected associations using multiple key strategies
        var expected: [(source: String, rank: Int?, sourceTitle: String?, title: String, year: Int?)] = []
        
        if let tmdbId = tmdbId {
            expected = associationsMap["tmdb-\(tmdbId)"] ?? []
        }
        
        if expected.isEmpty {
            let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespaces)
            if let year = year {
                expected = associationsMap["title-\(normalizedTitle)-\(year)"] ?? []
            }
            if expected.isEmpty {
                expected = associationsMap["title-\(normalizedTitle)"] ?? []
            }
        }
        
        let missing = expected.filter { !currentSources.contains($0.source) }
        
        if !missing.isEmpty {
            moviesNeedingAssociations.append((
                pk: pk,
                title: title,
                year: year,
                tmdbId: tmdbId,
                missing: missing.map { (source: $0.source, rank: $0.rank, sourceTitle: $0.sourceTitle) }
            ))
        }
    }
}
sqlite3_finalize(stmt)

// Also check for movies with NO associations at all
let getOrphanedSQL = """
    SELECT m.Z_PK, m.ZTITLE, m.ZYEAR, m.ZTMDBID
    FROM ZMOVIEDATA m
    LEFT JOIN ZSOURCECONTENT sc ON sc.ZMOVIE = m.Z_PK
    WHERE sc.Z_PK IS NULL
"""

var orphanedMovies: [(pk: Int, title: String, year: Int?, tmdbId: Int?)] = []

if sqlite3_prepare_v2(db, getOrphanedSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let year = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
        let tmdbId = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
        
        orphanedMovies.append((pk: pk, title: title, year: year, tmdbId: tmdbId))
    }
}
sqlite3_finalize(stmt)

// Find associations for orphaned movies
for orphan in orphanedMovies {
    var expected: [(source: String, rank: Int?, sourceTitle: String?)] = []
    
    if let tmdbId = orphan.tmdbId {
        if let assoc = associationsMap["tmdb-\(tmdbId)"] {
            expected = assoc.map { (source: $0.source, rank: $0.rank, sourceTitle: $0.sourceTitle) }
        }
    }
    
    if expected.isEmpty {
        let normalizedTitle = orphan.title.lowercased().trimmingCharacters(in: .whitespaces)
        if let year = orphan.year {
            if let assoc = associationsMap["title-\(normalizedTitle)-\(year)"] {
                expected = assoc.map { (source: $0.source, rank: $0.rank, sourceTitle: $0.sourceTitle) }
            }
        }
        if expected.isEmpty {
            if let assoc = associationsMap["title-\(normalizedTitle)"] {
                expected = assoc.map { (source: $0.source, rank: $0.rank, sourceTitle: $0.sourceTitle) }
            }
        }
    }
    
    if !expected.isEmpty {
        moviesNeedingAssociations.append((
            pk: orphan.pk,
            title: orphan.title,
            year: orphan.year,
            tmdbId: orphan.tmdbId,
            missing: expected
        ))
    }
}

if moviesNeedingAssociations.isEmpty {
    print("\n✅ All movies have their expected associations!")
    exit(0)
}

print("\n⚠️  Found \(moviesNeedingAssociations.count) movies needing associations:\n")

// Show first 20
for (index, movie) in moviesNeedingAssociations.prefix(20).enumerated() {
    print("\(index + 1). \(movie.title) (\(movie.year ?? 0))")
    for missing in movie.missing {
        print("   Missing: \(missing.source)\(missing.rank != nil ? " (rank: \(missing.rank!))" : "")")
    }
    print()
}

if moviesNeedingAssociations.count > 20 {
    print("   ... and \(moviesNeedingAssociations.count - 20) more\n")
}

print("\n🔧 Adding missing associations...")
print(String(repeating: "-", count: 70))

var addedCount = 0

for movie in moviesNeedingAssociations {
    for missing in movie.missing {
        guard let sourceInfo = sourceMap[missing.source] else {
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
            
            let sourceTitle = missing.sourceTitle ?? movie.title
            sqlite3_bind_text(insertStmt, 3, (sourceTitle as NSString).utf8String, -1, nil)
            
            let rank = sourceInfo.isRanked ? missing.rank : nil
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
                    print("   ✅ \(movie.title) -> \(missing.source)")
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





