# Product Lookup Testing Checklist

## Manual Testing Steps

### 1. First Launch - Database Seeding
- [ ] Launch app on fresh install
- [ ] Check that product database seeds automatically
- [ ] Verify no duplicate seeding on subsequent launches

**Expected Results**:
- Database seeds on first launch only
- 12+ tires available
- 7+ chains available
- 3+ wheelsets available

### 2. Chain Search - Basic

**Test in**: Bike Maintenance → Add Component → Select "Chain" → "Search Product Database"

- [ ] Opens `ChainSelectionView`
- [ ] Shows all chains when no search text
- [ ] Popular chains displayed with ⭐️

**Expected Results**:
- Shimano CN-M9100 ⭐️ (12-speed)
- Shimano CN-HG701 ⭐️ (11-speed)
- SRAM XX1 Eagle ⭐️ (12-speed MTB)
- SRAM Red AXS ⭐️ (12-speed road)
- KMC X11SL ⭐️ (11-speed)
- KMC X12 (12-speed)
- Campagnolo Record ⭐️ (12-speed)

### 3. Chain Search - Autocomplete

Type in search field:

- [ ] Type "Shi" → Should show Shimano chains
- [ ] Type "SRAM" → Should show 2 SRAM chains
- [ ] Type "KMC" → Should show 2 KMC chains
- [ ] Type "12" → Should show all 12-speed chains
- [ ] Type "xyz" → Should show empty results with "Manual Entry" option

**Expected Behavior**:
- Results update in real-time as you type
- Minimum 2 characters required
- Case-insensitive search
- Matches brand, model, and speed count

### 4. Chain Selection

- [ ] Tap a chain from results
- [ ] Should dismiss search view
- [ ] Brand and model fields auto-fill in parent form
- [ ] Can complete rest of form (install date, lube type) and save

**Expected**: 
- Brand: "Shimano"
- Model: "CN-M9100" (or selected chain)
- Other fields remain editable

### 5. Tire Search (Future Integration)

**When integrated into Add Tire Tracking**:

- [ ] Opens `TireSelectionView`
- [ ] Search bar at top
- [ ] Filter chips for wheel size (All, 700c, 650b, 29", 27.5", 26")
- [ ] Popular tires section when no search

**Expected Popular Tires**:
- Continental Grand Prix 5000 ⭐️ (25mm, 28mm, 32mm)
- Schwalbe Pro One ⭐️ (28mm)
- Schwalbe G-One Allround ⭐️ (38mm, 45mm)
- Vittoria Corsa N.EXT ⭐️ (26mm)
- Pirelli P Zero Race TLR ⭐️ (28mm)
- Maxxis Minion DHR II (29" × 2.4")

### 6. Tire Search - Filtering

- [ ] Select "700c" filter → Only 700c tires show
- [ ] Type "Continental" → Shows Continental tires
- [ ] Type "Schwalbe" → Shows 2+ Schwalbe tires
- [ ] Type "45" → Shows wide tires
- [ ] Clear search → Returns to filtered results or popular

**Expected**:
- Filters persist during search
- Multiple filters combine (AND logic)
- Clear button (X) appears when typing

### 7. Tire Product Card Display

Each tire card should show:
- [ ] Product image placeholder (dotted circle)
- [ ] Brand name (bold)
- [ ] Model name
- [ ] Wheel size × width (e.g., "700c × 28mm")
- [ ] Year (if available)
- [ ] Weight (if available, e.g., "265g")
- [ ] ⭐️ star for popular products
- [ ] Chevron (→) on right

### 8. Manual Entry Fallback

When no results found:

- [ ] Tap "Add Manually" or "Manual Entry"
- [ ] Opens manual entry form
- [ ] Fill in brand, model, specs
- [ ] Save
- [ ] Product added to database
- [ ] Future searches should find it

**Expected**:
- Form validates required fields
- Product persists in database
- Available in future searches
- Syncs via CloudKit

### 9. Search Relevance

Test search ranking:

- [ ] Type "Pro" → "Pro One" should rank high
- [ ] Type "5000" → "Grand Prix 5000" should be top result
- [ ] Popular products should rank higher than non-popular with same match

**Expected Order**:
1. Exact matches first
2. Starts-with matches
3. Contains matches
4. Popular boost applied

### 10. Performance

- [ ] Search with 2 characters is instant
- [ ] No lag typing in search field
- [ ] Scrolling results is smooth
- [ ] Database queries complete <100ms

### 11. Edge Cases

- [ ] Empty database → Shows "No products" message
- [ ] Search with special characters (e.g., "GP5000-TL")
- [ ] Very long search query
- [ ] Rapid typing and clearing
- [ ] Switch between filters quickly

## Automated Tests

Run test suite:

```bash
xcodebuild test -scheme SpinMin -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Test Coverage** (`ProductLookupTests.swift`):
- ✅ Empty query returns all results
- ✅ Brand search filtering
- ✅ Partial match (autocomplete)
- ✅ Model search
- ✅ Wheel size filtering
- ✅ Width range filtering
- ✅ Combined filters
- ✅ No results handling
- ✅ Popular products prioritization
- ✅ Speed count filtering (chains)
- ✅ Compatibility filtering (chains)
- ✅ Autocomplete minimum length (2 chars)
- ✅ Autocomplete result limiting (10 max)
- ✅ Display name formatting
- ✅ Brand/model extraction
- ✅ Database seeder deduplication

## Known Limitations

1. **No API Integration**: Uses local database only
2. **No Product Images**: Placeholder icons only
3. **Limited Initial Catalog**: ~20 products (user-extensible)
4. **No Barcode Scanning**: Manual entry only
5. **No Web Scraping**: Specs entered manually

## Future Testing Needs

When implementing:
- [ ] API integration tests (HLC, Bike Matrix)
- [ ] Image loading tests
- [ ] Barcode scanner tests
- [ ] Network failure handling
- [ ] Large database performance (1000+ products)
- [ ] CloudKit sync verification
- [ ] Concurrent access tests

## Debug Checklist

If search not working:

1. **Check database seeded**:
   - Set breakpoint in `ProductDatabaseSeeder.seedDatabaseIfNeeded`
   - Verify `try? context.fetchCount(descriptor)` returns > 0 on second launch

2. **Check search logic**:
   - Set breakpoint in `ProductLookupService.searchTires/searchChains`
   - Verify `allTires` fetched successfully
   - Check `queryLower` matches expected search
   - Inspect `results` array after filtering

3. **Check UI binding**:
   - Verify `@State private var searchResults` updates in view
   - Check `onChange(of: searchText)` triggers
   - Verify `ForEach(searchResults)` renders

4. **Check model context**:
   - Verify `@Environment(\.modelContext)` injected
   - Check SwiftData schema includes product models
   - Verify CloudKit container configured

## Test Data

### Sample Searches

**Tire Searches**:
- "Continental" → 3 results (GP5000 25/28/32mm)
- "Schwalbe" → 2-3 results (Pro One, G-One)
- "700c" → Most road/gravel tires
- "45" → Gravel tires (45mm width)
- "tubeless" → Most modern tires

**Chain Searches**:
- "Shimano" → 2 results (M9100, HG701)
- "SRAM" → 2 results (XX1 Eagle, Red AXS)
- "12" → All 12-speed chains
- "KMC" → 2 results (X11SL, X12)

### Expected Counts

After seeding:
- **Tires**: 12+ (8 road, 2 gravel, 2 MTB)
- **Chains**: 7+ (Shimano, SRAM, KMC, Campagnolo)
- **Wheelsets**: 3+ (Zipp, DT Swiss, Mavic)
- **Components**: 4+ (cassettes, brake pads)

## Success Criteria

✅ **Core Functionality**:
- Database seeds on first launch
- Search returns relevant results
- Filters work correctly
- Selection auto-fills parent form
- Manual entry persists to database

✅ **User Experience**:
- Search is fast (<100ms)
- Results ranked by relevance
- Popular products prioritized
- Clear empty states
- Smooth scrolling

✅ **Edge Cases**:
- Handles empty database
- Handles no results
- Handles rapid input
- Handles special characters
- Prevents duplicate seeding
