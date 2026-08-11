//
//  ReplaceTireView.swift
//  SpinMin
//
//  Replace a tire - archive old tire to history and start new tracking
//

import SwiftUI
import SwiftData

struct ReplaceTireView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    let position: TirePosition
    
    @State private var removeDate = Date()
    @State private var removalReason: RemovalReason = .worn
    @State private var conditionNotes: String = ""
    
    // New tire details
    @State private var newTireBrand: String = ""
    @State private var newTireModel: String = ""
    @State private var newCompoundType: TireCompoundType = .training
    @State private var installDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                if let currentTire = wheelset.tireTracking.first(where: { $0.tirePosition == position }) {
                    Section("Current Tire") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentTire.displayName)
                                .bodyLarge()
                                .foregroundHeadline()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Mileage")
                                        .captionSmall()
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.0f km", currentTire.tireMileageKm))
                                        .bodyMedium()
                                        .monospacedDigit()
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Age")
                                        .captionSmall()
                                        .foregroundStyle(.secondary)
                                    Text("\(currentTire.tireAgeDays) days")
                                        .bodyMedium()
                                        .monospacedDigit()
                                }
                                
                                Spacer()
                                
                                let health = TireHealthService.calculateHealth(for: currentTire)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status")
                                        .captionSmall()
                                        .foregroundStyle(.secondary)
                                    Text(health.status.emoji + " " + health.status.displayName)
                                        .bodyMedium()
                                }
                            }
                        }
                    }
                    
                    Section("Removal Details") {
                        DatePicker("Removal Date", selection: $removeDate, displayedComponents: [.date])
                        
                        Picker("Reason", selection: $removalReason) {
                            ForEach(RemovalReason.allCases, id: \.self) { reason in
                                Text(reason.displayName).tag(reason)
                            }
                        }
                        
                        TextField("Condition Notes (optional)", text: $conditionNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }
                
                Section("New Tire") {
                    TextField("Brand", text: $newTireBrand)
                    TextField("Model", text: $newTireModel)
                    
                    Picker("Compound Type", selection: $newCompoundType) {
                        ForEach(TireCompoundType.allCases, id: \.self) { compound in
                            Text(compound.displayName).tag(compound)
                        }
                    }
                    
                    Text(newCompoundType.description)
                        .captionMedium()
                        .foregroundStyle(.secondary)
                    
                    DatePicker("Install Date", selection: $installDate, displayedComponents: [.date])
                }
            }
            .navigationTitle("Replace \(position.displayName) Tire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace") {
                        replaceTire()
                    }
                    .disabled(newTireBrand.isEmpty || newTireModel.isEmpty)
                }
            }
        }
    }
    
    private func replaceTire() {
        guard let currentTire = wheelset.tireTracking.first(where: { $0.tirePosition == position }) else {
            return
        }
        
        // Archive current tire to history
        let history = TireHistory(
            from: currentTire,
            removeDate: removeDate,
            removalReason: removalReason,
            conditionNotes: conditionNotes
        )
        modelContext.insert(history)
        wheelset.tireHistory.append(history)
        
        // Remove current tire tracking
        modelContext.delete(currentTire)
        
        // Add new tire tracking
        let newTracking = TireTracking(
            position: position,
            tireBrand: newTireBrand,
            tireModel: newTireModel,
            compoundType: newCompoundType,
            installDate: installDate,
            initialMileageKm: wheelset.totalMileageKm,
            expectedLifespanKm: nil  // Use default based on compound
        )
        
        modelContext.insert(newTracking)
        wheelset.tireTracking.append(newTracking)
        
        dismiss()
    }
}

#Preview {
    ReplaceTireView(
        wheelset: Wheelset(
            name: "Race Wheels",
            wheelDiameter: .road700c,
            tireWidthMM: 28
        ),
        position: .front
    )
    .environment(ThemeManager.shared)
    .modelContainer(for: [Wheelset.self, TireTracking.self, TireHistory.self], inMemory: true)
}
