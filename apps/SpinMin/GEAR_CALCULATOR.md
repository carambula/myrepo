# Gear Calculator Feature

SpinMin now includes a comprehensive gear ratio calculator and analysis suite!

## Overview

The gear calculator helps cyclists:
- **Analyze current gearing** - Understand your bike's gear ratios
- **Plan new drivetrains** - Compare 1x vs 2x, different cassettes
- **Compare setups** - Side-by-side analysis of different bikes
- **Optimize for terrain** - Ensure you have the right gears for your riding

## Features

### 🎯 Three Input Modes

1. **New Setup** - Manual input for custom configurations
2. **From My Bike** - Use saved bike profiles
3. **Popular Drivetrain** - Select from pre-configured groupsets

### 📊 Four Analysis Tabs

#### 1. Overview
- Total gear count
- Gear range percentage
- Lowest/highest gear (gear inches)
- Speed range at 90 RPM
- Average gap between gears
- Visual range indicator

#### 2. Table
- Complete gear chart
- Ratio for each combination
- Gear inches
- Speed at 90 RPM
- Highlights easiest/hardest gears

#### 3. Speed
- Speed at different cadences (60-110 RPM)
- km/h and mph display
- Interactive gear selection
- Perfect for planning descents/flats

#### 4. Climbing
- Maximum climbable grade estimate
- Speed at 60 RPM
- Context for different grade levels
- Based on rider + bike weight

### 🗄️ Popular Drivetrain Database

Pre-configured groupsets from top manufacturers:

**Shimano Road**
- Dura-Ace R9200 (52/36 × 11-30/28)
- Ultegra R8100 (52/36 × 11-30/28)
- 105 R7100 (50/34 × 11-30/34)

**Shimano Gravel**
- GRX RX820 2x (48/31 × 11-40/42)
- GRX RX820 1x (40t × 11-40 or 10-45)

**Shimano MTB**
- XTR M9100 (32t × 10-51)
- XT M8100 (32t × 10-51)
- SLX M7100 (32t × 10-51)

**SRAM Road**
- RED eTap AXS (52/37 × 10-33)
- Force eTap AXS (48/35 × 10-33)

**SRAM Gravel**
- RED XPLR (40t × 10-44)
- Force XPLR (42t × 10-44)
- Rival XPLR (40t × 10-44)

**SRAM MTB**
- XX Eagle AXS (32t × 10-52)
- X01 Eagle (32t × 10-50)
- GX Eagle (32t × 10-50)
- NX Eagle (32t × 11-50)

**Campagnolo Road**
- Super Record (52/39 × 10-29/11-34) 13-speed
- Record (52/39 × 10-29/11-34) 13-speed
- Chorus (52/36 × 11-34) 13-speed

**Campagnolo Gravel**
- Ekar (40t × 9-42) 13-speed

## Key Metrics Explained

### Gear Ratio
`Chainring teeth ÷ Cassette cog teeth`

Example: 50t chainring with 25t cog = 2.0 ratio

### Gear Inches (GI)
Universal metric for comparing gears across wheel sizes.
Higher number = harder to pedal, faster speed.

Formula: `(Chainring ÷ Cog) × Wheel diameter in inches`

**Typical Ranges:**
- Road climbing: 30-40 GI
- Road moderate: 50-70 GI
- Road fast: 90-120 GI
- Gravel: 20-60 GI
- MTB: 18-35 GI

### Development
Meters traveled per crank revolution.
Used in Europe, helpful for bikepacking planning.

### Gap Analysis
Percentage jump between gears.

- < 15%: Very smooth shifts
- 15-18%: Smooth (ideal)
- 18-22%: Noticeable but OK
- \> 22%: Large gap (may feel abrupt)

### Gear Range
`((Highest ratio ÷ Lowest ratio) - 1) × 100`

**Typical Ranges:**
- Classic 2x road: 370% (52/36 × 11-28)
- Modern 2x road: 420% (50/34 × 11-34)
- Gravel 1x: 440% (42t × 10-44)
- MTB 1x Eagle: 520% (32t × 10-52)

## Compare Mode

Side-by-side analysis of two bikes:
- Gear range comparison
- Low/high gear differences
- Gap analysis
- Visual indicators for better setup
- Percentage differences highlighted

Access via bike profile → Compare button

## Integration with Bike Profiles

Gearing is optional on bike profiles:
- Add gearing to existing bikes
- Store chainrings + cassette
- Link to popular drivetrains
- Used for What-If scenarios

## Use Cases

### Planning a 1x Conversion
**Question**: "Will 42t × 10-44 work for my rides?"

**How to use:**
1. Input current 2x setup (e.g., 50/34 × 11-32)
2. Compare with proposed 1x (42t × 10-44)
3. Check:
   - Do you lose needed climbing gears?
   - Do you lose top speed?
   - Are gaps acceptable?

### Choosing a Cassette
**Question**: "11-34 or 11-36 for my road bike?"

**How to use:**
1. Input: 50/34 × 11-34
2. Compare to: 50/34 × 11-36
3. See: 2 GI difference in low gear (easier climbing)
4. Check: Speed range at your typical cadence

### Bikepacking Gearing
**Question**: "Can I climb 15% grades loaded?"

**How to use:**
1. Input your setup (e.g., 30/46 × 11-36)
2. Go to Climbing tab
3. Enter loaded weight (rider + bike + gear)
4. See estimated max grade
5. Check speed at 60 RPM (sustainable climbing cadence)

### MTB Cassette Choice
**Question**: "10-50 or 10-52 cassette?"

**How to use:**
1. Compare 32t × 10-50 vs 32t × 10-52
2. Check gap analysis
3. 10-52 has larger jump at low end (42-50: 19%, 42-52: 24%)
4. Decision: Do you need the 2 GI difference for steeps?

## Tips

### For Road Riders
- 52/36 for racing/fast riding
- 50/34 for climbing/endurance
- Consider 11-32 or 11-34 for hilly areas
- 11-28 only if your terrain is flat

### For Gravel Riders
- 1x simplifies shifting, less maintenance
- 40-42t is sweet spot for most terrain
- 10-44 cassette for fast gravel
- 10-50 cassette for loaded/hilly
- 2x (48/31) if you need road-bike speeds

### For MTB Riders
- 32t is standard for trail/XC
- 30t for very steep terrain or heavy riders
- 34t for less technical, more pedaling
- 10-51 has smoother gaps than 11-50
- 10-52 for extreme climbing

## Technical Notes

### Wheel Size + Tire Width
The calculator accounts for actual wheel circumference:
- BSD (Bead Seat Diameter) + tire height
- Tire height ≈ 60% of tire width
- Matters for accurate speed/development

**Example:**
- 700c × 28mm ≈ 2111mm circumference
- 700c × 40mm ≈ 2159mm circumference
- 48mm difference = ~2% speed difference

### Climbing Estimation
The climbing grade estimate is conservative:
- Based on 200W sustained power
- Uses actual gear + weight
- Real-world climbing depends on:
  - Your fitness/power
  - Cadence preference
  - Surface (pavement vs dirt)
  - Grade consistency

Use as a starting point, adjust for personal ability.

### Gap Tolerance
Ideal gap depends on riding style:
- **Racing**: Tighter gaps (12-16%) for precision
- **Endurance**: Moderate gaps (15-18%) are fine
- **MTB**: Larger gaps OK (18-22%) - terrain dictates
- **Touring**: Smooth gaps preferred for loaded climbing

## Future Enhancements

Planned features:
- [ ] Chain line efficiency warnings
- [ ] Overlap visualization for 2x systems
- [ ] Export gear charts as PDF
- [ ] Integration with route planning
- [ ] Power-based climbing predictions
- [ ] Cassette cog editor (currently fixed presets)
- [ ] Historical comparison tracking
- [ ] Gear recommendation AI based on riding data

## Feedback

The gear calculator is designed to be iteratable. The `GearCalculationService` is isolated and testable, making it easy to:
- Adjust climbing formulas
- Add new metrics
- Refine recommendations
- Integrate external data

Found inaccuracies? Have suggestions? The algorithms can be tuned based on real-world feedback!
