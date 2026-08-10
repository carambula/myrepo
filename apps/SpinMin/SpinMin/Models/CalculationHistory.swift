//
//  CalculationHistory.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation
import SwiftData

@Model
final class CalculationHistory {
    var id: UUID
    var timestamp: Date
    var riderWeightKg: Double
    var bikeConfigurationID: UUID?
    var bikeConfigurationName: String?
    var bikeType: TirePressureCalculationService.BikeType
    var tireWidthMM: Double
    var terrainRawValue: String
    var casingRawValue: String
    var ridingStyleRawValue: String
    var temperatureCelsius: Double?
    var frontPressurePSI: Double
    var rearPressurePSI: Double
    
    init(
        riderWeightKg: Double,
        bikeConfiguration: BikeConfiguration?,
        terrain: TirePressureCalculationService.TerrainType,
        casing: TirePressureCalculationService.TireCasingType,
        ridingStyle: TirePressureCalculationService.RidingStyle,
        temperatureCelsius: Double?,
        result: TirePressureCalculationService.PressureResult
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.riderWeightKg = riderWeightKg
        self.bikeConfigurationID = bikeConfiguration?.id
        self.bikeConfigurationName = bikeConfiguration?.name
        self.bikeType = bikeConfiguration?.bikeType ?? .road
        self.tireWidthMM = bikeConfiguration?.tireWidthMM ?? 28
        self.terrainRawValue = terrain.rawValue
        self.casingRawValue = casing.rawValue
        self.ridingStyleRawValue = ridingStyle.rawValue
        self.temperatureCelsius = temperatureCelsius
        self.frontPressurePSI = result.frontPressurePSI
        self.rearPressurePSI = result.rearPressurePSI
    }
    
    var terrain: TirePressureCalculationService.TerrainType {
        TirePressureCalculationService.TerrainType(rawValue: terrainRawValue) ?? .mixed
    }
    
    var casing: TirePressureCalculationService.TireCasingType {
        TirePressureCalculationService.TireCasingType(rawValue: casingRawValue) ?? .standard
    }
    
    var ridingStyle: TirePressureCalculationService.RidingStyle {
        TirePressureCalculationService.RidingStyle(rawValue: ridingStyleRawValue) ?? .balanced
    }
}
