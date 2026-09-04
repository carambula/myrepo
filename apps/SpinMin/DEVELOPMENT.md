# SpinMin Development Guide

## Architecture Overview

SpinMin follows the min apps family architecture patterns with a focus on testability and iterability of the core tire pressure calculation logic.

## Key Components

### 1. TirePressureCalculationService

The heart of the app - a pure calculation service with no UI dependencies.

**Location**: `Services/TirePressureCalculationService.swift`

**Design Principles**:
- Pure functions with no side effects
- All calculation logic in one place
- Easy to test in isolation
- Algorithm parameters can be tuned without UI changes

**Testing Strategy**:
```swift
// Run all calculation tests
xcodebuild test -scheme SpinMin -only-testing:SpinMinTests/TirePressureCalculationServiceTests
```

**Iterating on the Algorithm**:
1. Modify calculation logic in `TirePressureCalculationService`
2. Run tests to validate changes
3. Test edge cases (extreme weights, tire widths)
4. Validate against real-world data

**Key Parameters to Tune**:
- `weightDistribution` - Front/rear weight split per bike type
- `pressureMultiplier` - Terrain-based adjustments
- `pressureAdjustment` - Casing and riding style offsets
- `calculateBasePressure` - Base formula (currently uses empirical approach)
- `clampPressure` - Min/max safe ranges per bike type

### 2. Data Models

**BikeConfiguration**: Persisted bike profiles
- Uses SwiftData for local + iCloud storage
- Tracks last used time for sorting
- Optional bike weight (uses typical defaults if not specified)

**CalculationHistory**: Past pressure calculations
- Stores full context of each calculation
- Useful for analyzing user preferences
- Could be used for ML-based recommendations in future

**ThemePreference**: Theme selection
- Simple preference storage
- Syncs via SwiftData

### 3. Views

**CalculatorView**: Main calculator interface
- Real-time input with sliders
- Bike configuration selection or manual entry
- Results display with PSI/BAR toggle
- Follows 24pt screen margins (MinSpacing.screenHorizontalPadding)
- Uses 16pt floating control insets where applicable

**BikeConfigurationsView**: Bike profile management
- List/empty state pattern
- SwiftData Query for automatic updates
- Card-based layout with 16pt grid-like spacing

**SettingsView**: App settings and info
- Theme selection
- About/version info
- Educational content about tire pressure

## Design System Integration

SpinMin uses MinAppKit tokens:

```swift
import MinAppKit

// Spacing
MinSpacing.screenHorizontalPadding  // 24pt - screen content margins
MinSpacing.lg                         // 16pt - floating controls, grid gutters
MinSpacing.xl                         // 24pt - section spacing
MinSpacing.md                         // 12pt - inter-component spacing

// Corner Radius
MinCornerRadius.md                    // 12pt - cards, inputs
MinCornerRadius.lg                    // 16pt - result cards

// Opacity
MinOpacity.pressed                    // 0.7 - button press state
```

## Testing Strategy

### Unit Tests
Focus on `TirePressureCalculationService`:
- Basic calculations for each bike type
- Weight sensitivity
- Tire width sensitivity
- Terrain adjustments
- Casing effects
- Riding style effects
- Temperature compensation
- Safety range validation
- Unit conversions (PSI ↔ BAR)

### UI Tests
(To be added as needed):
- Calculator flow
- Bike profile creation/deletion
- Theme switching
- Results display

## Iteration Guide

### Adding a New Bike Type

1. Add case to `BikeType` enum
2. Define `weightDistribution` for that type
3. Add `typicalBikeWeight` default
4. Update `baseMultiplier` in `calculateBasePressure`
5. Define safe pressure ranges in `clampPressure`
6. Add test cases

### Adjusting Pressure Recommendations

The algorithm uses several tunable parameters:

**Weight Distribution** (front/rear split):
```swift
var weightDistribution: (front: Double, rear: Double) {
    switch self {
    case .road: return (0.48, 0.52)  // Road: more weight on rear
    case .gravel: return (0.47, 0.53)
    case .mountainXC: return (0.465, 0.535)
    }
}
```

**Terrain Multipliers** (reduce pressure for rough terrain):
```swift
var pressureMultiplier: Double {
    switch self {
    case .smooth: return 1.0    // No reduction
    case .mixed: return 0.95    // 5% reduction
    case .technical: return 0.70  // 30% reduction
    }
}
```

**Base Pressure Formula**:
```swift
let basePressure = (weightLbs * baseMultiplier) / pow(tireWidthInches, 1.5)
```

The exponent 1.5 is empirically derived. Adjust based on real-world testing.

### Validating Against Real Data

To validate recommendations:
1. Compare against SILCA calculator for road bikes
2. Compare against Wolf Tooth for gravel/MTB
3. Cross-reference with tire manufacturer recommendations
4. Test with real riders and collect feedback

## Roadmap Ideas

Future enhancements to consider:

- [ ] Save temperature with bike configurations
- [ ] Pressure adjustment based on tubeless vs tubes
- [ ] Rim width considerations
- [ ] Pressure recommendations for specific tire models (database)
- [ ] ML model trained on user feedback
- [ ] Historical pressure tracking/charts
- [ ] Export/share bike configurations
- [ ] Apple Watch complication for quick pressure checks
- [ ] Integration with bike computer apps
- [ ] Barometric pressure sensor integration

## Contributing

When making changes:

1. **Write tests first** for calculation changes
2. **Follow spacing rules** from workspace rules (.cursor/rules)
3. **Use design tokens** from MinAppKit
4. **No mid-dot separators** - use three spaces for metadata
5. **Commit messages** should be descriptive

## Resources

### Tire Pressure Research
- [SILCA Blog](https://silca.cc/blogs/journal) - Excellent articles on tire pressure science
- [Bicycle Quarterly](https://www.renehersecycles.com/tire-pressure-calculator/) - Frank Berto's research
- [Wolf Tooth Resources](https://www.wolftoothcomponents.com/pages/tire-pressure-calculator)

### Design System
- `packages/design-system/README.md` - Design system documentation
- `.cursor/rules/spacing-margins-grids.mdc` - Spacing rules for minapp family
- `.cursor/rules/no-mid-dot-separator.mdc` - Text formatting rules
