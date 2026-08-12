//
//  SpinMinApp.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

@main
struct SpinMinApp: App {
    @State private var themeManager = ThemeManager.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BikeConfiguration.self,
            Wheelset.self,
            TireTracking.self,
            TireHistory.self,
            RideLog.self,
            MaintenanceRecord.self,
            ComponentTracking.self,
            CalculationHistory.self,
            GearConfiguration.self,
            ThemePreference.self,
            // Product database
            TireProduct.self,
            ChainProduct.self,
            WheelsetProduct.self,
            ComponentProduct.self,
            BikeProduct.self,
            // Vendor preferences
            VendorPreference.self,
            // Gear tracking
            GearItem.self,
            // Checklists
            RideChecklist.self,
            ChecklistItem.self,
            // Ride scheduling
            ScheduledRide.self,
            Route.self,
        ])
        
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let localStoreURL = appSupportURL.appendingPathComponent("SpinMin.store")
        
        // First preference: CloudKit-backed store for iCloud sync
        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("CloudKit ModelContainer failed, falling back to local store: \(error)")
        }
        
        // Second preference: local on-disk store
        do {
            let localConfig = ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            print("Local ModelContainer failed, resetting local SwiftData files: \(error)")
        }
        
        // Last resort: remove local store files and recreate from scratch
        do {
            let fileManager = FileManager.default
            let potentialStoreFiles = [
                localStoreURL,
                localStoreURL.appendingPathExtension("wal"),
                localStoreURL.appendingPathExtension("shm"),
            ]
            for fileURL in potentialStoreFiles where fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            let resetConfig = ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [resetConfig])
        } catch {
            fatalError("Could not create ModelContainer even after reset: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.currentTheme.isDark ? .dark : nil)
                .onAppear {
                    // Seed product database on first launch
                    ProductDatabaseSeeder.seedDatabaseIfNeeded(context: sharedModelContainer.mainContext)
                }
                .task {
                    // Keep pending notifications in sync with current data
                    await NotificationService.refreshAll(context: sharedModelContainer.mainContext)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
