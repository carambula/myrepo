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
}
