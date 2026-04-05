#!/usr/bin/env swift

import Foundation
import SQLite3

/// Comprehensive script to ensure ALL movies have associations
/// 1. Checks bootstrap database for missing associations
/// 2. Cross-references with JSON to find missing links
/// 3. Adds any missing associations

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

print("🔧 Fixing All Movie Associations\n")
print(String(repeating: "=", count: 70))

// Load JSON
print("\n📂 Loading bootstrap_data.json...")
let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
let jsonMovies = jsonDict?["movies"] as? [[String: Any]] ?? []

print("✅ Loaded \(jsonMovies.count) movie entries")

// Build comprehensive map: (tmdbId or title+year) -> [sources]
var expectedAssociations: [String: [(source: String, rank: Int?, sourceTitle: String?)]] = [:]

for movie in jsonMovies {
    let title = (movie["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
    let sourceIdentifier = movie["sourceIdentifier"] as? String ?? ""
    let tmdbId = movie["tmdbId"] as? Int
    let year = movie["year"] as? Int
    let rank = movie["rank"] as? Int
    let sourceTitle = movie["sourceTitle"] as? String
    
    // Create key - prefer TMDB ID, fallback to title+year
    let key: String
    if let tmdbId = tmdbId {
        key = "tmdb-\(tmdbId)"
    } else if let year = year {
        key = "title-\(title.lowercased())-\(year)"
    } else {
        key = "title-\(title.lowercased())"
    }
    
    if expectedAssociations[key] == nil {
        expectedAssociations[key] = []
    }
    expectedAssociations[key]?.append((source: sourceIdentifier, rank: rank, sourceTitle: sourceTitle))
}

print("✅ Built associations map for \(expectedAssociations.count) unique movies")

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
var sourceMap: [String: Int] = [:]
let getSourcesSQL = "SELECT Z_PK, ZIDENTIFIER, ZISRANKEDLIST FROM ZDATASOURCE"
var stmt: OpaquePointer?

if sqlite3_prepare_v2(db, getSourcesSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = Int(sqlite3_column_int(stmt, 0))
        let identifier = String(cString: sqlite3_column_text(stmt, 1))
        sourceMap[identifier] = pk
    }
}

sqlite3_finalize(stmt)
print("✅ Found \(sourceMap.count) sources in database")

// Get all movies and check associations
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
        
        let currentSources = Set(currentSourcesStr.split(separator: ",").map { String($0) })
        
        // Find expected associations
        var key: String
        if let tmdbId = tmdbId {
            key = "tmdb-\(tmdbId)"
        } else if let year = year {
            key = "title-\(title.lowercased())-\(year)"
        } else {
            key = "title-\(title.lowercased())"
        }
        
        var expected = expectedAssociations[key]
        
        // Try alternative keys if not found
        if expected == nil {
            if let year = year {
                expected = expectedAssociations["title-\(title.lowercased())-\(year)"]
            }
            if expected == nil {
                expected = expectedAssociations["title-\(title.lowercased())"]
            }
            if expected == nil, let tmdbId = tmdbId {
                expected = expectedAssociations["tmdb-\(tmdbId)"]
            }
        }
        
        guard let expected = expected else { continue }
        
        let missing = expected.filter { !currentSources.contains($0.source) }
        
        if !missing.isEmpty {
            moviesNeedingAssociations.append((
                pk: pk,
                title: title,
                year: year,
                tmdbId: tmdbId,
                missing: missing
            ))
        }
    }
}

sqlite3_finalize(stmt)

if moviesNeedingAssociations.isEmpty {
    print("\n✅ All movies have all their expected associations!")
    exit(0)
}

print("\n⚠️  Found \(moviesNeedingAssociations.count) movies with missing associations\n")

// Show first 10
for (index, movie) in moviesNeedingAssociations.prefix(10).enumerated() {
    print("\(index + 1). \(movie.title) (\(movie.year ?? 0))")
    for missing in movie.missing {
        print("   Missing: \(missing.source) (rank: \(missing.rank ?? 0))")
    }
    print()
}

if moviesNeedingAssociations.count > 10 {
    print("   ... and \(moviesNeedingAssociations.count - 10) more\n")
}

print("\n🔧 Adding missing associations...")
print(String(repeating: "-", count: 70))

var addedCount = 0

for movie in moviesNeedingAssociations {
    for missing in movie.missing {
        guard let sourcePk = sourceMap[missing.source] else {
            print("   ⚠️  Source '\(missing.source)' not found")
            continue
        }
        
        // Check if link already exists
        let checkSQL = "SELECT COUNT(*) FROM ZSOURCECONTENT WHERE ZMOVIE = ? AND ZSOURCE = ?"
        var checkStmt: OpaquePointer?
        var exists = false
        
        if sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStmt, 1, Int32(movie.pk))
            sqlite3_bind_int(checkStmt, 2, Int32(sourcePk))
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                exists = sqlite3_column_int(checkStmt, 0) > 0
            }
        }
        sqlite3_finalize(checkStmt)
        
        if exists {
            continue
        }
        
        // Get if source is ranked
        let getRankedSQL = "SELECT ZISRANKEDLIST FROM ZDATASOURCE WHERE Z_PK = ?"
        var rankedStmt: OpaquePointer?
        var isRanked = false
        
        if sqlite3_prepare_v2(db, getRankedSQL, -1, &rankedStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(rankedStmt, 1, Int32(sourcePk))
            if sqlite3_step(rankedStmt) == SQLITE_ROW {
                isRanked = sqlite3_column_int(rankedStmt, 0) != 0
            }
        }
        sqlite3_finalize(rankedStmt)
        
        // Insert SourceContent
        let insertSQL = """
            INSERT INTO ZSOURCECONTENT (ZMOVIE, ZSOURCE, ZSOURCETITLE, ZRANK, ZLASTUPDATED, ZDISCOVEREDAT)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        var insertStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(insertStmt, 1, Int32(movie.pk))
            sqlite3_bind_int(insertStmt, 2, Int32(sourcePk))
            
            let sourceTitle = missing.sourceTitle ?? movie.title
            sqlite3_bind_text(insertStmt, 3, (sourceTitle as NSString).utf8String, -1, nil)
            
            let rank = isRanked ? missing.rank : nil
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
                if addedCount <= 20 {
                    print("   ✅ \(movie.title) -> \(missing.source)")
                }
            }
        }
        
        sqlite3_finalize(insertStmt)
    }
}

if addedCount > 20 {
    print("   ... and \(addedCount - 20) more")
}

print("\n" + String(repeating: "=", count: 70))
print("✅ Added \(addedCount) missing source associations")
print("✅ Database updated successfully!")





