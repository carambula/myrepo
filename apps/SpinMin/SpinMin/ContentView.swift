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
            CalculatorView()
                .tabItem {
                    Label("Calculator", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(0)
            
            BikeConfigurationsView()
                .tabItem {
                    Label("Bikes", systemImage: "bicycle")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(themeManager.currentTheme.accent)
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, CalculationHistory.self, ThemePreference.self], inMemory: true)
}
