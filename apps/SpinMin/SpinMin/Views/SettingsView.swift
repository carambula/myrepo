//
//  SettingsView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import MinAppKit
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var vendorPreferences: [VendorPreference]
    
    @AppStorage(NotificationService.ridePrepEnabledKey) private var notifyRidePrep = true
    @AppStorage(NotificationService.batteryEnabledKey) private var notifyBattery = true
    @AppStorage(NotificationService.maintenanceEnabledKey) private var notifyMaintenance = true
    
    private func refreshNotifications() {
        Task {
            _ = await NotificationService.requestPermission()
            await NotificationService.refreshAll(context: modelContext)
        }
    }
    
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportURL: ExportedFile?
    @State private var exportError: String?
    
    private func exportButton(
        _ title: String,
        icon: String,
        action: @escaping () throws -> URL
    ) -> some View {
        Button {
            do {
                exportError = nil
                exportURL = ExportedFile(url: try action())
            } catch {
                exportError = "Export failed: \(error.localizedDescription)"
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundAccent()
                Text(title)
                Spacer()
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
    
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
                
                Section {
                    NavigationLink {
                        StravaSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "figure.outdoor.cycle")
                                .foregroundAccent()
                            Text("Strava")
                            Spacer()
                            Text(StravaAuthService.shared.isConnected ? "Connected" : "Not connected")
                                .foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        AgentSettingsView(app: .spin, exporter: SpinAgentExportAdapter(context: modelContext))
                    } label: {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundAccent()
                            Text("Agents")
                            Spacer()
                            Text("Read and write")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Connections")
                } footer: {
                    Text("Import rides from Strava or connect an agent with read or write access. Agent writes stay undoable for 7 days.")
                }

                Section {
                    IdeasSettingsLink(app: .spin)
                } header: {
                    Text("Ideas")
                } footer: {
                    Text("Send a bug or an idea. Status shows here as it moves through review and shipping.")
                }

                Section {
                    Toggle("Ride prep reminders", isOn: $notifyRidePrep)
                    Toggle("Battery charge reminders", isOn: $notifyBattery)
                    Toggle("Maintenance alerts", isOn: $notifyMaintenance)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Prep reminders arrive the evening before a scheduled ride. Notifications are asked for permission on first use.")
                }
                .onChange(of: notifyRidePrep) { refreshNotifications() }
                .onChange(of: notifyBattery) { refreshNotifications() }
                .onChange(of: notifyMaintenance) { refreshNotifications() }
                
                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    exportButton("Maintenance Records", icon: "wrench.and.screwdriver") {
                        try DataExportService.exportMaintenanceRecords(context: modelContext, format: exportFormat)
                    }
                    exportButton("Tire History", icon: "circle.circle") {
                        try DataExportService.exportTireHistory(context: modelContext, format: exportFormat)
                    }
                    exportButton("Ride Logs", icon: "figure.outdoor.cycle") {
                        try DataExportService.exportRideLogs(context: modelContext, format: exportFormat)
                    }
                } header: {
                    Text("Export Data")
                } footer: {
                    Text(exportError ?? "Your data stays yours: export it any time as \(exportFormat.rawValue).")
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
            .sheet(item: $exportURL) { exported in
                ExportShareSheet(url: exported.url)
            }
        }
    }
}

struct ExportedFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Simple share screen for an exported file
private struct ExportShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "doc.text")
                    .font(.system(size: 44))
                    .foregroundAccent()
                
                Text(url.lastPathComponent)
                    .bodyMedium()
                    .multilineTextAlignment(.center)
                
                ShareLink(item: url) {
                    Label("Share File", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
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
                            .fill(theme.accent)
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
