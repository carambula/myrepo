//
//  RideScheduleModels.swift
//  SpinMin
//
//  Models for ride scheduling, routes, and pre-ride preparation
//

import Foundation
import SwiftData

// MARK: - Scheduled Ride

@Model
final class ScheduledRide {
    var id: UUID
    var name: String
    var scheduledDate: Date
    var duration: TimeInterval  // seconds
    var distance: Double?  // kilometers
    var rideTypeRawValue: String
    var notes: String
    
    // Training platform sync
    var trainingPeaksWorkoutId: String?
    var garminWorkoutId: String?
    var lastSynced: Date?
    
    // Route
    var route: Route?
    
    // Bike selection
    var recommendedBike: BikeConfiguration?
    var selectedBike: BikeConfiguration?
    
    // Weather
    var weatherForecast: String?
    var temperature: Double?  // Celsius
    var precipitationChance: Double?  // 0-1
    
    // Preparation
    var isPrepared: Bool
    var preparedDate: Date?
    var gearChecked: Bool
    var bikeChecked: Bool
    
    // Completion
    var isCompleted: Bool
    var completedDate: Date?
    var actualDuration: TimeInterval?
    var actualDistance: Double?
    
    init(
        name: String,
        scheduledDate: Date,
        duration: TimeInterval,
        rideType: RideType,
        distance: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.scheduledDate = scheduledDate
        self.duration = duration
        self.rideTypeRawValue = rideType.rawValue
        self.distance = distance
        self.notes = notes
        self.isPrepared = false
        self.gearChecked = false
        self.bikeChecked = false
        self.isCompleted = false
    }
    
    var rideType: RideType {
        get { RideType(rawValue: rideTypeRawValue) ?? .training }
        set { rideTypeRawValue = newValue.rawValue }
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(scheduledDate)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(scheduledDate)
    }
    
    var isUpcoming: Bool {
        scheduledDate > Date()
    }
    
    var hoursUntil: Double {
        scheduledDate.timeIntervalSinceNow / 3600
    }
    
    var needsPreparation: Bool {
        !isPrepared && hoursUntil < 24 && hoursUntil > 0
    }
    
    func markPrepared() {
        isPrepared = true
        preparedDate = Date()
    }
}

enum RideType: String, CaseIterable, Codable {
    case training
    case race
    case recovery
    case interval
    case endurance
    case tempo
    case threshold
    case vo2max = "vo2_max"
    case sprint
    case longRide = "long_ride"
    case groupRide = "group_ride"
    case commute
    
    var displayName: String {
        switch self {
        case .training: return "Training"
        case .race: return "Race"
        case .recovery: return "Recovery"
        case .interval: return "Intervals"
        case .endurance: return "Endurance"
        case .tempo: return "Tempo"
        case .threshold: return "Threshold"
        case .vo2max: return "VO2 Max"
        case .sprint: return "Sprint"
        case .longRide: return "Long Ride"
        case .groupRide: return "Group Ride"
        case .commute: return "Commute"
        }
    }
    
    var icon: String {
        switch self {
        case .training: return "figure.outdoor.cycle"
        case .race: return "flag.checkered"
        case .recovery: return "leaf.fill"
        case .interval, .vo2max, .sprint: return "bolt.fill"
        case .endurance, .longRide: return "arrow.forward.circle.fill"
        case .tempo, .threshold: return "speedometer"
        case .groupRide: return "person.3.fill"
        case .commute: return "building.2.fill"
        }
    }
    
    var recommendedChecklistType: ChecklistType {
        switch self {
        case .race: return .race
        case .longRide, .endurance: return .longRide
        default: return .training
        }
    }
    
    var intensityLevel: Int {
        switch self {
        case .recovery, .commute: return 1
        case .endurance, .longRide: return 2
        case .tempo, .groupRide: return 3
        case .threshold, .training: return 4
        case .interval, .vo2max, .sprint, .race: return 5
        }
    }
}

// MARK: - Route

@Model
final class Route {
    var id: UUID
    var name: String
    var distance: Double  // kilometers
    var elevation: Double?  // meters
    var routeTypeRawValue: String
    var surfaceTypeRawValue: String
    var notes: String
    
    // Map data
    var gpxFileURL: String?
    var startLatitude: Double?
    var startLongitude: Double?
    
    // Characteristics
    var trafficLevel: Int  // 1-5
    var technicalLevel: Int  // 1-5
    var scenicRating: Int?  // 1-5
    
    // Usage
    var timesRidden: Int
    var lastRidden: Date?
    var isFavorite: Bool
    
    init(
        name: String,
        distance: Double,
        routeType: RouteType,
        surfaceType: SurfaceType,
        elevation: Double? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.distance = distance
        self.routeTypeRawValue = routeType.rawValue
        self.surfaceTypeRawValue = surfaceType.rawValue
        self.elevation = elevation
        self.notes = notes
        self.trafficLevel = 3
        self.technicalLevel = 3
        self.timesRidden = 0
        self.isFavorite = false
    }
    
    var routeType: RouteType {
        RouteType(rawValue: routeTypeRawValue) ?? .mixed
    }
    
    var surfaceType: SurfaceType {
        SurfaceType(rawValue: surfaceTypeRawValue) ?? .paved
    }
}

enum RouteType: String, CaseIterable, Codable {
    case loop
    case outAndBack = "out_and_back"
    case pointToPoint = "point_to_point"
    case mixed
    
    var displayName: String {
        switch self {
        case .loop: return "Loop"
        case .outAndBack: return "Out & Back"
        case .pointToPoint: return "Point to Point"
        case .mixed: return "Mixed"
        }
    }
}

enum SurfaceType: String, CaseIterable, Codable {
    case paved
    case gravel
    case mixed
    case singleTrack = "single_track"
    
    var displayName: String {
        switch self {
        case .paved: return "Paved"
        case .gravel: return "Gravel"
        case .mixed: return "Mixed"
        case .singleTrack: return "Single Track"
        }
    }
}

// MARK: - Training Platform Integration

struct TrainingPeaksIntegration {
    var isConnected: Bool
    var username: String?
    var lastSync: Date?
    
    // API credentials (stored securely in keychain)
    static func syncWorkouts() async throws -> [ScheduledRide] {
        // TODO: Implement TrainingPeaks API integration
        // 1. Authenticate with TrainingPeaks
        // 2. Fetch upcoming workouts
        // 3. Convert to ScheduledRide objects
        // 4. Return rides
        return []
    }
}

struct GarminIntegration {
    var isConnected: Bool
    var lastSync: Date?
    
    // API credentials (stored securely in keychain)
    static func syncCalendar() async throws -> [ScheduledRide] {
        // TODO: Implement Garmin Connect API integration
        // 1. Authenticate with Garmin
        // 2. Fetch calendar events
        // 3. Convert to ScheduledRide objects
        // 4. Return rides
        return []
    }
}

// MARK: - Pre-Ride Preparation

struct PreRidePreparation {
    let ride: ScheduledRide
    let recommendedBike: BikeConfiguration?
    let recommendedRoute: Route?
    let requiredGear: [GearItem]
    let optionalGear: [GearItem]
    let weatherAlert: String?
    let bikeChecks: [BikeCheck]
    let gearChecks: [GearCheck]
    
    struct BikeCheck {
        let item: String
        let isComplete: Bool
        let priority: CheckPriority
    }
    
    struct GearCheck {
        let gear: GearItem
        let isReady: Bool
        let issue: String?
        let priority: CheckPriority
    }
    
    enum CheckPriority {
        case critical
        case important
        case optional
    }
    
    var isReadyToRide: Bool {
        bikeChecks.filter { $0.priority == .critical }.allSatisfy { $0.isComplete } &&
        gearChecks.filter { $0.priority == .critical }.allSatisfy { $0.isReady }
    }
    
    var completionPercentage: Double {
        let totalChecks = bikeChecks.count + gearChecks.count
        guard totalChecks > 0 else { return 0 }
        
        let completedBike = bikeChecks.filter { $0.isComplete }.count
        let completedGear = gearChecks.filter { $0.isReady }.count
        
        return Double(completedBike + completedGear) / Double(totalChecks) * 100
    }
}
