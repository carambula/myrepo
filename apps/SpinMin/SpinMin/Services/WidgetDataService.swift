//
//  WidgetDataService.swift
//  SpinMin
//
//  Publishes a snapshot of dashboard data to the App Group container
//  so the widget and Siri intents can read it without the main store.
//

import Foundation
import SwiftData
import WidgetKit

struct WidgetDataService {
    
    /// Rider weight used when none has been saved yet
    static let defaultRiderWeightKg = 75.0
    
    /// Rebuilds the widget snapshot from current data and asks WidgetKit
    /// to refresh timelines. Call after sync, ride logging, or edits.
    @MainActor
    static func refreshSnapshot(context: ModelContext) {
        let riderWeight = UserDefaults.standard.double(forKey: "riderWeightKg")
        let weight = riderWeight > 0 ? riderWeight : defaultRiderWeightKg
        
        // Per-bike pressures on the default wheelset
        var bikePressures: [WidgetSnapshot.BikePressure] = []
        if let bikes = try? context.fetch(FetchDescriptor<BikeConfiguration>(
            sortBy: [SortDescriptor(\.lastUsed, order: .reverse)]
        )) {
            for bike in bikes.prefix(4) {
                let wheelset = bike.defaultWheelset
                let tireWidth = wheelset.map { Double($0.tireWidthMM) } ?? bike.tireWidthMM
                
                let result = TirePressureCalculationService.calculatePressure(
                    riderWeightKg: weight,
                    bikeWeightKg: bike.bikeWeightKg,
                    bikeType: bike.bikeType,
                    tireWidthMM: tireWidth,
                    terrain: bike.defaultTerrain ?? .mixed,
                    tireCasing: wheelset?.tireCasing ?? bike.defaultCasing ?? .standard,
                    ridingStyle: bike.defaultRidingStyle ?? .balanced,
                    rimType: wheelset?.rimType ?? .hooked,
                    internalRimWidthMM: wheelset?.internalRimWidthMM
                )
                
                bikePressures.append(WidgetSnapshot.BikePressure(
                    bikeName: bike.name,
                    wheelsetName: wheelset?.name,
                    frontPSI: result.frontPressurePSI,
                    rearPSI: result.rearPressurePSI
                ))
            }
        }
        
        // Today's and next upcoming ride
        var todayRide: WidgetSnapshot.UpcomingRide?
        var nextRide: WidgetSnapshot.UpcomingRide?
        if let rides = try? context.fetch(FetchDescriptor<ScheduledRide>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )) {
            let calendar = Calendar.current
            let upcoming = rides.filter { $0.scheduledDate > calendar.startOfDay(for: Date()) }
            
            if let today = upcoming.first(where: { calendar.isDateInToday($0.scheduledDate) }) {
                todayRide = snapshotRide(today)
            }
            if let next = upcoming.first(where: { !calendar.isDateInToday($0.scheduledDate) }) {
                nextRide = snapshotRide(next)
            }
        }
        
        WidgetSnapshot(
            generatedAt: Date(),
            bikes: bikePressures,
            todayRide: todayRide,
            nextRide: nextRide
        ).save()
        
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private static func snapshotRide(_ ride: ScheduledRide) -> WidgetSnapshot.UpcomingRide {
        WidgetSnapshot.UpcomingRide(
            name: ride.name,
            date: ride.scheduledDate,
            rideTypeName: ride.rideType.displayName,
            distanceKm: ride.distance,
            isPrepared: ride.isPrepared
        )
    }
}
