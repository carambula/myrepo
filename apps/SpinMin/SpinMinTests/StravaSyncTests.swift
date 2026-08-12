//
//  StravaSyncTests.swift
//  SpinMinTests
//
//  Tests for Strava bike matching and activity import
//

import XCTest
import SwiftData
@testable import SpinMin

final class StravaSyncTests: XCTestCase {
    
    // MARK: - Helpers
    
    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: BikeConfiguration.self, Wheelset.self, RideLog.self,
            ScheduledRide.self, TireTracking.self, ComponentTracking.self,
            configurations: config
        )
        return container.mainContext
    }
    
    private func makeBike(name: String) -> BikeConfiguration {
        BikeConfiguration(name: name, bikeType: .road, tireWidthMM: 28)
    }
    
    private func makeActivity(
        id: Int64,
        name: String = "Morning Ride",
        distanceMeters: Double = 40000,
        gearId: String? = nil,
        sportType: String = "Ride",
        startDate: Date = Date()
    ) -> StravaActivity {
        StravaActivity(
            id: id,
            name: name,
            distance: distanceMeters,
            movingTime: 5400,
            elapsedTime: 6000,
            startDate: startDate,
            sportType: sportType,
            gearId: gearId,
            totalElevationGain: 500
        )
    }
    
    // MARK: - Name Similarity
    
    func testExactNameMatch() {
        XCTAssertEqual(StravaSyncService.nameSimilarity("Canyon Ultimate", "Canyon Ultimate"), 1.0)
    }
    
    func testNicknameContainedInFullName() {
        // Short local name fully contained in the Strava name scores 1.0
        let score = StravaSyncService.nameSimilarity("Canyon Ultimate CF SL", "Ultimate")
        XCTAssertEqual(score, 1.0)
    }
    
    func testCaseAndPunctuationInsensitive() {
        let score = StravaSyncService.nameSimilarity("TREK Émonda-SLR", "trek emonda slr")
        XCTAssertGreaterThanOrEqual(score, 0.5)
    }
    
    func testUnrelatedNamesScoreZero() {
        XCTAssertEqual(StravaSyncService.nameSimilarity("Canyon Ultimate", "Santa Cruz Hightower"), 0)
    }
    
    // MARK: - Auto Matching
    
    func testAutoMatchAssignsGearId() {
        let local = makeBike(name: "Ultimate")
        let strava = StravaGear(id: "b111", name: "Canyon Ultimate CF SL", primary: true, distance: nil)
        
        StravaSyncService.autoMatchBikes(stravaBikes: [strava], localBikes: [local])
        
        XCTAssertEqual(local.stravaGearId, "b111")
    }
    
    func testAutoMatchSkipsAmbiguousCandidates() {
        // Two local bikes tie on similarity; neither should be auto-linked
        let bike1 = makeBike(name: "Canyon Road")
        let bike2 = makeBike(name: "Canyon Gravel")
        let strava = StravaGear(id: "b222", name: "Canyon", primary: nil, distance: nil)
        
        StravaSyncService.autoMatchBikes(stravaBikes: [strava], localBikes: [bike1, bike2])
        
        XCTAssertNil(bike1.stravaGearId)
        XCTAssertNil(bike2.stravaGearId)
    }
    
    func testAutoMatchRespectsExistingLinks() {
        let bike1 = makeBike(name: "Ultimate")
        bike1.stravaGearId = "b999"  // manually linked already
        let strava = StravaGear(id: "b111", name: "Ultimate", primary: nil, distance: nil)
        
        StravaSyncService.autoMatchBikes(stravaBikes: [strava], localBikes: [bike1])
        
        XCTAssertEqual(bike1.stravaGearId, "b999")
    }
    
    // MARK: - Activity Import
    
    @MainActor
    func testImportCreatesRideLogAndUpdatesOdometer() throws {
        let context = try makeContext()
        let bike = makeBike(name: "Road Bike")
        bike.stravaGearId = "b1"
        context.insert(bike)
        
        let result = try StravaSyncService.importActivities(
            [makeActivity(id: 100, distanceMeters: 40000, gearId: "b1")],
            context: context
        )
        
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.unassigned, 0)
        XCTAssertEqual(bike.totalMileageKm, 40, accuracy: 0.01)
        
        let rides = try context.fetch(FetchDescriptor<RideLog>())
        XCTAssertEqual(rides.count, 1)
        XCTAssertEqual(rides[0].stravaActivityId, "100")
        XCTAssertEqual(rides[0].bikeConfiguration?.id, bike.id)
    }
    
    @MainActor
    func testImportDedupesByActivityId() throws {
        let context = try makeContext()
        let bike = makeBike(name: "Road Bike")
        bike.stravaGearId = "b1"
        context.insert(bike)
        
        let activity = makeActivity(id: 100, gearId: "b1")
        _ = try StravaSyncService.importActivities([activity], context: context)
        let second = try StravaSyncService.importActivities([activity], context: context)
        
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.skipped, 1)
        
        let rides = try context.fetch(FetchDescriptor<RideLog>())
        XCTAssertEqual(rides.count, 1)
        // Odometer only counted once
        XCTAssertEqual(bike.totalMileageKm, 40, accuracy: 0.01)
    }
    
    @MainActor
    func testUnknownGearImportsUnassignedWithoutOdometerUpdate() throws {
        let context = try makeContext()
        let bike = makeBike(name: "Road Bike")
        context.insert(bike)
        
        let result = try StravaSyncService.importActivities(
            [makeActivity(id: 101, gearId: "b-unknown")],
            context: context
        )
        
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.unassigned, 1)
        XCTAssertEqual(bike.totalMileageKm, 0)
        
        let rides = try context.fetch(FetchDescriptor<RideLog>())
        XCTAssertTrue(rides[0].needsBikeAssignment)
    }
    
    @MainActor
    func testAssignBikeAppliesDeferredMileage() throws {
        let context = try makeContext()
        let bike = makeBike(name: "Road Bike")
        context.insert(bike)
        
        _ = try StravaSyncService.importActivities(
            [makeActivity(id: 102, distanceMeters: 25000)],
            context: context
        )
        let ride = try context.fetch(FetchDescriptor<RideLog>())[0]
        
        RideLogger.assignBike(ride, to: bike)
        
        XCTAssertEqual(bike.totalMileageKm, 25, accuracy: 0.01)
        XCTAssertFalse(ride.needsBikeAssignment)
        
        // Assigning twice must not double-count
        RideLogger.assignBike(ride, to: bike)
        XCTAssertEqual(bike.totalMileageKm, 25, accuracy: 0.01)
    }
    
    @MainActor
    func testNonCyclingActivitiesAreIgnored() throws {
        let context = try makeContext()
        
        let result = try StravaSyncService.importActivities(
            [makeActivity(id: 103, sportType: "Run")],
            context: context
        )
        
        XCTAssertEqual(result.imported, 0)
        let rides = try context.fetch(FetchDescriptor<RideLog>())
        XCTAssertTrue(rides.isEmpty)
    }
    
    @MainActor
    func testSameDayScheduledRideAutoCompletes() throws {
        let context = try makeContext()
        let scheduled = ScheduledRide(
            name: "Threshold intervals",
            scheduledDate: Date(),
            duration: 3600,
            rideType: .threshold
        )
        context.insert(scheduled)
        
        let result = try StravaSyncService.importActivities(
            [makeActivity(id: 104, distanceMeters: 40000)],
            context: context
        )
        
        XCTAssertEqual(result.completedScheduledRides, 1)
        XCTAssertTrue(scheduled.isCompleted)
        XCTAssertEqual(scheduled.actualDistance ?? 0, 40, accuracy: 0.01)
        XCTAssertEqual(scheduled.actualDuration ?? 0, 5400, accuracy: 1)
    }
    
    @MainActor
    func testScheduledRideOnDifferentDayNotCompleted() throws {
        let context = try makeContext()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let scheduled = ScheduledRide(
            name: "Tomorrow's ride",
            scheduledDate: tomorrow,
            duration: 3600,
            rideType: .endurance
        )
        context.insert(scheduled)
        
        _ = try StravaSyncService.importActivities(
            [makeActivity(id: 105)],
            context: context
        )
        
        XCTAssertFalse(scheduled.isCompleted)
    }
}
