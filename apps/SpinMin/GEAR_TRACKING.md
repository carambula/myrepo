# Gear Tracking & Ride Checklists

SpinMin includes comprehensive tracking for personal gear and pre-ride checklists for training and race day preparation.

## Overview

**Gear Tracking**:
- Track helmets, shoes, cleats, pedals, lights, tools, nutrition, and clothing
- Auto-calculated expiry dates based on safety standards
- Usage tracking (rides and hours)
- Safety-critical warnings for helmets and expired gear
- Direct ordering integration for replacements

**Ride Checklists**:
- Pre-configured templates (Training, Race Day, Long Ride, Bike Packing)
- Categorized items (Safety, Bike, Tools, Nutrition, Clothing)
- Progress tracking
- Gear linking for automated checks

## Gear Types

### Safety Critical
- **Helmet** - 5-year expiration, crash tracking, inspection dates
- **Shoes** - 2-year lifespan (~1000 hours)
- **Cleats** - 1-year lifespan (~500 hours)
- **Pedals** - 5-year lifespan
- **Lights** - 2-year lifespan (battery/LED degradation)

### Electronics
- **Computer/GPS** - 3-year lifespan (battery cycles)
- **Lights** - 2-year lifespan

### Tools & Spares
- **Multi-Tool** - Indefinite with care
- **Pump/CO2** - Indefinite
- **Spare Kit** - 2-year lifespan (tubes/patches degrade)
- **Saddle Bag** - Indefinite

### Consumables
- **Water Bottles** - 1-year (hygiene)
- **Nutrition** - 1-month (expiration)

### Clothing
- **Jersey/Bibs** - 2 years (~200 washes)
- **Jacket** - 3 years
- **Gloves** - 1 year
- **Sunglasses** - 2 years (scratches/coating)

## Health Status System

### Status Levels
- **✨ New** (< 10% lifespan used)
- **🟢 Good** (10-50% used)
- **🟡 Aging** (50-75% used)
- **🟠 Replace Soon** (75-90% used)
- **🔴 Replace Now** (90-100% used)
- **⛔️ Expired** (> 100% or past expiration)
- **⚠️ UNSAFE** (helmet crash, critical damage)

### Helmet Safety Rules
- **5-Year Rule**: Helmets expire 5 years from purchase date
- **Crash Rule**: Helmets must be replaced immediately after any crash
- **Inspection**: Recommend inspection every 90 days
- **Warning Signs**: Cracks, loose straps, worn padding, compromised retention

## Usage

### Adding Gear

1. Open **Gear Locker** tab
2. Tap **+ menu** → Select gear type
3. Enter brand, model, purchase date
4. Optional: Purchase price, notes
5. Save

**Auto-tracking**:
- Helmets marked as safety-critical automatically
- Expiration dates calculated based on type
- Health status computed on-the-fly

### Tracking Usage

**Record Rides**:
- Usage count increments with each ride log
- Hours estimated (default: 2 hours per ride)
- Affects wear calculations for shoes, cleats

**Inspect Gear**:
- Mark inspection date for safety items
- Resets inspection warning timer

### Retiring Gear

When gear expires or is damaged:
1. Open gear detail
2. Tap "Retire Gear"
3. Gear moves to Retired archive
4. Automatically suggests ordering replacement

### Ordering Replacements

**Automatic Order Buttons**:
- Appear when status is "Replace Soon", "Replace Now", or "Expired"
- Opens vendor selection sheet
- Links to recommended retailers

**Supported Categories**:
- Helmets, shoes, cleats → Tools category vendors
- Lights, computers → Electronics vendors
- Nutrition, bottles → General vendors

## Ride Checklists

### Pre-Configured Templates

#### Training Ride (11 items)
**Categories**: Safety, Bike, Tools, Hydration

- Helmet ✓
- Cycling shoes ✓
- Sunglasses ✓
- Front & rear lights ✓
- Bike computer/GPS ✓
- Tire pressure checked
- Chain lubed
- Multi-tool
- Spare tube
- CO2 or mini pump
- Water bottles filled

#### Race Day (19 items)
**Categories**: Pre-Race, Gear, Bike, Nutrition, Post-Race

- Registration confirmed
- Course map reviewed
- Weather checked
- Helmet ✓
- Race shoes & cleats ✓
- Race kit (jersey/bibs) ✓
- Sunglasses ✓
- Bike computer/GPS ✓
- Bike cleaned
- Tire pressure optimal
- Chain waxed/lubed
- Shifting checked
- Brakes checked
- Wheels secured
- Pre-race meal eaten
- Water bottles filled
- Race nutrition packed
- Spare tube in pocket
- Multi-tool
- CO2 cartridges

#### Long Ride (16 items)
**Categories**: Safety, Bike, Tools, Nutrition, Clothing

- All training ride essentials
- Plus: 2-3 bottles, energy bars/gels, cafe money, arm warmers, gilet/jacket, gloves

### Using Checklists

1. Open **Checklists** tab
2. Select or create checklist
3. Tap items to check off
4. Progress bar shows completion
5. Reset when done

**Creating Custom**:
- Tap **+** → Custom Checklist
- Choose type and name
- Add items manually or start from template

## Data Models

### GearItem
```swift
@Model final class GearItem {
    var gearType: GearType
    var brand, model: String?
    var purchaseDate: Date
    var purchasePrice: Double?
    
    // Tracking
    var usageCount: Int
    var totalHours: Double
    var retirementDate: Date?
    
    // Safety
    var isSafetyCritical: Bool
    var lastInspectionDate: Date?
    var crashDate: Date?  // Helmets
    
    // Checklist integration
    var isRequiredForRides: Bool
    var isRequiredForRaces: Bool
}
```

### RideChecklist
```swift
@Model final class RideChecklist {
    var name: String
    var checklistType: ChecklistType
    var items: [ChecklistItem]
    
    var completionPercentage: Double
    var isComplete: Bool
}
```

## GearTrackingService

### Health Calculation
```swift
let health = GearTrackingService.calculateHealth(for: gear)
// Returns:
// - health: GearHealth (.new, .good, .aging, etc.)
// - agePercentage: 0-100+
// - usagePercentage: 0-100+
// - warnings: [String]
// - recommendations: [String]
// - daysUntilExpiry: Int?
// - shouldOrder: Bool
```

### Helmet-Specific Logic
- Checks crash date → immediate UNSAFE status
- Checks age → 5-year expiration
- Checks inspection → 90-day reminder
- Generates critical warnings for safety

### Usage-Based Wear
```swift
// Shoes: ~1000 hours expected life
// Cleats: ~500 hours expected life
// Computer: ~500 charge cycles
```

## UI Features

### Gear Locker View
- Summary card: Active, Replace, Expired counts
- Category filter: Safety, Electronics, Tools, Consumables, Clothing
- Gear cards with health status badges
- Quick navigation to gear details

### Gear Detail View
- Health status with emoji indicator
- Stats: Age, usage count, total hours
- Warnings (orange background)
- Recommendations (with checkmarks)
- Order replacement button (when needed)
- Retire gear action

### Checklist View
- Template-based creation
- Progress tracking (X of Y complete)
- Category grouping
- Check/uncheck items
- Reset for next use

## Integration

### With Vendor Ordering
```swift
// Gear Detail → Order button
OrderGearSheet(gear: gear)
// Maps gear type to component category
// Generates vendor links with brand/model search
```

### With Ride Logging
```swift
// Future: Auto-increment gear usage when logging rides
gear.recordUse(hours: rideDuration)
```

### With Checklists
```swift
// Future: Link gear items to checklist items
// Auto-check if gear is in locker
ChecklistItem(
    title: "Helmet",
    linkedGearId: helmetGear.id
)
```

## Best Practices

### For Users

**Gear Tracking**:
1. Add gear immediately after purchase
2. Record accurate purchase dates
3. Log rides to track usage hours
4. Inspect safety items regularly (helmets every 3 months)
5. Replace helmets after ANY crash
6. Order replacements early (when "Replace Soon" appears)

**Checklists**:
1. Use templates as starting point
2. Customize for your specific needs
3. Check items as you go (don't rush)
4. Reset after each use
5. Review and update seasonally

### For Safety

**Helmets**:
- Replace every 5 years regardless of condition
- Replace immediately after any crash (even minor)
- Inspect every 3 months for cracks, damage
- Check retention system, straps, buckles
- Never buy used helmets

**Shoes & Cleats**:
- Replace cleats at first sign of play/looseness
- Inspect soles for separation
- Check cleat bolt tightness regularly
- Replace shoes when soles are worn smooth

## Performance Tips

- Health calculations are on-demand (not stored)
- Checklist progress computed from items
- Gear list queries filter retired items
- Category filters use in-memory filtering

## Future Enhancements

**Gear Tracking**:
- Automatic usage tracking from ride logs
- Photo documentation (purchase receipts, condition)
- Maintenance tracking (shoe resoling, tool servicing)
- Price tracking and sale alerts
- Gear recommendations based on riding style

**Checklists**:
- Weather-aware items (add jacket if <50°F)
- Route-aware items (add climbing gears for hilly routes)
- Shared checklists with teammates
- Reminder notifications (night before race)
- Post-ride verification (did you bring everything back?)

**Integration**:
- Link gear to specific bikes (pedals, computers)
- Track which gear used on which rides
- Wear heatmaps (which items wear fastest)
- Cost per use analysis
- Warranty tracking

## Troubleshooting

**Gear shows expired but looks fine**:
- Safety standards require replacement by date
- Materials degrade even without visible damage
- Trust the expiration date for critical items

**Can't find gear type**:
- Use closest match or "Tools" category
- Request new gear type via feedback

**Checklist too long**:
- Create multiple shorter checklists
- Use category filters
- Customize templates to your needs

**Lost gear data**:
- Check CloudKit sync status
- Verify iCloud account signed in
- Check retired gear archive

---

**Safety Note**: This app provides recommendations based on industry standards. Always consult manufacturer guidelines and replace safety-critical items (helmets, lights) per their specifications. When in doubt, replace it.
