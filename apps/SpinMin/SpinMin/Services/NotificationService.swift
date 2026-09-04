//
//  NotificationService.swift
//  SpinMin
//
//  Local notifications: nightly ride prep, battery charge reminders,
//  and maintenance alerts. All scheduling is local - no server.
//

import Foundation
import UserNotifications
import SwiftData

struct NotificationService {
    
    // Settings keys (toggled in SettingsView)
    static let ridePrepEnabledKey = "notifyRidePrep"
    static let batteryEnabledKey = "notifyBattery"
    static let maintenanceEnabledKey = "notifyMaintenance"
    
    /// Hour of day (24h) for the evening prep reminder
    static let eveningReminderHour = 20
    
    // MARK: - Permission
    
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    
    static func permissionStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    
    // MARK: - Refresh All Scheduled Notifications
    
    /// Recomputes every pending SpinMin notification from current data.
    /// Call after sync, ride changes, or app launch.
    @MainActor
    static func refreshAll(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let status = await permissionStatus()
        guard status == .authorized || status == .provisional else { return }
        
        center.removeAllPendingNotificationRequests()
        
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: ridePrepEnabledKey) as? Bool ?? true {
            await scheduleRidePrepReminders(context: context, center: center)
        }
        if defaults.object(forKey: batteryEnabledKey) as? Bool ?? true {
            await scheduleBatteryReminders(context: context, center: center)
        }
        if defaults.object(forKey: maintenanceEnabledKey) as? Bool ?? true {
            await scheduleMaintenanceReminders(context: context, center: center)
        }
    }
    
    // MARK: - Ride Prep (evening before)
    
    @MainActor
    private static func scheduleRidePrepReminders(
        context: ModelContext,
        center: UNUserNotificationCenter
    ) async {
        let calendar = Calendar.current
        let horizon = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        
        guard let rides = try? context.fetch(FetchDescriptor<ScheduledRide>(
            predicate: #Predicate { !$0.isCompleted },
            sortBy: [SortDescriptor(\.scheduledDate)]
        )) else { return }
        
        let upcoming = rides.filter { $0.scheduledDate > Date() && $0.scheduledDate <= horizon }
        
        for ride in upcoming {
            guard let eveningBefore = calendar.date(byAdding: .day, value: -1, to: ride.scheduledDate),
                  let fireDate = calendar.date(
                    bySettingHour: eveningReminderHour, minute: 0, second: 0, of: eveningBefore
                  ),
                  fireDate > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Ride tomorrow: \(ride.name)"
            
            var bodyParts = [
                ride.scheduledDate.formatted(date: .omitted, time: .shortened)
            ]
            if let distance = ride.distance {
                bodyParts.append("\(Int(distance)) km")
            }
            if !ride.isPrepared {
                bodyParts.append("Prep checklist not done")
            }
            if let temperature = ride.temperature {
                bodyParts.append("\(Int(temperature))°C forecast")
            }
            content.body = bodyParts.joined(separator: "   ")
            content.sound = .default
            
            schedule(content: content, at: fireDate, id: "ridePrep-\(ride.id)", center: center)
        }
    }
    
    // MARK: - Battery Charge Reminders
    
    @MainActor
    private static func scheduleBatteryReminders(
        context: ModelContext,
        center: UNUserNotificationCenter
    ) async {
        guard let gear = try? context.fetch(FetchDescriptor<GearItem>(
            predicate: #Predicate { $0.retirementDate == nil }
        )) else { return }
        
        let needingCharge = gear.filter { $0.hasBattery && $0.needsCharge }
        guard !needingCharge.isEmpty else { return }
        
        // Only relevant if there is a ride in the next 2 days
        guard let rides = try? context.fetch(FetchDescriptor<ScheduledRide>(
            predicate: #Predicate { !$0.isCompleted }
        )) else { return }
        let dayAfterTomorrow = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        guard rides.contains(where: { $0.scheduledDate > Date() && $0.scheduledDate < dayAfterTomorrow }) else {
            return
        }
        
        guard let tonight = Calendar.current.date(
            bySettingHour: eveningReminderHour, minute: 30, second: 0, of: Date()
        ), tonight > Date() else { return }
        
        let names = needingCharge.map { $0.displayName }.joined(separator: ", ")
        let content = UNMutableNotificationContent()
        content.title = "Charge before your ride"
        content.body = "Low battery: \(names)"
        content.sound = .default
        
        schedule(content: content, at: tonight, id: "battery-reminder", center: center)
    }
    
    // MARK: - Maintenance Reminders
    
    @MainActor
    private static func scheduleMaintenanceReminders(
        context: ModelContext,
        center: UNUserNotificationCenter
    ) async {
        guard let bikes = try? context.fetch(FetchDescriptor<BikeConfiguration>()) else { return }
        
        var dueItems: [String] = []
        for bike in bikes where bike.maintenanceDue {
            dueItems.append(bike.name)
        }
        
        // Helmet and safety gear past its life
        if let gear = try? context.fetch(FetchDescriptor<GearItem>(
            predicate: #Predicate { $0.retirementDate == nil }
        )) {
            for item in gear {
                let health = GearTrackingService.calculateHealth(for: item)
                if health.health == .expired || health.health == .unsafe || health.health == .replaceNow {
                    dueItems.append(item.displayName)
                }
            }
        }
        
        guard !dueItems.isEmpty else { return }
        
        // Tomorrow morning at 9, one combined summary
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
              let fireDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Maintenance needed"
        content.body = dueItems.prefix(4).joined(separator: "   ")
        content.sound = .default
        
        schedule(content: content, at: fireDate, id: "maintenance-summary", center: center)
    }
    
    // MARK: - Helpers
    
    private static func schedule(
        content: UNNotificationContent,
        at date: Date,
        id: String,
        center: UNUserNotificationCenter
    ) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
