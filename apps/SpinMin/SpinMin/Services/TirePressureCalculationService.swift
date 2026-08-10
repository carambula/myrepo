//
//  TirePressureCalculationService.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation

/// Service for calculating optimal tire pressure for cycling.
/// Based on the 15% tire drop rule and empirical data from various sources.
///
/// References:
/// - Frank Berto's 15% tire drop rule
/// - SILCA professional tire pressure calculator methodology
/// - Wolf Tooth tire pressure calculator approach
public struct TirePressureCalculationService {
    
    // MARK: - Public Types
    
    public enum BikeType: String, CaseIterable, Codable {
        case road = "Road"
        case gravel = "Gravel"
        case mountainXC = "Mountain (XC)"
        case mountainTrail = "Mountain (Trail)"
        case mountainEnduro = "Mountain (Enduro)"
        case fat = "Fat Bike"
        
        /// Recommended weight distribution (front/rear) for this bike type
        var weightDistribution: (front: Double, rear: Double) {
            switch self {
            case .road:
                return (0.48, 0.52)
            case .gravel:
                return (0.47, 0.53)
            case .mountainXC, .mountainTrail, .mountainEnduro:
                return (0.465, 0.535)
            case .fat:
                return (0.47, 0.53)
            }
        }
    }
    
    public enum TerrainType: String, CaseIterable, Codable {
        case smooth = "Smooth (New Pavement)"
        case mixed = "Mixed (Worn Pavement)"
        case rough = "Rough (Poor Pavement/Chipseal)"
        case gravel1 = "Gravel (Category 1)"
        case gravel2 = "Gravel (Category 2)"
        case gravel3 = "Gravel (Category 3)"
        case gravel4 = "Gravel (Category 4)"
        case trail = "Trail (Singletrack)"
        case technical = "Technical (Roots/Rocks)"
        
        /// Base pressure adjustment multiplier for terrain (lower = more compliant)
        var pressureMultiplier: Double {
            switch self {
            case .smooth: return 1.0
            case .mixed: return 0.95
            case .rough: return 0.90
            case .gravel1: return 0.88
            case .gravel2: return 0.85
            case .gravel3: return 0.82
            case .gravel4: return 0.78
            case .trail: return 0.75
            case .technical: return 0.70
            }
        }
    }
    
    public enum TireCasingType: String, CaseIterable, Codable {
        case supple = "Supple/High TPI"
        case standard = "Standard"
        case reinforced = "Reinforced/Heavy Duty"
        
        /// Pressure adjustment for casing type (psi)
        var pressureAdjustment: Double {
            switch self {
            case .supple: return -2.0
            case .standard: return 0.0
            case .reinforced: return 3.0
            }
        }
    }
    
    public enum RidingStyle: String, CaseIterable, Codable {
        case comfort = "Comfort/Recreational"
        case balanced = "Balanced"
        case performance = "Performance/Racing"
        
        /// Pressure adjustment for riding style (psi)
        var pressureAdjustment: Double {
            switch self {
            case .comfort: return -3.0
            case .balanced: return 0.0
            case .performance: return 2.0
            }
        }
    }
    
    public struct PressureResult: Codable, Equatable {
        public let frontPressurePSI: Double
        public let rearPressurePSI: Double
        public let frontPressureBAR: Double
        public let rearPressureBAR: Double
        
        public init(frontPSI: Double, rearPSI: Double) {
            self.frontPressurePSI = frontPSI
            self.rearPressurePSI = rearPSI
            self.frontPressureBAR = frontPSI / 14.5038
            self.rearPressureBAR = rearPSI / 14.5038
        }
    }
    
    // MARK: - Public Methods
    
    /// Calculate optimal tire pressure based on rider and bike parameters.
    ///
    /// - Parameters:
    ///   - riderWeightKg: Rider weight in kilograms
    ///   - bikeWeightKg: Bike weight in kilograms (optional, defaults to typical values)
    ///   - bikeType: Type of bike
    ///   - tireWidthMM: Tire width in millimeters
    ///   - terrain: Terrain type
    ///   - tireCasing: Tire casing type
    ///   - ridingStyle: Riding style preference
    ///   - temperatureCelsius: Ambient temperature (optional, for fine-tuning)
    /// - Returns: Recommended front and rear tire pressures
    public static func calculatePressure(
        riderWeightKg: Double,
        bikeWeightKg: Double? = nil,
        bikeType: BikeType,
        tireWidthMM: Double,
        terrain: TerrainType,
        tireCasing: TireCasingType = .standard,
        ridingStyle: RidingStyle = .balanced,
        temperatureCelsius: Double? = nil
    ) -> PressureResult {
        // Use typical bike weight if not provided
        let actualBikeWeight = bikeWeightKg ?? typicalBikeWeight(for: bikeType)
        let totalWeightKg = riderWeightKg + actualBikeWeight
        let totalWeightLbs = totalWeightKg * 2.20462
        
        // Get weight distribution for bike type
        let distribution = bikeType.weightDistribution
        let frontWeightLbs = totalWeightLbs * distribution.front
        let rearWeightLbs = totalWeightLbs * distribution.rear
        
        // Calculate base pressure using empirical formula
        // This is based on the 15% tire drop rule and tire contact patch physics
        let baseFrontPressure = calculateBasePressure(
            weightLbs: frontWeightLbs,
            tireWidthMM: tireWidthMM,
            bikeType: bikeType
        )
        let baseRearPressure = calculateBasePressure(
            weightLbs: rearWeightLbs,
            tireWidthMM: tireWidthMM,
            bikeType: bikeType
        )
        
        // Apply terrain multiplier
        var frontPressure = baseFrontPressure * terrain.pressureMultiplier
        var rearPressure = baseRearPressure * terrain.pressureMultiplier
        
        // Apply casing adjustment
        frontPressure += tireCasing.pressureAdjustment
        rearPressure += tireCasing.pressureAdjustment
        
        // Apply riding style adjustment
        frontPressure += ridingStyle.pressureAdjustment
        rearPressure += ridingStyle.pressureAdjustment
        
        // Apply temperature adjustment if provided
        if let temp = temperatureCelsius {
            let tempAdjustment = temperatureAdjustment(celsius: temp)
            frontPressure += tempAdjustment
            rearPressure += tempAdjustment
        }
        
        // Ensure pressures are within safe ranges
        frontPressure = clampPressure(frontPressure, tireWidthMM: tireWidthMM, bikeType: bikeType)
        rearPressure = clampPressure(rearPressure, tireWidthMM: tireWidthMM, bikeType: bikeType)
        
        // Round to nearest 0.5 psi for practical use
        frontPressure = round(frontPressure * 2) / 2
        rearPressure = round(rearPressure * 2) / 2
        
        return PressureResult(frontPSI: frontPressure, rearPSI: rearPressure)
    }
    
    // MARK: - Private Helper Methods
    
    private static func typicalBikeWeight(for bikeType: BikeType) -> Double {
        switch bikeType {
        case .road: return 8.0 // kg
        case .gravel: return 9.5
        case .mountainXC: return 12.0
        case .mountainTrail: return 13.5
        case .mountainEnduro: return 15.0
        case .fat: return 16.0
        }
    }
    
    private static func calculateBasePressure(
        weightLbs: Double,
        tireWidthMM: Double,
        bikeType: BikeType
    ) -> Double {
        // Base formula derived from empirical data
        // Pressure ≈ (Weight / Contact Patch Area) with adjustments for tire volume
        
        let tireWidthInches = tireWidthMM / 25.4
        
        // Base pressure increases with weight and decreases with tire width
        // Different bike types have different optimal pressure ranges
        let baseMultiplier: Double
        switch bikeType {
        case .road:
            baseMultiplier = 0.95
        case .gravel:
            baseMultiplier = 0.85
        case .mountainXC:
            baseMultiplier = 0.75
        case .mountainTrail:
            baseMultiplier = 0.65
        case .mountainEnduro:
            baseMultiplier = 0.55
        case .fat:
            baseMultiplier = 0.35
        }
        
        // Empirical formula: pressure scales with weight and inversely with tire volume
        let basePressure = (weightLbs * baseMultiplier) / pow(tireWidthInches, 1.5)
        
        return basePressure
    }
    
    private static func temperatureAdjustment(celsius: Double) -> Double {
        // Adjust pressure based on temperature
        // Cold temps: reduce pressure slightly for better grip
        // Hot temps: increase pressure slightly as air expands
        let baseTemp = 20.0 // 20°C reference
        let tempDiff = celsius - baseTemp
        return tempDiff * 0.15 // ~0.15 psi per degree C
    }
    
    private static func clampPressure(
        _ pressure: Double,
        tireWidthMM: Double,
        bikeType: BikeType
    ) -> Double {
        // Define safe pressure ranges based on bike type and tire width
        let (minPressure, maxPressure): (Double, Double)
        
        switch bikeType {
        case .road:
            if tireWidthMM < 25 {
                (minPressure, maxPressure) = (80, 130)
            } else if tireWidthMM < 32 {
                (minPressure, maxPressure) = (60, 100)
            } else {
                (minPressure, maxPressure) = (45, 85)
            }
        case .gravel:
            if tireWidthMM < 35 {
                (minPressure, maxPressure) = (40, 70)
            } else if tireWidthMM < 45 {
                (minPressure, maxPressure) = (30, 55)
            } else {
                (minPressure, maxPressure) = (20, 45)
            }
        case .mountainXC:
            (minPressure, maxPressure) = (22, 35)
        case .mountainTrail:
            (minPressure, maxPressure) = (20, 32)
        case .mountainEnduro:
            (minPressure, maxPressure) = (18, 30)
        case .fat:
            (minPressure, maxPressure) = (5, 15)
        }
        
        return max(minPressure, min(maxPressure, pressure))
    }
}
