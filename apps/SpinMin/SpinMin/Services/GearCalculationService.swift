//
//  GearCalculationService.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import Foundation

/// Service for calculating gear ratios, speeds, climbing ability, and gearing analysis.
public struct GearCalculationService {
    
    // MARK: - Public Types
    
    public struct GearRatio: Identifiable, Equatable {
        public let id = UUID()
        public let chainring: Int
        public let cog: Int
        public let ratio: Double
        public let gearInches: Double
        public let development: Double  // meters per crank revolution
        public let speedAt90RPM: Double  // km/h
        
        public init(chainring: Int, cog: Int, wheelCircumferenceMM: Double) {
            self.chainring = chainring
            self.cog = cog
            self.ratio = Double(chainring) / Double(cog)
            
            // Gear inches = (chainring / cog) × wheel diameter in inches
            let wheelDiameterInches = wheelCircumferenceMM / (Double.pi * 25.4)
            self.gearInches = self.ratio * wheelDiameterInches
            
            // Development = (chainring / cog) × wheel circumference in meters
            self.development = self.ratio * (wheelCircumferenceMM / 1000.0)
            
            // Speed at 90 RPM in km/h
            let metersPerMinute = self.development * 90
            self.speedAt90RPM = (metersPerMinute * 60) / 1000
        }
    }
    
    public struct GearingAnalysis {
        public let gearRatios: [GearRatio]
        public let lowestRatio: GearRatio
        public let highestRatio: GearRatio
        public let gearRange: Double  // percentage
        public let averageGapPercentage: Double
        public let largestGapPercentage: Double
        public let largestGapBetween: (GearRatio, GearRatio)?
        public let wheelCircumferenceMM: Double
        
        public var speedRangeAt90RPM: (min: Double, max: Double) {
            (lowestRatio.speedAt90RPM, highestRatio.speedAt90RPM)
        }
        
        public var gearInchesRange: (min: Double, max: Double) {
            (lowestRatio.gearInches, highestRatio.gearInches)
        }
    }
    
    public struct SpeedAtCadence {
        public let cadenceRPM: Int
        public let speedKPH: Double
        public let speedMPH: Double
        
        public init(cadenceRPM: Int, speedKPH: Double) {
            self.cadenceRPM = cadenceRPM
            self.speedKPH = speedKPH
            self.speedMPH = speedKPH * 0.621371
        }
    }
    
    public struct ClimbingAnalysis {
        public let gear: GearRatio
        public let maxGradePercent: Double  // At 60 RPM with given rider/bike weight
        public let speedAt60RPM: Double     // km/h
        public let description: String
        
        public init(gear: GearRatio, riderWeightKg: Double, bikeWeightKg: Double) {
            self.gear = gear
            
            // Simplified climbing model
            // Lower gear inches = steeper climbs possible
            // This is a rough approximation based on power-to-weight and gear ratio
            let totalWeightKg = riderWeightKg + bikeWeightKg
            let powerEstimate = 200.0 // Watts (conservative estimate)
            let speedMetersPerSecond = (gear.development * 60.0) / 60.0  // at 60 RPM
            
            // Grade % ≈ (Power / (Weight × g × Speed)) × 100
            // Simplified: lower gear = steeper grade possible
            let baseGrade = (powerEstimate / (totalWeightKg * 9.81 * speedMetersPerSecond)) * 100
            self.maxGradePercent = min(baseGrade, 35.0)  // Cap at 35%
            
            self.speedAt60RPM = gear.speedAt90RPM * (60.0 / 90.0)
            
            if gear.gearInches < 20 {
                self.description = "Ultra-low gear for steep loaded climbing"
            } else if gear.gearInches < 25 {
                self.description = "Very low gear for steep climbs"
            } else if gear.gearInches < 30 {
                self.description = "Low gear for moderate climbs"
            } else if gear.gearInches < 40 {
                self.description = "Climbing gear for rolling terrain"
            } else {
                self.description = "Not suitable for steep climbing"
            }
        }
    }
    
    public struct GearGap {
        public let fromGear: GearRatio
        public let toGear: GearRatio
        public let percentageJump: Double
        public let isLarge: Bool  // > 18% is considered large
        
        public init(from: GearRatio, to: GearRatio) {
            self.fromGear = from
            self.toGear = to
            self.percentageJump = ((to.ratio - from.ratio) / from.ratio) * 100
            self.isLarge = abs(percentageJump) > 18
        }
    }
    
    // MARK: - Public Methods
    
    /// Calculate all gear ratios for a given drivetrain configuration
    public static func calculateGearRatios(
        chainrings: [Int],
        cassette: [Int],
        wheelDiameterMM: Double,
        tireWidthMM: Int
    ) -> GearingAnalysis {
        let wheelCircumference = calculateWheelCircumference(
            diameterMM: wheelDiameterMM,
            tireWidthMM: tireWidthMM
        )
        
        var allRatios: [GearRatio] = []
        
        for chainring in chainrings.sorted(by: >) {
            for cog in cassette.sorted() {
                let ratio = GearRatio(
                    chainring: chainring,
                    cog: cog,
                    wheelCircumferenceMM: wheelCircumference
                )
                allRatios.append(ratio)
            }
        }
        
        // Sort by gear inches (ascending)
        allRatios.sort { $0.gearInches < $1.gearInches }
        
        guard let lowest = allRatios.first,
              let highest = allRatios.last else {
            fatalError("No gear ratios calculated")
        }
        
        // Calculate gear range percentage
        let gearRange = ((highest.ratio / lowest.ratio) - 1.0) * 100
        
        // Calculate average and largest gaps
        var gaps: [Double] = []
        var largestGap: (Double, GearRatio, GearRatio)? = nil
        
        for i in 0..<(allRatios.count - 1) {
            let current = allRatios[i]
            let next = allRatios[i + 1]
            let gapPercent = ((next.ratio - current.ratio) / current.ratio) * 100
            gaps.append(gapPercent)
            
            if largestGap == nil || gapPercent > largestGap!.0 {
                largestGap = (gapPercent, current, next)
            }
        }
        
        let averageGap = gaps.isEmpty ? 0 : gaps.reduce(0, +) / Double(gaps.count)
        
        return GearingAnalysis(
            gearRatios: allRatios,
            lowestRatio: lowest,
            highestRatio: highest,
            gearRange: gearRange,
            averageGapPercentage: averageGap,
            largestGapPercentage: largestGap?.0 ?? 0,
            largestGapBetween: largestGap.map { ($0.1, $0.2) },
            wheelCircumferenceMM: wheelCircumference
        )
    }
    
    /// Calculate speed at various cadences for a specific gear
    public static func calculateSpeedAtCadences(
        gear: GearRatio,
        cadences: [Int] = [60, 70, 80, 90, 100, 110]
    ) -> [SpeedAtCadence] {
        return cadences.map { cadence in
            let speedKPH = (gear.development * Double(cadence) * 60) / 1000
            return SpeedAtCadence(cadenceRPM: cadence, speedKPH: speedKPH)
        }
    }
    
    /// Analyze climbing ability with the lowest gear
    public static func analyzeClimbing(
        analysis: GearingAnalysis,
        riderWeightKg: Double,
        bikeWeightKg: Double
    ) -> ClimbingAnalysis {
        return ClimbingAnalysis(
            gear: analysis.lowestRatio,
            riderWeightKg: riderWeightKg,
            bikeWeightKg: bikeWeightKg
        )
    }
    
    /// Calculate all gaps between gears
    public static func calculateGearGaps(analysis: GearingAnalysis) -> [GearGap] {
        var gaps: [GearGap] = []
        let ratios = analysis.gearRatios
        
        for i in 0..<(ratios.count - 1) {
            let gap = GearGap(from: ratios[i], to: ratios[i + 1])
            gaps.append(gap)
        }
        
        return gaps
    }
    
    /// Get recommended gearing for different disciplines
    public static func recommendedGearing(for discipline: BikeCategory) -> String {
        switch discipline {
        case .road:
            return """
            Racing: 52/36 × 11-30 (or 50/34 × 11-34 for climbing)
            Endurance: 50/34 × 11-34
            Hilly: 48/32 × 11-36
            """
        case .gravel:
            return """
            Fast/Racing: 42-44t × 10-44
            All-Around: 40-42t × 10-50
            Loaded/Bikepacking: 38-40t × 11-50 or 30/46 × 11-36
            """
        case .mtb:
            return """
            XC Racing: 32t × 10-51
            Trail: 30-32t × 10-52
            Enduro: 30-32t × 10-52 (heavy duty)
            """
        }
    }
    
    /// Compare two drivetrain setups
    public static func compare(
        _ setup1: GearingAnalysis,
        _ setup2: GearingAnalysis,
        setup1Name: String = "Setup 1",
        setup2Name: String = "Setup 2"
    ) -> String {
        let range1 = setup1.gearRange
        let range2 = setup2.gearRange
        let rangeDiff = range2 - range1
        
        let low1 = setup1.lowestRatio.gearInches
        let low2 = setup2.lowestRatio.gearInches
        let lowDiff = ((low2 - low1) / low1) * 100
        
        let high1 = setup1.highestRatio.gearInches
        let high2 = setup2.highestRatio.gearInches
        let highDiff = ((high2 - high1) / high1) * 100
        
        return """
        \(setup2Name) vs \(setup1Name):
        • Range: \(rangeDiff > 0 ? "+" : "")\(String(format: "%.1f", rangeDiff))% total range
        • Low gear: \(lowDiff > 0 ? "harder" : "easier") by \(String(format: "%.1f", abs(lowDiff)))%
        • High gear: \(highDiff > 0 ? "harder" : "easier") by \(String(format: "%.1f", abs(highDiff)))%
        """
    }
    
    // MARK: - Private Helper Methods
    
    private static func calculateWheelCircumference(diameterMM: Double, tireWidthMM: Int) -> Double {
        // Approximate: circumference = π × (BSD + 2 × tire height)
        // Tire height ≈ tire width × 0.6 (approximate)
        let tireHeightMM = Double(tireWidthMM) * 0.6
        let effectiveDiameterMM = diameterMM + (2 * tireHeightMM)
        return Double.pi * effectiveDiameterMM
    }
}
