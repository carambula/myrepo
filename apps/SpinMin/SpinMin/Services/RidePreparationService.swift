//
//  RidePreparationService.swift
//  SpinMin
//
//  Smart recommendations for ride preparation
//

import Foundation
import SwiftData

struct RidePreparationService {
    
    // MARK: - Bike Recommendation
    
    static func recommendBike(
        for ride: ScheduledRide,
        bikes: [BikeConfiguration]
    ) -> BikeConfiguration? {
        guard !bikes.isEmpty else { return nil }
        
        // Score each bike based on ride type
        let scoredBikes = bikes.map { bike in
            (bike: bike, score: calculateBikeScore(bike, for: ride))
        }
        
        return scoredBikes.max(by: { $0.score < $1.score })?.bike
    }
    
    private static func calculateBikeScore(_ bike: BikeConfiguration, for ride: ScheduledRide) -> Double {
        var score = 0.0
        
        // Match bike type to ride type
        switch ride.rideType {
        case .race, .interval, .vo2max, .sprint, .threshold:
            // High-intensity rides favor road bikes
            if bike.bikeType == .road { score += 50 }
            else if bike.bikeType == .gravel { score += 30 }
            else { score += 10 }
            
        case .endurance, .tempo, .longRide:
            // Endurance rides favor any road-capable bike
            if bike.bikeType == .gravel { score += 50 }
            else if bike.bikeType == .road { score += 45 }
            else { score += 20 }
            
        case .groupRide, .training:
            // General rides - match to any
            if bike.bikeType == .road { score += 40 }
            else if bike.bikeType == .gravel { score += 35 }
            else { score += 30 }
            
        case .recovery:
            // Recovery rides favor comfortable bikes
            if bike.bikeType == .gravel { score += 45 }
            else if bike.bikeType == .road { score += 30 }
            else { score += 40 }
            
        case .commute:
            // Commute favors any bike
            score += 30
        }
        
        // Penalize bikes needing maintenance
        if bike.maintenanceDue {
            score -= 20
        }
        
        // Favor bikes with default wheelsets ready
        if let defaultWheelset = bike.wheelsets.first(where: { $0.isDefault }) {
            score += 10
            
            // Penalize if tires need attention
            if defaultWheelset.needsAttention {
                score -= 15
            }
        }
        
        return score
    }
    
    // MARK: - Route Recommendation
    
    static func recommendRoute(
        for ride: ScheduledRide,
        routes: [Route],
        bike: BikeConfiguration?
    ) -> Route? {
        guard !routes.isEmpty else { return nil }
        
        let scoredRoutes = routes.map { route in
            (route: route, score: calculateRouteScore(route, for: ride, bike: bike))
        }
        
        return scoredRoutes.max(by: { $0.score < $1.score })?.route
    }
    
    private static func calculateRouteScore(_ route: Route, for ride: ScheduledRide, bike: BikeConfiguration?) -> Double {
        var score = 0.0
        
        // Match route distance to ride duration (assume 25 km/h average)
        let expectedDistanceKm = (ride.duration / 3600) * 25
        let distanceDiff = abs(route.distance - expectedDistanceKm)
        score += max(0, 50 - distanceDiff)  // Closer to target = higher score
        
        // Match surface type to bike type
        if let bike = bike {
            switch (bike.bikeType, route.surfaceType) {
            case (.road, .paved): score += 40
            case (.gravel, .gravel), (.gravel, .mixed): score += 40
            case (.mountainBike, .singleTrack), (.mountainBike, .gravel): score += 40
            case (.road, .mixed): score += 20
            default: score += 10
            }
        }
        
        // Match intensity to route difficulty
        let rideIntensity = ride.rideType.intensityLevel
        if rideIntensity >= 4 {
            // High intensity - favor less technical routes
            score += Double(5 - route.technicalLevel) * 5
        } else if rideIntensity <= 2 {
            // Low intensity - any route is fine
            score += 20
        }
        
        // Favor favorites
        if route.isFavorite {
            score += 15
        }
        
        // Favor frequently ridden routes
        score += Double(min(route.timesRidden, 10)) * 2
        
        return score
    }
    
    // MARK: - Gear Check
    
    static func generateGearChecks(
        for ride: ScheduledRide,
        allGear: [GearItem]
    ) -> [PreRidePreparation.GearCheck] {
        let rideType = ride.rideType
        let checklistType = rideType.recommendedChecklistType
        
        var checks: [PreRidePreparation.GearCheck] = []
        
        // Critical safety gear
        checks.append(contentsOf: checkSafetyGear(allGear))
        
        // Electronics with battery checks
        checks.append(contentsOf: checkElectronics(allGear))
        
        // Consumables
        checks.append(contentsOf: checkConsumables(allGear))
        
        // Ride-specific gear
        if checklistType == .race {
            checks.append(contentsOf: checkRaceGear(allGear))
        } else if checklistType == .longRide {
            checks.append(contentsOf: checkLongRideGear(allGear))
        }
        
        return checks
    }
    
    private static func checkSafetyGear(_ allGear: [GearItem]) -> [PreRidePreparation.GearCheck] {
        var checks: [PreRidePreparation.GearCheck] = []
        
        // Helmet (critical)
        if let helmet = allGear.first(where: { $0.gearType == .helmet && !$0.isRetired }) {
            let health = GearTrackingService.calculateHealth(for: helmet)
            let isReady = health.health != .unsafe && health.health != .replaceSoon
            let issue = !isReady ? health.warnings.first : nil
            checks.append(PreRidePreparation.GearCheck(
                gear: helmet,
                isReady: isReady,
                issue: issue,
                priority: .critical
            ))
        } else {
            // No helmet found - critical issue
            let dummyHelmet = GearItem(gearType: .helmet)
            checks.append(PreRidePreparation.GearCheck(
                gear: dummyHelmet,
                isReady: false,
                issue: "No helmet found - add one to your gear locker",
                priority: .critical
            ))
        }
        
        // Shoes
        if let shoes = allGear.first(where: { $0.gearType == .shoes && !$0.isRetired }) {
            checks.append(PreRidePreparation.GearCheck(
                gear: shoes,
                isReady: true,
                issue: nil,
                priority: .important
            ))
        }
        
        return checks
    }
    
    private static func checkElectronics(_ allGear: [GearItem]) -> [PreRidePreparation.GearCheck] {
        var checks: [PreRidePreparation.GearCheck] = []
        
        for gearType in [GearType.headUnit, .radar, .tailLight, .frontLight] {
            if let item = allGear.first(where: { $0.gearType == gearType && !$0.isRetired }) {
                let needsCharge = item.needsCharge
                let issue = needsCharge ? "Battery below 20% - needs charging" : nil
                checks.append(PreRidePreparation.GearCheck(
                    gear: item,
                    isReady: !needsCharge,
                    issue: issue,
                    priority: gearType == .headUnit ? .critical : .important
                ))
            }
        }
        
        return checks
    }
    
    private static func checkConsumables(_ allGear: [GearItem]) -> [PreRidePreparation.GearCheck] {
        var checks: [PreRidePreparation.GearCheck] = []
        
        // Chamois cream
        if let cream = allGear.first(where: { $0.gearType == .chamoisCream && !$0.isRetired }) {
            checks.append(PreRidePreparation.GearCheck(
                gear: cream,
                isReady: true,
                issue: nil,
                priority: .important
            ))
        }
        
        // Bottles
        if let bottles = allGear.first(where: { $0.gearType == .bottles && !$0.isRetired }) {
            checks.append(PreRidePreparation.GearCheck(
                gear: bottles,
                isReady: true,
                issue: nil,
                priority: .important
            ))
        }
        
        return checks
    }
    
    private static func checkRaceGear(_ allGear: [GearItem]) -> [PreRidePreparation.GearCheck] {
        var checks: [PreRidePreparation.GearCheck] = []
        
        // Nutrition
        if let nutrition = allGear.first(where: { $0.gearType == .nutrition && !$0.isRetired }) {
            checks.append(PreRidePreparation.GearCheck(
                gear: nutrition,
                isReady: true,
                issue: nil,
                priority: .critical
            ))
        }
        
        return checks
    }
    
    private static func checkLongRideGear(_ allGear: [GearItem]) -> [PreRidePreparation.GearCheck] {
        var checks: [PreRidePreparation.GearCheck] = []
        
        // Spare kit
        if let spareKit = allGear.first(where: { $0.gearType == .spareKit && !$0.isRetired }) {
            checks.append(PreRidePreparation.GearCheck(
                gear: spareKit,
                isReady: true,
                issue: nil,
                priority: .important
            ))
        }
        
        // Multi-tool
        if let multiTool = allGear.first(where: { $0.gearType == .multiTool && !$0.isRetired }) {
            checks.append(PreRidePreparation.GearCheck(
                gear: multiTool,
                isReady: true,
                issue: nil,
                priority: .important
            ))
        }
        
        return checks
    }
    
    // MARK: - Bike Checks
    
    static func generateBikeChecks(
        for bike: BikeConfiguration?,
        wheelset: Wheelset?
    ) -> [PreRidePreparation.BikeCheck] {
        var checks: [PreRidePreparation.BikeCheck] = []
        
        guard let bike = bike else {
            checks.append(PreRidePreparation.BikeCheck(
                item: "Select a bike",
                isComplete: false,
                priority: .critical
            ))
            return checks
        }
        
        // Tire pressure
        checks.append(PreRidePreparation.BikeCheck(
            item: "Check tire pressure",
            isComplete: false,
            priority: .critical
        ))
        
        // Chain condition
        if let chain = bike.currentChain {
            let status = MaintenanceService.calculateChainMaintenance(for: chain, speedCount: bike.speedCount ?? 11)
            let needsService = status.health == .replaceSoon || status.health == .replaceNow || status.waxDue
            checks.append(PreRidePreparation.BikeCheck(
                item: needsService ? "Chain needs service" : "Chain condition OK",
                isComplete: !needsService,
                priority: needsService ? .important : .optional
            ))
        }
        
        // Wheelset tires
        if let wheelset = wheelset, wheelset.needsAttention {
            checks.append(PreRidePreparation.BikeCheck(
                item: "Tires need attention - check before riding",
                isComplete: false,
                priority: .important
            ))
        }
        
        // General checks
        checks.append(PreRidePreparation.BikeCheck(
            item: "Check brakes",
            isComplete: false,
            priority: .critical
        ))
        
        checks.append(PreRidePreparation.BikeCheck(
            item: "Check shifting",
            isComplete: false,
            priority: .important
        ))
        
        return checks
    }
    
    // MARK: - Weather Alert
    
    static func generateWeatherAlert(for ride: ScheduledRide) -> String? {
        guard let temp = ride.temperature else { return nil }
        guard let precip = ride.precipitationChance else { return nil }
        
        var alerts: [String] = []
        
        if temp < 5 {
            alerts.append("⚠️ Cold ride - wear extra layers")
        } else if temp > 35 {
            alerts.append("🔥 Hot ride - stay hydrated")
        }
        
        if precip > 0.5 {
            alerts.append("☔️ High chance of rain - bring jacket")
        } else if precip > 0.3 {
            alerts.append("🌧 Possible rain - consider jacket")
        }
        
        return alerts.isEmpty ? nil : alerts.joined(separator: "\n")
    }
    
    // MARK: - Full Preparation
    
    static func prepareForRide(
        _ ride: ScheduledRide,
        bikes: [BikeConfiguration],
        routes: [Route],
        allGear: [GearItem]
    ) -> PreRidePreparation {
        // Recommend bike
        let recommendedBike = recommendBike(for: ride, bikes: bikes)
        let selectedBike = ride.selectedBike ?? recommendedBike
        
        // Recommend route
        let recommendedRoute = recommendRoute(for: ride, routes: routes, bike: selectedBike)
        
        // Default wheelset for selected bike
        let defaultWheelset = selectedBike?.wheelsets.first(where: { $0.isDefault })
        
        // Generate checks
        let gearChecks = generateGearChecks(for: ride, allGear: allGear)
        let bikeChecks = generateBikeChecks(for: selectedBike, wheelset: defaultWheelset)
        
        // Determine required vs optional gear
        let criticalGear = gearChecks.filter { $0.priority == .critical }.map { $0.gear }
        let optionalGear = gearChecks.filter { $0.priority != .critical }.map { $0.gear }
        
        // Weather alert
        let weatherAlert = generateWeatherAlert(for: ride)
        
        return PreRidePreparation(
            ride: ride,
            recommendedBike: recommendedBike,
            recommendedRoute: recommendedRoute,
            requiredGear: criticalGear,
            optionalGear: optionalGear,
            weatherAlert: weatherAlert,
            bikeChecks: bikeChecks,
            gearChecks: gearChecks
        )
    }
}
