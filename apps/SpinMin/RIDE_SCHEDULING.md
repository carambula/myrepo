# Ride Scheduling & Preparation

SpinMin includes a comprehensive ride scheduling system with smart preparation recommendations. Plan your rides, get bike and route suggestions, and ensure you're ready before every ride.

## Features

### 📅 Ride Scheduling
- **Manual ride entry** - Create rides with date, time, type, duration, and distance
- **Training platform sync** - Import scheduled workouts from any iCalendar (ICS) feed: TrainingPeaks, intervals.icu, TrainerRoad, Final Surge. Ride type, duration, and distance are inferred from the workout title and description
- **Ride types** - Training, race, recovery, intervals, endurance, tempo, threshold, VO2 max, sprint, long ride, group ride, commute
- **Notes and details** - Add ride-specific notes and planning details

### 🎯 Smart Recommendations
- **Bike selection** - Algorithm recommends the best bike based on ride type, intensity, and maintenance status
- **Route matching** - Suggests routes based on ride duration, surface type compatibility, and difficulty
- **Scoring system** - Intelligently weighs multiple factors for optimal recommendations

### ✅ Pre-Ride Preparation
- **Preparation dashboard** - See all critical checks in one place
- **Progress tracking** - Visual progress bar shows how ready you are
- **Smart checklists** - Dynamic checks based on ride type and intensity
- **Weather alerts** - Get warnings for extreme temperatures or precipitation
- **Completion percentage** - Track your readiness at a glance

### 🚴 Bike Checks
- **Tire pressure** - Reminder to check before every ride
- **Chain condition** - Alerts if chain needs wax or replacement
- **Tire health** - Warnings if tires need attention
- **Brake check** - Critical safety reminder
- **Shifting check** - Ensure smooth gear changes

### 🎒 Gear Checks
- **Critical safety gear** - Helmet (mandatory), shoes, sunglasses
- **Electronics battery** - Head unit, radar, tail light, front light all must be charged
- **Consumables** - Chamois cream, water bottles, nutrition
- **Ride-specific gear** - Additional checks for races and long rides
- **Priority levels** - Critical, important, and optional items clearly marked

### 🌤 Weather Integration & Smart Gear Selection
- **Temperature-based clothing recommendations**
  - Freezing (< 0°C): Full winter kit (insulated jacket, winter gloves, thermal layers, shoe covers)
  - Very cold (0-5°C): Insulated jacket, winter gloves, thermal leg warmers
  - Cold (5-10°C): Thermal jacket, full-finger gloves
  - Cool (10-15°C): Vest or arm warmers for long rides
  - Hot (> 30°C): Lightweight breathable kit, extra hydration, sunscreen
  - Extreme (> 35°C): Ice vest, electrolytes, heat management critical
- **Precipitation-based gear**
  - Possible (30-50%): Packable rain jacket (optional)
  - Likely (50-70%): Waterproof jacket (essential), fenders (recommended)
  - Very likely (> 70%): Full rain kit (jacket + pants), waterproof gloves, shoe covers, visibility lights
- **Combined weather warnings**
  - Cold + wet: Hypothermia risk - full waterproof layer system essential
  - Hot + dry: Double-check water supply before departure
- **Smart hydration calculations**
  - Base: 500-750ml per hour
  - Adjusted for temperature, ride duration, and intensity
  - Automatic electrolyte recommendations for hot weather
  - Refill stop planning for rides > 3 hours
- **Priority system**
  - Essential: Must have for safety (red)
  - Recommended: Strongly advised (orange)
  - Optional: Nice to have (gray)

### 🗺 Route Management
- **Route library** - Save and manage your favorite routes
- **Route characteristics**
  - Distance and elevation
  - Route type: Loop, out & back, point-to-point
  - Surface type: Paved, gravel, mixed, single track
  - Traffic level (1-5)
  - Technical difficulty (1-5)
  - Scenic rating (1-5)
- **Usage tracking** - Times ridden, last ridden date
- **GPX support** - *Coming soon:* Import and export GPX files
- **Favorites** - Mark your go-to routes

## Usage

### Creating a Ride

1. Open the **Schedule** tab
2. Tap the **+** button
3. Fill in ride details:
   - Name
   - Date & time
   - Type (training, race, etc.)
   - Duration
   - Distance (optional)
   - Notes
4. Tap **Add**

### Preparing for a Ride

1. Find your ride in the **Schedule** tab
2. Rides needing preparation appear in the "Needs Preparation" section
3. Tap the ride card to open preparation view
4. Review:
   - Recommended bike and route
   - Weather alert (if applicable)
   - Bike checks
   - Gear checks
5. Complete all checks
6. Tap **Mark as Prepared**

### Adding a Route

1. Open **Settings** → **Routes** *(Coming soon)*
2. Tap **Add Route**
3. Enter route details:
   - Name
   - Distance
   - Route type
   - Surface type
   - Elevation (optional)
   - Difficulty ratings
4. Tap **Save**

## Data Models

### ScheduledRide
```swift
- id: UUID
- name: String
- scheduledDate: Date
- duration: TimeInterval
- distance: Double?
- rideType: RideType
- notes: String
- trainingPeaksWorkoutId: String?  // For future OAuth API sync
- garminWorkoutId: String?  // For future OAuth API sync
- calendarEventId: String?  // ICS feed event UID (dedupe key for calendar sync)
- route: Route?
- recommendedBike: BikeConfiguration?
- selectedBike: BikeConfiguration?
- weatherForecast: String?
- temperature: Double?
- precipitationChance: Double?
- isPrepared: Bool
- gearChecked: Bool
- bikeChecked: Bool
- isCompleted: Bool
```

### Route
```swift
- id: UUID
- name: String
- distance: Double
- elevation: Double?
- routeType: RouteType (loop, out & back, point-to-point)
- surfaceType: SurfaceType (paved, gravel, mixed, single track)
- notes: String
- gpxFileURL: String?
- startLatitude/startLongitude: Double?
- trafficLevel: Int (1-5)
- technicalLevel: Int (1-5)
- scenicRating: Int? (1-5)
- timesRidden: Int
- lastRidden: Date?
- isFavorite: Bool
```

### RideType
- **Training** - General training ride
- **Race** - Competition day
- **Recovery** - Easy recovery spin
- **Intervals** - High-intensity interval workout
- **Endurance** - Steady aerobic effort
- **Tempo** - Moderate sustained effort
- **Threshold** - Near-maximal sustained effort
- **VO2 Max** - Maximum aerobic intervals
- **Sprint** - Maximum power efforts
- **Long Ride** - 3+ hours endurance
- **Group Ride** - Social ride
- **Commute** - Utilitarian ride

Each type has:
- Display name
- Icon
- Recommended checklist type
- Intensity level (1-5)

## Services

### WeatherService

**Temperature Categorization**
```swift
enum TemperatureCategory {
    case freezing, veryCold, cold, cool, mild, warm, hot, veryHot, extreme
}
```
Each category has specific clothing recommendations and warnings.

**Precipitation Levels**
```swift
enum PrecipitationLevel {
    case none, slight, possible, likely, veryLikely, certain
}
```
Determines rain gear requirements and priority.

**Clothing Recommendations**
```swift
static func recommendClothing(temperature: Double, precipitationChance: Double, rideDuration: TimeInterval) -> ClothingRecommendations
```
Returns structured recommendations for:
- Jacket (type based on temp/rain)
- Gloves (thermal level based on temp)
- Leg covering (warmers/tights based on temp)
- Base layer (thermal if cold)
- Accessories (shoe covers, neck warmer, sunscreen, fenders, lights, etc.)

Each item includes:
- Name (specific description)
- Priority (essential/recommended/optional)
- Reason (why it's needed)

**Hydration Calculation**
```swift
static func recommendHydration(temperature: Double, rideDuration: TimeInterval, rideIntensity: Int) -> String
```
Calculates:
- Base: 500ml/hour
- Temperature adjustment: +100-500ml for heat
- Intensity adjustment: +50ml per intensity level (1-5 scale)
- Total bottle count (based on 750ml bottles)
- Electrolyte recommendation for hot weather
- Refill stop planning for long rides

### RidePreparationService

**Bike Recommendation**
```swift
static func recommendBike(for ride: ScheduledRide, bikes: [BikeConfiguration]) -> BikeConfiguration?
```
Scores each bike based on:
- Bike type match to ride type (road for races, gravel for mixed terrain)
- Maintenance status (penalizes bikes needing service)
- Wheelset readiness (favors bikes with default wheelset)
- Tire health (penalizes bikes with tires needing attention)

**Route Recommendation**
```swift
static func recommendRoute(for ride: ScheduledRide, routes: [Route], bike: BikeConfiguration?) -> Route?
```
Scores each route based on:
- Distance match to ride duration (assumes 25 km/h average)
- Surface type compatibility with bike type
- Route difficulty vs. ride intensity
- Favorite status
- Frequency of use

**Gear Checks**
```swift
static func generateGearChecks(for ride: ScheduledRide, allGear: [GearItem]) -> [PreRidePreparation.GearCheck]
```
Generates weather-aware checks for:
- **Safety gear**: Helmet (critical), shoes, sunglasses (upgraded to important in sunny weather)
- **Electronics**: Head unit (critical), radar (important), lights (important if rain or commute, optional otherwise) - all with battery checks
- **Consumables**: Chamois cream (important), water bottles (critical if hot, important otherwise)
- **Weather clothing**: 
  - Jacket (essential if cold/rain, optional if cool on long ride)
  - Gloves (essential if very cold, important if cold, optional if cool)
  - Leg warmers/tights (essential if freezing, recommended if very cold)
  - Base layers (essential if freezing, recommended if very cold)
  - Accessories (shoe covers, neck warmer, sunscreen, fenders, visibility lights) based on conditions
- **Ride-specific**: Additional gear for races and long rides

Priority levels dynamically adjust based on weather:
- Cold + wet: Jacket upgraded to essential (hypothermia risk)
- Hot weather: Bottles upgraded to critical (dehydration risk)
- Rain likely: Lights upgraded to important (visibility)

**Bike Checks**
```swift
static func generateBikeChecks(for bike: BikeConfiguration?, wheelset: Wheelset?) -> [PreRidePreparation.BikeCheck]
```
Generates checks for:
- Tire pressure (critical)
- Chain condition (based on MaintenanceService)
- Tire health (based on TireHealthService)
- Brakes (critical)
- Shifting (important)

**Weather Alerts**
```swift
static func generateWeatherAlert(for ride: ScheduledRide) -> String?
```
Generates detailed, actionable alerts:
- **Temperature warnings**: Specific gear recommendations for each temperature range
- **Precipitation alerts**: Rain gear requirements based on probability
- **Combined warnings**: Special alerts for dangerous combinations (cold + wet)
- **Hydration reminders**: Extra emphasis in hot/dry conditions
- **Safety advisories**: Earlier start times, route adjustments for extreme conditions

**Full Preparation**
```swift
static func prepareForRide(_ ride: ScheduledRide, bikes: [BikeConfiguration], routes: [Route], allGear: [GearItem]) -> PreRidePreparation
```
Orchestrates all recommendation and check generation into a complete preparation package.

## UI Components

### RideScheduleView
Main view showing:
- **Today's rides** - Rides scheduled for today
- **Needs Preparation** - Rides within 24 hours that aren't prepared
- **Upcoming** - All future rides
- Empty state with add ride CTA

### RideCard
Displays:
- Ride icon and time
- Ride name and type
- Duration and distance
- Selected/recommended bike
- Preparation status badge
- Ready checkmark when prepared

### AddRideView
Form for creating new rides:
- Ride details (name, date, type)
- Duration picker (30min - 5+ hours)
- Optional distance input
- Notes field

### PreRidePreparationView
Comprehensive preparation interface:
- **Header**: Ride name, date, progress bar, completion percentage
- **Recommendations**: Bike and route suggestions with reasoning
- **Weather Alert**: Detailed temperature and precipitation warnings with specific actions
- **Weather Gear Section**: Smart clothing recommendations based on conditions
  - Temperature and precipitation display with emojis
  - Each clothing item with priority badge (Essential/Recommended/Optional)
  - Specific reasons for each recommendation
  - Hydration calculation with bottle count and electrolyte guidance
  - Color-coded priority (red=essential, orange=recommended, gray=optional)
- **Bike Checks**: List with completion status and priority
- **Gear Checks**: List with readiness status, issues, and priority
- **Actions**: Mark as Prepared button (enabled when all critical checks complete)

## Integration Points

### Existing Systems
- **Bike configurations** - Recommends bikes, checks maintenance
- **Wheelsets** - Checks tire health and default wheelset
- **Gear tracking** - Validates gear readiness and battery levels
- **Maintenance tracking** - Checks chain condition
- **Tire tracking** - Checks tire health
- **Checklists** - Uses ride type to determine checklist recommendations

### Calendar Feed Sync (implemented)
`TrainingCalendarSyncService` downloads and parses an iCalendar (ICS) feed and merges its events into scheduled rides:

- **Works today, no partner API required** - TrainingPeaks, intervals.icu, TrainerRoad, and Final Surge all publish per-user ICS feed URLs
- **Setup** - Ride Schedule tab → sync button → paste your feed URL (webcal:// or https://). In TrainingPeaks: Settings → Calendar Sync
- **Smart import** - Ride type inferred from workout keywords (race, recovery, VO2, threshold, tempo, etc.); distance parsed from text like "60km" or "40 mi"
- **Safe merge** - Events are deduplicated by calendar UID. Re-syncing updates changed workouts; completed rides are never modified
- **Sync window** - Imports rides from today through the next 60 days
- **Pull to refresh** - Swipe down on the schedule to sync

Garmin Connect does not publish a calendar feed; push Garmin-planned workouts to TrainingPeaks or intervals.icu and sync from there.

### Weather Forecasts (implemented)
`WeatherForecastService` uses Apple WeatherKit to populate ride temperature, precipitation chance, and conditions:

- **No API keys** - WeatherKit is built into iOS; enable the WeatherKit capability on the app target in Xcode (Signing & Capabilities)
- **Location** - Uses the ride's route start coordinates when set, otherwise the device location (add `NSLocationWhenInUseUsageDescription` to Info.plist)
- **Forecast window** - Rides within the next 10 days get hourly forecasts matched to the ride start time
- **Feeds recommendations** - The stored temperature and precipitation drive weather-based clothing and hydration suggestions

### Future Integrations
- **TrainingPeaks / Garmin OAuth APIs** - Direct API sync (requires partner program approval); the ICS merge logic is reusable
- **Notifications** - Daily prep reminders and ride alerts
- **Apple Calendar** - Sync rides to device calendar
- **Route planning** - GPX import/export, turn-by-turn navigation

## Best Practices

### Ride Planning
- **Create rides early** - Add rides at least 24 hours in advance for best preparation
- **Set realistic durations** - Helps with route recommendations
- **Choose appropriate types** - Ride type drives bike and gear recommendations
- **Add notes** - Include specific goals or requirements

### Preparation
- **Check the night before** - Review preparation 12-24 hours before ride
- **Charge electronics overnight** - Avoid last-minute battery panic
- **Mark as prepared** - Confirms you've completed all checks
- **Review weather** - Adjust gear based on conditions

### Route Management
- **Build your library** - Add routes after riding them
- **Mark favorites** - Helps with recommendations
- **Update characteristics** - Accurate ratings improve recommendations
- **Track usage** - Helps identify your go-to routes

### Gear Tracking
- **Keep gear locker current** - Add new gear, retire old gear
- **Update battery levels** - Charge items and update status
- **Check safety items** - Helmet, lights, radar should always be ready
- **Stock consumables** - Keep chamois cream, nutrition stocked

## Example Workflows

### Planning a Weekend Long Ride

1. **Thursday Evening**
   - Open Schedule tab
   - Add new ride: "Saturday Long Ride", 100km, 4 hours, Endurance type
   - Review recommended bike and route

2. **Friday Evening**
   - Tap ride in "Needs Preparation"
   - Check recommended bike (gravel bike for mixed terrain)
   - Review 100km route suggestion
   - Check weather alert (none)
   - Verify all electronics charged
   - Ensure consumables ready
   - Mark as prepared

3. **Saturday Morning**
   - Quick glance at Dashboard
   - Confirm tire pressures
   - Head out with confidence

### Preparing for a Race

1. **Week Before**
   - Add race to schedule: "Criterium Race", 1 hour, Race type
   - Note any specific requirements

2. **Day Before**
   - Review preparation
   - Check recommended bike (road bike for high intensity)
   - Verify chain waxed recently
   - Charge all electronics
   - Pack race kit
   - Prepare nutrition

3. **Race Morning**
   - Final preparation check
   - Confirm tire pressure optimal
   - Double-check gear checklist
   - Mark as prepared
   - Race with confidence

### Recovery Ride After Hard Training

1. **Post-Workout**
   - Add recovery ride for next day: "Easy Spin", 1 hour, Recovery type
   
2. **Recovery Day**
   - App recommends gravel bike (more comfortable)
   - Suggests easy, scenic route
   - Minimal preparation required
   - Focus on enjoying the ride

## Future Enhancements

### Training Platform Sync
- OAuth integration with TrainingPeaks and Garmin
- Automatic workout import
- Bi-directional sync of completed rides
- TSS and training load tracking

### Advanced Route Features
- GPX file import/export
- Route creation with map interface
- Turn-by-turn navigation
- Strava segment integration
- Popular routes discovery

### Smart Notifications
- Daily preparation reminders (evening before ride)
- Ride start reminders (30 minutes before)
- Weather change alerts
- Maintenance due notifications
- Gear charging reminders

### Analytics
- Ride history and trends
- Bike usage statistics
- Route frequency analysis
- Preparation compliance tracking
- Gear readiness metrics

### Group Ride Features
- Invite friends to rides
- Share routes
- Group preparation status
- Ride meetup coordination
- Post-ride social features

## Technical Implementation

### Recommendation Algorithm

**Bike Scoring** (0-100 scale)
- Base type match: 10-50 points
- Maintenance penalty: -20 points
- Wheelset bonus: +10 points
- Tire health penalty: -15 points

**Route Scoring** (0-100+ scale)
- Distance match: up to 50 points
- Surface compatibility: up to 40 points
- Difficulty match: up to 25 points
- Favorite bonus: +15 points
- Frequency bonus: up to 20 points

### Check Priority System
- **Critical**: Must complete before riding (helmet, tire pressure, brakes)
- **Important**: Should complete but ride possible without (electronics, chain)
- **Optional**: Nice to have (spare kit, jacket)

### Readiness Calculation
```swift
completionPercentage = (completedChecks / totalChecks) * 100
isReadyToRide = all critical checks are complete
```

### Battery Tracking
- Electronics have `batteryPercentage` (0-100)
- `needsCharge` when battery < 20%
- Prep checks fail when electronics need charging
- Battery drains during rides based on `batteryRuntimeHours`
