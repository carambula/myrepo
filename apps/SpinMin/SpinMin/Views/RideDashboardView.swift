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
    @Query(sort: \ScheduledRide.scheduledDate) private var allRides: [ScheduledRide]
    @Query private var routes: [Route]
    @Query(filter: #Predicate<GearItem> { $0.retirementDate == nil }) private var activeGear: [GearItem]
    
    @State private var selectedBike: BikeConfiguration?
    @State private var showingAddBike = false
    @State private var riderWeight: Double = 70
    @State private var selectedRide: ScheduledRide?
    @State private var rideToComplete: ScheduledRide?
    
    var todayRides: [ScheduledRide] {
        allRides.filter { Calendar.current.isDateInToday($0.scheduledDate) && !$0.isCompleted }
    }
    
    var upcomingRidesNeedingPrep: [ScheduledRide] {
        allRides.filter { $0.needsPreparation && !$0.isToday }
    }
    
    /// Past rides (last 7 days) never marked complete
    var ridesAwaitingCompletion: [ScheduledRide] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allRides.filter {
            !$0.isCompleted && $0.scheduledDate < Date() && $0.scheduledDate > weekAgo
        }
    }
    
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
                        
                        Text(headerSubtitle)
                            .bodyMedium()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Today's scheduled rides
                    if !todayRides.isEmpty {
                        todayRidesSection
                    }
                    
                    // Rides needing preparation (next 24 hours)
                    if !upcomingRidesNeedingPrep.isEmpty {
                        prepNeededSection
                    }
                    
                    // Prompt to complete past rides so mileage stays accurate
                    if let pastRide = ridesAwaitingCompletion.first {
                        Button {
                            rideToComplete = pastRide
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundAccent()
                                Text(ridesAwaitingCompletion.count == 1
                                     ? "Complete \(pastRide.name)?"
                                     : "\(ridesAwaitingCompletion.count) rides need completing")
                                    .bodyMedium()
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .captionMedium()
                                    .foregroundStyle(.secondary)
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))
                        }
                        .buttonStyle(.plain)
                    }
                    
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
            .refreshable {
                if StravaAuthService.shared.isConnected {
                    _ = try? await StravaSyncService.sync(context: modelContext)
                }
            }
            .navigationTitle("My Bikes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    QuickLogRideButton()
                }
                
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
            .sheet(item: $selectedRide) { ride in
                PreRidePreparationView(
                    ride: ride,
                    bikes: bikes,
                    routes: routes,
                    allGear: activeGear
                )
            }
            .sheet(item: $rideToComplete) { ride in
                CompleteRideView(ride: ride)
            }
        }
    }
    
    private var headerSubtitle: String {
        if !todayRides.isEmpty {
            return "\(todayRides.count) ride\(todayRides.count > 1 ? "s" : "") scheduled today"
        } else if !upcomingRidesNeedingPrep.isEmpty {
            return "Upcoming rides need preparation"
        } else {
            return "Quick setup for today's ride"
        }
    }
    
    // MARK: - Today's Rides Section
    
    private var todayRidesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Today's Rides")
                    .h2()
                Spacer()
                NavigationLink(destination: RideScheduleView()) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("View All")
                            .captionMedium()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundAccent()
                }
            }
            
            ForEach(todayRides) { ride in
                TodayRideCard(ride: ride) {
                    selectedRide = ride
                }
            }
        }
    }
    
    // MARK: - Prep Needed Section
    
    private var prepNeededSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Preparation Needed")
                    .h3()
                Spacer()
            }
            
            ForEach(upcomingRidesNeedingPrep.prefix(2)) { ride in
                PrepNeededCard(ride: ride) {
                    selectedRide = ride
                }
            }
            
            if upcomingRidesNeedingPrep.count > 2 {
                NavigationLink(destination: RideScheduleView()) {
                    HStack {
                        Text("View \(upcomingRidesNeedingPrep.count - 2) more")
                            .bodyMedium()
                            .foregroundAccent()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DesignSystem.Spacing.sm)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
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
    @State private var showingAddWheelset = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Bike Header
            HStack(alignment: .top) {
                Image(systemName: bikeIcon)
                    .font(.system(size: 40))
                    .foregroundAccent()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(bike.name)
                            .headlineLarge()
                            .foregroundHeadline()
                        
                        // Maintenance indicator
                        if bike.maintenanceDue {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(bike.bikeType.rawValue)
                            .bodySmall()
                            .foregroundStyle(.secondary)
                        
                        Text("   ")
                            .bodySmall()
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "%.0f km", bike.totalMileageKm))
                            .bodySmall()
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
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
                    showingAddWheelset = true
                }) {
                    Label("Add Wheelset", systemImage: "plus.circle")
                        .font(DesignSystem.Typography.labelMedium)
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
            }
            
            // Quick Actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                NavigationLink(destination: BikeMaintenanceView(bike: bike)) {
                    HStack(spacing: 4) {
                        Label("Maintenance", systemImage: "wrench.and.screwdriver")
                            .font(DesignSystem.Typography.labelSmall)
                        if bike.maintenanceDue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 12))
                        }
                    }
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
                
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
        .sheet(isPresented: $showingAddWheelset) {
            WheelsetEditView(bike: bike)
        }
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
                            
                            // Tire health indicator
                            if wheelset.needsAttention {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Text(wheelset.tireDescription)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        
                        // Tire health badges (compact)
                        if wheelset.hasTireTracking {
                            HStack(spacing: 4) {
                                if let front = wheelset.frontTire {
                                    let health = TireHealthService.calculateHealth(for: front)
                                    TireHealthBadge(position: "F", status: health.status, compact: true)
                                }
                                if let rear = wheelset.rearTire {
                                    let health = TireHealthService.calculateHealth(for: rear)
                                    TireHealthBadge(position: "R", status: health.status, compact: true)
                                }
                                
                                Text("   ")
                                    .foregroundStyle(.secondary)
                                
                                Text("\(String(format: "%.0f", wheelset.totalMileageKm)) km")
                                    .captionSmall()
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
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
                    
                    // Tire health section (if tracking is enabled)
                    if wheelset.hasTireTracking {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("TIRE HEALTH")
                                .captionSmall()
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: DesignSystem.Spacing.md) {
                                if let front = wheelset.frontTire {
                                    TireHealthCard(tire: front, position: "Front")
                                }
                                
                                if let rear = wheelset.rearTire {
                                    TireHealthCard(tire: rear, position: "Rear")
                                }
                            }
                            
                            // Quick stats
                            HStack {
                                Label("\(wheelset.totalRides) rides", systemImage: "list.bullet")
                                    .captionMedium()
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                NavigationLink(destination: TireManagementView(wheelset: wheelset)) {
                                    Text("Manage Tires")
                                        .captionMedium()
                                        .foregroundAccent()
                                }
                            }
                        }
                    } else {
                        // Offer to start tracking
                        Divider()
                        
                        NavigationLink(destination: TireManagementView(wheelset: wheelset)) {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundAccent()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Start Tire Tracking")
                                        .bodyMedium()
                                    Text("Monitor mileage and replacement timing")
                                        .captionSmall()
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
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
            ridingStyle: bike.defaultRidingStyle ?? .balanced,
            rimType: wheelset.rimType,
            internalRimWidthMM: wheelset.internalRimWidthMM
        )
        
        wheelset.lastUsed = Date()
    }
}

struct LegacyTireSetupView: View {
    let bike: BikeConfiguration
    let riderWeight: Double
    @Binding var terrain: TirePressureCalculationService.TerrainType
    
    @State private var calculatedPressure: TirePressureCalculationService.PressureResult?
    @State private var showingAddWheelset = false
    
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
                showingAddWheelset = true
            }
            .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
        }
        .sheet(isPresented: $showingAddWheelset) {
            WheelsetEditView(bike: bike)
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

// MARK: - Tire Health Components

struct TireHealthBadge: View {
    let position: String
    let status: TireHealthService.HealthStatus
    let compact: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Text(position)
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
            Text(status.emoji)
                .font(.system(size: compact ? 10 : 12))
        }
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 2 : 4)
        .background(statusColor.opacity(0.15))
        .cornerRadius(DesignSystem.CornerRadius.xs)
    }
    
    private var statusColor: Color {
        switch status.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

struct TireHealthCard: View {
    let tire: TireTracking
    let position: String
    
    var body: some View {
        let health = TireHealthService.calculateHealth(for: tire)
        
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(position)
                    .captionSmall()
                    .foregroundStyle(.secondary)
                Spacer()
                Text(health.status.emoji)
                    .font(.system(size: 16))
            }
            
            Text(tire.displayName)
                .captionMedium()
                .foregroundHeadline()
            
            HStack(spacing: 4) {
                Text("\(String(format: "%.0f", tire.tireMileageKm)) km")
                    .captionSmall()
                    .monospacedDigit()
                Text("   ")
                    .captionSmall()
                    .foregroundStyle(.secondary)
                Text("\(tire.tireAgeDays)d")
                    .captionSmall()
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(statusColor(for: health.status))
                        .frame(width: geometry.size.width * min(1.0, health.mileagePercentage / 100), height: 4)
                }
            }
            .frame(height: 4)
            
            Text(health.status.displayName)
                .captionSmall()
                .foregroundStyle(statusColor(for: health.status))
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.background)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
    
    private func statusColor(for status: TireHealthService.HealthStatus) -> Color {
        switch status.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

#Preview {
    RideDashboardView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, Wheelset.self], inMemory: true)
}
