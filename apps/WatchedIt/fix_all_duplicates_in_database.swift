#!/usr/bin/env swift

import Foundation
import SQLite3

/// Script to fix ALL duplicate issues in bootstrap database:
/// 1. Remove duplicate source links (same movie + same source, multiple times)
/// 2. Fix duplicate MovieData entries (same title+year or TMDB ID)

let dbPath = "WatchedIt/bootstrap_database.store"

guard FileManager.default.fileExists(atPath: dbPath) else {
    print("❌ Error: bootstrap_database.store not found")
    exit(1)
}

print("🔧 Fixing All Duplicates in Bootstrap Database\n")
print(String(repeating: "=", count: 70))

var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ Error: Could not open database")
    exit(1)
}

defer {
    sqlite3_close(db)
}

// STEP 1: Fix duplicate source links
print("\n1️⃣ Fixing duplicate source links...")
print(String(repeating: "-", count: 70))

let findDuplicateLinksSQL = """
    SELECT 
        m.Z_PK as movie_pk,
        s.Z_PK as source_pk,
        m.ZTITLE,
        s.ZNAME,
        COUNT(*) as link_count,
        GROUP_CONCAT(sc.Z_PK) as link_pks
    FROM ZSOURCECONTENT sc
    JOIN ZMOVIEDATA m ON sc.ZMOVIE = m.Z_PK
    JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
    GROUP BY m.Z_PK, s.Z_PK
    HAVING link_count > 1
"""

var stmt: OpaquePointer?
var duplicateLinks: [(moviePk: Int, sourcePk: Int, title: String, sourceName: String, linkPks: [Int])] = []

if sqlite3_prepare_v2(db, findDuplicateLinksSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let moviePk = Int(sqlite3_column_int(stmt, 0))
        let sourcePk = Int(sqlite3_column_int(stmt, 1))
        let title = String(cString: sqlite3_column_text(stmt, 2))
        let sourceName = String(cString: sqlite3_column_text(stmt, 3))
        let linkCount = Int(sqlite3_column_int(stmt, 4))
        let linkPksString = String(cString: sqlite3_column_text(stmt, 5))
        
        let linkPks = linkPksString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        duplicateLinks.append((moviePk: moviePk, sourcePk: sourcePk, title: title, sourceName: sourceName, linkPks: linkPks))
        
        print("   Found: \(title) on \(sourceName): \(linkCount) duplicate links")
    }
}

sqlite3_finalize(stmt)

var removedLinksCount = 0

for duplicate in duplicateLinks {
    // Keep first link, remove others
    let keepPk = duplicate.linkPks.first!
    let removePks = Array(duplicate.linkPks.dropFirst())
    
    for removePk in removePks {
        let deleteSQL = "DELETE FROM ZSOURCECONTENT WHERE Z_PK = ?"
        var deleteStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStmt, 1, Int32(removePk))
            if sqlite3_step(deleteStmt) == SQLITE_DONE {
                removedLinksCount += 1
                print("   ✅ Removed duplicate link \(removePk) for \(duplicate.title) on \(duplicate.sourceName)")
            }
        }
        
        sqlite3_finalize(deleteStmt)
    }
}

print("   ✅ Removed \(removedLinksCount) duplicate source links")

// STEP 2: Fix duplicate MovieData entries
print("\n2️⃣ Fixing duplicate MovieData entries...")
print(String(repeating: "-", count: 70))

// Find duplicates by title + year
let findDuplicateMoviesSQL = """
    SELECT ZTITLE, ZYEAR, COUNT(*) as count, GROUP_CONCAT(Z_PK) as pks, GROUP_CONCAT(ZTMDBID) as tmdb_ids
    FROM ZMOVIEDATA
    WHERE ZTITLE IS NOT NULL AND ZYEAR IS NOT NULL
    GROUP BY ZTITLE, ZYEAR
    HAVING count > 1
"""

var duplicateMovies: [(title: String, year: Int, pks: [Int], tmdbIds: [Int?])] = []

if sqlite3_prepare_v2(db, findDuplicateMoviesSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let title = String(cString: sqlite3_column_text(stmt, 0))
        let year = Int(sqlite3_column_int(stmt, 1))
        let count = Int(sqlite3_column_int(stmt, 2))
        let pksString = sqlite3_column_text(stmt, 3) != nil ? String(cString: sqlite3_column_text(stmt, 3)) : ""
        let tmdbIdsString = sqlite3_column_text(stmt, 4) != nil ? String(cString: sqlite3_column_text(stmt, 4)) : ""
        
        let pks = pksString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        let tmdbIds = tmdbIdsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) == "NULL" || $0.isEmpty ? nil : Int($0) }
        
        duplicateMovies.append((title: title, year: year, pks: pks, tmdbIds: tmdbIds))
        
        print("   Found: \(title) (\(year)): \(count) duplicate entries")
    }
}

sqlite3_finalize(stmt)

var removedMoviesCount = 0
var mergedLinksCount = 0

for duplicate in duplicateMovies {
    // Find the best entry to keep (prefer one with TMDB ID, or first one)
    var keepPk: Int? = nil
    var removePks: [Int] = []
    
    // Prefer entry with valid TMDB ID
    if let index = duplicate.tmdbIds.firstIndex(where: { $0 != nil && $0 != 0 }) {
        keepPk = duplicate.pks[index]
        removePks = duplicate.pks.enumerated().filter { $0.offset != index }.map { $0.element }
    } else {
        // No TMDB IDs, keep first and remove others
        keepPk = duplicate.pks.first!
        removePks = Array(duplicate.pks.dropFirst())
    }
    
    guard let keepPk = keepPk, !removePks.isEmpty else { continue }
    
    print("   Merging: \(duplicate.title) (\(duplicate.year))")
    print("      Keeping PK: \(keepPk)")
    
    // For each duplicate, move source links to the kept entry, then delete
    for removePk in removePks {
        // Check what sources the duplicate has
        let getLinksSQL = """
            SELECT sc.ZSOURCE, sc.ZSOURCETITLE, sc.ZRANK
            FROM ZSOURCECONTENT sc
            WHERE sc.ZMOVIE = ?
        """
        var linksStmt: OpaquePointer?
        var linksToTransfer: [(sourcePk: Int, sourceTitle: String?, rank: Int?)] = []
        
        if sqlite3_prepare_v2(db, getLinksSQL, -1, &linksStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(linksStmt, 1, Int32(removePk))
            while sqlite3_step(linksStmt) == SQLITE_ROW {
                let sourcePk = Int(sqlite3_column_int(linksStmt, 0))
                let sourceTitle = sqlite3_column_text(linksStmt, 1) != nil ? String(cString: sqlite3_column_text(linksStmt, 1)) : nil
                let rank = sqlite3_column_type(linksStmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(linksStmt, 2))
                linksToTransfer.append((sourcePk: sourcePk, sourceTitle: sourceTitle, rank: rank))
            }
        }
        sqlite3_finalize(linksStmt)
        
        // Transfer links that don't already exist
        for link in linksToTransfer {
            // Check if link already exists
            let checkSQL = "SELECT COUNT(*) FROM ZSOURCECONTENT WHERE ZMOVIE = ? AND ZSOURCE = ?"
            var checkStmt: OpaquePointer?
            var exists = false
            
            if sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK {
                sqlite3_bind_int(checkStmt, 1, Int32(keepPk))
                sqlite3_bind_int(checkStmt, 2, Int32(link.sourcePk))
                if sqlite3_step(checkStmt) == SQLITE_ROW {
                    exists = sqlite3_column_int(checkStmt, 0) > 0
                }
            }
            sqlite3_finalize(checkStmt)
            
            if !exists {
                // Create new link
                let insertSQL = """
                    INSERT INTO ZSOURCECONTENT (ZMOVIE, ZSOURCE, ZSOURCETITLE, ZRANK, ZLASTUPDATED, ZDISCOVEREDAT)
                    SELECT ?, ZSOURCE, ZSOURCETITLE, ZRANK, ZLASTUPDATED, ZDISCOVEREDAT
                    FROM ZSOURCECONTENT
                    WHERE ZMOVIE = ? AND ZSOURCE = ?
                    LIMIT 1
                """
                var insertStmt: OpaquePointer?
                
                if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) == SQLITE_OK {
                    sqlite3_bind_int(insertStmt, 1, Int32(keepPk))
                    sqlite3_bind_int(insertStmt, 2, Int32(removePk))
                    sqlite3_bind_int(insertStmt, 3, Int32(link.sourcePk))
                    if sqlite3_step(insertStmt) == SQLITE_DONE {
                        mergedLinksCount += 1
                    }
                }
                sqlite3_finalize(insertStmt)
            }
        }
        
        // Delete the duplicate movie (cascading will remove its links)
        let deleteSQL = "DELETE FROM ZMOVIEDATA WHERE Z_PK = ?"
        var deleteStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStmt, 1, Int32(removePk))
            if sqlite3_step(deleteStmt) == SQLITE_DONE {
                removedMoviesCount += 1
                print("      ✅ Deleted duplicate PK: \(removePk)")
            }
        }
        
        sqlite3_finalize(deleteStmt)
    }
}

print("   ✅ Removed \(removedMoviesCount) duplicate movie entries")
print("   ✅ Merged \(mergedLinksCount) source links")

print("\n" + String(repeating: "=", count: 70))
print("✅ Fixed all duplicates:")
print("   - Removed \(removedLinksCount) duplicate source links")
print("   - Removed \(removedMoviesCount) duplicate movie entries")
print("   - Merged \(mergedLinksCount) source links")
print("✅ Database updated successfully!")





