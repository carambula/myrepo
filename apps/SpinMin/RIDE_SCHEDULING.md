# Ride Scheduling & Preparation

SpinMin includes a comprehensive ride scheduling system with smart preparation recommendations. Plan your rides, get bike and route suggestions, and ensure you're ready before every ride.

## Features

### 📅 Ride Scheduling
- **Manual ride entry** - Create rides with date, time, type, duration, and distance
- **Training platform integration** - *Coming soon:* Sync with TrainingPeaks and Garmin Connect
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

### 🌤 Weather Integration
- **Temperature alerts**
  - Cold rides (< 5°C): Warning to wear extra layers
  - Hot rides (> 35°C): Hydration reminder
- **Precipitation warnings**
  - High chance (> 50%): Bring rain jacket
  - Possible rain (> 30%): Consider jacket

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
- trainingPeaksWorkoutId: String?  // For sync
- garminWorkoutId: String?  // For sync
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
Generates checks for:
- **Safety gear**: Helmet (critical), shoes, sunglasses
- **Electronics**: Head unit, radar, tail light, front light (battery checks)
- **Consumables**: Chamois cream, water bottles
- **Ride-specific**: Additional gear for races and long rides

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
Analyzes temperature and precipitation chance to generate actionable alerts.

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
- **Recommendations**: Bike and route suggestions
- **Weather Alert**: Temperature and precipitation warnings
- **Bike Checks**: List with completion status and priority
- **Gear Checks**: List with readiness status, issues, and priority
- **Actions**: Mark as Prepared button (enabled when ready)

## Integration Points

### Existing Systems
- **Bike configurations** - Recommends bikes, checks maintenance
- **Wheelsets** - Checks tire health and default wheelset
- **Gear tracking** - Validates gear readiness and battery levels
- **Maintenance tracking** - Checks chain condition
- **Tire tracking** - Checks tire health
- **Checklists** - Uses ride type to determine checklist recommendations

### Future Integrations
- **TrainingPeaks API** - Sync workouts and training plans
- **Garmin Connect API** - Sync calendar and completed activities
- **Weather API** - Live weather forecasts
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
