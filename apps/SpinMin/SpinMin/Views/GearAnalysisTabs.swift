//
//  GearAnalysisTabs.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI

// MARK: - Overview Tab

struct OverviewTab: View {
    let analysis: GearCalculationService.GearingAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Gearing Overview")
                .headlineMedium()
                .foregroundHeadline()
            
            // Key Stats
            VStack(spacing: DesignSystem.Spacing.md) {
                StatRow(
                    label: "Total Gears",
                    value: "\(analysis.gearRatios.count)",
                    icon: "gearshape.2"
                )
                
                StatRow(
                    label: "Gear Range",
                    value: String(format: "%.0f%%", analysis.gearRange),
                    icon: "arrow.up.arrow.down"
                )
                
                StatRow(
                    label: "Lowest Gear",
                    value: String(format: "%.1f GI", analysis.lowestRatio.gearInches),
                    detail: "\(analysis.lowestRatio.chainring)-\(analysis.lowestRatio.cog)",
                    icon: "arrow.down.circle"
                )
                
                StatRow(
                    label: "Highest Gear",
                    value: String(format: "%.1f GI", analysis.highestRatio.gearInches),
                    detail: "\(analysis.highestRatio.chainring)-\(analysis.highestRatio.cog)",
                    icon: "arrow.up.circle"
                )
                
                StatRow(
                    label: "Speed Range @ 90 RPM",
                    value: String(format: "%.1f - %.1f km/h", 
                                analysis.lowestRatio.speedAt90RPM,
                                analysis.highestRatio.speedAt90RPM),
                    icon: "speedometer"
                )
                
                StatRow(
                    label: "Average Gap",
                    value: String(format: "%.1f%%", analysis.averageGapPercentage),
                    icon: "chart.bar"
                )
                
                if analysis.largestGapPercentage > 18 {
                    StatRow(
                        label: "Largest Gap",
                        value: String(format: "%.1f%%", analysis.largestGapPercentage),
                        detail: "⚠️ May feel abrupt",
                        icon: "exclamationmark.triangle",
                        isWarning: true
                    )
                }
            }
            
            // Gear Range Visualization
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Gear Range Visualization")
                    .labelMedium()
                
                GeometryReader { geometry in
                    let minGI = analysis.lowestRatio.gearInches
                    let maxGI = analysis.highestRatio.gearInches
                    let range = maxGI - minGI
                    
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(DesignSystem.Color.surface)
                            .frame(height: 24)
                        
                        // Range bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [DesignSystem.Color.accent.opacity(0.6), DesignSystem.Color.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width, height: 24)
                        
                        // Markers
                        HStack {
                            Text(String(format: "%.0f", minGI))
                                .captionSmall()
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.0f", maxGI))
                                .captionSmall()
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                    }
                }
                .frame(height: 24)
                
                HStack {
                    Text("Easier")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Harder")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    let icon: String
    var isWarning: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.IconSize.md))
                .foregroundColor(isWarning ? DesignSystem.Color.warning : DesignSystem.Color.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .bodySmall()
                    .foregroundStyle(.secondary)
                if let detail = detail {
                    Text(detail)
                        .captionSmall()
                        .foregroundColor(isWarning ? DesignSystem.Color.warning : .secondary)
                }
            }
            
            Spacer()
            
            Text(value)
                .bodyMedium()
                .fontWeight(.semibold)
                .foregroundAccent()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Table Tab

struct TableTab: View {
    let analysis: GearCalculationService.GearingAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Complete Gear Table")
                .headlineMedium()
                .foregroundHeadline()
            
            ScrollView {
                VStack(spacing: 2) {
                    // Header
                    HStack {
                        Text("Gear")
                            .frame(width: 60, alignment: .leading)
                        Text("Ratio")
                            .frame(width: 50, alignment: .trailing)
                        Text("GI")
                            .frame(width: 50, alignment: .trailing)
                        Text("@ 90rpm")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    
                    ForEach(analysis.gearRatios) { gear in
                        HStack {
                            Text("\(gear.chainring)-\(gear.cog)")
                                .frame(width: 60, alignment: .leading)
                            Text(String(format: "%.2f", gear.ratio))
                                .frame(width: 50, alignment: .trailing)
                            Text(String(format: "%.1f", gear.gearInches))
                                .frame(width: 50, alignment: .trailing)
                            Text(String(format: "%.1f", gear.speedAt90RPM))
                                .frame(width: 70, alignment: .trailing)
                        }
                        .font(DesignSystem.Typography.captionMedium)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            gear == analysis.lowestRatio || gear == analysis.highestRatio
                            ? DesignSystem.Color.accent.opacity(0.1)
                            : Color.clear
                        )
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Color.surface)
                .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            .frame(maxHeight: 400)
            
            Text("GI = Gear Inches   Speed in km/h")
                .captionSmall()
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Speed Tab

struct SpeedTab: View {
    let analysis: GearCalculationService.GearingAnalysis
    @State private var selectedGear: GearCalculationService.GearRatio?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Speed Analysis")
                .headlineMedium()
                .foregroundHeadline()
            
            // Gear Selector
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Select Gear")
                    .labelMedium()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(analysis.gearRatios) { gear in
                            Button(action: { selectedGear = gear }) {
                                VStack(spacing: 4) {
                                    Text("\(gear.chainring)-\(gear.cog)")
                                        .font(DesignSystem.Typography.labelSmall)
                                    Text(String(format: "%.1f", gear.gearInches))
                                        .font(DesignSystem.Typography.captionSmall)
                                }
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(
                                    selectedGear == gear
                                    ? DesignSystem.Color.accent
                                    : DesignSystem.Color.surface
                                )
                                .foregroundColor(
                                    selectedGear == gear
                                    ? .white
                                    : DesignSystem.Color.textPrimary
                                )
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                            }
                        }
                    }
                }
            }
            
            if let gear = selectedGear {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Speed at Different Cadences")
                        .labelMedium()
                    
                    let speeds = GearCalculationService.calculateSpeedAtCadences(gear: gear)
                    
                    ForEach(speeds, id: \.cadenceRPM) { speed in
                        HStack {
                            Text("\(speed.cadenceRPM) RPM")
                                .bodySmall()
                                .frame(width: 80, alignment: .leading)
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f km/h", speed.speedKPH))
                                    .bodyMedium()
                                    .fontWeight(.semibold)
                                Text(String(format: "%.1f mph", speed.speedMPH))
                                    .captionSmall()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Color.surface)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }
            } else {
                Text("Select a gear to see speed analysis")
                    .bodySmall()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Color.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
        .onAppear {
            selectedGear = analysis.lowestRatio
        }
    }
}

// MARK: - Climbing Tab

struct ClimbingTab: View {
    let analysis: GearCalculationService.GearingAnalysis
    let riderWeight: Double
    let bikeWeight: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Climbing Analysis")
                .headlineMedium()
                .foregroundHeadline()
            
            let climbingAnalysis = GearCalculationService.analyzeClimbing(
                analysis: analysis,
                riderWeightKg: riderWeight,
                bikeWeightKg: bikeWeight
            )
            
            // Lowest Gear Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "arrow.up.hill")
                        .font(.system(size: 48))
                        .foregroundAccent()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Easiest Gear")
                            .labelMedium()
                            .foregroundStyle(.secondary)
                        Text("\(climbingAnalysis.gear.chainring)-\(climbingAnalysis.gear.cog)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundHeadline()
                        Text(String(format: "%.1f Gear Inches", climbingAnalysis.gear.gearInches))
                            .bodySmall()
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                StatRow(
                    label: "Max Climbable Grade",
                    value: String(format: "%.1f%%", climbingAnalysis.maxGradePercent),
                    detail: "At 60 RPM, \(String(format: "%.0f", riderWeight))kg + \(String(format: "%.0f", bikeWeight))kg",
                    icon: "arrow.up.right"
                )
                
                StatRow(
                    label: "Speed at 60 RPM",
                    value: String(format: "%.1f km/h", climbingAnalysis.speedAt60RPM),
                    detail: String(format: "%.1f mph", climbingAnalysis.speedAt60RPM * 0.621371),
                    icon: "speedometer"
                )
                
                Text(climbingAnalysis.description)
                    .bodySmall()
                    .foregroundStyle(.secondary)
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignSystem.Color.surface)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            
            // Context
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Reference Grades")
                    .labelMedium()
                
                VStack(spacing: 4) {
                    GradeReference(grade: 5, description: "Moderate climb")
                    GradeReference(grade: 10, description: "Steep climb")
                    GradeReference(grade: 15, description: "Very steep - hard effort required")
                    GradeReference(grade: 20, description: "Extreme - only with very low gears")
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Color.surface.opacity(0.5))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
}

struct GradeReference: View {
    let grade: Int
    let description: String
    
    var body: some View {
        HStack {
            Text("\(grade)%")
                .captionMedium()
                .fontWeight(.semibold)
                .frame(width: 40, alignment: .leading)
            Text(description)
                .captionSmall()
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let analysis = GearCalculationService.calculateGearRatios(
        chainrings: [40],
        cassette: [11, 13, 15, 17, 19, 21, 24, 28, 32, 36, 44],
        wheelDiameterMM: 622,
        tireWidthMM: 40
    )
    
    return OverviewTab(analysis: analysis)
        .padding()
        .background(DesignSystem.Color.background)
}
