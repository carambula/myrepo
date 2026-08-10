//
//  RideDashboardView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//  Main screen - Quick access to bike setups before rides
//

import SwiftUI
import SwiftData

struct RideDashboardView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BikeConfiguration.lastUsed, order: .reverse) private var bikes: [BikeConfiguration]
    @Query private var wheelsets: [Wheelset]
    
    @State private var selectedBike: BikeConfiguration?
    @State private var showingAddBike = false
    @State private var riderWeight: Double = 70
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "bicycle.circle.fill")
                            .font(.system(size: 56))
                            .foregroundAccent()
                        
                        Text("Ready to Ride")
                            .displayMedium()
                            .foregroundHeadline()
                        
                        Text("Quick setup for today's ride")
                            .bodyMedium()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    if bikes.isEmpty {
                        emptyStateView
                    } else {
                        // Rider weight (affects all calculations)
                        riderWeightCard
                        
                        // Bike cards with wheelsets
                        ForEach(bikes) { bike in
                            BikeSetupCard(
                                bike: bike,
                                wheelsets: wheelsetsForBike(bike),
                                riderWeight: riderWeight
                            )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Color.background)
            .navigationTitle("My Bikes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddBike = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                    }
                }
            }
            .sheet(isPresented: $showingAddBike) {
                AddBikeConfigurationView()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "bicycle.circle")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("No Bikes Yet")
                .displaySmall()
                .foregroundHeadline()
            
            Text("Add your bikes to see tire pressure and gearing at a glance")
                .bodyMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
            
            Button(action: { showingAddBike = true }) {
                Label("Add First Bike", systemImage: "plus")
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
            .padding(.top, DesignSystem.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }
    
    private var riderWeightCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "figure.stand")
                    .foregroundAccent()
                Text("Rider Weight")
                    .labelLarge()
                Spacer()
                Text("\(String(format: "%.0f", riderWeight)) kg")
                    .titleMedium()
                    .foregroundAccent()
            }
            
            Slider(value: $riderWeight, in: 40...150, step: 0.5)
                .tint(DesignSystem.Color.accent)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private func wheelsetsForBike(_ bike: BikeConfiguration) -> [Wheelset] {
        wheelsets.filter { $0.bikeConfiguration?.id == bike.id }
    }
}

struct BikeSetupCard: View {
    let bike: BikeConfiguration
    let wheelsets: [Wheelset]
    let riderWeight: Double
    
    @State private var selectedWheelset: Wheelset?
    @State private var terrain: TirePressureCalculationService.TerrainType = .mixed
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Bike Header
            HStack(alignment: .top) {
                Image(systemName: bikeIcon)
                    .font(.system(size: 40))
                    .foregroundAccent()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bike.name)
                        .headlineLarge()
                        .foregroundHeadline()
                    
                    Text(bike.bikeType.rawValue)
                        .bodySmall()
                        .foregroundStyle(.secondary)
                    
                    if let weight = bike.bikeWeightKg {
                        Text("Bike: \(String(format: "%.1f", weight))kg")
                            .captionMedium()
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    bike.lastUsed = Date()
                }) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DesignSystem.Color.warning)
                }
            }
            
            Divider()
            
            // Wheelsets Section
            if wheelsets.isEmpty {
                // Use legacy single tire setup
                LegacyTireSetupView(
                    bike: bike,
                    riderWeight: riderWeight,
                    terrain: $terrain
                )
            } else {
                // Show wheelsets
                ForEach(wheelsets.sorted(by: { $0.isDefault && !$1.isDefault })) { wheelset in
                    WheelsetQuickView(
                        wheelset: wheelset,
                        bike: bike,
                        riderWeight: riderWeight,
                        terrain: $terrain,
                        isExpanded: expandedSections.contains(wheelset.id.uuidString)
                    ) {
                        toggleExpansion(for: wheelset)
                    }
                }
                
                Button(action: {
                    // Add wheelset
                }) {
                    Label("Add Wheelset", systemImage: "plus.circle")
                        .font(DesignSystem.Typography.labelMedium)
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
            }
            
            // Quick Actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                NavigationLink(destination: Text("Edit Bike")) {
                    Label("Edit", systemImage: "pencil")
                        .font(DesignSystem.Typography.labelSmall)
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .tertiary, size: .small))
                
                if bike.hasGearing {
                    NavigationLink(destination: Text("View Gearing")) {
                        Label("Gearing", systemImage: "gearshape.2")
                            .font(DesignSystem.Typography.labelSmall)
                    }
                    .buttonStyle(DesignSystemButtonStyle(variant: .tertiary, size: .small))
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
    
    private var bikeIcon: String {
        switch bike.bikeType {
        case .road: return "bicycle"
        case .gravel: return "bicycle.circle"
        case .mountainXC, .mountainTrail, .mountainEnduro: return "figure.outdoor.cycle"
        case .fat: return "snow"
        }
    }
    
    private func toggleExpansion(for wheelset: Wheelset) {
        let id = wheelset.id.uuidString
        if expandedSections.contains(id) {
            expandedSections.remove(id)
        } else {
            expandedSections.insert(id)
        }
    }
}

struct WheelsetQuickView: View {
    let wheelset: Wheelset
    let bike: BikeConfiguration
    let riderWeight: Double
    @Binding var terrain: TirePressureCalculationService.TerrainType
    let isExpanded: Bool
    let onToggle: () -> Void
    
    @State private var calculatedPressure: TirePressureCalculationService.PressureResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Wheelset header - always visible
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(wheelset.name)
                                .bodyLarge()
                                .fontWeight(.semibold)
                            if wheelset.isDefault {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Color.success)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Text(wheelset.tireDescription)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Quick pressure display
                    if let pressure = calculatedPressure {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(String(format: "%.0f", pressure.frontPressurePSI))/\(String(format: "%.0f", pressure.rearPressurePSI))")
                                .titleLarge()
                                .foregroundAccent()
                            Text("PSI")
                                .captionSmall()
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            
            // Expanded details
            if isExpanded {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Divider()
                    
                    // Terrain selector
                    Picker("Terrain", selection: $terrain) {
                        ForEach([TirePressureCalculationService.TerrainType.smooth, .mixed, .rough, .gravel2, .trail], id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(DesignSystem.Spacing.sm)
                    .background(DesignSystem.Color.background)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    
                    // Detailed pressure
                    if let pressure = calculatedPressure {
                        HStack(spacing: DesignSystem.Spacing.xl) {
                            VStack(spacing: 4) {
                                Text("FRONT")
                                    .captionSmall()
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", pressure.frontPressurePSI))
                                    .titleLarge()
                                    .foregroundAccent()
                                Text("PSI")
                                    .captionSmall()
                                Text(String(format: "%.2f BAR", pressure.frontPressureBAR))
                                    .captionSmall()
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Divider()
                                .frame(height: 60)
                            
                            VStack(spacing: 4) {
                                Text("REAR")
                                    .captionSmall()
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f", pressure.rearPressurePSI))
                                    .titleLarge()
                                    .foregroundAccent()
                                Text("PSI")
                                    .captionSmall()
                                Text(String(format: "%.2f BAR", pressure.rearPressureBAR))
                                    .captionSmall()
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Color.background)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .onAppear {
            calculatePressure()
        }
        .onChange(of: terrain) { _, _ in
            calculatePressure()
        }
        .onChange(of: riderWeight) { _, _ in
            calculatePressure()
        }
    }
    
    private func calculatePressure() {
        calculatedPressure = TirePressureCalculationService.calculatePressure(
            riderWeightKg: riderWeight,
            bikeWeightKg: bike.bikeWeightKg,
            bikeType: bike.bikeType,
            tireWidthMM: Double(wheelset.tireWidthMM),
            terrain: terrain,
            tireCasing: wheelset.tireCasing ?? .standard,
            ridingStyle: bike.defaultRidingStyle ?? .balanced
        )
        
        wheelset.lastUsed = Date()
    }
}

struct LegacyTireSetupView: View {
    let bike: BikeConfiguration
    let riderWeight: Double
    @Binding var terrain: TirePressureCalculationService.TerrainType
    
    @State private var calculatedPressure: TirePressureCalculationService.PressureResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Tires: \(Int(bike.tireWidthMM))mm")
                .bodyMedium()
            
            Picker("Terrain", selection: $terrain) {
                ForEach([TirePressureCalculationService.TerrainType.smooth, .mixed, .rough, .gravel2, .trail], id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.menu)
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.Color.surfaceElevated)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            
            if let pressure = calculatedPressure {
                HStack(spacing: DesignSystem.Spacing.xl) {
                    PressureDisplay(label: "FRONT", psi: pressure.frontPressurePSI, bar: pressure.frontPressureBAR)
                    Divider().frame(height: 60)
                    PressureDisplay(label: "REAR", psi: pressure.rearPressurePSI, bar: pressure.rearPressureBAR)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Color.surfaceElevated)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            
            Button("Add Wheelsets") {
                // Navigate to wheelset management
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
        }
        .onAppear {
            calculatePressure()
        }
        .onChange(of: terrain) { _, _ in
            calculatePressure()
        }
    }
    
    private func calculatePressure() {
        calculatedPressure = TirePressureCalculationService.calculatePressure(
            riderWeightKg: riderWeight,
            bikeWeightKg: bike.bikeWeightKg,
            bikeType: bike.bikeType,
            tireWidthMM: bike.tireWidthMM,
            terrain: terrain,
            tireCasing: bike.defaultCasing ?? .standard,
            ridingStyle: bike.defaultRidingStyle ?? .balanced
        )
    }
}

struct PressureDisplay: View {
    let label: String
    let psi: Double
    let bar: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .captionSmall()
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", psi))
                .titleLarge()
                .foregroundAccent()
            Text("PSI")
                .captionSmall()
            Text(String(format: "%.2f BAR", bar))
                .captionSmall()
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RideDashboardView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, Wheelset.self], inMemory: true)
}
