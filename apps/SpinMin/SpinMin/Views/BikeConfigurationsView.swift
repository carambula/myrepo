//
//  BikeConfigurationsView.swift
//  SpinMin
//
//  Created by Cloud Agent on 8/10/26.
//

import SwiftUI
import SwiftData

struct BikeConfigurationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \BikeConfiguration.lastUsed, order: .reverse) private var bikeConfigurations: [BikeConfiguration]
    @State private var showingAddBike = false
    
    var body: some View {
        NavigationStack {
            Group {
                if bikeConfigurations.isEmpty {
                    emptyStateView
                } else {
                    bikeListView
                }
            }
            .navigationTitle("My Bikes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddBike = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBike) {
                AddBikeConfigurationView()
            }
            .background(DesignSystem.Color.background)
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
            
            Text("Add your bikes to quickly calculate tire pressure for each one")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bikeListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                ForEach(bikeConfigurations) { config in
                    BikeConfigurationCard(configuration: config)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteBike(config)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenHorizontalPadding)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
    
    private func deleteBike(_ config: BikeConfiguration) {
        modelContext.delete(config)
    }
}

struct BikeConfigurationCard: View {
    let configuration: BikeConfiguration
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(alignment: .top) {
                Image(systemName: bikeTypeIcon(configuration.bikeType))
                    .font(.system(size: 32))
                    .foregroundAccent()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(configuration.name)
                        .headlineSmall()
                        .foregroundHeadline()
                    
                    Text(configuration.bikeType.rawValue)
                        .bodySmall()
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            HStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Tire Width")
                        .captionMedium()
                        .foregroundStyle(.secondary)
                    Text("\(Int(configuration.tireWidthMM))mm")
                        .bodyMedium()
                }
                
                if let weight = configuration.bikeWeightKg {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Bike Weight")
                            .captionMedium()
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1fkg", weight))
                            .bodyMedium()
                    }
                }
                
                Spacer()
            }
            
            if !configuration.notes.isEmpty {
                Text(configuration.notes)
                    .captionMedium()
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
            
            Text("Last used \(configuration.lastUsed.formatted(date: .abbreviated, time: .omitted))")
                .captionSmall()
                .foregroundStyle(.tertiary)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Color.surface)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    private func bikeTypeIcon(_ type: TirePressureCalculationService.BikeType) -> String {
        switch type {
        case .road: return "bicycle"
        case .gravel: return "bicycle.circle"
        case .mountainXC, .mountainTrail, .mountainEnduro: return "figure.outdoor.cycle"
        case .fat: return "snow"
        }
    }
}

struct AddBikeConfigurationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var bikeType: TirePressureCalculationService.BikeType = .road
    @State private var tireWidthMM: Double = 28
    @State private var bikeWeightKg: Double?
    @State private var useBikeWeight = false
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bike Details") {
                    TextField("Name (e.g., Road Bike, Gravel Bike)", text: $name)
                    
                    Picker("Bike Type", selection: $bikeType) {
                        ForEach(TirePressureCalculationService.BikeType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                
                Section("Tire Specs") {
                    HStack {
                        Text("Tire Width")
                        Spacer()
                        Text("\(Int(tireWidthMM))mm")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $tireWidthMM, in: 18...75, step: 1)
                }
                
                Section {
                    Toggle("Specify Bike Weight", isOn: $useBikeWeight)
                    
                    if useBikeWeight {
                        HStack {
                            Text("Bike Weight")
                            Spacer()
                            Text(String(format: "%.1fkg", bikeWeightKg ?? 10))
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { bikeWeightKg ?? 10 },
                            set: { bikeWeightKg = $0 }
                        ), in: 6...20, step: 0.5)
                    }
                } footer: {
                    Text("If not specified, a typical weight for this bike type will be used")
                }
                
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Bike")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBike()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveBike() {
        let config = BikeConfiguration(
            name: name,
            bikeType: bikeType,
            tireWidthMM: tireWidthMM,
            bikeWeightKg: useBikeWeight ? bikeWeightKg : nil,
            notes: notes
        )
        modelContext.insert(config)
        dismiss()
    }
}

#Preview {
    BikeConfigurationsView()
        .environment(ThemeManager.shared)
        .modelContainer(for: [BikeConfiguration.self], inMemory: true)
}
