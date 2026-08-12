//
//  WheelsetEditView.swift
//  SpinMin
//
//  Create or edit a wheelset: tire specs, weight, and rim details
//  (rim type and internal width affect pressure recommendations)
//

import SwiftUI
import SwiftData

struct WheelsetEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let bike: BikeConfiguration
    let existingWheelset: Wheelset?
    
    @State private var name = ""
    @State private var wheelDiameter: WheelSize = .road700c
    @State private var tireWidthMM = 28
    @State private var tireBrand = ""
    @State private var tireModel = ""
    @State private var tireCasing: TirePressureCalculationService.TireCasingType = .standard
    @State private var weightKg: Double?
    @State private var rimType: TirePressureCalculationService.RimType = .hooked
    @State private var internalRimWidthMM: Double?
    @State private var isDefault = false
    @State private var notes = ""
    
    init(bike: BikeConfiguration, wheelset: Wheelset? = nil) {
        self.bike = bike
        self.existingWheelset = wheelset
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Wheelset") {
                    TextField("Name (e.g. Race Wheels)", text: $name)
                    
                    Picker("Wheel Size", selection: $wheelDiameter) {
                        ForEach(WheelSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    
                    Toggle("Default wheelset", isOn: $isDefault)
                }
                
                Section("Tires") {
                    Stepper("Width: \(tireWidthMM) mm", value: $tireWidthMM, in: 18...127)
                    
                    TextField("Tire brand", text: $tireBrand)
                    TextField("Tire model", text: $tireModel)
                    
                    Picker("Casing", selection: $tireCasing) {
                        ForEach(TirePressureCalculationService.TireCasingType.allCases, id: \.self) { casing in
                            Text(casing.rawValue).tag(casing)
                        }
                    }
                }
                
                Section {
                    Picker("Rim Type", selection: $rimType) {
                        ForEach(TirePressureCalculationService.RimType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    HStack {
                        Text("Internal Rim Width")
                        Spacer()
                        TextField("21", value: $internalRimWidthMM, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("mm")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Rim Details")
                } footer: {
                    Text("Hookless rims cap recommendations at 72.5 psi (ETRTO). Internal width adjusts the effective tire width used in pressure calculations.")
                }
                
                Section("Details") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Optional", value: $weightKg, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(existingWheelset == nil ? "New Wheelset" : "Edit Wheelset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { prefill() }
        }
    }
    
    private func prefill() {
        guard let wheelset = existingWheelset else { return }
        name = wheelset.name
        wheelDiameter = wheelset.wheelDiameter
        tireWidthMM = wheelset.tireWidthMM
        tireBrand = wheelset.tireBrand ?? ""
        tireModel = wheelset.tireModel ?? ""
        tireCasing = wheelset.tireCasing ?? .standard
        weightKg = wheelset.wheelsetWeightKg
        rimType = wheelset.rimType
        internalRimWidthMM = wheelset.internalRimWidthMM
        isDefault = wheelset.isDefault
        notes = wheelset.notes
    }
    
    private func save() {
        if isDefault {
            // Only one default per bike
            for other in bike.wheelsets where other.id != existingWheelset?.id {
                other.isDefault = false
            }
        }
        
        if let wheelset = existingWheelset {
            wheelset.name = name
            wheelset.wheelDiameter = wheelDiameter
            wheelset.tireWidthMM = tireWidthMM
            wheelset.tireBrand = tireBrand.isEmpty ? nil : tireBrand
            wheelset.tireModel = tireModel.isEmpty ? nil : tireModel
            wheelset.tireCasing = tireCasing
            wheelset.wheelsetWeightKg = weightKg
            wheelset.rimType = rimType
            wheelset.internalRimWidthMM = internalRimWidthMM
            wheelset.isDefault = isDefault
            wheelset.notes = notes
        } else {
            let wheelset = Wheelset(
                name: name,
                wheelDiameter: wheelDiameter,
                tireWidthMM: tireWidthMM,
                tireBrand: tireBrand.isEmpty ? nil : tireBrand,
                tireModel: tireModel.isEmpty ? nil : tireModel,
                tireCasing: tireCasing,
                wheelsetWeightKg: weightKg,
                notes: notes,
                isDefault: isDefault || bike.wheelsets.isEmpty
            )
            wheelset.rimType = rimType
            wheelset.internalRimWidthMM = internalRimWidthMM
            wheelset.bikeConfiguration = bike
            modelContext.insert(wheelset)
            bike.wheelsets.append(wheelset)
        }
        
        dismiss()
    }
}
