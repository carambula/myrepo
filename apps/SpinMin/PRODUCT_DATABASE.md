# Product Lookup System

SpinMin includes a comprehensive product database with autocomplete and structured selection for tires, chains, wheelsets, and components.

## Overview

The product lookup system provides:
- **Autocomplete search** as you type
- **Structured product selection** with specifications
- **Pre-populated database** of popular products
- **Offline-first** operation (no API required)
- **Extensible** - users can add custom products
- **Smart filtering** by specs (wheel size, speed count, etc.)

## Features

### Search with Autocomplete

Real-time search across product database:
- Type 2+ characters to see results
- Searches brand, model, and specifications
- Relevance scoring for best matches
- Popular products highlighted with ⭐️

### Structured Selection

Products display complete specifications:
- **Tires**: Wheel size, width, compound type, weight, max PSI
- **Chains**: Speed count, compatibility, coating, weight
- **Wheelsets**: Rim depth/width, material, brake type, weight
- **Components**: Type-specific specs (cassette teeth, pad type, etc.)

### Smart Filters

Context-aware filtering:
- Tire search: Filter by wheel size (700c, 650b, 29", etc.)
- Chain search: Filter by speed count (11, 12) and compatibility
- Wheelset search: Filter by size and brake type (disc/rim)

### Manual Entry Fallback

If product not found in database:
- Quick manual entry form
- Auto-saves to database for future use
- Same structure as pre-populated products

## Product Database

### Pre-Populated Products

**Tires** (12+):
- Continental Grand Prix 5000 / 5000 S TR (25mm, 28mm, 32mm)
- Schwalbe Pro One (28mm)
- Schwalbe G-One Allround (38mm, 45mm)
- Vittoria Corsa N.EXT (26mm)
- Vittoria Terreno Dry (40mm)
- Pirelli P Zero Race TLR (28mm)
- Specialized Turbo Cotton (28mm)
- Maxxis Minion DHR II (29" × 2.4")
- Maxxis Rekon (29" × 2.3")

**Chains** (7+):
- Shimano CN-M9100 (12-speed)
- Shimano CN-HG701 (11-speed)
- SRAM XX1 Eagle (12-speed MTB)
- SRAM Red AXS (12-speed road)
- KMC X11SL (11-speed, universal)
- KMC X12 (12-speed, universal)
- Campagnolo Record (12-speed)

**Wheelsets** (3+):
- Zipp 303 Firecrest
- DT Swiss ERC 1400 Spline
- Mavic Cosmic SLR 45

**Components**:
- Shimano / SRAM cassettes
- Shimano brake pads (resin and metal)

Database grows as users add products manually.

## Usage

### In Component Tracking

When adding a chain to track:

1. Navigate to Bike → Maintenance → Add Component
2. Select "Chain" as component type
3. Tap "Search Product Database"
4. Type brand/model (e.g., "Shimano XTR")
5. Select from results
6. Brand and model auto-fill
7. Choose lube type and save

### In Tire Tracking

When adding tire tracking:

1. Navigate to Wheelset → Start Tracking
2. Tap "Search Products" (if integrated)
3. Filter by wheel size if desired
4. Search by brand/model
5. Select tire
6. Specs auto-fill (width, compound, casing)
7. Confirm and save

### Manual Entry

If product not in database:

1. In search view, tap "Manual Entry" or "Add Manually"
2. Enter brand and model (required)
3. Enter specifications (wheel size, width, etc.)
4. Save
5. Product added to database for future searches

## Data Models

### TireProduct

```swift
@Model final class TireProduct {
    var brand: String
    var model: String
    var year: Int?
    
    // Specs
    var wheelSizeRawValue: String  // "700c", "650b", "29", etc.
    var widthMM: Int
    var tireTypeRawValue: String  // "clincher", "tubeless", "tubular"
    var compoundTypeRawValue: String  // TireCompoundType
    var casingRawValue: String?  // TireCasingType
    
    var weight: Int?  // grams
    var treadPattern: String?
    var maxPSI: Int?
    var description: String
    var isPopular: Bool
}
```

### ChainProduct

```swift
@Model final class ChainProduct {
    var brand: String
    var model: String
    var year: Int?
    
    // Specs
    var speedCount: Int  // 11, 12, etc.
    var compatibleBrands: [String]  // ["Shimano", "SRAM"]
    var linksCount: Int?
    
    var weight: Int?  // grams
    var coating: String?  // "nickel", "chrome", "gold"
    var description: String
    var isPopular: Bool
}
```

### WheelsetProduct

```swift
@Model final class WheelsetProduct {
    var brand: String
    var model: String
    var year: Int?
    
    // Specs
    var wheelSizeRawValue: String
    var rimDepthMM: Int?
    var rimWidthMM: Int?  // Internal width
    var isDiscBrake: Bool
    var freehubTypeRawValue: String?  // "Shimano HG", "SRAM XDR"
    
    var weight: Int?  // grams (pair)
    var material: String?  // "carbon", "aluminum"
    var description: String
    var isPopular: Bool
}
```

### ComponentProduct

```swift
@Model final class ComponentProduct {
    var brand: String
    var model: String
    var year: Int?
    var componentTypeRawValue: String  // ComponentType
    
    // Generic specs (flexible key-value)
    var specifications: [String: String]
    
    var weight: Int?
    var description: String
    var isPopular: Bool
}
```

## Search Service

### ProductLookupService

```swift
// Tire search with filters
ProductLookupService.searchTires(
    query: "Continental GP5000",
    wheelSize: "700c",
    widthRange: 25...32,
    context: modelContext
) -> [TireProduct]

// Chain search with filters
ProductLookupService.searchChains(
    query: "Shimano",
    speedCount: 12,
    compatibleWith: "Shimano",
    context: modelContext
) -> [ChainProduct]

// Autocomplete (returns display names)
ProductLookupService.autocompleteTires(
    query: "Cont",
    context: modelContext
) -> [String]  // ["Continental GP5000 25mm", ...]
```

### Relevance Scoring

Search results ranked by:
1. **Exact match**: +100 points
2. **Starts with query**: +50 points
3. **Contains query**: +25 points
4. **Popular product**: +10 points

Results sorted by score, then alphabetically by brand.

### Popular Products

Products marked `isPopular: true` get:
- Boosted search ranking
- Highlighted with ⭐️ in UI
- Shown in "Popular" section when no search

## Adding Products to Database

### Programmatically

Add to `ProductDatabaseSeeder.swift`:

```swift
TireProduct(
    brand: "Vittoria",
    model: "Corsa N.EXT",
    wheelSize: "700c",
    widthMM: 26,
    tireType: "tubeless",
    compoundType: .racing,
    year: 2024,
    casing: .supple,
    weight: 260,
    maxPSI: 110,
    description: "Premium racing tire",
    isPopular: true
)
```

Rebuild app to seed new products.

### User-Generated

Users adding products manually automatically save to database:
- Accessible in future searches
- Same structure as pre-populated products
- Can be marked popular later

### Importing from CSV/JSON

Future enhancement: Bulk import capability

```swift
// Potential API
ProductImporter.importTires(
    from: URL(fileURLWithPath: "tires.csv"),
    context: modelContext
)
```

## UI Components

### TireSelectionView

Complete tire picker with:
- Search bar with real-time results
- Wheel size filter chips
- Product cards with full specs
- Popular tires section (when no search)
- Manual entry button

```swift
TireSelectionView(
    wheelSize: "700c",
    onSelect: { tire in
        // Use selected tire
    }
)
```

### ChainSelectionView

Chain picker integrated into component tracking:
- Simpler UI focused on brand/model/speed
- Speed count filtering
- Auto-fills brand and model in parent form

### FilterChip

Reusable filter button:
```swift
FilterChip(
    label: "700c",
    isSelected: selectedSize == "700c",
    onTap: { selectedSize = "700c" }
)
```

### TireProductCard

Product display card:
```swift
TireProductCard(tire: tire) {
    // Handle selection
}
```

Shows:
- Product image placeholder
- Brand and model
- Wheel size and width
- Year, weight (if available)
- Popular star indicator

## Technical Implementation

### Database Seeding

On first app launch:

```swift
.onAppear {
    ProductDatabaseSeeder.seedDatabaseIfNeeded(
        context: sharedModelContainer.mainContext
    )
}
```

Checks for existing products before seeding to avoid duplicates.

### SwiftData Integration

All product models in SwiftData schema:

```swift
let schema = Schema([
    // ... existing models
    TireProduct.self,
    ChainProduct.self,
    WheelsetProduct.self,
    ComponentProduct.self,
    BikeProduct.self,
])
```

Syncs via CloudKit automatically.

### Search Implementation

Uses SwiftData `FetchDescriptor`:

```swift
let descriptor = FetchDescriptor<TireProduct>()
let allTires = try context.fetch(descriptor)

// Filter and score
let results = allTires
    .filter { /* apply filters */ }
    .map { SearchResult(product: $0, relevanceScore: score) }
    .sorted { $0.relevanceScore > $1.relevanceScore }
```

## Future Enhancements

### External API Integration

Potential integrations:
- **HLC API**: Retail product catalog (requires API key)
- **Bike Matrix**: SKU/UPC lookup
- **Manufacturer APIs**: Direct product data

### Web Scraping

Scrape product specs from:
- Manufacturer websites
- Retailer catalogs
- Community databases (e.g., BikeRoar, Bicycle Rolling Resistance)

Implementation approach:
```swift
struct ProductScraper {
    static func scrapeProduct(url: URL) async throws -> TireProduct {
        // Fetch HTML
        // Parse specs using SwiftSoup or similar
        // Return structured product
    }
}
```

### Barcode Scanning

Scan product UPC/EAN:
```swift
struct BarcodeScannerView: View {
    @Binding var scannedCode: String?
    
    // Use AVFoundation to scan barcode
    // Lookup in Bike Matrix or similar
    // Auto-populate product details
}
```

### AI-Powered Entry

Use LLMs to extract specs from freeform text:

**User input**: "I have Continental GP5000 in 28mm tubeless"

**AI extraction**:
```json
{
  "brand": "Continental",
  "model": "Grand Prix 5000",
  "wheelSize": "700c",
  "widthMM": 28,
  "tireType": "tubeless"
}
```

### Community Database

Shared product database across users:
- Crowdsourced product additions
- Verified specifications
- User reviews and ratings

### Product Images

Fetch product images:
- From manufacturer URLs
- From community uploads
- Placeholder → real image upgrade

## Best Practices

### For Users

1. **Search first**: Check database before manual entry
2. **Be specific**: Include model year if known
3. **Complete specs**: Fill all fields when adding manually
4. **Mark popular**: Flag products you use frequently

### For Developers

1. **Keep seeder updated**: Add new popular products regularly
2. **Validate specs**: Ensure accurate specifications
3. **Handle variants**: Different years/specs = separate products
4. **Optimize search**: Limit results (currently 50 max)
5. **Cache results**: Consider caching for better performance

## Troubleshooting

### Products Not Showing

**Check**:
1. Database seeded? (runs on first launch)
2. Search query > 2 characters?
3. Filters too restrictive?
4. Product actually in database?

**Solution**: Try "All Sizes" filter, broader search terms, or add manually.

### Duplicate Products

**Cause**: Manual additions of existing products

**Prevention**: Always search first before adding manually

**Solution**: Delete duplicates from database (future: merge tool)

### Slow Search

**Causes**:
- Large database (> 1000 products)
- Complex search query
- Multiple filters

**Solutions**:
- Index brand/model fields
- Limit result count
- Debounce search input (wait 300ms after typing)

## Data Sources

Product specifications from:
- Manufacturer websites (Continental, Schwalbe, etc.)
- Bicycle Rolling Resistance testing data
- Retailer catalogs (REI, Competitive Cyclist)
- Community databases (Weight Weenies, forums)

All product data is informational. Always verify specifications with manufacturer before purchase.
