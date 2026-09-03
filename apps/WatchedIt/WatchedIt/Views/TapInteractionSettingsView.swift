//
//  TapInteractionSettingsView.swift
//  WatchedIt
//
//  Created by Cursor on 3/2/26.
//

import SwiftUI

struct TapInteractionSettingsView: View {
    @AppStorage("tapInteractionStyle") private var tapStyleRaw: String = TapInteractionStyle.bounce.rawValue
    @AppStorage(TapInteractionParameters.storageKey) private var parametersData: Data = TapInteractionParameters().encode()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var parameters: TapInteractionParameters = TapInteractionParameters()
    @State private var isDemoPressed = false
    
    private var selectedStyle: TapInteractionStyle {
        TapInteractionStyle(rawValue: tapStyleRaw) ?? .bounce
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Style selector
                styleSelector
                
                // Demo area
                demoArea
                
                // Parameters for selected style
                parametersSection
            }
            .settingsScreenStyle()
        }
        .background(DesignSystem.Color.background.ignoresSafeArea())
        .navigationTitle("Tap Interactions")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            parameters = TapInteractionParameters.decode(from: parametersData)
        }
        .onChange(of: parameters.bounceScale) { _, _ in saveParameters() }
        .onChange(of: parameters.bounceShakeIntensity) { _, _ in saveParameters() }
        .onChange(of: parameters.bounceDuration) { _, _ in saveParameters() }
        .onChange(of: parameters.rippleSpeed) { _, _ in saveParameters() }
        .onChange(of: parameters.rippleAmplitude) { _, _ in saveParameters() }
        .onChange(of: parameters.rippleFrequency) { _, _ in saveParameters() }
        .onChange(of: parameters.shimmerIntensity) { _, _ in saveParameters() }
        .onChange(of: parameters.shimmerSpeed) { _, _ in saveParameters() }
        .onChange(of: parameters.shimmerParticleCount) { _, _ in saveParameters() }
        .onChange(of: parameters.glowIntensity) { _, _ in saveParameters() }
        .onChange(of: parameters.glowPulseSpeed) { _, _ in saveParameters() }
        .onChange(of: parameters.glowColorIntensity) { _, _ in saveParameters() }
    }
    
    // MARK: - Style Selector
    
    @ViewBuilder
    private var styleSelector: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Interaction Style")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            
            ForEach(TapInteractionStyle.allCases, id: \.rawValue) { style in
                Button {
                    tapStyleRaw = style.rawValue
                } label: {
                    SettingsOptionRow(
                        icon: style.icon,
                        title: style.rawValue,
                        description: style.description,
                        isSelected: selectedStyle == style
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Demo Area
    
    @ViewBuilder
    private var demoArea: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Try It Out")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            
            Button {
                // Demo action
            } label: {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .font(DesignSystem.Typography.iconLarge)
                    
                    Text("Tap to Test Effect")
                        .headlineMedium()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Color.accent)
                )
            }
            .interactiveTapStyle(
                style: selectedStyle,
                parameters: parameters,
                accentColor: DesignSystem.Color.accent
            )
        }
    }
    
    // MARK: - Parameters Section
    
    @ViewBuilder
    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Parameters")
                .headlineMedium()
                .foregroundColor(DesignSystem.Color.textPrimary)
            
            switch selectedStyle {
            case .classic:
                classicParameters
            case .bounce:
                bounceParameters
            case .ripple:
                rippleParameters
            case .shimmer:
                shimmerParameters
            case .glowPulse:
                glowPulseParameters
            }
        }
    }
    
    // MARK: - Bounce Parameters
    
    @ViewBuilder
    private var classicParameters: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Classic style mirrors the original tap behavior with a simple pressed opacity fade.")
                .bodyMedium()
                .foregroundColor(DesignSystem.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.surface)
        )
    }
    
    @ViewBuilder
    private var bounceParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ParameterSlider(
                title: "Recess Scale",
                value: $parameters.bounceScale,
                range: 0.7...0.98,
                description: "How much the element shrinks when pressed"
            )
            
            ParameterSlider(
                title: "Shake Intensity",
                value: $parameters.bounceShakeIntensity,
                range: 0.0...1.0,
                description: "Strength of the shake on release"
            )
            
            ParameterSlider(
                title: "Duration",
                value: $parameters.bounceDuration,
                range: 0.1...0.6,
                description: "Speed of the bounce animation"
            )
        }
    }
    
    // MARK: - Ripple Parameters
    
    @ViewBuilder
    private var rippleParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ParameterSlider(
                title: "Ripple Speed",
                value: $parameters.rippleSpeed,
                range: 0.5...2.0,
                description: "How fast the ripple expands"
            )
            
            ParameterSlider(
                title: "Amplitude",
                value: $parameters.rippleAmplitude,
                range: 0.2...1.5,
                description: "Thickness of the ripple rings"
            )
            
            ParameterSlider(
                title: "Frequency",
                value: $parameters.rippleFrequency,
                range: 0.5...3.0,
                description: "Number of concurrent ripple waves"
            )
        }
    }
    
    // MARK: - Shimmer Parameters
    
    @ViewBuilder
    private var shimmerParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ParameterSlider(
                title: "Intensity",
                value: $parameters.shimmerIntensity,
                range: 0.3...1.0,
                description: "Brightness of the sparkle particles"
            )
            
            ParameterSlider(
                title: "Speed",
                value: $parameters.shimmerSpeed,
                range: 0.5...2.0,
                description: "How fast particles rise and fade"
            )
            
            ParameterSlider(
                title: "Particle Count",
                value: $parameters.shimmerParticleCount,
                range: 0.3...1.0,
                description: "Number of sparkle particles"
            )
        }
    }
    
    // MARK: - Glow Pulse Parameters
    
    @ViewBuilder
    private var glowPulseParameters: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ParameterSlider(
                title: "Glow Intensity",
                value: $parameters.glowIntensity,
                range: 0.3...1.0,
                description: "Brightness of the glowing outline"
            )
            
            ParameterSlider(
                title: "Pulse Speed",
                value: $parameters.glowPulseSpeed,
                range: 0.5...2.0,
                description: "How fast the glow pulse expands"
            )
            
            ParameterSlider(
                title: "Color Intensity",
                value: $parameters.glowColorIntensity,
                range: 0.3...1.0,
                description: "Saturation of the accent color"
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveParameters() {
        parametersData = parameters.encode()
    }
}

// MARK: - Parameter Slider Component

struct ParameterSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .bodyMedium()
                    .foregroundColor(DesignSystem.Color.textPrimary)
                
                Spacer()
                
                Text(String(format: "%.2f", value))
                    .bodySmall()
                    .foregroundColor(DesignSystem.Color.accent)
                    .monospacedDigit()
            }
            
            Slider(value: $value, in: range)
                .tint(DesignSystem.Color.accent)
            
            Text(description)
                .bodySmall()
                .foregroundColor(DesignSystem.Color.textSecondary)
                .lineLimit(2)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Color.surface)
        )
    }
}
