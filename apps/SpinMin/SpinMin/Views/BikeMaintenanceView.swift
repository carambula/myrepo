//
//  BikeMaintenanceView.swift
//  SpinMin
//
//  Comprehensive bike maintenance tracking
//

import SwiftUI
import SwiftData

struct BikeMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    
    let bike: BikeConfiguration
    
    @State private var selectedTab = 0
    @State private var showingLogMaintenance = false
    @State private var showingAddComponent = false
    @State private var quickActionType: MaintenanceType?
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Current Components
            CurrentComponentsView(
                bike: bike,
                onAddComponent: { showingAddComponent = true },
                onQuickAction: { type in quickActionType = type }
            )
            .tabItem {
                Label("Components", systemImage: "wrench.and.screwdriver")
            }
            .tag(0)
            
            // Maintenance History
            MaintenanceHistoryView(bike: bike)
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)
            
            // Quick Actions
            QuickMaintenanceActionsView(
                bike: bike,
                onAction: { type in quickActionType = type }
            )
            .tabItem {
                Label("Quick Log", systemImage: "bolt.fill")
            }
            .tag(2)
        }
        .navigationTitle("\(bike.name) Maintenance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingLogMaintenance = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                }
            }
        }
        .sheet(isPresented: $showingLogMaintenance) {
            LogMaintenanceView(bike: bike)
        }
        .sheet(isPresented: $showingAddComponent) {
            AddComponentTrackingView(bike: bike)
        }
        .sheet(item: $quickActionType) { type in
            QuickLogMaintenanceView(bike: bike, maintenanceType: type)
        }
    }
}

// MARK: - Current Components View

struct CurrentComponentsView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let bike: BikeConfiguration
    let onAddComponent: () -> Void
    let onQuickAction: (MaintenanceType) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Bike odometer
                BikeOdometerCard(bike: bike)
                
                // Chain (special treatment)
                if let chain = bike.currentChain {
                    ChainComponentCard(chain: chain, bike: bike, onQuickAction: onQuickAction)
                } else {
                    EmptyComponentCard(
                        componentType: .chain,
                        onAdd: onAddComponent
                    )
                }
                
                // Other components
                ForEach(bike.componentTracking.filter { $0.component != .chain }) { component in
                    ComponentCard(component: component)
                }
                
                // Add component button
                Button(action: onAddComponent) {
                    Label("Track New Component", systemImage: "plus.circle")
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .medium))
            }
            .padding(DesignSystem.Spacing.screenHorizontalPadding)
        }
        .background(DesignSystem.Color.background)
    }
}

// MARK: - Component Cards

struct BikeOdometerCard: View {
    let bike: BikeConfiguration
    
    var body: some View {
        HStack {
            Image(systemName: "speedometer")
                .font(.system(size: 40))
                .foregroundAccent()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Bike Odometer")
                    .bodyMedium()
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f km", bike.totalMileageKm))
                    .displaySmall()
                    .foregroundAccent()
                    .monospacedDigit()
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

struct ChainComponentCard: View {
    @Environment(ThemeManager.self) private var themeManager
    
    let chain: ComponentTracking
    let bike: BikeConfiguration
    let onQuickAction: (MaintenanceType) -> Void
    
    var body: some View {
        let chainStatus = MaintenanceService.calculateChainMaintenance(
            for: chain,
            speedCount: bike.speedCount ?? 11
        )
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Chain")
                            .bodyLarge()
                            .foregroundStyle(.secondary)
                        Text(chainStatus.overallStatus.emoji)
                            .font(.system(size: 20))
                    }
                    Text(chain.displayName)
                        .titleMedium()
                        .foregroundHeadline()
                }
                
                Spacer()
                
                Text(chainStatus.overallStatus.displayName)
                    .captionMedium()
                    .foregroundStyle(statusColor(for: chainStatus.overallStatus))
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(statusColor(for: chainStatus.overallStatus).opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.xs)
            }
            
            Divider()
            
            // Chain stats
            HStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mileage")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f km", chain.componentMileageKm))
                        .bodyLarge()
                        .monospacedDigit()
                }
                
                if let lube = chain.lubeType {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Lube Type")
                            .captionSmall()
                            .foregroundStyle(.secondary)
                        Text(lube.shortName)
                            .bodyLarge()
                    }
                }
                
                if let wear = chainStatus.chainWearPercentage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wear")
                            .captionSmall()
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.2f%%", wear))
                            .bodyLarge()
                            .monospacedDigit()
                            .foregroundStyle(wear >= chainStatus.wearLimit * 0.8 ? .orange : .primary)
                    }
                }
            }
            
            // Wax/Clean status
            if let kmSinceWax = chainStatus.kmSinceWax,
               let kmUntilWax = chainStatus.kmUntilWax,
               chain.lubeType != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Since Last Wax/Lube")
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Spacer()
                        if chainStatus.waxDue {
                            Text("DUE")
                                .captionSmall()
                                .foregroundStyle(.red)
                                .fontWeight(.semibold)
                        } else {
                            Text("\(String(format: "%.0f km", kmUntilWax)) until due")
                                .captionSmall()
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(chainStatus.waxDue ? Color.red : Color.green)
                                .frame(width: geometry.size.width * min(1.0, kmSinceWax / (kmSinceWax + kmUntilWax)), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            
            // Warnings
            if !chainStatus.warnings.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(chainStatus.warnings.prefix(3).enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.orange)
                                .font(.system(size: 14))
                            Text(warning)
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Quick actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    onQuickAction(.chainWax)
                } label: {
                    Label("Log Wax", systemImage: "drop")
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .small))
                
                Button {
                    onQuickAction(.chainClean)
                } label: {
                    Label("Log Clean", systemImage: "sparkles")
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
                
                Button {
                    onQuickAction(.chainReplace)
                } label: {
                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .tertiary, size: .small))
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    private func statusColor(for status: MaintenanceService.ComponentHealth) -> Color {
        switch status.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

struct ComponentCard: View {
    let component: ComponentTracking
    
    var body: some View {
        let health = MaintenanceService.calculateComponentHealth(for: component)
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(component.component.displayName)
                            .bodyLarge()
                        Text(health.status.emoji)
                            .font(.system(size: 18))
                    }
                    if !component.displayName.contains(component.component.displayName) {
                        Text(component.displayName)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f km", component.componentMileageKm))
                        .bodyLarge()
                        .monospacedDigit()
                    Text(String(format: "%.0f%%", health.mileagePercentage))
                        .captionSmall()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

struct EmptyComponentCard: View {
    let componentType: ComponentType
    let onAdd: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("No \(componentType.displayName) Tracked")
                .bodyMedium()
                .foregroundHeadline()
            
            Text("Start tracking to monitor wear and replacement timing")
                .captionMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAdd) {
                Label("Start Tracking", systemImage: "plus")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

// Make MaintenanceType Identifiable for sheet binding
extension MaintenanceType: Identifiable {
    var id: String { rawValue }
}

#Preview {
    NavigationStack {
        BikeMaintenanceView(bike: BikeConfiguration(
            name: "Road Bike",
            bikeType: .road,
            tireWidthMM: 28
        ))
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, ComponentTracking.self], inMemory: true)
    }
}
