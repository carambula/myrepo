//
//  WeatherForecastService.swift
//  SpinMin
//
//  Populates scheduled ride weather (temperature, precipitation) using
//  Apple's WeatherKit. No API keys required - just the WeatherKit
//  capability on the app target and an active Apple Developer account.
//
//  Requires in Xcode:
//  - Signing & Capabilities → + Capability → WeatherKit
//  - Info.plist: NSLocationWhenInUseUsageDescription (for ride-location forecasts)
//

import Foundation
import CoreLocation
import WeatherKit

struct WeatherForecastService {
    
    /// WeatherKit provides ~10 days of daily/hourly forecast
    static let forecastHorizonDays = 10
    
    // MARK: - Refresh Forecasts
    
    /// Updates weather fields on all upcoming rides that fall inside the
    /// forecast window. Uses the ride's route start location when available,
    /// falling back to the provided location (usually the user's).
    @MainActor
    static func refreshForecasts(for rides: [ScheduledRide], fallbackLocation: CLLocation?) async {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: forecastHorizonDays, to: now) ?? now
        
        let upcoming = rides.filter { !$0.isCompleted && $0.scheduledDate > now && $0.scheduledDate <= horizon }
        
        for ride in upcoming {
            let location = rideLocation(for: ride) ?? fallbackLocation
            guard let location = location else { continue }
            await updateForecast(for: ride, at: location)
        }
    }
    
    /// Fetches the hourly forecast for one ride and stores it on the model.
    @MainActor
    static func updateForecast(for ride: ScheduledRide, at location: CLLocation) async {
        do {
            let weather = try await WeatherKit.WeatherService.shared.weather(
                for: location,
                including: .hourly
            )
            
            // Find the forecast hour closest to the ride start
            guard let hour = weather.forecast.min(by: {
                abs($0.date.timeIntervalSince(ride.scheduledDate)) < abs($1.date.timeIntervalSince(ride.scheduledDate))
            }) else { return }
            
            // Ignore stale matches more than 2 hours from the ride start
            guard abs(hour.date.timeIntervalSince(ride.scheduledDate)) <= 7200 else { return }
            
            ride.temperature = hour.temperature.converted(to: .celsius).value
            ride.precipitationChance = hour.precipitationChance
            ride.weatherForecast = hour.condition.description
        } catch {
            // WeatherKit unavailable (no capability, no network, rate limit).
            // Leave existing values in place; prep view degrades gracefully.
            print("WeatherKit forecast failed: \(error.localizedDescription)")
        }
    }
    
    private static func rideLocation(for ride: ScheduledRide) -> CLLocation? {
        guard let route = ride.route,
              let lat = route.startLatitude,
              let lon = route.startLongitude else {
            return nil
        }
        return CLLocation(latitude: lat, longitude: lon)
    }
}

// MARK: - One-Shot Location Provider

/// Requests the user's current location once, for weather lookups when a
/// ride has no route coordinates.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()
    
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    /// Returns the current location, or nil if permission is denied or
    /// the fix fails. Never throws - weather is a best-effort enhancement.
    func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        
        if status == .denied || status == .restricted {
            return nil
        }
        
        // One request at a time; concurrent callers just miss this cycle
        guard continuation == nil else { return nil }
        
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            resume(with: nil)
        case .notDetermined:
            break
        @unknown default:
            resume(with: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(with: locations.first)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: nil)
    }
    
    private func resume(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}
