//
//  TrainingCalendarSyncTests.swift
//  SpinMinTests
//
//  Tests for ICS calendar feed parsing and workout import logic
//

import XCTest
import SwiftData
@testable import SpinMin

final class TrainingCalendarSyncTests: XCTestCase {
    
    // MARK: - Sample Feed
    
    /// Realistic TrainingPeaks-style feed exercising UTC dates, all-day
    /// events, TZID dates, DURATION, line folding, and text escaping.
    private let sampleFeed = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//TrainingPeaks//EN",
        "BEGIN:VEVENT",
        "UID:tp-workout-98765@trainingpeaks.com",
        "DTSTART:20260812T070000Z",
        "DTEND:20260812T083000Z",
        "SUMMARY:Bike - Threshold 2x20",
        "DESCRIPTION:Warm up 15min\\, then 2x20min at FTP with 5min recovery. Targ",
        " et 60km total. Cool down easy.",
        "END:VEVENT",
        "BEGIN:VEVENT",
        "UID:tp-workout-98766@trainingpeaks.com",
        "DTSTART;VALUE=DATE:20260815",
        "SUMMARY:Long Ride - Century prep",
        "DESCRIPTION:Steady Z2\\; aim for 80 miles.",
        "END:VEVENT",
        "BEGIN:VEVENT",
        "UID:tp-workout-98767@trainingpeaks.com",
        "DTSTART;TZID=America/New_York:20260816T090000",
        "DURATION:PT1H15M",
        "SUMMARY:Recovery spin",
        "END:VEVENT",
        "END:VCALENDAR",
    ].joined(separator: "\r\n")
    
    // MARK: - Parsing
    
    func testParsesAllEvents() {
        let events = TrainingCalendarSyncService.parseICS(sampleFeed)
        XCTAssertEqual(events.count, 3)
    }
    
    func testUTCDateAndDuration() {
        let events = TrainingCalendarSyncService.parseICS(sampleFeed)
        let event = events[0]
        
        XCTAssertEqual(event.uid, "tp-workout-98765@trainingpeaks.com")
        XCTAssertEqual(event.summary, "Bike - Threshold 2x20")
        XCTAssertEqual(event.duration, 5400, accuracy: 1)
        
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let components = utc.dateComponents([.year, .month, .day, .hour], from: event.start)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 12)
        XCTAssertEqual(components.hour, 7)
    }
    
    func testLineUnfoldingAndEscaping() {
        let events = TrainingCalendarSyncService.parseICS(sampleFeed)
        
        // Folded line rejoined mid-word
        XCTAssertTrue(events[0].eventDescription.contains("Target 60km total"))
        // Escaped comma restored
        XCTAssertTrue(events[0].eventDescription.contains("Warm up 15min,"))
        // Escaped semicolon restored
        XCTAssertEqual(events[1].eventDescription, "Steady Z2; aim for 80 miles.")
    }
    
    func testAllDayEventDefaultsToMorning() {
        let events = TrainingCalendarSyncService.parseICS(sampleFeed)
        let event = events[1]
        
        XCTAssertTrue(event.isAllDay)
        XCTAssertEqual(Calendar.current.component(.hour, from: event.start), 8)
    }
    
    func testDurationProperty() {
        let events = TrainingCalendarSyncService.parseICS(sampleFeed)
        XCTAssertEqual(events[2].duration, 4500, accuracy: 1)
    }
    
    func testICSDurationParsing() {
        XCTAssertEqual(TrainingCalendarSyncService.parseICSDuration("PT1H30M"), 5400)
        XCTAssertEqual(TrainingCalendarSyncService.parseICSDuration("P1DT2H"), 93600)
        XCTAssertEqual(TrainingCalendarSyncService.parseICSDuration("PT45M"), 2700)
        XCTAssertNil(TrainingCalendarSyncService.parseICSDuration("PTXYZ"))
    }
    
    // MARK: - Ride Type Inference
    
    func testTitleTakesPrecedenceOverDescription() {
        // Description mentions "recovery" in passing; title says threshold
        let type = TrainingCalendarSyncService.inferRideType(
            title: "Bike - Threshold 2x20",
            description: "2x20min at FTP with 5min recovery between."
        )
        XCTAssertEqual(type, .threshold)
    }
    
    func testRideTypeKeywords() {
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "Tuesday Night Crit Race", description: ""), .race)
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "Recovery spin", description: ""), .recovery)
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "VO2max 5x3", description: ""), .vo2max)
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "Sweet Spot Base", description: ""), .threshold)
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "Long Ride - Century prep", description: ""), .longRide)
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "Saturday shop ride", description: ""), .groupRide)
        XCTAssertEqual(TrainingCalendarSyncService.inferRideType(title: "Bike workout", description: ""), .training)
    }
    
    // MARK: - Distance Inference
    
    func testDistanceExtraction() {
        XCTAssertEqual(TrainingCalendarSyncService.inferDistance(from: "Target 60km total")!, 60, accuracy: 0.01)
        XCTAssertEqual(TrainingCalendarSyncService.inferDistance(from: "aim for 80 miles")!, 128.75, accuracy: 0.01)
        XCTAssertEqual(TrainingCalendarSyncService.inferDistance(from: "40 mi easy")!, 64.37, accuracy: 0.01)
        XCTAssertNil(TrainingCalendarSyncService.inferDistance(from: "no distance here"))
    }
    
    func testDistanceDoesNotMatchMinutes() {
        // "15min" must not parse as "15 mi"
        XCTAssertNil(TrainingCalendarSyncService.inferDistance(from: "Warm up 15min then go"))
    }
    
    // MARK: - Merge Logic
    
    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ScheduledRide.self, Route.self, BikeConfiguration.self,
            configurations: config
        )
        return container.mainContext
    }
    
    @MainActor
    private func futureEvent(uid: String, daysAhead: Int, summary: String, description: String = "") -> ICSEvent {
        let start = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date())!
        return ICSEvent(
            uid: uid,
            summary: summary,
            eventDescription: description,
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: false
        )
    }
    
    @MainActor
    func testMergeImportsNewEvents() throws {
        let context = try makeContext()
        let events = [
            futureEvent(uid: "a", daysAhead: 1, summary: "Threshold 2x20"),
            futureEvent(uid: "b", daysAhead: 3, summary: "Recovery spin"),
        ]
        
        let result = try TrainingCalendarSyncService.mergeEvents(events, context: context)
        
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.updated, 0)
        
        let rides = try context.fetch(FetchDescriptor<ScheduledRide>())
        XCTAssertEqual(rides.count, 2)
        XCTAssertTrue(rides.allSatisfy { $0.calendarEventId != nil })
    }
    
    @MainActor
    func testMergeIsIdempotent() throws {
        let context = try makeContext()
        let events = [futureEvent(uid: "a", daysAhead: 1, summary: "Threshold 2x20")]
        
        _ = try TrainingCalendarSyncService.mergeEvents(events, context: context)
        let second = try TrainingCalendarSyncService.mergeEvents(events, context: context)
        
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.updated, 0)
        XCTAssertEqual(second.skipped, 1)
        
        let rides = try context.fetch(FetchDescriptor<ScheduledRide>())
        XCTAssertEqual(rides.count, 1)
    }
    
    @MainActor
    func testMergeUpdatesChangedEvents() throws {
        let context = try makeContext()
        _ = try TrainingCalendarSyncService.mergeEvents(
            [futureEvent(uid: "a", daysAhead: 1, summary: "Threshold 2x20")],
            context: context
        )
        
        let result = try TrainingCalendarSyncService.mergeEvents(
            [futureEvent(uid: "a", daysAhead: 2, summary: "Threshold 3x15")],
            context: context
        )
        
        XCTAssertEqual(result.updated, 1)
        let rides = try context.fetch(FetchDescriptor<ScheduledRide>())
        XCTAssertEqual(rides.count, 1)
        XCTAssertEqual(rides[0].name, "Threshold 3x15")
    }
    
    @MainActor
    func testMergeNeverTouchesCompletedRides() throws {
        let context = try makeContext()
        _ = try TrainingCalendarSyncService.mergeEvents(
            [futureEvent(uid: "a", daysAhead: 1, summary: "Threshold 2x20")],
            context: context
        )
        
        let rides = try context.fetch(FetchDescriptor<ScheduledRide>())
        rides[0].isCompleted = true
        try context.save()
        
        let result = try TrainingCalendarSyncService.mergeEvents(
            [futureEvent(uid: "a", daysAhead: 1, summary: "Renamed workout")],
            context: context
        )
        
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(rides[0].name, "Threshold 2x20")
    }
    
    @MainActor
    func testMergeIgnoresPastAndFarFutureEvents() throws {
        let context = try makeContext()
        let events = [
            futureEvent(uid: "past", daysAhead: -2, summary: "Old ride"),
            futureEvent(uid: "far", daysAhead: 90, summary: "Way out"),
            futureEvent(uid: "soon", daysAhead: 5, summary: "In window"),
        ]
        
        let result = try TrainingCalendarSyncService.mergeEvents(events, context: context)
        
        XCTAssertEqual(result.imported, 1)
        let rides = try context.fetch(FetchDescriptor<ScheduledRide>())
        XCTAssertEqual(rides.count, 1)
        XCTAssertEqual(rides[0].name, "In window")
    }
}
