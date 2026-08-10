//
//  QuickLogMaintenanceView.swift
//  SpinMin
//
//  Quick maintenance logging for common actions
//

import SwiftUI
import SwiftData

struct QuickLogMaintenanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let bike: BikeConfiguration
    let maintenanceType: MaintenanceType
    
    @State private var maintenanceDate = Date()
    @State private var notes = ""
    @State private var chainWearPercentage: Double = 0.0
    @State private var newChainBrand = ""
    @State private var newChainModel = ""
    @State private var lubeType: ChainLubeType = .hotWax
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $maintenanceDate, displayedComponents: [.date])
                    
                    HStack {
                        Text("Bike Odometer")
                        Spacer()
                        Text(String(format: "%.1f km", bike.totalMileageKm))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Chain-specific fields
                if maintenanceType == .chainReplace {
                    Section("New Chain") {
                        TextField("Brand", text: $newChainBrand)
                        TextField("Model", text: $newChainModel)
                        
                        Picker("Lube Type", selection: $lubeType) {
                            ForEach(ChainLubeType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        
                        Text(lubeType.description)
                            .captionMedium()
                            .foregroundStyle(.secondary)
                    }
                    
                    if let oldChain = bike.currentChain {
                        Section("Old Chain Stats") {
                            HStack {
                                Text("Total Mileage")
                                Spacer()
                                Text(String(format: "%.0f km", oldChain.componentMileageKm))
                                    .monospacedDigit()
                            }
                            
                            HStack {
                                Text("Age")
                                Spacer()
                                Text("\(oldChain.componentAgeDays) days")
                                    .monospacedDigit()
                            }
                            
                            HStack {
                                Text("Final Wear")
                                TextField("0.50", value: $chainWearPercentage, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text("%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(maintenanceType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMaintenanceQuick()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        if maintenanceType == .chainReplace {
            return !newChainBrand.isEmpty && !newChainModel.isEmpty
        }
        return true
    }
    
    private func saveMaintenanceQuick() {
        // Handle chain replacement specially
        if maintenanceType == .chainReplace {
            // Archive old chain to maintenance history
            if let oldChain = bike.currentChain {
                let record = MaintenanceRecord(
                    maintenanceType: .chainReplace,
                    date: maintenanceDate,
                    bikeOdometerKm: bike.totalMileageKm,
                    componentBrand: oldChain.brand,
                    componentModel: oldChain.model,
                    componentType: .chain,
                    notes: notes.isEmpty ? "Replaced chain. Wear: \(String(format: "%.2f%%", chainWearPercentage))" : notes,
                    performedBy: nil,
                    isReplacement: true,
                    replacedAtOdometerKm: oldChain.installOdometerKm
                )
                modelContext.insert(record)
                bike.maintenanceRecords.append(record)
                
                // Remove old chain tracking
                modelContext.delete(oldChain)
            }
            
            // Add new chain tracking
            let newChain = ComponentTracking(
                componentType: .chain,
                brand: newChainBrand,
                model: newChainModel,
                installDate: maintenanceDate,
                installOdometerKm: bike.totalMileageKm,
                notes: notes
            )
            newChain.lubeType = lubeType
            newChain.chainWearPercentage = 0.0
            
            modelContext.insert(newChain)
            bike.componentTracking.append(newChain)
            
        } else {
            // Regular maintenance logging
            let record = MaintenanceRecord(
                maintenanceType: maintenanceType,
                date: maintenanceDate,
                bikeOdometerKm: bike.totalMileageKm,
                notes: notes,
                performedBy: nil
            )
            modelContext.insert(record)
            bike.maintenanceRecords.append(record)
            
            // Update chain tracking for wax/clean
            if let chain = bike.currentChain {
                if maintenanceType == .chainWax || maintenanceType == .chainLube {
                    chain.recordWax(date: maintenanceDate, odometerKm: bike.totalMileageKm)
                } else if maintenanceType == .chainClean {
                    chain.recordClean(date: maintenanceDate, odometerKm: bike.totalMileageKm)
                }
            }
        }
        
        dismiss()
    }
}

#Preview {
    QuickLogMaintenanceView(
        bike: BikeConfiguration(
            name: "Road Bike",
            bikeType: .road,
            tireWidthMM: 28
        ),
        maintenanceType: .chainWax
    )
    .environment(ThemeManager.shared)
    .modelContainer(for: [BikeConfiguration.self, MaintenanceRecord.self], inMemory: true)
}
