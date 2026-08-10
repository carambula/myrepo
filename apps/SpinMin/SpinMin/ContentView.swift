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
            RideDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
                .tag(0)
            
            CalculatorView()
                .tabItem {
                    Label("Pressure", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(1)
            
            GearCalculatorView()
                .tabItem {
                    Label("Gearing", systemImage: "gearshape.2")
                }
                .tag(2)
            
            BikeConfigurationsView()
                .tabItem {
                    Label("Bikes", systemImage: "bicycle")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .tint(themeManager.currentTheme.accent)
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, CalculationHistory.self, ThemePreference.self], inMemory: true)
}
