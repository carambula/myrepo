//
//  TireInspectionView.swift
//  SpinMin
//
//  Manual tire inspection and condition updates
//

import SwiftUI
import SwiftData

struct TireInspectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let wheelset: Wheelset
    let position: TirePosition
    
    @State private var inspectionDate = Date()
    @State private var hasVisibleWear = false
    @State private var hasSquaredProfile = false
    @State private var hasSidewallCracks = false
    @State private var hasCasingExposure = false
    @State private var hasCuts = false
    @State private var punctureCount = 0
    @State private var conditionNotes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                if let tire = wheelset.tireTracking.first(where: { $0.tirePosition == position }) {
                    Section("Current Status") {
                        let health = TireHealthService.calculateHealth(for: tire)
                        
                        HStack {
                            Text("Health Status")
                            Spacer()
                            Text(health.status.emoji + " " + health.status.displayName)
                                .foregroundStyle(statusColor(for: health.status))
                        }
                        
                        HStack {
                            Text("Mileage")
                            Spacer()
                            Text(String(format: "%.0f km", tire.tireMileageKm))
                                .monospacedDigit()
                        }
                        
                        HStack {
                            Text("Wear Percentage")
                            Spacer()
                            Text(String(format: "%.0f%%", health.mileagePercentage))
                                .monospacedDigit()
                        }
                        
                        HStack {
                            Text("Age")
                            Spacer()
                            Text("\(tire.tireAgeDays) days")
                                .monospacedDigit()
                        }
                        
                        if let lastInspection = tire.lastInspectionDate {
                            HStack {
                                Text("Last Inspection")
                                Spacer()
                                Text(lastInspection.formatted(date: .abbreviated, time: .omitted))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section {
                        DatePicker("Inspection Date", selection: $inspectionDate, displayedComponents: [.date])
                        
                        Toggle("Visible Wear", isOn: $hasVisibleWear)
                        Toggle("Squared Profile", isOn: $hasSquaredProfile)
                        Toggle("Sidewall Cracks", isOn: $hasSidewallCracks)
                        Toggle("Casing Exposure", isOn: $hasCasingExposure)
                        Toggle("Cuts", isOn: $hasCuts)
                    } header: {
                        Text("Visual Inspection")
                    } footer: {
                        Text("Check these indicators based on visual inspection. Casing exposure means the tire should be replaced immediately.")
                    }
                    
                    Section {
                        Stepper("Puncture Count: \(punctureCount)", value: $punctureCount, in: 0...50)
                    } header: {
                        Text("Punctures")
                    } footer: {
                        Text("Total number of punctures this tire has experienced")
                    }
                    
                    Section {
                        TextField("Condition notes", text: $conditionNotes, axis: .vertical)
                            .lineLimit(4...8)
                    } header: {
                        Text("Notes")
                    } footer: {
                        Text("Record any additional observations about tire condition")
                    }
                } else {
                    Text("No tire tracking found for this position")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Inspect \(position.displayName) Tire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInspection()
                    }
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    private func loadCurrentValues() {
        guard let tire = wheelset.tireTracking.first(where: { $0.tirePosition == position }) else {
            return
        }
        
        hasVisibleWear = tire.hasVisibleWear
        hasSquaredProfile = tire.hasSquaredProfile
        hasSidewallCracks = tire.hasSidewallCracks
        hasCasingExposure = tire.hasCasingExposure
        hasCuts = tire.hasCuts
        punctureCount = tire.punctureCount
        conditionNotes = tire.conditionNotes
    }
    
    private func saveInspection() {
        guard let tire = wheelset.tireTracking.first(where: { $0.tirePosition == position }) else {
            return
        }
        
        tire.lastInspectionDate = inspectionDate
        tire.hasVisibleWear = hasVisibleWear
        tire.hasSquaredProfile = hasSquaredProfile
        tire.hasSidewallCracks = hasSidewallCracks
        tire.hasCasingExposure = hasCasingExposure
        tire.hasCuts = hasCuts
        tire.punctureCount = punctureCount
        tire.conditionNotes = conditionNotes
        
        dismiss()
    }
    
    private func statusColor(for status: TireHealthService.HealthStatus) -> Color {
        switch status.color {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}

#Preview {
    TireInspectionView(
        wheelset: Wheelset(
            name: "Race Wheels",
            wheelDiameter: .road700c,
            tireWidthMM: 28
        ),
        position: .front
    )
    .environment(ThemeManager.shared)
    .modelContainer(for: [Wheelset.self, TireTracking.self], inMemory: true)
}
