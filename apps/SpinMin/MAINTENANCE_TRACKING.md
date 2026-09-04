# Bike Maintenance Tracking

SpinMin includes a comprehensive bike maintenance tracking system for monitoring component wear, service intervals, and maintenance history.

## Overview

The maintenance tracking system helps cyclists:
- **Track component lifespans** and know when to replace parts
- **Monitor chain maintenance** including waxing/lubing and cleaning intervals
- **Log all maintenance activities** with costs and notes
- **Prevent expensive failures** by replacing chains before they damage cassettes
- **Maintain complete service history** for each bike

## Key Features

### Chain-Focused Tracking

Chain maintenance is the highest-leverage bike maintenance. A worn chain destroys cassettes and chainrings.

**Chain Wear Monitoring**:
- Replace at **0.5% wear** for 11+ speed systems
- Replace at **0.75% wear** for 8-10 speed systems
- Track wear percentage with chain gauge measurements
- Visual warnings when approaching limits

**Wax/Lube Intervals**:
- **Hot wax**: 300-600 km (avg 500 km)
- **Drip wax**: 200-400 km (avg 300 km)
- **Wet lube**: 300-400 km (avg 350 km)
- **Dry lube**: 150-250 km (avg 200 km)

**Chain Cleaning Intervals**:
- Hot wax: 1,000 km (re-wax is the clean)
- Drip wax: 600 km
- Wet lube: 300 km (attracts dirt quickly)
- Dry lube: 400 km

**Quick Actions**:
- Log Wax/Lube (one-tap with date/notes)
- Log Clean
- Replace Chain (with old chain stats)

### Component Lifespan Tracking

Track any bike component with automatic wear monitoring:

| Component | Expected Lifespan | Replace When |
|-----------|------------------|--------------|
| **Chain** | 3,500 km (2,000-5,000 km) | 0.5% wear (11-speed) |
| **Cassette** | 15,000 km | With regular chain replacement |
| **Chainrings** | 20,000 km | Teeth show hooking/wear |
| **Brake Pads** | 3,000 km (800-5,600 km) | <1mm remaining |
| **Brake Rotors** | 15,000 km | Below minimum thickness |
| **Bottom Bracket** | 15,000 km | Play or roughness |
| **Cables** | 10,000 km | Fraying or poor shift quality |
| **Headset** | 30,000 km | Play or notchiness |
| **Wheel Bearings** | 10,000 km | Play or roughness |

### Health Status System

Each component gets a health status based on mileage and age:

| Status | Criteria | Action |
|--------|----------|--------|
| **🟢 Excellent** | < 50% lifespan | Continue normal use |
| **🟡 Good** | 50-70% lifespan | Monitor regularly |
| **🟠 Service Due** | 70-85% lifespan | Plan replacement soon |
| **🔴 Replace Soon** | 85-100% lifespan | Replace within 200-500 km |
| **⛔️ Replace Now** | > 100% lifespan | Replace immediately |

### Maintenance Records

Log all maintenance activities:

**Maintenance Types**:
- Chain: wax, clean, lube, replace
- Drivetrain: cassette, chainring, derailleur service, cables
- Brakes: pads, cables, bleed, rotors
- Bearings: bottom bracket, headset, wheel bearings
- Wheels: truing, spokes
- General: full service, wash, misc

**Record Details**:
- Date and bike odometer reading
- Component brand/model (for replacements)
- Cost tracking
- Who performed the work (self/shop)
- Notes and observations
- Component lifespan (when replacing)

## Data Models

### ComponentTracking
Tracks current components installed on bike:
- Component type (chain, cassette, etc.)
- Installation date and odometer
- Current odometer (auto-updated from rides)
- Brand/model identification
- Chain-specific: lube type, last wax/clean dates, wear %
- Notes

### MaintenanceRecord
Historical record of all maintenance:
- Maintenance type and category
- Date and bike odometer
- Component details (for replacements)
- Cost and performer
- Notes
- Component lifespan calculation (when replacing)

### BikeConfiguration
Enhanced with:
- Bike odometer (total mileage)
- Speed count (11, 12, etc. for chain wear limits)
- Relationships to components and maintenance records
- Helper methods for logging distance and checking maintenance status

## User Interface

### BikeMaintenanceView

Main maintenance screen with 3 tabs:

**1. Current Components**
- Bike odometer display
- Chain status card (if tracked):
  - Current mileage and wear
  - Lube type and interval
  - Wax/lube due indicator with progress bar
  - Quick actions: Log Wax, Log Clean, Replace
- Other components with health indicators
- Add component button

**2. History**
- Chronological maintenance records
- Category filtering (chain, drivetrain, brakes, etc.)
- Cost tracking
- Component lifespan stats
- Search and filter options

**3. Quick Log**
- Grid of common maintenance actions:
  - Chain Wax
  - Chain Clean
  - New Chain
  - Bike Wash
  - Brake Pads
  - Full Service
- One-tap to quick log form

### Quick Logging Workflows

**Log Chain Wax** (most common):
1. Tap "Chain Wax" from Quick Log
2. Confirm date (defaults to today)
3. Add optional notes
4. Save → Updates last wax date and odometer

**Replace Chain**:
1. Tap "New Chain" from Quick Log
2. See old chain stats (mileage, age, wear)
3. Enter new chain brand/model
4. Select lube type (hot wax, drip wax, etc.)
5. Enter final wear percentage
6. Save → Archives old chain, creates new tracking

**Log Any Maintenance**:
1. Tap "+" in maintenance view
2. Select maintenance type
3. Enter date, notes, cost, performer
4. Save → Creates record at current odometer

### Dashboard Integration

**Bike Cards Show**:
- Bike odometer under name
- 🔧 Maintenance due indicator (orange wrench)
- Direct link to maintenance view
- Warning badge on "Maintenance" button if service due

**Ride Logging**:
- Automatically updates bike odometer
- Updates all component odometers
- Updates tire tracking
- Enables accurate maintenance interval tracking

## Best Practices

### Chain Maintenance is Critical

The chain is the cheapest drivetrain part but destroys the expensive ones:
- A cassette that should last 15,000 km can be ruined in 3,000 km by a worn chain
- Replace chain at 0.5% wear (11+ speed) to save cassette
- Check wear monthly with a quality chain gauge (Park CC-3.2, Shimano TL-CN42)

### Waxing Extends Chain Life

Hot-melt wax chains can last 4,000+ km vs. 2,500-3,000 km for wet-lubed chains:
- Wax doesn't attract grit like oil lubes
- Cleaner operation (no black grimy hands)
- Longer cassette life (can exceed 20,000 km)
- Requires slow cooker and initial setup
- Worth it for high-mileage riders

### Track Replacement History

When replacing components, note:
- Total mileage achieved
- What prompted replacement (wear, damage, upgrade)
- Condition observations
- Brand/model that worked well (or didn't)

This builds institutional knowledge for future purchases.

### Use Bike Odometer as Source of Truth

The bike odometer (from ride logging) drives all maintenance intervals:
- More accurate than component-specific tracking
- Handles component replacements seamlessly
- Provides context for all maintenance
- Enables cost-per-km analysis

### Set Up Components on New Bikes

When adding a bike to SpinMin:
1. Log bike odometer (from bike computer or estimate)
2. Add chain tracking with lube type
3. Track high-wear items (brake pads, cassette)
4. Note current condition in notes

This creates a baseline for future monitoring.

## Example Workflows

### New Bike Setup

1. Create bike in SpinMin
2. Navigate to bike → Maintenance
3. Tap "Track Component" → Chain
4. Enter current chain brand/model
5. Select lube type (e.g., Hot Wax)
6. Set install date (when chain was new or estimate)
7. Set initial odometer (bike's current mileage)
8. Repeat for cassette, brake pads if desired

### Regular Chain Waxing

Hot wax user, 500 km interval:

1. Dashboard shows bike with 🔧 indicator
2. Tap bike → Maintenance
3. See "Chain Wax due" with progress bar at 100%
4. Tap "Log Wax" quick action
5. Confirm date, add "Hot wax redip, 10 min" note
6. Save → Resets wax interval

### Chain Replacement

At 3,500 km with 0.55% wear:

1. Check chain with gauge: 0.55% (above 0.5% limit)
2. Navigate to bike → Maintenance
3. See chain card showing 🔴 Replace Now status
4. Tap "Replace" action
5. See old chain stats: 3,487 km, 287 days, 0.55% wear
6. Enter new chain: Shimano CN-M9100, Hot Wax
7. Enter final wear: 0.55%
8. Add note: "Replaced at limit to save cassette"
9. Save → Archives old chain, creates new tracking

Old chain archived to history showing 3,487 km lifespan.

### Brake Pad Replacement

After noticing reduced braking:

1. Navigate to bike → Maintenance → Current Components
2. See brake pad component at 🔴 Replace Now (3,200 km)
3. Tap "+" → Select "Brake Pad Replacement"
4. Enter cost: $35
5. Performed by: "Self"
6. Notes: "Front pads worn to metal backing"
7. Save → Creates maintenance record

### Full Service at Shop

After professional tune-up:

1. Tap "+" in maintenance
2. Select "Full Service"
3. Enter date and cost: $125
4. Performed by: "Local Bike Shop"
5. Notes: "New cables, chain lube, derailleur adjustment, brake bleed"
6. Save

Records full service in history with all details.

## Technical Implementation

### Services

**MaintenanceService**:
- `calculateComponentHealth(for: ComponentTracking) -> ComponentHealthResult`
  - Returns health status, warnings, recommendations
  - Calculates % of expected lifespan
  - Estimates remaining km

- `calculateChainMaintenance(for: ComponentTracking, speedCount: Int) -> ChainMaintenanceResult`
  - Wax/lube due calculations
  - Clean interval tracking
  - Chain wear vs. limit
  - Overall status and warnings

- `calculateBikeMaintenance(components:speedCount:) -> BikeMaintenanceSummary`
  - Bike-level maintenance status
  - Components needing attention
  - Upcoming maintenance list

### BikeConfiguration Extensions

```swift
// Update odometer and all components
func logDistance(_ distanceKm: Double)

// Get current chain
var currentChain: ComponentTracking?

// Check if maintenance due
var maintenanceDue: Bool

// Get full maintenance summary
func getMaintenanceSummary() -> MaintenanceService.BikeMaintenanceSummary
```

### ComponentTracking Extensions

```swift
// Update odometer from bike
func updateOdometer(_ newOdometerKm: Double)

// Record wax/lube
func recordWax(date: Date, odometerKm: Double)

// Record clean
func recordClean(date: Date, odometerKm: Double)

// Computed properties
var componentMileageKm: Double
var kmSinceLastWax: Double?
var kmSinceLastClean: Double?
```

## Data Sources

Chain maintenance intervals based on:
- [BikeSize Chain Maintenance Guide](https://bike-size.com/articles/bike-chain-maintenance-guide)
- [Cycling Archives Chain Lube 2026 Guide](https://cyclingarchives.com/bike-chain-lube-2026-complete-guide-wet-dry-hot-melt-wax-lubricants-watts-chain-life/)
- [SILCA Waxed Chain Maintenance](https://silca.cc/blogs/silca/how-to-maintain-a-waxed-chain)
- [CyclingCeramic Waxed vs Oil Chain Test](https://cyclingceramic.com/waxed-chain-vs-oil-chain/)

Component lifespans from industry standards and professional mechanics.

## Future Enhancements

Potential additions:
- Integration with bike computer odometers (automatic sync)
- Maintenance reminders/notifications
- Cost analysis ($/km for components)
- Batch maintenance logging (full service with multiple items)
- Photo attachments for condition documentation
- Parts inventory tracking (spare chains, pads, etc.)
- Service shop integration
- Warranty tracking
- Seasonal maintenance checklists
