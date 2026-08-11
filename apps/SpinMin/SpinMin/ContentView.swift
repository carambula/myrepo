//
//  ContentView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BikeConfiguration.lastUsed, order: .reverse) private var bikeConfigurations: [BikeConfiguration]
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
<<<<<<< HEAD
            RideDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)
            
            RideScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(1)
            
            CalculatorView()
                .tabItem {
                    Label("Pressure", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(2)
            
            GearCalculatorView()
                .tabItem {
                    Label("Gearing", systemImage: "gearshape.2")
                }
                .tag(3)
=======
            CalculatorView()
                .tabItem {
                    Label("Calculator", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(0)
>>>>>>> origin/master
            
            BikeConfigurationsView()
                .tabItem {
                    Label("Bikes", systemImage: "bicycle")
                }
<<<<<<< HEAD
                .tag(4)
            
            GearLockerView()
                .tabItem {
                    Label("Gear", systemImage: "tshirt.fill")
                }
                .tag(5)
            
            RideChecklistsView()
                .tabItem {
                    Label("Checklists", systemImage: "checklist")
                }
                .tag(6)
=======
                .tag(1)
>>>>>>> origin/master
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
<<<<<<< HEAD
                .tag(7)
=======
                .tag(2)
>>>>>>> origin/master
        }
        .tint(themeManager.currentTheme.accent)
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, CalculationHistory.self, ThemePreference.self], inMemory: true)
}
