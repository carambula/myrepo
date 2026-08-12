//
//  BikeConfiguration.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation
import SwiftData

@Model
final class BikeConfiguration {
    var id: UUID
    var name: String
    var bikeType: TirePressureCalculationService.BikeType
    var tireWidthMM: Double
    var bikeWeightKg: Double?
    var notes: String
    var lastUsed: Date
    var createdAt: Date
    
    // Odometer tracking
    var totalMileageKm: Double  // Total distance on this bike
    
    // Default settings for this bike
    var defaultTerrainRawValue: String?
    var defaultCasingRawValue: String?
    var defaultRidingStyleRawValue: String?
    
    // Gearing (optional)
    var drivetrainTypeRawValue: String?
    var smallChainring: Int?
    var largeChainring: Int?
    var cassetteTeeth: [Int]?
    var wheelDiameterRawValue: String?
    var popularDrivetrainID: String?
    
    // Drivetrain speed count (for chain wear limits)
    var speedCount: Int?  // 11, 12, etc. Defaults to 11
    
    // Strava gear id (e.g. "b1234567") linking this bike to a Strava bike
    var stravaGearId: String?
    
    // Relationships
    @Relationship(deleteRule: .cascade) var wheelsets: [Wheelset] = []
    @Relationship(deleteRule: .cascade) var maintenanceRecords: [MaintenanceRecord] = []
    @Relationship(deleteRule: .cascade) var componentTracking: [ComponentTracking] = []
    
    init(
        name: String,
        bikeType: TirePressureCalculationService.BikeType,
        tireWidthMM: Double,
        bikeWeightKg: Double? = nil,
        notes: String = "",
        defaultTerrain: TirePressureCalculationService.TerrainType? = nil,
        defaultCasing: TirePressureCalculationService.TireCasingType? = nil,
        defaultRidingStyle: TirePressureCalculationService.RidingStyle? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.bikeType = bikeType
        self.tireWidthMM = tireWidthMM
        self.bikeWeightKg = bikeWeightKg
        self.notes = notes
        self.lastUsed = Date()
        self.createdAt = Date()
        self.totalMileageKm = 0
        self.speedCount = 11  // Default to 11-speed
        self.defaultTerrainRawValue = defaultTerrain?.rawValue
        self.defaultCasingRawValue = defaultCasing?.rawValue
        self.defaultRidingStyleRawValue = defaultRidingStyle?.rawValue
    }
    
    var defaultTerrain: TirePressureCalculationService.TerrainType? {
        get {
            guard let raw = defaultTerrainRawValue else { return nil }
            return TirePressureCalculationService.TerrainType(rawValue: raw)
        }
        set {
            defaultTerrainRawValue = newValue?.rawValue
        }
    }
    
    var defaultCasing: TirePressureCalculationService.TireCasingType? {
        get {
            guard let raw = defaultCasingRawValue else { return nil }
            return TirePressureCalculationService.TireCasingType(rawValue: raw)
        }
        set {
            defaultCasingRawValue = newValue?.rawValue
        }
    }
    
    var defaultRidingStyle: TirePressureCalculationService.RidingStyle? {
        get {
            guard let raw = defaultRidingStyleRawValue else { return nil }
            return TirePressureCalculationService.RidingStyle(rawValue: raw)
        }
        set {
            defaultRidingStyleRawValue = newValue?.rawValue
        }
    }
    
    var drivetrainType: DrivetrainType? {
        get {
            guard let raw = drivetrainTypeRawValue else { return nil }
            return DrivetrainType(rawValue: raw)
        }
        set {
            drivetrainTypeRawValue = newValue?.rawValue
        }
    }
    
    var wheelDiameter: WheelSize? {
        get {
            guard let raw = wheelDiameterRawValue else { return nil }
            return WheelSize(rawValue: raw)
        }
        set {
            wheelDiameterRawValue = newValue?.rawValue
        }
    }
    
    var hasGearing: Bool {
        return smallChainring != nil && cassetteTeeth != nil && !cassetteTeeth!.isEmpty
    }
    
    // MARK: - Maintenance Helpers
    
    /// Update bike odometer and all associated components
    func logDistance(_ distanceKm: Double) {
        totalMileageKm += distanceKm
        lastUsed = Date()
        
        // Update all components' current odometer
        for component in componentTracking {
            component.updateOdometer(totalMileageKm)
        }
    }
    
    /// Get current chain component if tracked
    var currentChain: ComponentTracking? {
        componentTracking.first { $0.component == .chain }
    }
    
    /// Check if any components need attention
    var maintenanceDue: Bool {
        let summary = MaintenanceService.calculateBikeMaintenance(
            components: componentTracking,
            speedCount: speedCount ?? 11
        )
        return summary.needsAttention
    }
    
    /// Get maintenance summary
    func getMaintenanceSummary() -> MaintenanceService.BikeMaintenanceSummary {
        MaintenanceService.calculateBikeMaintenance(
            components: componentTracking,
            speedCount: speedCount ?? 11
        )
    }
}
