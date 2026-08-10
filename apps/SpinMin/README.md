# SpinMin — Tire Pressure Calculator

**spin min** is a cycling tire pressure calculator app for iOS, part of the min apps family.

## Overview

SpinMin helps cyclists find their optimal tire pressure based on:
- Rider weight
- Bike type (road, gravel, mountain, fat bike)
- Tire width
- Terrain conditions
- Tire casing type
- Riding style
- Temperature (optional)

## Features

### Gear Tracking & Checklists
- **Gear Locker**: Track helmets, shoes, cleats, tools, and accessories
- **Lifespan tracking**: Auto-calculated expiry dates (helmets: 5 years, shoes: 2 years, etc.)
- **Safety alerts**: Critical warnings for expired helmets, worn shoes
- **Usage tracking**: Record rides and hours for wear calculations
- **Consumables monitoring**: Track nutrition, bottles, spare kits
- **Pre-ride checklists**: Templates for training, races, long rides, bikepacking
- **Race day preparation**: Comprehensive race checklist with categories
- **Quick check-in**: Mark items complete, track progress
- **Gear ordering**: Direct links to replace expired/worn gear

See [GEAR_TRACKING.md](./GEAR_TRACKING.md) for complete documentation.

### Vendor Ordering System
- **One-tap ordering** of replacement components from trusted retailers
- **7 supported vendors**: Competitive Cyclist, Jenson USA, Silca, REI, Backcountry, Chain Reaction, Modern Bike
- **Smart vendor recommendations** based on component type
- **Context-aware buttons** (appear when replacement is needed)
- **Direct links** to Silca chain wax and popular products
- **User preferences** for favorite vendors
- **Deep linking** opens Safari with product search

See [VENDOR_ORDERING.md](./VENDOR_ORDERING.md) for complete documentation.

### Product Lookup Database
- **Autocomplete search** for tires, chains, wheelsets, and components
- **Pre-populated database** with 20+ popular products (Continental, Schwalbe, Shimano, SRAM, etc.)
- **Smart filtering** by wheel size, speed count, compatibility
- **Offline-first** operation with local database
- **Extensible** - add custom products via manual entry
- **Relevance scoring** for best search results

See [PRODUCT_DATABASE.md](./PRODUCT_DATABASE.md) for complete documentation.

### Ride-Ready Dashboard
- Quick-glance view of all saved bikes and wheelsets
- Real-time tire pressure recommendations
- Tire health status at a glance
- Easy ride logging with automatic mileage tracking

### Tire Pressure Calculator
- Science-based calculations using the 15% tire drop rule
- Empirical data from SILCA, Wolf Tooth, and industry research
- Separate front and rear pressure recommendations
- Display in PSI or BAR units

### Tire Tracking System
- **Track front and rear tires independently** (rear wears ~2× faster)
- **Mileage-based wear monitoring** with compound-specific lifespans
- **Age-based warnings** (5-6 year recommended, 10 year maximum)
- **Health status calculation**: Excellent → Good → Fair → Worn → Replace Soon → Replace Now → UNSAFE
- **Visual condition tracking**: squared profile, sidewall cracks, casing exposure, punctures
- **Ride logging**: Automatic odometer and mileage updates
- **Tire history**: Complete lifecycle records of replaced tires
- **Smart warnings**: Based on cycling industry best practices

See [TIRE_TRACKING.md](./TIRE_TRACKING.md) for detailed documentation.

### Bike Maintenance Tracking
**Chain-focused maintenance** with quick waxing/lubing workflows:
- **Chain wax/lube intervals**: Hot wax (500 km), drip wax (300 km), wet/dry lube tracking
- **Chain wear monitoring**: 0.5% limit for 11+ speed, prevents cassette damage
- **Quick actions**: One-tap chain wax, clean, and replace logging
- **Component lifespan tracking**: Chain, cassette, brake pads, cables, bearings, etc.
- **Health status system**: 🟢 Excellent → 🟡 Good → 🟠 Service Due → 🔴 Replace Soon → ⛔️ Replace Now
- **Maintenance history**: Chronological records with costs and notes
- **Bike odometer**: Automatic updates from ride logging
- **Dashboard indicators**: Maintenance due warnings on bike cards

See [MAINTENANCE_TRACKING.md](./MAINTENANCE_TRACKING.md) for detailed documentation.

### Gear Ratio Calculator
- Comprehensive gearing analysis with ratio, gear inches, development
- Speed at cadence calculations
- Climbing ability analysis
- Gap analysis between gears
- Pre-loaded popular drivetrains (Shimano, SRAM, Campagnolo)
- Compare mode for side-by-side analysis

### Bike & Wheelset Management
- Save multiple bike configurations
- Multiple wheelsets per bike with independent tire specs
- Weight tracking per wheelset
- Quick selection for calculations
- iCloud sync via SwiftData

### Themes
- Multiple color themes
- System dark/light mode support
- Shared theme system with other min apps

## Architecture

### Design System Integration
SpinMin uses the shared MinAppKit design tokens:
- `MinSpacing` - Spacing scale (4pt to 48pt)
- `MinCornerRadius` - Corner radius tokens
- `MinOpacity` - Opacity values for states
- `MinAffordanceStyle` - Button and interactive element styling

All spacing follows the minapp family standards:
- **Screen content margins**: 24pt (xl)
- **Floating controls inset**: 16pt (lg)
- **Grid gutters**: 16pt (lg)

### Tire Pressure Calculation Service

The core calculation service is designed to be testable and iteratable:

```swift
let result = TirePressureCalculationService.calculatePressure(
    riderWeightKg: 70,
    bikeType: .road,
    tireWidthMM: 28,
    terrain: .mixed,
    tireCasing: .standard,
    ridingStyle: .balanced,
    temperatureCelsius: 20
)
```

The service uses:
- Weight distribution based on bike type (road: 48/52, gravel: 47/53, MTB: 46.5/53.5)
- Terrain multipliers (smooth: 1.0, rough: 0.90, technical: 0.70)
- Casing adjustments (supple: -2psi, reinforced: +3psi)
- Temperature compensation (~0.15 psi per °C)
- Safety clamping to manufacturer-safe ranges

### Data Persistence

Uses SwiftData with CloudKit sync:
- `BikeConfiguration` - Saved bike profiles with optional gearing, bike odometer, and maintenance relationships
- `Wheelset` - Multiple wheel configurations per bike
- `TireTracking` - Current tire state (front/rear) with mileage and age
- `TireHistory` - Historical record of replaced tires
- `ComponentTracking` - Current components installed on bike (chain, cassette, brake pads, etc.)
- `MaintenanceRecord` - Historical maintenance activities with costs and notes
- `RideLog` - Ride tracking for mileage updates (updates bike + wheelset + component odometers)
- `GearConfiguration` - Standalone gear setups
- `CalculationHistory` - Past pressure calculations
- `ThemePreference` - Theme selection
- **Product Database**:
  - `TireProduct` - Pre-populated tire catalog with specs
  - `ChainProduct` - Chain specifications and compatibility
  - `WheelsetProduct` - Wheelset specifications
  - `ComponentProduct` - Generic component catalog
  - `BikeProduct` - Complete bike specifications

## Testing

Run tests to validate calculations:

```bash
xcodebuild test -scheme SpinMin -destination 'platform=iOS Simulator,name=iPhone 15'
```

Key test coverage:
- Basic calculations for all bike types
- Weight sensitivity
- Tire width sensitivity
- Terrain adjustments
- Temperature effects
- Safety range clamping

## Development

### Requirements
- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Dependencies
- MinAppKit (local package in `packages/design-system/swift`)
- SwiftUI
- SwiftData

### Building

1. Open `SpinMin.xcodeproj` in Xcode
2. Select the SpinMin scheme
3. Build and run (⌘R)

## Design Philosophy

SpinMin follows the min apps design principles:
- Clean, focused interface
- No mid-dot separators (use three spaces: " ")
- Consistent spacing and margins
- Theme support
- Offline-first with iCloud sync

## References

The tire pressure calculations are based on research from:
- Frank Berto's 15% tire drop rule
- SILCA professional tire pressure calculator
- Wolf Tooth tire pressure methodology
- Bicycle Quarterly suspension loss research

**Always verify recommendations against your tire and rim manufacturer's min/max specifications.**

## License

MIT
