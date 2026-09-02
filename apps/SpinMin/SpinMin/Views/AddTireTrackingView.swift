//
//  AddTireTrackingView.swift
//  SpinMin
//
//  Add new tire tracking
//

import SwiftUI
import SwiftData

struct AddTireTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    
    @State private var position: TirePosition = .front
    @State private var tireBrand: String = ""
    @State private var tireModel: String = ""
    @State private var compoundType: TireCompoundType = .training
    @State private var installDate = Date()
    @State private var initialMileage: Double = 0
    @State private var customLifespan: Double? = nil
    @State private var useCustomLifespan = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    Picker("Tire Position", selection: $position) {
                        ForEach(TirePosition.allCases) { pos in
                            Text(pos.displayName).tag(pos)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if existingTire != nil {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("This will replace existing \(position.displayName.lowercased()) tire tracking")
                                .captionMedium()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section("Tire Details") {
                    TextField("Brand", text: $tireBrand)
                    TextField("Model", text: $tireModel)
                    
                    Picker("Compound Type", selection: $compoundType) {
                        ForEach(TireCompoundType.allCases, id: \.self) { compound in
                            Text(compound.displayName).tag(compound)
                        }
                    }
                    
                    Text(compoundType.description)
                        .captionMedium()
                        .foregroundStyle(.secondary)
                }
                
                Section("Installation") {
                    DatePicker("Install Date", selection: $installDate, displayedComponents: [.date])
                    
                    HStack {
                        Text("Wheelset Odometer at Install")
                        Spacer()
                        TextField("0", value: $initialMileage, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Current: \(String(format: "%.1f km", wheelset.totalMileageKm))")
                        .captionSmall()
                        .foregroundStyle(.secondary)
                }
                
                Section {
                    Toggle("Custom Expected Lifespan", isOn: $useCustomLifespan)
                    
                    if useCustomLifespan {
                        HStack {
                            Text("Expected Lifespan")
                            Spacer()
                            TextField(String(format: "%.0f", compoundType.defaultLifespanKm(for: position)), value: $customLifespan, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("km")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Expected Lifespan")
                } footer: {
                    Text("Default: \(String(format: "%.0f km", compoundType.defaultLifespanKm(for: position))) based on \(compoundType.displayName) compound")
                        .captionSmall()
                }
            }
            .navigationTitle("Add Tire Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTireTracking()
                    }
                    .disabled(tireBrand.isEmpty || tireModel.isEmpty)
                }
            }
        }
    }
    
    private var existingTire: TireTracking? {
        wheelset.tireTracking.first { $0.tirePosition == position }
    }
    
    private func addTireTracking() {
        // If replacing existing, remove it first
        if let existing = existingTire {
            modelContext.delete(existing)
        }
        
        let tracking = TireTracking(
            position: position,
            tireBrand: tireBrand,
            tireModel: tireModel,
            compoundType: compoundType,
            installDate: installDate,
            initialMileageKm: initialMileage > 0 ? initialMileage : wheelset.totalMileageKm,
            expectedLifespanKm: useCustomLifespan ? customLifespan : nil
        )
        
        modelContext.insert(tracking)
        wheelset.tireTracking.append(tracking)
        
        dismiss()
    }
}

#Preview {
    AddTireTrackingView(wheelset: Wheelset(
        name: "Race Wheels",
        wheelDiameter: .road700c,
        tireWidthMM: 28
    ))
    .environment(ThemeManager.shared)
    .modelContainer(for: [Wheelset.self, TireTracking.self], inMemory: true)
}
