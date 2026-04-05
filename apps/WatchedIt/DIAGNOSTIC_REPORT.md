# Bootstrap Database Diagnostic Report

**Generated:** $(date)

## Executive Summary

The bootstrap database has **452 missing source links** across multiple sources. "Breaking Away" exists in the database and has a Rewatchables link, but the **year is incorrect** (2025 instead of 1979), which may cause display/filtering issues.

## Key Findings

### ✅ Good News
- All movies have at least one source link (0 movies without any sources)
- "Breaking Away" EXISTS in database and HAS Rewatchables link
- Database contains 2,467 movies with 2,641 source links

### ⚠️ Issues Found

#### 1. Missing Source Links (452 total)

| Source | Expected | Actual | Missing |
|--------|----------|--------|---------|
| **RT Christmas** | 100 | **0** | **100** ⚠️ |
| IMDB Auteurs | 430 | 197 | 233 |
| Criterion | 51 | 11 | 40 |
| RT Best All Time | 300 | 279 | 21 |
| RT Kids | 50 | 24 | 26 |
| RT Oscars | 98 | 66 | 32 |

**Note:** RT Christmas source is completely missing from the database!

#### 2. Extra Source Links (database has more than JSON)

| Source | Expected | Actual | Extra |
|--------|----------|--------|-------|
| Big Picture | 102 | 826 | +724 |
| Blank Check | 330 | 363 | +33 |
| Confused Breakfast | 233 | 365 | +132 |
| Filmspotting | 15 | 60 | +45 |
| Rewatchables | 314 | 330 | +16 |

**This suggests the database was generated from a different version of JSON than currently exists.**

#### 3. "Breaking Away" Year Issue

- **Database:** "Breaking Away" (2025, TMDB: 1556468) ✅ Has Rewatchables link
- **Expected:** "Breaking Away" (1979)
- **Issue:** Wrong year - likely a different movie or incorrect data

The movie exists with source links, but the year mismatch may cause:
- Filtering issues in the app
- Display of wrong movie
- User confusion

## Root Causes

1. **Database out of sync with JSON** - Database was generated from older/different JSON file
2. **Missing source** - RT Christmas source not created in database
3. **Data quality** - Wrong year for "Breaking Away"

## Recommended Fix Plan

### Phase 1: Fix Missing Links (Can fix with existing data)

1. **Run the fix script:**
   ```bash
   swift fix_bootstrap_database_links.swift
   ```
   This will create missing SourceContent links based on JSON data.

2. **If that doesn't work, regenerate database:**
   ```bash
   swift generate_bootstrap_database.swift
   ```
   This will create a fresh database from current JSON.

### Phase 2: Fix "Breaking Away" Year Issue

**Option A: If it's in JSON with wrong year**
- Fix the year in `bootstrap_data.json` (change 2025 to 1979)
- Regenerate database

**Option B: If 1979 version is missing entirely**
- Add "Breaking Away" (1979) to `bootstrap_data.json` with correct TMDB ID
- Enrich with TMDB data
- Regenerate database

### Phase 3: Investigate RT Christmas Missing Source

1. Check if RT Christmas source exists in JSON `dataSources` array
2. If missing, add it to JSON
3. Regenerate database

### Phase 4: Handle Extra Links

The extra links suggest database has data from a previous version. Options:
- Keep them (they're additional data, not harmful)
- Or regenerate from clean JSON to remove them

## Next Steps

1. ✅ **Diagnostic complete** - We know what's wrong
2. 🔄 **Run fix script** - `swift fix_bootstrap_database_links.swift`
3. 🔄 **Regenerate database** - `swift generate_bootstrap_database.swift`
4. 🔄 **Fix Breaking Away year** - Update JSON and regenerate
5. 🔄 **Add missing RT Christmas source** - Update JSON and regenerate
6. ✅ **Test** - Verify all links are present

## Files Created

- `diagnose_database_sqlite.py` - Python diagnostic script (SQLite direct)
- `diagnose_bootstrap_database.swift` - Swift diagnostic script (SwiftData - had schema issues)
- This report

## Commands to Run

```bash
# 1. Fix missing links
swift fix_bootstrap_database_links.swift

# 2. Or regenerate entire database
swift generate_bootstrap_database.swift

# 3. Re-run diagnostic to verify
python3 diagnose_database_sqlite.py
```

