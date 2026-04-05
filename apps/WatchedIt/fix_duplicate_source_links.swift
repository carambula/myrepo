#!/usr/bin/env swift

import Foundation
import SQLite3

/// Script to fix duplicate source links in bootstrap database
/// Removes duplicate SourceContent entries that link the same movie to the same source

let dbPath = "WatchedIt/bootstrap_database.store"

guard FileManager.default.fileExists(atPath: dbPath) else {
    print("❌ Error: bootstrap_database.store not found")
    exit(1)
}

print("🔧 Fixing Duplicate Source Links in Bootstrap Database\n")
print(String(repeating: "=", count: 70))

var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ Error: Could not open database")
    exit(1)
}

defer {
    sqlite3_close(db)
}

// Find duplicate source links
print("\n1️⃣ Finding duplicate source links...")
print(String(repeating: "-", count: 70))

let findDuplicatesSQL = """
    SELECT 
        m.Z_PK as movie_pk,
        m.ZTITLE,
        m.ZYEAR,
        s.Z_PK as source_pk,
        s.ZNAME,
        COUNT(*) as link_count,
        GROUP_CONCAT(sc.Z_PK) as link_pks
    FROM ZSOURCECONTENT sc
    JOIN ZMOVIEDATA m ON sc.ZMOVIE = m.Z_PK
    JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
    GROUP BY m.Z_PK, s.Z_PK
    HAVING link_count > 1
    ORDER BY link_count DESC
"""

var stmt: OpaquePointer?
var duplicates: [(moviePk: Int, sourcePk: Int, linkPks: [Int], movieTitle: String, sourceName: String)] = []

if sqlite3_prepare_v2(db, findDuplicatesSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let moviePk = Int(sqlite3_column_int(stmt, 0))
        let title = String(cString: sqlite3_column_text(stmt, 1))
        let year = Int(sqlite3_column_int(stmt, 2))
        let sourcePk = Int(sqlite3_column_int(stmt, 3))
        let sourceName = String(cString: sqlite3_column_text(stmt, 4))
        let linkCount = Int(sqlite3_column_int(stmt, 5))
        let linkPksString = String(cString: sqlite3_column_text(stmt, 6))
        
        let linkPks = linkPksString.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        
        duplicates.append((moviePk: moviePk, sourcePk: sourcePk, linkPks: linkPks, movieTitle: "\(title) (\(year))", sourceName: sourceName))
        
        print("   Found: \(title) (\(year)) on \(sourceName): \(linkCount) links")
    }
}

sqlite3_finalize(stmt)

if duplicates.isEmpty {
    print("\n✅ No duplicate source links found!")
    exit(0)
}

print("\n📊 Found \(duplicates.count) movies with duplicate source links")

// Fix duplicates by keeping the best link and removing others
print("\n2️⃣ Removing duplicate links (keeping best one)...")
print(String(repeating: "-", count: 70))

var removedCount = 0

for duplicate in duplicates {
    let (_, _, linkPks, movieTitle, sourceName) = duplicate
    
    // Get details for each link to determine which one to keep
    var linkDetails: [(pk: Int, rank: Int?, hasTitle: Bool, hasDescription: Bool)] = []
    
    for linkPk in linkPks {
        let getLinkSQL = """
            SELECT ZRANK, ZSOURCETITLE, ZSOURCEDESCRIPTION
            FROM ZSOURCECONTENT
            WHERE Z_PK = ?
        """
        
        var linkStmt: OpaquePointer?
        var rank: Int? = nil
        var hasTitle = false
        var hasDescription = false
        
        if sqlite3_prepare_v2(db, getLinkSQL, -1, &linkStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(linkStmt, 1, Int32(linkPk))
            
            if sqlite3_step(linkStmt) == SQLITE_ROW {
                if sqlite3_column_type(linkStmt, 0) != SQLITE_NULL {
                    rank = Int(sqlite3_column_int(linkStmt, 0))
                }
                hasTitle = sqlite3_column_text(linkStmt, 1) != nil
                hasDescription = sqlite3_column_text(linkStmt, 2) != nil
            }
        }
        
        sqlite3_finalize(linkStmt)
        
        linkDetails.append((pk: linkPk, rank: rank, hasTitle: hasTitle, hasDescription: hasDescription))
    }
    
    // Determine which link to keep:
    // Prefer links with rank, then with title, then with description, otherwise first one
    linkDetails.sort { link1, link2 in
        if let r1 = link1.rank, let r2 = link2.rank {
            return r1 < r2  // Keep lower rank (better)
        }
        if link1.rank != nil { return true }
        if link2.rank != nil { return false }
        if link1.hasTitle != link2.hasTitle {
            return link1.hasTitle  // Prefer one with title
        }
        if link1.hasDescription != link2.hasDescription {
            return link1.hasDescription  // Prefer one with description
        }
        return false  // Keep first one
    }
    
    let _ = linkDetails.first!.pk  // Keep the best one
    let removePks = Array(linkDetails.dropFirst().map { $0.pk })
    
    // Delete duplicate links
    for removePk in removePks {
        let deleteSQL = "DELETE FROM ZSOURCECONTENT WHERE Z_PK = ?"
        var deleteStmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, deleteSQL, -1, &deleteStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(deleteStmt, 1, Int32(removePk))
            if sqlite3_step(deleteStmt) == SQLITE_DONE {
                removedCount += 1
                print("   ✅ Removed duplicate link \(removePk) for \(movieTitle) on \(sourceName)")
            }
        }
        
        sqlite3_finalize(deleteStmt)
    }
}

// Also fix the weird "Die Hard" title
print("\n3️⃣ Fixing 'Die Hard' title issue...")
print(String(repeating: "-", count: 70))

let fixDieHardSQL = """
    UPDATE ZMOVIEDATA
    SET ZTITLE = 'Die Hard with a Vengeance'
    WHERE ZTMDBID = 652704 AND ZTITLE LIKE ''%Die Hard%'
"""

var fixStmt: OpaquePointer?
if sqlite3_prepare_v2(db, fixDieHardSQL, -1, &fixStmt, nil) == SQLITE_OK {
    if sqlite3_step(fixStmt) == SQLITE_DONE {
        let changes = sqlite3_changes(db)
        if changes > 0 {
            print("   ✅ Fixed 'Die Hard' title (changed \(changes) entry)")
        } else {
            print("   ℹ️  No 'Die Hard' title changes needed")
        }
    }
}
sqlite3_finalize(fixStmt)

// Commit changes
print("\n4️⃣ Committing changes...")
if sqlite3_exec(db, "COMMIT", nil, nil, nil) == SQLITE_OK {
    print("   ✅ Changes committed")
} else {
    print("   ⚠️  Warning: Could not commit (changes may have auto-committed)")
}

print("\n" + String(repeating: "=", count: 70))
print("✅ Fixed \(removedCount) duplicate source links")
print("✅ Database updated successfully!")
print("\n💡 Tip: You may need to regenerate the database or update the bundle")

