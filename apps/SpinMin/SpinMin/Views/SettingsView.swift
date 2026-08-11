//
//  SettingsView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var vendorPreferences: [VendorPreference]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundAccent()
                            Text("Theme")
                            Spacer()
                            Circle()
                                .fill(themeManager.currentTheme.accent)
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                
                Section {
                    NavigationLink {
                        VendorPreferencesView()
                    } label: {
                        HStack {
                            Image(systemName: "cart")
                                .foregroundAccent()
                            Text("Preferred Vendors")
                            Spacer()
                            Text("\(vendorPreferences.first?.vendors.count ?? 3) selected")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Ordering")
                } footer: {
                    Text("Choose your preferred retailers for ordering replacement components")
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Calculator Info") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("About Tire Pressure")
                            .headlineSmall()
                        
                        Text("This calculator uses the 15% tire drop rule and empirical data to recommend optimal tire pressures. Recommendations are based on research from Frank Berto, SILCA, Wolf Tooth, and other cycling industry sources.")
                            .bodySmall()
                            .foregroundStyle(.secondary)
                        
                        Text("Always verify recommendations against your tire and rim manufacturer's specifications. Start with these values and adjust based on your personal preference and riding conditions.")
                            .bodySmall()
                            .foregroundStyle(.secondary)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct ThemeSelectionView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        List {
            ForEach(themeManager.availableThemes) { theme in
                Button(action: {
                    themeManager.setTheme(theme)
                }) {
                    HStack {
                        Circle()
                            .fill(theme.accent.color)
                            .frame(width: 32, height: 32)
                        
                        Text(theme.name)
                            .bodyMedium()
                        
                        Spacer()
                        
                        if theme.id == themeManager.currentTheme.id {
                            Image(systemName: "checkmark")
                                .foregroundAccent()
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environment(ThemeManager.shared)
}
