# Vendor Ordering System

SpinMin includes integrated ordering for replacement components from trusted cycling retailers.

## Overview

The vendor ordering system provides:
- **One-tap ordering** from maintenance and tire tracking views
- **Smart vendor recommendations** based on component type
- **Multiple retailer options** (7 supported vendors)
- **Deep linking** directly to product searches
- **User preferences** for favorite vendors
- **Context-aware ordering** (shows when replacement is needed)

## Supported Vendors

### Competitive Cyclist
- **Specialties**: Tires, chains, cassettes, wheels, tools
- **URL**: https://www.competitivecyclist.com
- **Description**: Premium cycling gear with expert staff and fast shipping
- **Best for**: Road and gravel components, high-end parts

### Jenson USA
- **Specialties**: Tires, chains, cassettes, wheels, tools
- **URL**: https://www.jensonusa.com
- **Description**: Wide selection at competitive prices
- **Best for**: Mountain bike components, value pricing

### Silca
- **Specialties**: Tools, lubricants, pumps
- **URL**: https://silca.cc
- **Description**: Premium pumps, tools, and chain wax directly from manufacturer
- **Best for**: Chain wax (Super Secret), floor pumps, precision tools
- **Direct products**: Super Secret Chain Lube, Superpista floor pumps

### REI
- **Specialties**: Tires, chains, complete bikes, tools
- **URL**: https://www.rei.com
- **Description**: Co-op with bike components, gear, and expert advice
- **Best for**: Casual riders, REI members (dividends)

### Backcountry
- **Specialties**: Tires, chains, complete bikes
- **URL**: https://www.backcountry.com
- **Description**: Outdoor and cycling gear with great customer service
- **Best for**: All-around cycling and outdoor needs

### Chain Reaction Cycles
- **Specialties**: Tires, chains, cassettes, wheels
- **URL**: https://www.chainreactioncycles.com
- **Description**: Global cycling retailer with competitive international shipping
- **Best for**: International orders, bulk purchases

### Modern Bike
- **Specialties**: Tires, chains, cassettes, wheels, tools
- **URL**: https://www.modernbike.com
- **Description**: Comprehensive bike parts with technical expertise
- **Best for**: Hard-to-find parts, technical components

## Features

### Context-Aware Order Buttons

Order buttons appear automatically when components need replacement:

**Chain Maintenance** (BikeMaintenanceView):
- "Order Replacement" button when chain status is "Replace Soon" or "Replace Now"
- "Order Chain Wax" button when wax is due (hot wax, drip wax, etc.)

**Tire Tracking** (TireManagementView):
- "Order Replacement" button when tire status is "Replace Soon", "Replace Now", or "Unsafe"
- Appears on tire detail cards in current tires view

**Component Tracking** (ComponentCard):
- "Order" button (compact) when any component needs replacement
- Shows for cassettes, brake pads, cables, etc.

### Smart Vendor Recommendations

System recommends vendors based on component type:

| Component | Recommended Vendors |
|-----------|-------------------|
| Chain Wax/Lube | Silca, Competitive Cyclist, Jenson USA |
| Tools | Silca, Jenson USA, Competitive Cyclist |
| Pumps | Silca, Competitive Cyclist |
| Tires | Competitive Cyclist, Jenson USA, Chain Reaction |
| Chains | Competitive Cyclist, Jenson USA, Modern Bike |
| Other Components | Competitive Cyclist, Jenson USA, Backcountry |

### Search Query Generation

Service automatically builds optimized search queries:

**Tires**:
```swift
// Example: Continental Grand Prix 5000 28mm
"Continental Grand Prix 5000 28mm"

// If no model: generic + width
"road tire 28mm"
```

**Chains**:
```swift
// Example: Shimano CN-M9100
"Shimano CN-M9100 chain"
```

**Chain Wax**:
```swift
// Hot wax
"Silca Super Secret chain wax"

// Drip wax
"chain drip wax"
```

### Vendor Preferences

Users can customize vendor order in **Settings → Preferred Vendors**:

1. Select/deselect vendors
2. Vendors appear in selection order
3. Unselected vendors hidden from order sheets
4. Default: Competitive Cyclist, Jenson USA, Silca

## Usage

### For Users

**Order a Replacement Chain**:
1. Navigate to Bike → Maintenance
2. See chain status: "Replace Soon" 🔴
3. Tap "Order Replacement" button
4. Select vendor (Competitive Cyclist, Jenson USA, etc.)
5. Opens Safari with product search
6. Complete purchase on vendor site

**Order Chain Wax**:
1. In Bike Maintenance view
2. See "Wax Due" warning
3. Tap "Order [Lube Type]" button
4. Select Silca (direct link) or other vendor
5. Purchase wax

**Order Replacement Tire**:
1. Navigate to Wheelset → Tire Management
2. See tire status: "Replace Now" ⛔️
3. Tap "Order Replacement" button
4. Select vendor
5. Opens search for tire brand/model/width

**Set Vendor Preferences**:
1. Open Settings → Preferred Vendors
2. Tap vendors to select/deselect
3. Order reflects your preferences
4. Selected vendors appear first

### For Developers

**Generate Order Links**:
```swift
// For a tire
let tire: TireTracking = ...
let links = VendorService.orderLinks(for: tire)
// Returns [OrderLink] for Competitive Cyclist, Jenson, etc.

// For a chain
let chain: ComponentTracking = ...
let links = VendorService.orderLinks(for: chain)

// For chain wax
let links = VendorService.orderLinksForChainWax(
    lubeType: .hotWax
)

// Generic product search
let links = VendorService.orderLinks(
    brand: "Continental",
    model: "GP5000",
    category: .tires
)
```

**Filter by Preferences**:
```swift
let preference: VendorPreference? = ...
let filtered = VendorService.filterByPreferences(
    vendors: allVendors,
    preference: preference
)
// Returns vendors in user's preferred order
```

**Add Order Button to UI**:
```swift
// For components
OrderReplacementButton(
    component: chain,
    style: .prominent  // or .compact, .icon
)

// For tires
OrderTireButton(
    tire: frontTire,
    style: .prominent
)

// For chain wax
OrderChainWaxButton(lubeType: .hotWax)
```

## Data Models

### Vendor Enum
```swift
enum Vendor: String, CaseIterable {
    case competitiveCyclist
    case jensonUSA
    case silca
    case rei
    case backcountry
    case chainReactionCycles
    case modernBike
    
    var displayName: String
    var baseURL: String
    var searchPath: String
    var searchQueryParam: String
    var iconName: String  // SF Symbol
    var specialties: [ComponentCategory]
    var description: String
}
```

### VendorPreference Model
```swift
@Model
final class VendorPreference {
    var preferredVendors: [String]  // Vendor rawValues
    var lastUpdated: Date
    
    var vendors: [Vendor]  // Computed property
    func primaryVendor() -> Vendor
}
```

### OrderLink
```swift
struct OrderLink: Identifiable {
    let vendor: Vendor
    let url: URL
    let displayText: String
    let category: ComponentCategory
}
```

## UI Components

### OrderReplacementSheet
Full-screen vendor selection modal:
- Title and subtitle (component name)
- List of vendor cards with icons
- Opens Safari when vendor tapped
- Auto-dismisses after selection

### VendorLinkCard
Individual vendor option in selection sheet:
- Vendor icon (SF Symbol)
- Name and description
- "Search on [Vendor]" label
- External link icon

### OrderReplacementButton
Flexible order button for components:
- **Compact**: Small "Order" button with cart icon
- **Prominent**: Full-width with "Order Replacement" label
- **Icon**: Cart icon only

### OrderTireButton
Tire-specific order button:
- Same styles as OrderReplacementButton
- Generates tire-specific search queries
- Recommends tire-focused vendors

### OrderChainWaxButton
Chain wax order button:
- Full-width prominent style
- "Order [Lube Type]" label
- Direct Silca links for hot wax

### VendorPreferencesView
Settings screen for managing vendors:
- List of all vendors with descriptions
- Checkmark selection
- Specialty tags
- Saves on dismiss

## Technical Implementation

### VendorService

**URL Generation**:
```swift
private static func buildSearchURL(
    vendor: Vendor,
    query: String
) -> URL? {
    var components = URLComponents(
        string: vendor.baseURL + vendor.searchPath
    )
    components?.queryItems = [
        URLQueryItem(
            name: vendor.searchQueryParam,
            value: query
        )
    ]
    return components?.url
}
```

**Direct Product Links**:
```swift
static func silcaChainWaxLink() -> OrderLink {
    OrderLink(
        vendor: .silca,
        url: URL(string: "https://silca.cc/collections/chain-lube-wax/products/super-secret-chain-lube")!,
        displayText: "Silca Super Secret Wax",
        category: .lubricants
    )
}
```

### Deep Linking

All vendor links use `openURL` environment action:
```swift
@Environment(\.openURL) private var openURL

Button("Order") {
    openURL(orderLink.url)
}
```

Opens in:
- **Safari** (default)
- **In-app browser** (if implemented)
- **Vendor app** (if installed and supports universal links)

## Integration Points

### BikeMaintenanceView
```swift
// In ChainComponentCard
if chainStatus.health == .replaceSoon || 
   chainStatus.health == .replaceNow {
    OrderReplacementButton(
        component: chain,
        style: .prominent
    )
}

if chainStatus.waxDue, let lube = chain.lubeType {
    OrderChainWaxButton(lubeType: lube)
}
```

### TireManagementView
```swift
// In TireDetailCard
if health.status == .replaceSoon || 
   health.status == .replaceNow || 
   health.status == .unsafe {
    OrderTireButton(
        tire: tire,
        style: .prominent
    )
}
```

### SettingsView
```swift
Section {
    NavigationLink {
        VendorPreferencesView()
    } label: {
        HStack {
            Image(systemName: "cart")
            Text("Preferred Vendors")
            Spacer()
            Text("\(count) selected")
        }
    }
} header: {
    Text("Ordering")
}
```

## Best Practices

### For Users

1. **Set Preferences**: Configure favorite vendors in Settings
2. **Check Multiple Vendors**: Prices and availability vary
3. **Verify Specs**: Confirm component compatibility before purchasing
4. **Use Search as Starting Point**: Refine search on vendor site
5. **Check Return Policies**: Different vendors have different policies

### For Developers

1. **Recommend Appropriate Vendors**: Use `recommendedVendors(for:)` helper
2. **Filter by Preferences**: Always apply user preferences when available
3. **Build Specific Queries**: Include brand, model, and key specs
4. **Handle Missing Data**: Fallback to generic searches when brand/model unknown
5. **Test Deep Links**: Verify URLs open correctly in Safari

## Future Enhancements

### Affiliate Links
Add affiliate tracking for monetization:
```swift
var affiliateParam: String {
    switch self {
    case .competitiveCyclist:
        return "?utm_source=spinmin&utm_medium=app"
    // ...
    }
}
```

### Price Comparison
Fetch real-time prices from multiple vendors:
```swift
struct PriceInfo {
    let vendor: Vendor
    let price: Double
    let inStock: Bool
    let url: URL
}
```

### In-App Purchase Flow
Embed vendor sites in WKWebView:
```swift
struct VendorWebView: View {
    let url: URL
    // WKWebView implementation
}
```

### Product Availability API
Check stock before showing vendor:
```swift
static func checkAvailability(
    product: String,
    vendor: Vendor
) async -> Bool {
    // API call to vendor
}
```

### Order History
Track purchases made through app:
```swift
@Model
final class OrderHistory {
    var vendor: String
    var component: String
    var date: Date
    var price: Double?
}
```

## Troubleshooting

### Links Not Opening

**Issue**: Tapping vendor doesn't open Safari

**Solutions**:
1. Check URL is valid: `print(orderLink.url)`
2. Verify `openURL` environment action available
3. Test in simulator vs. device
4. Check app has network permissions

### Wrong Search Results

**Issue**: Vendor search returns irrelevant products

**Solutions**:
1. Verify search query generation: `print(query)`
2. Add more specific terms (year, speed count)
3. Use direct product links for known items
4. Update `buildSearchQuery` logic for better terms

### Preferences Not Saving

**Issue**: Vendor selections reset on app restart

**Solutions**:
1. Check `VendorPreference` in SwiftData schema
2. Verify `try? modelContext.save()` called
3. Check CloudKit sync status
4. Test with `.onDisappear` vs. explicit save button

### Vendor Not Listed

**Issue**: Need to add new vendor

**Solution**:
1. Add case to `Vendor` enum
2. Implement all required properties
3. Add to `recommendedVendors` where appropriate
4. Test search URL generation

## Performance Considerations

- **URL Generation**: O(1) - simple string concatenation
- **Vendor Filtering**: O(n) - linear scan of preferences
- **Link Generation**: O(n×m) - vendors × categories
- **UI Rendering**: Lazy loading with `LazyVStack`

No API calls or network requests during link generation - all offline.

## Privacy & Security

- **No Tracking**: App doesn't track purchases or browsing
- **No Personal Data**: Only vendor preferences stored locally
- **HTTPS Only**: All vendor URLs use secure connections
- **No Cookies**: No cross-site tracking or cookies shared
- **User Control**: Full control over vendor selection

## Testing

### Manual Testing

1. **Order Chain**:
   - Mark chain at 0.5% wear
   - Verify "Order Replacement" button appears
   - Tap button → Opens vendor sheet
   - Select Competitive Cyclist
   - Verify Safari opens with chain search

2. **Order Chain Wax**:
   - Log 500km since last wax (hot wax)
   - Verify "Order Chain Wax" button appears
   - Tap button → Opens Silca product page

3. **Order Tire**:
   - Set tire to 5000km (Replace Now status)
   - Verify "Order Replacement" button in tire card
   - Select vendor → Verify tire search

4. **Vendor Preferences**:
   - Open Settings → Preferred Vendors
   - Deselect REI
   - Order component → REI not in list

### Unit Tests

```swift
func testOrderLinkGeneration() {
    let tire = TireTracking(...)
    let links = VendorService.orderLinks(for: tire)
    
    XCTAssertGreaterThan(links.count, 0)
    XCTAssertTrue(links.contains { $0.vendor == .competitiveCyclist })
}

func testSearchQueryBuilder() {
    let query = VendorService.buildTireSearchQuery(
        TireTracking(brand: "Continental", model: "GP5000", widthMM: 28)
    )
    XCTAssertEqual(query, "Continental GP5000 28mm")
}

func testVendorPreferences() {
    let pref = VendorPreference(preferredVendors: [.silca, .jensonUSA])
    XCTAssertEqual(pref.primaryVendor(), .silca)
}
```

## Resources

- [Competitive Cyclist](https://www.competitivecyclist.com)
- [Jenson USA](https://www.jensonusa.com)
- [Silca Chain Wax](https://silca.cc/collections/chain-lube-wax)
- [REI Cycling](https://www.rei.com/c/cycling)

---

**Note**: SpinMin is not affiliated with any vendor. Links are provided for user convenience. Always verify product compatibility and pricing before purchase.
