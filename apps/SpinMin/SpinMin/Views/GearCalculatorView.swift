//
//  GearCalculatorView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

struct GearCalculatorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BikeConfiguration.lastUsed, order: .reverse) private var bikeConfigurations: [BikeConfiguration]
    
    @State private var selectedMode: CalculatorMode = .fresh
    @State private var selectedBikeConfig: BikeConfiguration?
    @State private var selectedPopularDrivetrain: PopularDrivetrain?
    
    // Manual inputs
    @State private var drivetrainType: DrivetrainType = .single
    @State private var smallChainring = 40
    @State private var largeChainring = 52
    @State private var customCassette = [11, 13, 15, 17, 19, 21, 24, 28, 32, 36, 44]
    @State private var wheelSize: WheelSize = .road700c
    @State private var tireWidth = 28
    
    // For analysis
    @State private var riderWeight: Double = 70
    @State private var bikeWeight: Double = 9.5
    
    @State private var analysis: GearCalculationService.GearingAnalysis?
    @State private var selectedTab: AnalysisTab = .overview
    
    enum CalculatorMode: String, CaseIterable {
        case fresh = "New Setup"
        case fromBike = "From My Bike"
        case popular = "Popular Drivetrain"
    }
    
    enum AnalysisTab: String, CaseIterable {
        case overview = "Overview"
        case table = "Table"
        case speed = "Speed"
        case climbing = "Climbing"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode Picker
                Picker("Mode", selection: $selectedMode) {
                    ForEach(CalculatorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.md)
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Input Section
                        inputSection
                        
                        // Calculate Button
                        Button(action: calculate) {
                            HStack {
                                Image(systemName: "gearshape.2")
                                Text("Calculate Gearing")
                                    .titleMedium()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                        
                        // Results
                        if let analysis = analysis {
                            resultsSection(analysis: analysis)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                .background(DesignSystem.Color.background)
            }
            .navigationTitle("Gear Calculator")
        }
    }
    
    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            SectionHeaderView(title: "Drivetrain Setup")
            
            switch selectedMode {
            case .fresh:
                freshInputSection
            case .fromBike:
                fromBikeSection
            case .popular:
                popularDrivetrainSection
            }
            
            // Wheel specs (always shown)
            VStack(spacing: DesignSystem.Spacing.md) {
                Picker("Wheel Size", selection: $wheelSize) {
                    ForEach(WheelSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.md)
                
                HStack {
                    Text("Tire Width")
                    Spacer()
                    Text("\(tireWidth)mm")
                        .foregroundAccent()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.md)
                
                Slider(value: Binding(get: { Double(tireWidth) }, set: { tireWidth = Int($0) }), in: 20...75, step: 1)
                    .tint(DesignSystem.Color.accent)
            }
            
            // Rider/Bike weight for climbing analysis
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("For Climbing Analysis")
                    .captionLarge()
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("Rider: \(String(format: "%.0f", riderWeight))kg")
                    Spacer()
                    Text("Bike: \(String(format: "%.1f", bikeWeight))kg")
                }
                .captionMedium()
                .foregroundStyle(.secondary)
            }
            .padding(DesignSystem.Spacing.sm)
        }
    }
    
    @ViewBuilder
    private var freshInputSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Picker("Drivetrain Type", selection: $drivetrainType) {
                ForEach(DrivetrainType.allCases, id: \.self) { type in
                    Text(type.description).tag(type)
                }
            }
            .pickerStyle(.menu)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.surface)
            .cornerRadius(DesignSystem.CornerRadius.md)
            
            if drivetrainType == .double {
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading) {
                        Text("Large Ring")
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Stepper("\(largeChainring)t", value: $largeChainring, in: 34...56)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.Color.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    
                    VStack(alignment: .leading) {
                        Text("Small Ring")
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Stepper("\(smallChainring)t", value: $smallChainring, in: 28...42)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(DesignSystem.Color.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            } else {
                VStack(alignment: .leading) {
                    Text("Chainring")
                        .captionMedium()
                        .foregroundStyle(.secondary)
                    Stepper("\(smallChainring)t", value: $smallChainring, in: 28...56)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Cassette")
                    .labelMedium()
                Text(customCassette.map { "\($0)" }.joined(separator: "-"))
                    .captionMedium()
                    .foregroundStyle(.secondary)
                
                Button("Edit Cassette") {
                    // Would open cassette editor
                }
                .buttonStyle(DesignSystemButtonStyle(variant: .secondary, size: .small))
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Color.surface)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
    
    @ViewBuilder
    private var fromBikeSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            if bikeConfigurations.filter({ $0.hasGearing }).isEmpty {
                Text("No bikes with gearing configured yet")
                    .bodySmall()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Color.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            } else {
                Picker("Select Bike", selection: $selectedBikeConfig) {
                    Text("Choose a bike...").tag(nil as BikeConfiguration?)
                    ForEach(bikeConfigurations.filter { $0.hasGearing }) { config in
                        Text(config.name).tag(config as BikeConfiguration?)
                    }
                }
                .pickerStyle(.menu)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.md)
                
                if let bike = selectedBikeConfig, bike.hasGearing {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(bike.name)
                            .headlineSmall()
                        
                        if let drivetrain = bike.drivetrainType {
                            if drivetrain == .double, let large = bike.largeChainring {
                                Text("Chainrings: \(large)/\(bike.smallChainring!)t")
                            } else {
                                Text("Chainring: \(bike.smallChainring!)t")
                            }
                        }
                        
                        if let cassette = bike.cassetteTeeth {
                            Text("Cassette: \(cassette.map { "\($0)" }.joined(separator: "-"))")
                        }
                    }
                    .bodySmall()
                    .foregroundStyle(.secondary)
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Color.surfaceElevated)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
        }
    }
    
    @ViewBuilder
    private var popularDrivetrainSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            drivetrainPicker
            
            if let drivetrain = selectedPopularDrivetrain {
                selectedDrivetrainSummary(drivetrain)
            }
        }
    }
    
    private var drivetrainPicker: some View {
        Picker("Select Drivetrain", selection: $selectedPopularDrivetrain) {
            Text("Choose drivetrain...").tag(nil as PopularDrivetrain?)
            
            ForEach(PopularDrivetrain.Manufacturer.allCases, id: \.self) { manufacturer in
                Section(manufacturer.rawValue) {
                    drivetrainOptions(for: manufacturer)
                }
            }
        }
        .pickerStyle(.menu)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private func drivetrainOptions(for manufacturer: PopularDrivetrain.Manufacturer) -> some View {
        let drivetrains = PopularDrivetrain.database.filter { $0.manufacturer == manufacturer }
        return ForEach(drivetrains, id: \.id) { drivetrain in
            Text("\(drivetrain.groupsetName) (\(drivetrain.chainringDescription))")
                .tag(drivetrain as PopularDrivetrain?)
        }
    }
    
    private func selectedDrivetrainSummary(_ drivetrain: PopularDrivetrain) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(drivetrain.displayName)
                    .headlineSmall()
                Spacer()
                Text(drivetrain.category.rawValue)
                    .captionMedium()
                    .foregroundAccent()
            }
            
            Text("\(drivetrain.speeds)-speed   \(drivetrain.chainringDescription)")
                .bodySmall()
                .foregroundStyle(.secondary)
            
            if drivetrain.cassettes.count > 1 {
                Text("Multiple cassette options available")
                    .captionSmall()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    @ViewBuilder
    private func resultsSection(analysis: GearCalculationService.GearingAnalysis) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Tab Picker
            Picker("View", selection: $selectedTab) {
                ForEach(AnalysisTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            
            // Tab Content
            switch selectedTab {
            case .overview:
                OverviewTab(analysis: analysis)
            case .table:
                TableTab(analysis: analysis)
            case .speed:
                SpeedTab(analysis: analysis)
            case .climbing:
                ClimbingTab(analysis: analysis, riderWeight: riderWeight, bikeWeight: bikeWeight)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private func calculate() {
        let chainrings: [Int]
        let cassette: [Int]
        
        switch selectedMode {
        case .fresh:
            chainrings = drivetrainType == .double ? [largeChainring, smallChainring] : [smallChainring]
            cassette = customCassette
            
        case .fromBike:
            guard let bike = selectedBikeConfig, bike.hasGearing else { return }
            if bike.drivetrainType == .double, let large = bike.largeChainring {
                chainrings = [large, bike.smallChainring!]
            } else {
                chainrings = [bike.smallChainring!]
            }
            cassette = bike.cassetteTeeth!
            if let wheel = bike.wheelDiameter {
                wheelSize = wheel
            }
            tireWidth = Int(bike.tireWidthMM)
            
        case .popular:
            guard let drivetrain = selectedPopularDrivetrain else { return }
            chainrings = drivetrain.chainrings
            cassette = drivetrain.cassettes[0]  // Use first cassette option
        }
        
        analysis = GearCalculationService.calculateGearRatios(
            chainrings: chainrings,
            cassette: cassette,
            wheelDiameterMM: wheelSize.bsdMM,
            tireWidthMM: tireWidth
        )
        
        selectedTab = .overview
    }
}

#Preview {
    GearCalculatorView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self], inMemory: true)
}
