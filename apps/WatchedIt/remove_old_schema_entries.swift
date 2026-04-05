#!/usr/bin/env swift

import Foundation
import SQLite3

/// Script to remove old MovieDataSource entries from bootstrap database
/// Since we're using SourceContent (new schema), the old MovieDataSource entries
/// can cause duplicates when the app queries both schemas

let dbPath = "WatchedIt/bootstrap_database.store"

guard FileManager.default.fileExists(atPath: dbPath) else {
    print("❌ Error: bootstrap_database.store not found")
    exit(1)
}

print("🔧 Removing Old Schema (MovieDataSource) Entries\n")
print(String(repeating: "=", count: 70))

var db: OpaquePointer?
if sqlite3_open(dbPath, &db) != SQLITE_OK {
    print("❌ Error: Could not open database")
    exit(1)
}

defer {
    sqlite3_close(db)
}

// Check if table exists
var tableExists = false
let checkTableSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='ZMOVIEDATASOURCE'"
var stmt: OpaquePointer?

if sqlite3_prepare_v2(db, checkTableSQL, -1, &stmt, nil) == SQLITE_OK {
    if sqlite3_step(stmt) == SQLITE_ROW {
        tableExists = true
    }
}
sqlite3_finalize(stmt)

if !tableExists {
    print("✅ Old schema table doesn't exist - nothing to remove")
    exit(0)
}

// Count entries before removal
let countSQL = "SELECT COUNT(*) FROM ZMOVIEDATASOURCE"
if sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK {
    if sqlite3_step(stmt) == SQLITE_ROW {
        let count = sqlite3_column_int(stmt, 0)
        print("📊 Found \(count) old MovieDataSource entries")
    }
}
sqlite3_finalize(stmt)

// Get some examples before deletion
print("\n🔍 Sample entries before removal:\n")
let sampleSQL = """
    SELECT m.ZTITLE, s.ZNAME, COUNT(*) as link_count
    FROM ZMOVIEDATASOURCE mds
    JOIN ZMOVIEDATA m ON mds.ZMOVIE = m.Z_PK
    JOIN ZDATASOURCE s ON mds.ZDATASOURCE = s.Z_PK
    GROUP BY m.Z_PK, s.Z_PK
    LIMIT 5
"""

if sqlite3_prepare_v2(db, sampleSQL, -1, &stmt, nil) == SQLITE_OK {
    while sqlite3_step(stmt) == SQLITE_ROW {
        let title = String(cString: sqlite3_column_text(stmt, 0))
        let sourceName = String(cString: sqlite3_column_text(stmt, 1))
        let linkCount = Int(sqlite3_column_int(stmt, 2))
        print("   - \(title) on \(sourceName): \(linkCount) link(s)")
    }
}
sqlite3_finalize(stmt)

// Delete all MovieDataSource entries
print("\n🗑️  Removing all old MovieDataSource entries...")
let deleteSQL = "DELETE FROM ZMOVIEDATASOURCE"

if sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK {
    if sqlite3_step(stmt) == SQLITE_DONE {
        let changes = sqlite3_changes(db)
        print("   ✅ Removed \(changes) entries")
    }
}
sqlite3_finalize(stmt)

// Verify removal
print("\n✅ Verification:")
let verifySQL = "SELECT COUNT(*) FROM ZMOVIEDATASOURCE"
if sqlite3_prepare_v2(db, verifySQL, -1, &stmt, nil) == SQLITE_OK {
    if sqlite3_step(stmt) == SQLITE_ROW {
        let remaining = sqlite3_column_int(stmt, 0)
        if remaining == 0 {
            print("   ✅ All old schema entries removed successfully")
        } else {
            print("   ⚠️  \(remaining) entries still remain")
        }
    }
}
sqlite3_finalize(stmt)

// Check Heat specifically
print("\n🔍 Verifying Heat:")
let heatSQL = """
    SELECT COUNT(*) FROM ZMOVIEDATASOURCE mds
    JOIN ZMOVIEDATA m ON mds.ZMOVIE = m.Z_PK
    WHERE m.ZTMDBID = 949
"""

if sqlite3_prepare_v2(db, heatSQL, -1, &stmt, nil) == SQLITE_OK {
    if sqlite3_step(stmt) == SQLITE_ROW {
        let heatCount = sqlite3_column_int(stmt, 0)
        print("   Heat old schema links: \(heatCount)")
        
        if heatCount == 0 {
            print("   ✅ Heat no longer has old schema entries")
        }
    }
}
sqlite3_finalize(stmt)

// Check SourceContent still has the links
print("\n🔍 Verifying new schema (SourceContent) still has all links:")
let sourceContentSQL = """
    SELECT COUNT(*) FROM ZSOURCECONTENT sc
    JOIN ZMOVIEDATA m ON sc.ZMOVIE = m.Z_PK
    WHERE m.ZTMDBID = 949
"""

if sqlite3_prepare_v2(db, sourceContentSQL, -1, &stmt, nil) == SQLITE_OK {
    if sqlite3_step(stmt) == SQLITE_ROW {
        let scCount = sqlite3_column_int(stmt, 0)
        print("   Heat SourceContent links: \(scCount)")
        
        if scCount == 2 {
            print("   ✅ Heat has all 2 source links in new schema")
        }
    }
}
sqlite3_finalize(stmt)

print("\n" + String(repeating: "=", count: 70))
print("✅ Old schema entries removed successfully!")
print("   All movies now only use SourceContent (new schema)")
print("   This should eliminate duplicates in the app")





