//
//  TirePressureCalculationServiceTests.swift
//  SpinMinTests
//
//  Created by Cloud Agent on 8/10/26.
//

import XCTest
@testable import SpinMin

final class TirePressureCalculationServiceTests: XCTestCase {
    
    // MARK: - Basic Calculation Tests
    
    func testRoadBikeBasicCalculation() {
        // Test a typical road bike setup
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Pressure should be in a reasonable range for road bikes
        XCTAssertGreaterThan(result.frontPressurePSI, 60)
        XCTAssertLessThan(result.frontPressurePSI, 100)
        XCTAssertGreaterThan(result.rearPressurePSI, 60)
        XCTAssertLessThan(result.rearPressurePSI, 100)
        
        // Rear pressure should be higher than front
        XCTAssertGreaterThan(result.rearPressurePSI, result.frontPressurePSI)
    }
    
    func testGravelBikeCalculation() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 75,
            bikeType: .gravel,
            tireWidthMM: 40,
            terrain: .gravel2,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Gravel bike pressures should be lower than road
        XCTAssertGreaterThan(result.frontPressurePSI, 30)
        XCTAssertLessThan(result.frontPressurePSI, 60)
        XCTAssertGreaterThan(result.rearPressurePSI, result.frontPressurePSI)
    }
    
    func testMountainBikeCalculation() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 80,
            bikeType: .mountainTrail,
            tireWidthMM: 2.4 * 25.4, // 2.4 inches in mm
            terrain: .trail,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // MTB pressures should be much lower. Both wheels can clamp to the
        // same safety floor, so rear >= front rather than strictly greater.
        XCTAssertGreaterThanOrEqual(result.frontPressurePSI, 18)
        XCTAssertLessThan(result.frontPressurePSI, 35)
        XCTAssertGreaterThanOrEqual(result.rearPressurePSI, result.frontPressurePSI)
    }
    
    func testFatBikeCalculation() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 85,
            bikeType: .fat,
            tireWidthMM: 4.0 * 25.4, // 4.0 inches in mm
            terrain: .trail,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Fat bike pressures should be very low; 5 psi is the safety floor
        XCTAssertGreaterThanOrEqual(result.frontPressurePSI, 5)
        XCTAssertLessThan(result.frontPressurePSI, 15)
    }
    
    // MARK: - Weight Sensitivity Tests
    
    func testWeightIncreasesPressure() {
        let lightRider = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 55,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        let heavyRider = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 95,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Heavier rider should need more pressure
        XCTAssertGreaterThan(heavyRider.frontPressurePSI, lightRider.frontPressurePSI)
        XCTAssertGreaterThan(heavyRider.rearPressurePSI, lightRider.rearPressurePSI)
    }
    
    // MARK: - Tire Width Sensitivity Tests
    
    func testWiderTiresLowerPressure() {
        let narrowTire = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 23,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        let wideTire = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 32,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Wider tires should need less pressure
        XCTAssertGreaterThan(narrowTire.frontPressurePSI, wideTire.frontPressurePSI)
        XCTAssertGreaterThan(narrowTire.rearPressurePSI, wideTire.rearPressurePSI)
    }
    
    // MARK: - Terrain Adjustment Tests
    
    func testTerrainAffectsPressure() {
        let smoothTerrain = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .gravel,
            tireWidthMM: 40,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        let roughTerrain = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .gravel,
            tireWidthMM: 40,
            terrain: .gravel4,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Rough terrain should recommend lower pressure
        XCTAssertGreaterThan(smoothTerrain.frontPressurePSI, roughTerrain.frontPressurePSI)
        XCTAssertGreaterThan(smoothTerrain.rearPressurePSI, roughTerrain.rearPressurePSI)
    }
    
    // MARK: - Casing Adjustment Tests
    
    func testCasingTypeAffectsPressure() {
        let supple = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .supple,
            ridingStyle: .balanced
        )
        
        let reinforced = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .reinforced,
            ridingStyle: .balanced
        )
        
        // Reinforced casing should need more pressure
        XCTAssertGreaterThan(reinforced.frontPressurePSI, supple.frontPressurePSI)
    }
    
    // MARK: - Riding Style Tests
    
    func testRidingStyleAffectsPressure() {
        let comfort = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .comfort
        )
        
        let performance = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .performance
        )
        
        // Performance style should recommend higher pressure
        XCTAssertGreaterThan(performance.frontPressurePSI, comfort.frontPressurePSI)
    }
    
    // MARK: - Temperature Adjustment Tests
    
    func testTemperatureAffectsPressure() {
        let cold = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced,
            temperatureCelsius: 5
        )
        
        let hot = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced,
            temperatureCelsius: 35
        )
        
        // Hot weather should recommend slightly higher pressure
        XCTAssertGreaterThan(hot.frontPressurePSI, cold.frontPressurePSI)
    }
    
    // MARK: - BAR Conversion Tests
    
    func testPSItoBARConversion() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 70,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            tireCasing: .standard,
            ridingStyle: .balanced
        )
        
        // Test conversion is approximately correct (1 BAR ≈ 14.5 PSI)
        let frontBARtoPSI = result.frontPressureBAR * 14.5038
        let rearBARtoPSI = result.rearPressureBAR * 14.5038
        
        XCTAssertEqual(frontBARtoPSI, result.frontPressurePSI, accuracy: 0.1)
        XCTAssertEqual(rearBARtoPSI, result.rearPressurePSI, accuracy: 0.1)
    }
    
    // MARK: - Safety Range Tests
    
    func testPressureStaysWithinSafeRange() {
        // Test extreme cases to ensure clamping works
        let extremelyLight = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 40,
            bikeType: .road,
            tireWidthMM: 32,
            terrain: .technical,
            tireCasing: .supple,
            ridingStyle: .comfort,
            temperatureCelsius: 0
        )
        
        // Should still be above minimum
        XCTAssertGreaterThanOrEqual(extremelyLight.frontPressurePSI, 45)
        
        let extremelyHeavy = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 150,
            bikeType: .road,
            tireWidthMM: 23,
            terrain: .smooth,
            tireCasing: .reinforced,
            ridingStyle: .performance,
            temperatureCelsius: 40
        )
        
        // Should be capped at maximum
        XCTAssertLessThanOrEqual(extremelyHeavy.rearPressurePSI, 130)
    }
    
    // MARK: - Hookless Rim Safety
    
    func testHooklessCapsPressureAt72_5PSI() {
        // Heavy rider on narrow road tires would exceed 72.5 psi
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 100,
            bikeType: .road,
            tireWidthMM: 25,
            terrain: .smooth,
            ridingStyle: .performance,
            rimType: .hookless
        )
        
        XCTAssertLessThanOrEqual(result.frontPressurePSI, 72.5)
        XCTAssertLessThanOrEqual(result.rearPressurePSI, 72.5)
        XCTAssertTrue(result.warnings.contains { $0.contains("72.5") })
    }
    
    func testHookedRimNotCapped() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 100,
            bikeType: .road,
            tireWidthMM: 25,
            terrain: .smooth,
            ridingStyle: .performance,
            rimType: .hooked
        )
        
        XCTAssertGreaterThan(result.rearPressurePSI, 72.5)
        XCTAssertTrue(result.warnings.isEmpty)
    }
    
    func testHooklessNarrowTireWarning() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 60,
            bikeType: .road,
            tireWidthMM: 25,
            terrain: .smooth,
            rimType: .hookless
        )
        
        XCTAssertTrue(result.warnings.contains { $0.contains("28mm") })
    }
    
    func testHooklessLowPressureSetupHasNoCapWarning() {
        // Wide gravel tires run well under the cap: no warnings expected
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 75,
            bikeType: .gravel,
            tireWidthMM: 45,
            terrain: .gravel2,
            rimType: .hookless
        )
        
        XCTAssertLessThan(result.rearPressurePSI, 72.5)
        XCTAssertFalse(result.warnings.contains { $0.contains("capped") })
    }
    
    // MARK: - Rim Width Compensation
    
    func testWiderRimGrowsEffectiveWidth() {
        // 25mm above the 19mm reference: +2.4mm effective width
        let effective = TirePressureCalculationService.effectiveTireWidth(
            labeledWidthMM: 28,
            internalRimWidthMM: 25
        )
        XCTAssertEqual(effective, 30.4, accuracy: 0.01)
    }
    
    func testNarrowerRimShrinksEffectiveWidth() {
        let effective = TirePressureCalculationService.effectiveTireWidth(
            labeledWidthMM: 28,
            internalRimWidthMM: 17
        )
        XCTAssertEqual(effective, 27.2, accuracy: 0.01)
    }
    
    func testNilRimWidthLeavesLabeledWidth() {
        let effective = TirePressureCalculationService.effectiveTireWidth(
            labeledWidthMM: 28,
            internalRimWidthMM: nil
        )
        XCTAssertEqual(effective, 28)
    }
    
    func testWiderRimLowersRecommendedPressure() {
        let narrow = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 75,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            internalRimWidthMM: 19
        )
        let wide = TirePressureCalculationService.calculatePressure(
            riderWeightKg: 75,
            bikeType: .road,
            tireWidthMM: 28,
            terrain: .smooth,
            internalRimWidthMM: 25
        )
        
        // Same tire on a wider rim measures wider, so it needs less pressure
        XCTAssertLessThan(wide.rearPressurePSI, narrow.rearPressurePSI)
    }
}
