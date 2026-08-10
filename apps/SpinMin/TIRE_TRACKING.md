# Tire Tracking System

SpinMin includes a comprehensive tire tracking system based on cycling industry best practices for monitoring tire wear, age, and replacement timing.

## Overview

The tire tracking system monitors front and rear tires independently, calculating health status based on:
- **Mileage**: Distance traveled on each tire
- **Age**: Calendar time since installation (rubber degrades even without use)
- **Visual indicators**: Condition notes from manual inspections
- **Usage patterns**: Ride logs and terrain tracking

## Key Principles

### Separate Front/Rear Tracking
Rear tires wear approximately **2× faster** than front tires due to:
- Higher weight distribution
- Drive force transmission
- Braking forces
- Skidding during turns

### Age Matters
Rubber compounds degrade over time regardless of mileage:
- **Recommended limit**: 5-6 years from manufacture
- **Absolute maximum**: 10 years (unsafe beyond this point)
- Factors: UV exposure, ozone, temperature cycling, storage conditions

### Mileage Guidelines

| Tire Type | Expected Lifespan (rear) | Front Tire |
|-----------|-------------------------|------------|
| Racing (soft compound) | 2,500 km | 5,000 km |
| Training/All-Round | 5,000 km | 10,000 km |
| Endurance (hard compound) | 8,000 km | 16,000 km |
| Touring/Puncture-Resistant | 10,000+ km | 20,000+ km |
| Gravel (mixed terrain) | 3,500 km | 7,000 km |
| MTB Cross-Country | 3,000 km | 6,000 km |
| MTB Trail | 2,500 km | 5,000 km |
| MTB Enduro | 2,000 km | 4,000 km |

*Note: Actual lifespan varies based on rider weight, terrain, riding style, and conditions.*

## Data Models

### TireTracking
Current state of a tire on a wheelset:
- Position (front/rear)
- Brand, model, compound type
- Installation date and initial odometer reading
- Expected lifespan (calculated or custom)
- Visual wear indicators:
  - Visible wear
  - Squared profile
  - Sidewall cracks
  - Casing exposure (critical)
  - Cuts
- Puncture count
- Manual condition notes

### TireHistory
Historical record when tires are replaced:
- All identification and lifecycle data
- Total mileage achieved
- Duration in service
- Removal reason (worn, damaged, aged, upgrade, etc.)
- Final condition notes
- Wear indicators at removal

### RideLog
Individual ride tracking:
- Date, distance, name
- Associated bike and wheelset
- Terrain type
- Weather conditions
- Notes

Automatically updates wheelset odometer and tire mileage.

## Health Status Calculation

### Status Levels

| Status | Criteria | Color | Action |
|--------|----------|-------|--------|
| **Excellent** | < 25% wear, no warnings | 🟢 Green | Continue normal use |
| **Good** | 25-50% wear | 🟢 Green | Monitor regularly |
| **Fair** | 50-75% wear | 🟡 Yellow | Inspect frequently |
| **Worn** | 75-90% wear | 🟠 Orange | Plan replacement |
| **Replace Soon** | 90-100% wear or 5+ years old | 🔴 Red | Replace within 1-2 weeks |
| **Replace Now** | > 100% wear, high warnings, 6+ years | 🔴 Red | Replace before next ride |
| **UNSAFE** | Casing exposure or 10+ years | ⛔️ Red | Do not ride |

### Warning System

**Critical Warnings** (Do Not Ride):
- Casing exposure visible
- 10+ years old

**High Warnings** (Replace Before Next Ride):
- Sidewall cracks
- 110%+ of expected mileage
- 6+ years old

**Medium Warnings** (Replace Soon):
- Squared-off profile (reduced cornering grip)
- Frequent punctures (5+)
- Cuts detected

**Low Warnings** (Monitor):
- Inspection overdue (90+ days)
- 3+ years old

### Recommendations Engine

The system provides context-specific recommendations:
- Estimated remaining kilometers
- Replacement timing guidance
- Alternative tire suggestions for frequent punctures
- Inspection frequency based on status

## User Interface

### Dashboard Integration

**Ride Dashboard** shows at-a-glance tire health:
- Health badges for front/rear tires (emoji + color)
- Odometer reading
- Warning indicators
- Quick access to tire management

**Wheelset Quick View** (collapsible):
- Tire health summary
- Pressure recommendations
- Link to full tire management

### Log Ride

Quick ride logging updates tire mileage:
- Select bike and wheelset
- Enter distance and date
- Optional: ride name, terrain, notes
- Automatically updates odometer and tire tracking

### Tire Management View

**Current Tab**:
- Wheelset odometer and total rides
- Detailed tire cards for front/rear with:
  - Health status and emoji indicator
  - Mileage, age, wear percentage
  - Progress bars
  - Warnings and recommendations
  - Actions: Inspect, Replace
- "Start Tracking" for untracked positions

**History Tab**:
- Chronological list of replaced tires
- Stats: total mileage, duration, avg km/day
- Removal reason and condition notes
- Wear indicators at removal

**Rides Tab**:
- Summary statistics (total rides, distance, average)
- Chronological ride list
- Per-ride details: distance, date, terrain, notes

### Tire Actions

**Add Tire Tracking**:
- Select position (front/rear)
- Enter brand, model, compound type
- Set installation date
- Specify initial odometer reading
- Optional: custom expected lifespan

**Replace Tire**:
- Archives current tire to history
- Records removal reason and condition
- Sets up new tire tracking
- Automatic odometer continuity

**Inspect Tire**:
- Update visual wear indicators
- Record puncture count
- Add condition notes
- Updates "last inspection" date

## Best Practices

### For Riders

1. **Log rides regularly** to maintain accurate mileage
2. **Inspect tires monthly** or before long rides
3. **Replace tires proactively** when status reaches "Replace Soon"
4. **Never ride** with "Unsafe" status tires
5. **Check age** in addition to mileage - 5-6 years is the sweet spot
6. **Rotate front/rear** if using identical tires (extends life)
7. **Track punctures** - frequent punctures indicate worn tread
8. **Note conditions** during replacement for future reference

### Visual Inspection Checklist

- **Tread wear**: Is the center flattened (squared profile)?
- **Wear indicators**: Are built-in indicators still visible?
- **Sidewalls**: Any cracks, cuts, or bulges?
- **Casing**: Is any fabric visible through the rubber?
- **Embedded debris**: Glass, thorns, or sharp objects?
- **Deformation**: Lumps, waves, or irregular shape?

### When to Replace Immediately

Replace tires **before your next ride** if you observe:
- ⛔️ **Casing threads visible** through rubber
- ⛔️ **Deep sidewall cracks** (> 1mm deep)
- ⛔️ **Bulges or deformations** in the tire
- ⛔️ **10+ years old** regardless of appearance
- ⚠️ **Cuts exposing casing** layers
- ⚠️ **Sudden increase in punctures** (tread worn through)

## Technical Implementation

### Services

**TireHealthService**:
- `calculateHealth(for: TireTracking) -> HealthResult`
- Returns: status, warnings, recommendations, remaining km
- Considers: mileage %, age, visual indicators, compound type

**Wheelset Extensions**:
- `frontTire`, `rearTire`: Convenience accessors
- `tireHealthSummary`: Both tire statuses
- `worstTireHealth`: Most critical status
- `needsAttention`: Boolean for dashboard warnings
- `logDistance(_:)`: Update odometer and tire mileage

### SwiftData Relationships

```
Wheelset 1 --> * TireTracking  (cascade delete)
Wheelset 1 --> * TireHistory   (cascade delete)
Wheelset 1 --> * RideLog       (nullify delete)
```

### CloudKit Sync

All tire tracking data syncs via CloudKit:
- Tire tracking state
- Historical records
- Ride logs

Perfect for multi-device use (iPhone + iPad + Mac).

## Example Workflows

### New Wheelset Setup

1. Create wheelset in bike configuration
2. Navigate to wheelset → "Start Tire Tracking"
3. Add front tire: Continental GP5000, Training, install today
4. Add rear tire: Continental GP5000, Training, install today
5. Odometer starts at 0 km

### Logging a Ride

1. Tap "Log Ride" in dashboard
2. Select bike and wheelset
3. Enter distance (e.g., 45.0 km)
4. Optional: add ride name "Morning Loop" and terrain "Pavement"
5. Save → Odometer updates, tire mileage increases

### Replacing a Worn Tire

1. Dashboard shows 🔴 "Replace Soon" for rear tire
2. Tap wheelset → "Current" tab → "Replace" on rear tire
3. Review current tire stats (4,850 km, 287 days)
4. Select removal reason "Worn Out"
5. Add note: "Squared profile, 3 punctures last month"
6. Enter new tire details
7. Save → Old tire archived, new tracking begins

### Periodic Inspection

1. Navigate to wheelset → Current tab → "Inspect"
2. Review current health status
3. Update visual indicators:
   - ☑️ Visible wear
   - ☑️ Squared profile
   - ☐ Sidewall cracks
   - ☐ Casing exposure
4. Increment puncture count if applicable
5. Add notes: "Small cut on sidewall, monitoring"
6. Save → Health recalculated with new data

## Data Sources

Tire lifespan guidelines based on:
- [WatchMy.bike tire replacement guide](https://watchmy.bike/blog/when-to-replace-bike-tires)
- [Michelin bicycle tire longevity](https://www.michelinman.com/bicycle/bicycle-tips-and-advice/fitting-bike-tires/how-long-do-bike-tires-last)
- [BicycleNest replacement timing](https://bicyclenest.com/bike-tire-replacement-guide-when-and-how-to-change-tires/)
- Industry standard compound lifespan data
- Professional mechanic recommendations

## Future Enhancements

Potential additions:
- Tire pressure correlation (pressure history per ride)
- Wear rate prediction (ML-based remaining life)
- Photo uploads for visual condition tracking
- Tire rotation suggestions
- Integration with Strava/other ride tracking
- Tire comparison (different models/compounds)
- Cost tracking ($/km analysis)
- Seasonal tire swaps (reminders)
