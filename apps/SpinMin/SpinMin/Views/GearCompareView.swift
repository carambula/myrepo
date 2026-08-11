//
//  GearCompareView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

struct GearCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \BikeConfiguration.lastUsed, order: .reverse) private var bikeConfigurations: [BikeConfiguration]
    
    let primaryBike: BikeConfiguration
    @State private var comparisonBike: BikeConfiguration?
    @State private var primaryAnalysis: GearCalculationService.GearingAnalysis?
    @State private var comparisonAnalysis: GearCalculationService.GearingAnalysis?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Primary Bike (Fixed)
                    BikeGearingSummary(
                        bike: primaryBike,
                        analysis: primaryAnalysis,
                        isPrimary: true
                    )
                    
                    // VS Divider
                    HStack {
                        Rectangle()
                            .fill(DesignSystem.Color.border)
                            .frame(height: 1)
                        
                        Text("VS")
                            .titleLarge()
                            .foregroundAccent()
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        
                        Rectangle()
                            .fill(DesignSystem.Color.border)
                            .frame(height: 1)
                    }
                    
                    // Comparison Bike Selector
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Picker("Compare With", selection: $comparisonBike) {
                            Text("Select a bike...").tag(nil as BikeConfiguration?)
                            ForEach(bikeConfigurations.filter { $0.hasGearing && $0.id != primaryBike.id }) { config in
                                Text(config.name).tag(config as BikeConfiguration?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Color.surface)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        
                        if let comparison = comparisonBike {
                            BikeGearingSummary(
                                bike: comparison,
                                analysis: comparisonAnalysis,
                                isPrimary: false
                            )
                        }
                    }
                    
                    // Comparison Results
                    if let primary = primaryAnalysis, let comparison = comparisonAnalysis {
                        comparisonResults(primary: primary, comparison: comparison)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Color.background)
            .navigationTitle("Compare Gearing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            calculatePrimaryAnalysis()
        }
        .onChange(of: comparisonBike) { _, newBike in
            if let bike = newBike {
                calculateComparisonAnalysis(bike: bike)
            } else {
                comparisonAnalysis = nil
            }
        }
    }
    
    @ViewBuilder
    private func comparisonResults(primary: GearCalculationService.GearingAnalysis, comparison: GearCalculationService.GearingAnalysis) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Analysis")
                .headlineMedium()
                .foregroundHeadline()
            
            ComparisonRow(
                label: "Total Gears",
                primaryValue: "\(primary.gearRatios.count)",
                comparisonValue: "\(comparison.gearRatios.count)",
                higherIsBetter: true
            )
            
            ComparisonRow(
                label: "Gear Range",
                primaryValue: String(format: "%.0f%%", primary.gearRange),
                comparisonValue: String(format: "%.0f%%", comparison.gearRange),
                higherIsBetter: true
            )
            
            ComparisonRow(
                label: "Lowest Gear",
                primaryValue: String(format: "%.1f GI", primary.lowestRatio.gearInches),
                comparisonValue: String(format: "%.1f GI", comparison.lowestRatio.gearInches),
                higherIsBetter: false,
                note: "Lower = easier climbing"
            )
            
            ComparisonRow(
                label: "Highest Gear",
                primaryValue: String(format: "%.1f GI", primary.highestRatio.gearInches),
                comparisonValue: String(format: "%.1f GI", comparison.highestRatio.gearInches),
                higherIsBetter: true,
                note: "Higher = faster top speed"
            )
            
            ComparisonRow(
                label: "Average Gap",
                primaryValue: String(format: "%.1f%%", primary.averageGapPercentage),
                comparisonValue: String(format: "%.1f%%", comparison.averageGapPercentage),
                higherIsBetter: false,
                note: "Lower = smoother shifts"
            )
            
            // Text Summary
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Summary")
                    .labelMedium()
                
                let summary = GearCalculationService.compare(
                    primary,
                    comparison,
                    setup1Name: primaryBike.name,
                    setup2Name: comparisonBike?.name ?? "Comparison"
                )
                
                Text(summary)
                    .bodySmall()
                    .foregroundStyle(.secondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.surfaceElevated)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
    
    private func calculatePrimaryAnalysis() {
        guard primaryBike.hasGearing else { return }
        
        let chainrings: [Int]
        if primaryBike.drivetrainType == .double, let large = primaryBike.largeChainring {
            chainrings = [large, primaryBike.smallChainring!]
        } else {
            chainrings = [primaryBike.smallChainring!]
        }
        
        primaryAnalysis = GearCalculationService.calculateGearRatios(
            chainrings: chainrings,
            cassette: primaryBike.cassetteTeeth!,
            wheelDiameterMM: primaryBike.wheelDiameter?.bsdMM ?? 622,
            tireWidthMM: Int(primaryBike.tireWidthMM)
        )
    }
    
    private func calculateComparisonAnalysis(bike: BikeConfiguration) {
        guard bike.hasGearing else { return }
        
        let chainrings: [Int]
        if bike.drivetrainType == .double, let large = bike.largeChainring {
            chainrings = [large, bike.smallChainring!]
        } else {
            chainrings = [bike.smallChainring!]
        }
        
        comparisonAnalysis = GearCalculationService.calculateGearRatios(
            chainrings: chainrings,
            cassette: bike.cassetteTeeth!,
            wheelDiameterMM: bike.wheelDiameter?.bsdMM ?? 622,
            tireWidthMM: Int(bike.tireWidthMM)
        )
    }
}

struct BikeGearingSummary: View {
    let bike: BikeConfiguration
    let analysis: GearCalculationService.GearingAnalysis?
    let isPrimary: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "bicycle")
                    .font(.system(size: 32))
                    .foregroundAccent()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bike.name)
                        .headlineSmall()
                        .foregroundHeadline()
                    
                    if bike.hasGearing {
                        if bike.drivetrainType == .double, let large = bike.largeChainring {
                            Text("\(large)/\(bike.smallChainring!)t × \(bike.cassetteTeeth!.first!)-\(bike.cassetteTeeth!.last!)")
                        } else {
                            Text("\(bike.smallChainring!)t × \(bike.cassetteTeeth!.first!)-\(bike.cassetteTeeth!.last!)")
                        }
                    }
                }
                .bodySmall()
                .foregroundStyle(.secondary)
            }
            
            if let analysis = analysis {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    QuickStat(label: "Range", value: String(format: "%.0f%%", analysis.gearRange))
                    QuickStat(label: "Low", value: String(format: "%.1f GI", analysis.lowestRatio.gearInches))
                    QuickStat(label: "High", value: String(format: "%.1f GI", analysis.highestRatio.gearInches))
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(isPrimary ? DesignSystem.Color.accent.opacity(0.1) : DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }
}

struct QuickStat: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .bodySmall()
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bodyMedium()
                .fontWeight(.semibold)
        }
    }
}

struct ComparisonRow: View {
    let label: String
    let primaryValue: String
    let comparisonValue: String
    let higherIsBetter: Bool
    var note: String? = nil
    
    private var winner: Int {
        // 0 = tie, 1 = primary better, 2 = comparison better
        guard let pVal = Double(primaryValue.replacingOccurrences(of: "%", with: "")),
              let cVal = Double(comparisonValue.replacingOccurrences(of: "%", with: "")) else {
            return 0
        }
        
        if abs(pVal - cVal) < 0.1 { return 0 }
        
        if higherIsBetter {
            return pVal > cVal ? 1 : 2
        } else {
            return pVal < cVal ? 1 : 2
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .labelMedium()
            
            HStack {
                HStack {
                    Text(primaryValue)
                        .bodyMedium()
                        .fontWeight(winner == 1 ? .bold : .regular)
                    if winner == 1 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Color.success)
                    }
                }
                .frame(maxWidth: .infinity)
                
                HStack {
                    Text(comparisonValue)
                        .bodyMedium()
                        .fontWeight(winner == 2 ? .bold : .regular)
                    if winner == 2 {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Color.success)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            if let note = note {
                Text(note)
                    .captionSmall()
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

#Preview {
    let config = PreviewSampleData.mockModelContainer
    let context = config.mainContext
    
    let bike1 = BikeConfiguration(
        name: "Gravel Bike",
        bikeType: .gravel,
        tireWidthMM: 40
    )
    bike1.drivetrainType = .single
    bike1.smallChainring = 40
    bike1.cassetteTeeth = [11, 13, 15, 17, 19, 21, 24, 28, 32, 36, 44]
    bike1.wheelDiameter = .road700c
    
    return GearCompareView(primaryBike: bike1)
        .environment(ThemeManager.shared)
        .modelContainer(config)
}

struct PreviewSampleData {
    static var mockModelContainer: ModelContainer = {
        let schema = Schema([BikeConfiguration.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return container
    }()
}
