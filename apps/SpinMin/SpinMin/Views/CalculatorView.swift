//
//  CalculatorView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

struct CalculatorView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BikeConfiguration.lastUsed, order: .reverse) private var bikeConfigurations: [BikeConfiguration]
    
    @State private var riderWeightKg: Double = 70
    @State private var selectedBikeConfig: BikeConfiguration?
    @State private var manualBikeType: TirePressureCalculationService.BikeType = .road
    @State private var manualTireWidthMM: Double = 28
    @State private var manualBikeWeightKg: Double?
    @State private var terrain: TirePressureCalculationService.TerrainType = .mixed
    @State private var casing: TirePressureCalculationService.TireCasingType = .standard
    @State private var ridingStyle: TirePressureCalculationService.RidingStyle = .balanced
    @State private var temperatureCelsius: Double?
    @State private var useTemperature = false
    @State private var calculationResult: TirePressureCalculationService.PressureResult?
    @State private var showingUnitPicker = false
    @State private var usePounds = false
    
    private var effectiveBikeType: TirePressureCalculationService.BikeType {
        selectedBikeConfig?.bikeType ?? manualBikeType
    }
    
    private var effectiveTireWidthMM: Double {
        selectedBikeConfig?.tireWidthMM ?? manualTireWidthMM
    }
    
    private var effectiveBikeWeightKg: Double? {
        selectedBikeConfig?.bikeWeightKg ?? manualBikeWeightKg
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .font(.system(size: 48))
                            .foregroundHeadline()
                        
                        Text("Tire Pressure Calculator")
                            .displayMedium()
                            .foregroundHeadline()
                            .multilineTextAlignment(.center)
                        
                        Text("Find your optimal pressure")
                            .bodyMedium()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, DesignSystem.Spacing.xl)
                    
                    // Bike Selection
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        SectionHeaderView(title: "Bike Setup")
                        
                        if !bikeConfigurations.isEmpty {
                            Picker("Bike", selection: $selectedBikeConfig) {
                                Text("Manual Entry").tag(nil as BikeConfiguration?)
                                ForEach(bikeConfigurations) { config in
                                    Text(config.name).tag(config as BikeConfiguration?)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Color.surface)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                        
                        if selectedBikeConfig == nil {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Picker("Bike Type", selection: $manualBikeType) {
                                    ForEach(TirePressureCalculationService.BikeType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(DesignSystem.Spacing.md)
                                .background(DesignSystem.Color.surface)
                                .cornerRadius(DesignSystem.CornerRadius.md)
                                
                                SliderInputView(
                                    title: "Tire Width",
                                    value: $manualTireWidthMM,
                                    range: 18...75,
                                    unit: "mm",
                                    step: 1
                                )
                            }
                        } else {
                            HStack(spacing: DesignSystem.Spacing.md) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text("Type")
                                        .labelSmall()
                                        .foregroundStyle(.secondary)
                                    Text(effectiveBikeType.rawValue)
                                        .bodyMedium()
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                                    Text("Tire Width")
                                        .labelSmall()
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(effectiveTireWidthMM))mm")
                                        .bodyMedium()
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Color.surface)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                    }
                    
                    // Rider Weight
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        SectionHeaderView(title: "Rider")
                        
                        SliderInputView(
                            title: "Weight",
                            value: $riderWeightKg,
                            range: 40...150,
                            unit: "kg",
                            step: 0.5
                        )
                    }
                    
                    // Conditions
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        SectionHeaderView(title: "Conditions")
                        
                        Picker("Terrain", selection: $terrain) {
                            ForEach(TirePressureCalculationService.TerrainType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Color.surface)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        
                        Picker("Tire Casing", selection: $casing) {
                            ForEach(TirePressureCalculationService.TireCasingType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Color.surface)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        
                        Picker("Riding Style", selection: $ridingStyle) {
                            ForEach(TirePressureCalculationService.RidingStyle.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Color.surface)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        
                        Toggle("Include Temperature", isOn: $useTemperature)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Color.surface)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        
                        if useTemperature {
                            SliderInputView(
                                title: "Temperature",
                                value: Binding(
                                    get: { temperatureCelsius ?? 20 },
                                    set: { temperatureCelsius = $0 }
                                ),
                                range: -10...45,
                                unit: "°C",
                                step: 1
                            )
                        }
                    }
                    
                    // Calculate Button
                    Button(action: calculate) {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            Text("Calculate Pressure")
                                .titleMedium()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DesignSystemButtonStyle(variant: .primary, size: .large))
                    .padding(.vertical, DesignSystem.Spacing.md)
                    
                    // Results
                    if let result = calculationResult {
                        PressureResultView(result: result)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Color.background)
        }
    }
    
    private func calculate() {
        let result = TirePressureCalculationService.calculatePressure(
            riderWeightKg: riderWeightKg,
            bikeWeightKg: effectiveBikeWeightKg,
            bikeType: effectiveBikeType,
            tireWidthMM: effectiveTireWidthMM,
            terrain: terrain,
            tireCasing: casing,
            ridingStyle: ridingStyle,
            temperatureCelsius: useTemperature ? temperatureCelsius : nil
        )
        
        calculationResult = result
        
        // Save to history
        let history = CalculationHistory(
            riderWeightKg: riderWeightKg,
            bikeConfiguration: selectedBikeConfig,
            terrain: terrain,
            casing: casing,
            ridingStyle: ridingStyle,
            temperatureCelsius: useTemperature ? temperatureCelsius : nil,
            result: result
        )
        modelContext.insert(history)
        
        // Update bike config last used time
        if let config = selectedBikeConfig {
            config.lastUsed = Date()
        }
    }
}

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .headlineSmall()
            .foregroundHeadline()
    }
}

struct SliderInputView: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let step: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .bodyMedium()
                Spacer()
                Text(String(format: "%.1f \(unit)", value))
                    .bodyMedium()
                    .foregroundAccent()
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(DesignSystem.Color.accent)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

struct PressureResultView: View {
    let result: TirePressureCalculationService.PressureResult
    @State private var usePSI = true
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Recommended Pressure")
                    .headlineMedium()
                    .foregroundHeadline()
                Spacer()
                Button(action: { usePSI.toggle() }) {
                    Text(usePSI ? "PSI" : "BAR")
                        .labelMedium()
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Color.accent.opacity(0.2))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            
            HStack(spacing: DesignSystem.Spacing.xl) {
                // Front
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 32))
                        .foregroundAccent()
                        .rotationEffect(.degrees(-90))
                    
                    Text("FRONT")
                        .overline()
                        .foregroundStyle(.secondary)
                    
                    if usePSI {
                        Text(String(format: "%.1f", result.frontPressurePSI))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundHeadline()
                        Text("PSI")
                            .labelLarge()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: "%.2f", result.frontPressureBAR))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundHeadline()
                        Text("BAR")
                            .labelLarge()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 120)
                
                // Rear
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 32))
                        .foregroundAccent()
                        .rotationEffect(.degrees(90))
                    
                    Text("REAR")
                        .overline()
                        .foregroundStyle(.secondary)
                    
                    if usePSI {
                        Text(String(format: "%.1f", result.rearPressurePSI))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundHeadline()
                        Text("PSI")
                            .labelLarge()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(String(format: "%.2f", result.rearPressureBAR))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundHeadline()
                        Text("BAR")
                            .labelLarge()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            Text("Always check your tire and rim manufacturer's min/max pressure recommendations")
                .captionMedium()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surfaceElevated)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    CalculatorView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self, CalculationHistory.self], inMemory: true)
}
