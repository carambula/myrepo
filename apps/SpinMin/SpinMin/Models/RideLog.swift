//
//  RideLog.swift
//  SpinMin
//
//  Track rides to update tire mileage
//

import Foundation
import SwiftData

@Model
final class RideLog {
    var id: UUID
    var rideDate: Date
    var distanceKm: Double
    var rideName: String
    var notes: String
    
    // Which bike/wheelset was used
    @Relationship var bikeConfiguration: BikeConfiguration?
    @Relationship var wheelset: Wheelset?
    
    // Ride conditions (affects tire wear)
    var terrainType: String?  // TerrainType
    var weatherConditions: String?
    
    // Strava activity id when imported from Strava (dedupe key)
    var stravaActivityId: String?
    
    init(
        rideDate: Date = Date(),
        distanceKm: Double,
        rideName: String = "",
        notes: String = "",
        bike: BikeConfiguration? = nil,
        wheelset: Wheelset? = nil,
        terrain: TirePressureCalculationService.TerrainType? = nil
    ) {
        self.id = UUID()
        self.rideDate = rideDate
        self.distanceKm = distanceKm
        self.rideName = rideName.isEmpty ? "Ride" : rideName
        self.notes = notes
        self.bikeConfiguration = bike
        self.wheelset = wheelset
        self.terrainType = terrain?.rawValue
        self.weatherConditions = nil
    }
    
    var terrain: TirePressureCalculationService.TerrainType? {
        get {
            guard let raw = terrainType else { return nil }
            return TirePressureCalculationService.TerrainType(rawValue: raw)
        }
        set {
            terrainType = newValue?.rawValue
        }
    }
    
    var displayName: String {
        let km = String(format: "%.1f", distanceKm)
        let date = rideDate.formatted(date: .abbreviated, time: .omitted)
        return "\(rideName)   \(km) km   \(date)"
    }
    
    /// Imported from Strava with unrecognized gear; needs a bike assigned
    var needsBikeAssignment: Bool {
        stravaActivityId != nil && bikeConfiguration == nil
    }
    
    var bikeName: String {
        bikeConfiguration?.name ?? "Unknown Bike"
    }
    
    var wheelsetName: String {
        wheelset?.name ?? "Default Wheelset"
    }
}
