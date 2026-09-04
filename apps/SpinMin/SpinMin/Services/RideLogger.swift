//
//  RideLogger.swift
//  SpinMin
//
//  Single code path for recording a completed ride: creates the RideLog
//  and propagates distance to the bike, wheelset, tire, and component
//  odometers. Used by manual logging, Strava import, and the post-ride
//  completion flow.
//

import Foundation
import SwiftData

struct RideLogger {
    
    /// Creates a ride log and updates all odometers.
    @discardableResult
    static func log(
        context: ModelContext,
        date: Date,
        distanceKm: Double,
        name: String,
        notes: String = "",
        bike: BikeConfiguration?,
        wheelset: Wheelset? = nil,
        terrain: TirePressureCalculationService.TerrainType? = nil,
        stravaActivityId: String? = nil
    ) -> RideLog {
        let resolvedWheelset = wheelset ?? bike?.defaultWheelset
        
        let ride = RideLog(
            rideDate: date,
            distanceKm: distanceKm,
            rideName: name,
            notes: notes,
            bike: bike,
            wheelset: resolvedWheelset,
            terrain: terrain
        )
        ride.stravaActivityId = stravaActivityId
        context.insert(ride)
        
        bike?.logDistance(distanceKm)
        resolvedWheelset?.logDistance(distanceKm)
        
        return ride
    }
    
    /// Assigns a bike to a ride imported without one (unknown Strava gear)
    /// and applies the deferred odometer updates.
    static func assignBike(
        _ ride: RideLog,
        to bike: BikeConfiguration,
        wheelset: Wheelset? = nil
    ) {
        guard ride.bikeConfiguration == nil else { return }
        
        let resolvedWheelset = wheelset ?? bike.defaultWheelset
        ride.bikeConfiguration = bike
        ride.wheelset = resolvedWheelset
        
        bike.logDistance(ride.distanceKm)
        resolvedWheelset?.logDistance(ride.distanceKm)
    }
}
