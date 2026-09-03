#!/usr/bin/env python3

"""
Diagnostic script to analyze bootstrap database for missing source associations.
Uses SQLite directly to avoid SwiftData schema issues.
"""

import json
import sqlite3
import subprocess
from collections import defaultdict
from pathlib import Path

def normalize_title(title):
    """Normalize title for comparison"""
    title = title.strip()
    # Remove quotes
    title = title.strip("'\"")
    # Remove list numbering
    import re
    title = re.sub(r'^\d+\.\s*', '', title)
    return title.lower().strip()

def main():
    print("🔍 Bootstrap Database Diagnostic (SQLite Direct)\n")
    print("=" * 70)
    
    # Paths
    json_path = Path("WatchedIt/bootstrap_data.json")
    db_path = Path("WatchedIt/bootstrap_database.store")
    
    if not json_path.exists():
        print(f"❌ Error: {json_path} not found")
        return 1
    
    if not db_path.exists():
        print(f"❌ Error: {db_path} not found")
        return 1
    
    # Load JSON
    print("\n📂 Loading bootstrap JSON...")
    with open(json_path, 'r') as f:
        bootstrap_data = json.load(f)
    
    print(f"✅ Loaded {len(bootstrap_data['dataSources'])} sources and {len(bootstrap_data['movies'])} movies from JSON")
    
    # Connect to database
    print("\n🗄️ Opening bootstrap database...")
    conn = sqlite3.connect(str(db_path))
    cursor = conn.cursor()
    
    # Get counts
    cursor.execute("SELECT COUNT(*) FROM ZMOVIEDATA")
    movie_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM ZSOURCECONTENT")
    source_content_count = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM ZDATASOURCE")
    source_count = cursor.fetchone()[0]
    
    print(f"✅ Database contains:")
    print(f"   Movies: {movie_count}")
    print(f"   Sources: {source_count}")
    print(f"   SourceContent links: {source_content_count}")
    
    # REPORT SECTION
    print("\n" + "=" * 70)
    print("📊 DIAGNOSTIC REPORT")
    print("=" * 70)
    
    # 1. Source Link Counts
    print("\n1️⃣ SOURCE LINK COUNTS (JSON Expected vs Database Actual):")
    print("-" * 70)
    
    # Count expected from JSON
    expected_by_source = defaultdict(int)
    for movie in bootstrap_data['movies']:
        expected_by_source[movie['sourceIdentifier']] += 1
    
    # Count actual from database
    cursor.execute("""
        SELECT s.ZIDENTIFIER, s.ZNAME, COUNT(*) as count 
        FROM ZSOURCECONTENT sc 
        JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK 
        GROUP BY s.ZIDENTIFIER 
        ORDER BY s.ZIDENTIFIER
    """)
    actual_by_source = {}
    for row in cursor.fetchall():
        source_id, source_name, count = row
        actual_by_source[source_id] = (count, source_name)
    
    total_missing = 0
    for source_id in sorted(set(expected_by_source.keys()) | set(actual_by_source.keys())):
        expected = expected_by_source.get(source_id, 0)
        if source_id in actual_by_source:
            actual, source_name = actual_by_source[source_id]
        else:
            actual, source_name = 0, source_id
        
        diff = expected - actual
        if diff != 0:
            print(f"  ⚠️  {source_name} ({source_id}):")
            print(f"      Expected: {expected} links")
            print(f"      Actual:   {actual} links")
            print(f"      Missing:  {diff} links")
            total_missing += diff if diff > 0 else 0
        else:
            print(f"  ✅ {source_name} ({source_id}): {expected} links")
    
    # 2. Movies Without Sources
    print("\n2️⃣ MOVIES WITHOUT ANY SOURCE LINKS:")
    print("-" * 70)
    cursor.execute("""
        SELECT COUNT(DISTINCT m.Z_PK) 
        FROM ZMOVIEDATA m 
        LEFT JOIN ZSOURCECONTENT sc ON sc.ZMOVIE = m.Z_PK 
        WHERE sc.Z_PK IS NULL
    """)
    movies_without_sources = cursor.fetchone()[0]
    print(f"   Total movies with 0 source links: {movies_without_sources}")
    
    if movies_without_sources > 0:
        cursor.execute("""
            SELECT m.ZTITLE, m.ZYEAR, m.Z_PK
            FROM ZMOVIEDATA m 
            LEFT JOIN ZSOURCECONTENT sc ON sc.ZMOVIE = m.Z_PK 
            WHERE sc.Z_PK IS NULL
            LIMIT 20
        """)
        print("\n   Sample of movies without sources (first 20):")
        for idx, (title, year, pk) in enumerate(cursor.fetchall(), 1):
            year_str = f" ({year})" if year else ""
            print(f"   {idx}. {title}{year_str} [PK: {pk}]")
    
    # 3. Breaking Away Analysis
    print("\n3️⃣ SEARCHING FOR 'BREAKING AWAY':")
    print("-" * 70)
    
    cursor.execute("""
        SELECT m.Z_PK, m.ZTITLE, m.ZYEAR, m.ZTMDBID
        FROM ZMOVIEDATA m
        WHERE m.ZTITLE LIKE '%Breaking Away%' OR m.ZTITLE LIKE '%breaking away%'
    """)
    breaking_away_movies = cursor.fetchall()
    
    if not breaking_away_movies:
        print("  ❌ 'Breaking Away' NOT FOUND in database")
        
        # Check JSON
        json_matches = [m for m in bootstrap_data['movies'] 
                       if 'breaking away' in normalize_title(m['title'])]
        if json_matches:
            print("  ⚠️  But it EXISTS in bootstrap_data.json:")
            for movie in json_matches:
                print(f"      Title: {movie['title']}")
                print(f"      Source: {movie['sourceIdentifier']}")
                print(f"      TMDB ID: {movie.get('tmdbId')}")
                print(f"      Year: {movie.get('year')}")
                print("  💡 This suggests the database generation failed to create this movie entry")
        else:
            print("  ⚠️  Also NOT FOUND in bootstrap_data.json")
            print("  💡 This movie needs to be added to the JSON source data")
    else:
        for pk, title, year, tmdb_id in breaking_away_movies:
            print(f"  ✅ Found: {title} [PK: {pk}, Year: {year}, TMDB: {tmdb_id}]")
            
            # Get source links
            cursor.execute("""
                SELECT s.ZIDENTIFIER, s.ZNAME
                FROM ZSOURCECONTENT sc
                JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
                WHERE sc.ZMOVIE = ?
            """, (pk,))
            sources = cursor.fetchall()
            
            if not sources:
                print("     ❌ Has NO source links attached")
            else:
                source_ids = [s[0] for s in sources]
                source_names = [s[1] for s in sources]
                print(f"     ✅ Has {len(sources)} source link(s): {', '.join(source_names)}")
                
                if 'rewatchables' in source_ids:
                    print("     ✅ Rewatchables link exists")
                else:
                    print("     ❌ Missing Rewatchables link (should have it)")
                    
                    # Check JSON
                    json_matches = [m for m in bootstrap_data['movies']
                                  if normalize_title(m['title']) == normalize_title(title) 
                                  and m['sourceIdentifier'] == 'rewatchables']
                    if json_matches:
                        print("     💡 JSON indicates this should have Rewatchables link")
            
            # Check if year is correct (should be 1979)
            if year and year != 1979:
                print(f"     ⚠️  Year mismatch: database has {year}, expected 1979")
    
    # 4. Rewatchables Specific Analysis
    print("\n4️⃣ REWATCHABLES SOURCE ANALYSIS:")
    print("-" * 70)
    
    rewatchables_expected = expected_by_source.get('rewatchables', 0)
    rewatchables_actual = actual_by_source.get('rewatchables', (0, ''))[0]
    
    print(f"   Expected from JSON: {rewatchables_expected} movies")
    print(f"   Actual in database: {rewatchables_actual} movies")
    print(f"   Difference: {rewatchables_actual - rewatchables_expected}")
    
    # Find Rewatchables movies in JSON
    rewatchables_json = [m for m in bootstrap_data['movies'] 
                        if m['sourceIdentifier'] == 'rewatchables']
    
    # Check which ones might be missing from database
    print(f"\n   Checking Rewatchables movies from JSON against database...")
    missing_from_db = []
    
    for json_movie in rewatchables_json[:50]:  # Sample first 50
        title = normalize_title(json_movie['title'])
        year = json_movie.get('year')
        tmdb_id = json_movie.get('tmdbId')
        
        found = False
        
        # Try by TMDB ID first
        if tmdb_id:
            cursor.execute("SELECT COUNT(*) FROM ZMOVIEDATA WHERE ZTMDBID = ?", (tmdb_id,))
            if cursor.fetchone()[0] > 0:
                found = True
        
        # Try by title + year
        if not found:
            if year:
                cursor.execute("""
                    SELECT COUNT(*) FROM ZMOVIEDATA 
                    WHERE LOWER(REPLACE(REPLACE(ZTITLE, '"', ''), ''', '')) LIKE ? 
                    AND ZYEAR = ?
                """, (f"%{title}%", year))
            else:
                cursor.execute("""
                    SELECT COUNT(*) FROM ZMOVIEDATA 
                    WHERE LOWER(REPLACE(REPLACE(ZTITLE, '"', ''), ''', '')) LIKE ?
                """, (f"%{title}%",))
            
            if cursor.fetchone()[0] > 0:
                found = True
        
        if not found:
            missing_from_db.append(json_movie)
    
    if missing_from_db:
        print(f"   ⚠️  Found {len(missing_from_db)} Rewatchables movies (sample) that might be missing:")
        for movie in missing_from_db[:10]:
            print(f"      - {movie['title']} ({movie.get('year', '?')})")
    else:
        print(f"   ✅ All sampled Rewatchables movies from JSON exist in database")
    
    # 5. Movies Missing Expected Source Links
    print("\n5️⃣ MOVIES MISSING EXPECTED SOURCE LINKS:")
    print("-" * 70)
    
    missing_links = []
    for json_movie in bootstrap_data['movies'][:200]:  # Sample first 200
        title = normalize_title(json_movie['title'])
        year = json_movie.get('year')
        tmdb_id = json_movie.get('tmdbId')
        expected_source = json_movie['sourceIdentifier']
        
        # Find movie in database
        movie_pk = None
        
        if tmdb_id:
            cursor.execute("SELECT Z_PK FROM ZMOVIEDATA WHERE ZTMDBID = ? LIMIT 1", (tmdb_id,))
            row = cursor.fetchone()
            if row:
                movie_pk = row[0]
        
        if not movie_pk and year:
            cursor.execute("""
                SELECT Z_PK FROM ZMOVIEDATA 
                WHERE LOWER(REPLACE(REPLACE(ZTITLE, '"', ''), ''', '')) LIKE ?
                AND ZYEAR = ?
                LIMIT 1
            """, (f"%{title}%", year))
            row = cursor.fetchone()
            if row:
                movie_pk = row[0]
        
        if movie_pk:
            # Check if link exists
            cursor.execute("""
                SELECT COUNT(*) FROM ZSOURCECONTENT sc
                JOIN ZDATASOURCE s ON sc.ZSOURCE = s.Z_PK
                WHERE sc.ZMOVIE = ? AND s.ZIDENTIFIER = ?
            """, (movie_pk, expected_source))
            
            if cursor.fetchone()[0] == 0:
                missing_links.append((json_movie['title'], expected_source))
    
    print(f"   Total missing links (sample of first 200): {len(missing_links)}")
    if missing_links:
        print("\n   Sample of missing links:")
        for title, source in missing_links[:20]:
            print(f"      - '{title}' missing link to: {source}")
    
    # Summary
    print("\n" + "=" * 70)
    print("📋 SUMMARY & RECOMMENDATIONS")
    print("=" * 70)
    
    issues = []
    if total_missing > 0:
        issues.append(f"Missing {total_missing} source links across all sources")
    if movies_without_sources > 0:
        issues.append(f"{movies_without_sources} movies have no source links")
    if missing_links:
        issues.append(f"Sample shows {len(missing_links)} movies missing expected links")
    
    if issues:
        print("\n⚠️  ISSUES FOUND:")
        for issue in issues:
            print(f"   - {issue}")
        print("\n💡 RECOMMENDED FIXES:")
        print("   1. Run 'swift fix_bootstrap_database_links.swift' to create missing links")
        print("   2. If that doesn't work, regenerate database: swift generate_bootstrap_database.swift")
        print("   3. If movies are missing from JSON, re-scrape the sources")
    else:
        print("\n✅ No major issues detected in sample!")
    
    print("\n" + "=" * 70)
    
    conn.close()
    return 0

if __name__ == "__main__":
    exit(main())

