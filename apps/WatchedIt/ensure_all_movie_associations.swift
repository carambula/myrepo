#!/usr/bin/env swift

import Foundation
import SQLite3

/// Script to ensure all movies in bootstrap database have all their source associations
/// Cross-references with bootstrap_data.json to find missing associations and add them

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

print("🔍 Ensuring All Movie Associations\n")
print(String(repeating: "=", count: 70))

// Load JSON data
print("\n📂 Loading bootstrap_data.json...")
let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonPath))
let jsonDict = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
let jsonMovies = jsonDict?["movies"] as? [[String: Any]] ?? []

print("✅ Loaded \(jsonMovies.count) movie entries from JSON")

// Build map of expected associations: (tmdbId or title) -> [sourceIdentifier]
var expectedAssociations: [String: Set<String>] = [:]
var movieDetails: [String: (title: String, year: Int?, rank: Int?, sourceTitle: String?)] = [:]

for movie in jsonMovies {
    let title = (movie["title"] as? String ?? "").lowercased().trimmingCharacters(in: .whitespaces)
    let sourceIdentifier = movie["sourceIdentifier"] as? String ?? ""
    let tmdbId = movie["tmdbId"] as? Int
    let year = movie["year"] as? Int
    let rank = movie["rank"] as? Int
    let sourceTitle = movie["sourceTitle"] as? String
    
    // Key by TMDB ID if available, otherwise by title
    let key: String
    if let tmdbId = tmdbId {
        key = "tmdb-\(tmdbId)"
    } else {
        key = "title-\(title)"
    }
    
    if expectedAssociations[key] == nil {
        expectedAssociations[key] = []
    }
    expectedAssociations[key]?.insert(sourceIdentifier)
    
    // Store details (keep first occurrence or one with most data)
    if movieDetails[key] == nil || (year != nil && movieDetails[key]?.year == nil) {
        movieDetails[key] = (
            title: movie["title"] as? String ?? "",
            year: year,
            rank: rank,
            sourceTitle: sourceTitle
        )
    }
}

print("✅ Built expected associations map")

// Open database
var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ Error: Could not open database")
    exit(1)
}

defer {
    sqlite3_close(db)
}

print("\n📊 Analyzing database...")

// Get all movies from database with their current associations
let querySQL = """
    SELECT 
        m.Z_PK as movie_pk,
        m.ZTITLE,
        m.ZYEAR,
        m.ZTMDBID,
        GROUP_CONCAT(DISTINCT s.ZIDENTIFIER) as current_sources
    FROM ZMOVIEDATA m
    LEFT JOIN ZSOURCECONTENT sc ON sc.ZMOVIE = m.Z_PK
    LEFT JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
    GROUP BY m.Z_PK
"""

var stmt: OpaquePointer?
var moviesNeedingAssociations: [(pk: Int, title: String, year: Int?, tmdbId: Int?, currentSources: Set<String>, missingSources: Set<String>)] = []

if sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let pk = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let year = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
        let tmdbId = sqlite3_column_type(stmt, 3) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 3))
        let currentSourcesStr = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : ""
        
        let currentSources = Set(currentSourcesStr.split(separator: ",").map { String($0) })
        
        // Find expected associations
        let key: String
        if let tmdbId = tmdbId {
            key = "tmdb-\(tmdbId)"
        } else {
            key = "title-\(title.lowercased().trimmingCharacters(in: .whitespaces))"
        }
        
        let expectedSources = expectedAssociations[key] ?? []
        let missingSources = expectedSources.subtracting(currentSources)
        
        if !missingSources.isEmpty {
            moviesNeedingAssociations.append((
                pk: pk,
                title: title,
                year: year,
                tmdbId: tmdbId,
                currentSources: currentSources,
                missingSources: missingSources
            ))
        }
    }
}

sqlite3_finalize(stmt)

if moviesNeedingAssociations.isEmpty {
    print("✅ All movies have their expected associations!")
    exit(0)
}

print("\n⚠️  Found \(moviesNeedingAssociations.count) movies missing source associations:\n")

// Show first 20
for (index, movie) in moviesNeedingAssociations.prefix(20).enumerated() {
    print("\(index + 1). \(movie.title) (\(movie.year ?? 0))")
    print("   Current: \(movie.currentSources.isEmpty ? "NONE" : movie.currentSources.joined(separator: ", "))")
    print("   Missing: \(movie.missingSources.joined(separator: ", "))")
    print()
}

if moviesNeedingAssociations.count > 20 {
    print("   ... and \(moviesNeedingAssociations.count - 20) more\n")
}

print("\n🔧 Adding missing associations...")
print(String(repeating: "-", count: 70))

var addedCount = 0

for movie in moviesNeedingAssociations {
    for sourceIdentifier in movie.missingSources {
        // Get source PK
        let getSourceSQL = "SELECT Z_PK FROM ZDATASOURCE WHERE ZIDENTIFIER = ?"
        var sourceStmt: OpaquePointer?
        var sourcePk: Int? = nil
        
        if sqlite3_prepare_v2(db, getSourceSQL, -1, &sourceStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(sourceStmt, 1, (sourceIdentifier as NSString).utf8String, -1, nil)
            if sqlite3_step(sourceStmt) == SQLITE_ROW {
                sourcePk = Int(sqlite3_column_int(sourceStmt, 0))
            }
        }
        sqlite3_finalize(sourceStmt)
        
        guard let sourcePk = sourcePk else {
            print("   ⚠️  Source '\(sourceIdentifier)' not found in database")
            continue
        }
        
        // Get source details to determine if it's ranked
        let getSourceDetailsSQL = "SELECT ZISRANKEDLIST FROM ZDATASOURCE WHERE Z_PK = ?"
        var detailsStmt: OpaquePointer?
        var isRanked = false
        
        if sqlite3_prepare_v2(db, getSourceDetailsSQL, -1, &detailsStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(detailsStmt, 1, Int32(sourcePk))
            if sqlite3_step(detailsStmt) == SQLITE_ROW {
                isRanked = sqlite3_column_int(detailsStmt, 0) != 0
            }
        }
        sqlite3_finalize(detailsStmt)
        
        // Find rank and source title from JSON
        let key: String
        if let tmdbId = movie.tmdbId {
            key = "tmdb-\(tmdbId)"
        } else {
            key = "title-\(movie.title.lowercased().trimmingCharacters(in: .whitespaces))"
        }
        
        let details = movieDetails[key]
        let rank = isRanked ? (details?.rank) : nil
        let sourceTitle = details?.sourceTitle ?? movie.title
        
        // Check if link already exists
        let checkLinkSQL = """
            SELECT COUNT(*) FROM ZSOURCECONTENT
            WHERE ZMOVIE = ? AND ZSOURCE = ?
        """
        var checkStmt: OpaquePointer?
        var linkExists = false
        
        if sqlite3_prepare_v2(db, checkLinkSQL, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(checkStmt, 1, Int32(movie.pk))
            sqlite3_bind_int(checkStmt, 2, Int32(sourcePk))
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                linkExists = sqlite3_column_int(checkStmt, 0) > 0
            }
        }
        sqlite3_finalize(checkStmt)
        
        if linkExists {
            continue
        }
        
        // Create SourceContent link
        let insertSQL = """
            INSERT INTO ZSOURCECONTENT (ZMOVIE, ZSOURCE, ZSOURCETITLE, ZRANK, ZLASTUPDATED, ZDISCOVEREDAT)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        var insertStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(insertStmt, 1, Int32(movie.pk))
            sqlite3_bind_int(insertStmt, 2, Int32(sourcePk))
            
            let sourceTitleCStr = (sourceTitle as NSString).utf8String
            sqlite3_bind_text(insertStmt, 3, sourceTitleCStr, -1, nil)
            
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
                print("   ✅ Added link: \(movie.title) -> \(sourceIdentifier)")
            }
        }
        
        sqlite3_finalize(insertStmt)
    }
}

print("\n" + String(repeating: "=", count: 70))
print("✅ Added \(addedCount) missing source associations")
print("✅ Database updated successfully!")





