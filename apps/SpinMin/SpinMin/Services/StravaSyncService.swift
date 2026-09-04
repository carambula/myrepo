//
//  StravaSyncService.swift
//  SpinMin
//
//  Imports Strava activities as ride logs, matching Strava bikes to
//  local bike configurations via gear_id so odometers update automatically.
//

import Foundation
import SwiftData

// MARK: - Sync Result

struct StravaSyncResult {
    var imported: Int = 0
    var skipped: Int = 0
    var unassigned: Int = 0
    var completedScheduledRides: Int = 0
    
    var summary: String {
        var parts: [String] = []
        if imported > 0 { parts.append("\(imported) rides imported") }
        if unassigned > 0 { parts.append("\(unassigned) need a bike assigned") }
        if completedScheduledRides > 0 { parts.append("\(completedScheduledRides) scheduled rides completed") }
        if parts.isEmpty { return "Already up to date" }
        return parts.joined(separator: "   ")
    }
}

// MARK: - Sync Service

struct StravaSyncService {
    
    /// How far back the first-ever sync reaches
    static let initialSyncDays = 90
    
    // MARK: Full Sync
    
    /// Fetches the athlete (for bike matching) and new activities, then
    /// merges everything into the local store.
    @MainActor
    static func sync(context: ModelContext) async throws -> StravaSyncResult {
        let auth = StravaAuthService.shared
        let token = try await auth.validAccessToken()
        
        // 1. Refresh bike matching from the athlete's gear list
        let athlete = try await StravaAPI.fetchAthlete(accessToken: token)
        if !athlete.displayName.isEmpty {
            auth.athleteName = athlete.displayName
        }
        let localBikes = try context.fetch(FetchDescriptor<BikeConfiguration>())
        autoMatchBikes(stravaBikes: athlete.bikes ?? [], localBikes: localBikes)
        
        // 2. Fetch activities since the last imported ride
        let after = lastImportedRideDate(context: context)
            ?? Calendar.current.date(byAdding: .day, value: -initialSyncDays, to: Date())
        let activities = try await StravaAPI.fetchActivities(accessToken: token, after: after)
        
        // 3. Merge
        let result = try importActivities(activities, context: context)
        try context.save()
        return result
    }
    
    @MainActor
    private static func lastImportedRideDate(context: ModelContext) -> Date? {
        var descriptor = FetchDescriptor<RideLog>(
            predicate: #Predicate { $0.stravaActivityId != nil },
            sortBy: [SortDescriptor(\.rideDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.rideDate
    }
    
    // MARK: - Bike Matching
    
    /// Links Strava bikes to local bike configurations by gear id. Bikes
    /// without a link get auto-matched by name similarity when the best
    /// match is unambiguous; ambiguous cases are left for the mapping UI.
    static func autoMatchBikes(stravaBikes: [StravaGear], localBikes: [BikeConfiguration]) {
        let unmatchedLocal = localBikes.filter { $0.stravaGearId == nil }
        let claimedGearIds = Set(localBikes.compactMap { $0.stravaGearId })
        
        for stravaBike in stravaBikes where !claimedGearIds.contains(stravaBike.id) {
            let scored = unmatchedLocal
                .filter { $0.stravaGearId == nil }
                .map { (bike: $0, score: nameSimilarity(stravaBike.name, $0.name)) }
                .filter { $0.score >= 0.5 }
                .sorted { $0.score > $1.score }
            
            // Only auto-assign when there is a clear single winner
            guard let best = scored.first,
                  scored.count == 1 || best.score > scored[1].score + 0.001 else {
                continue
            }
            best.bike.stravaGearId = stravaBike.id
        }
    }
    
    /// Token-based similarity between two bike names, 0...1.
    /// "Canyon Ultimate CF SL" vs "Ultimate" scores well because all the
    /// shorter name's tokens appear in the longer one.
    static func nameSimilarity(_ a: String, _ b: String) -> Double {
        let tokensA = tokenize(a)
        let tokensB = tokenize(b)
        guard !tokensA.isEmpty, !tokensB.isEmpty else { return 0 }
        
        if tokensA == tokensB { return 1 }
        
        let intersection = tokensA.intersection(tokensB)
        guard !intersection.isEmpty else { return 0 }
        
        // Containment coefficient: overlap relative to the smaller set,
        // so a short nickname matching part of a full name still scores high
        return Double(intersection.count) / Double(min(tokensA.count, tokensB.count))
    }
    
    private static func tokenize(_ name: String) -> Set<String> {
        Set(
            name.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 1 }
        )
    }
    
    // MARK: - Activity Import
    
    /// Merges Strava activities into ride logs. Deduped by activity id;
    /// activities with an unmatched gear_id import without a bike and are
    /// surfaced for manual assignment (odometer updates are deferred until
    /// assignment via RideLogger.assignBike).
    @MainActor
    static func importActivities(
        _ activities: [StravaActivity],
        context: ModelContext
    ) throws -> StravaSyncResult {
        var result = StravaSyncResult()
        
        let existingIds = Set(
            try context.fetch(FetchDescriptor<RideLog>(
                predicate: #Predicate { $0.stravaActivityId != nil }
            )).compactMap { $0.stravaActivityId }
        )
        
        let bikes = try context.fetch(FetchDescriptor<BikeConfiguration>())
        let bikesByGearId = Dictionary(
            bikes.filter { $0.stravaGearId != nil }.map { ($0.stravaGearId!, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        let scheduledRides = try context.fetch(FetchDescriptor<ScheduledRide>(
            predicate: #Predicate { !$0.isCompleted }
        ))
        
        for activity in activities where activity.isCyclingActivity {
            let activityId = String(activity.id)
            guard !existingIds.contains(activityId) else {
                result.skipped += 1
                continue
            }
            
            let bike = activity.gearId.flatMap { bikesByGearId[$0] }
            
            RideLogger.log(
                context: context,
                date: activity.startDate,
                distanceKm: activity.distanceKm,
                name: activity.name,
                notes: "Imported from Strava",
                bike: bike,
                stravaActivityId: activityId
            )
            
            if bike == nil {
                result.unassigned += 1
            }
            result.imported += 1
            
            if completeMatchingScheduledRide(for: activity, in: scheduledRides) {
                result.completedScheduledRides += 1
            }
        }
        
        return result
    }
    
    /// Marks a same-day scheduled ride as completed with the activity's
    /// actual distance and duration.
    private static func completeMatchingScheduledRide(
        for activity: StravaActivity,
        in scheduledRides: [ScheduledRide]
    ) -> Bool {
        let calendar = Calendar.current
        let candidates = scheduledRides.filter {
            !$0.isCompleted && calendar.isDate($0.scheduledDate, inSameDayAs: activity.startDate)
        }
        
        // With multiple rides that day, pick the closest planned start time
        guard let match = candidates.min(by: {
            abs($0.scheduledDate.timeIntervalSince(activity.startDate)) <
            abs($1.scheduledDate.timeIntervalSince(activity.startDate))
        }) else {
            return false
        }
        
        match.isCompleted = true
        match.completedDate = activity.startDate
        match.actualDistance = activity.distanceKm
        match.actualDuration = TimeInterval(activity.movingTime)
        return true
    }
}
