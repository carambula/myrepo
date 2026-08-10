//
//  LogRideView.swift
//  SpinMin
//
//  Quick ride logging to update tire mileage
//

import SwiftUI
import SwiftData

struct LogRideView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var bikes: [BikeConfiguration]
    
    // Form inputs
    @State private var selectedBike: BikeConfiguration?
    @State private var selectedWheelset: Wheelset?
    @State private var rideDate = Date()
    @State private var distanceKm: Double = 0
    @State private var rideName: String = ""
    @State private var notes: String = ""
    @State private var terrain: TirePressureCalculationService.TerrainType = .pavedSmooth
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Ride Details") {
                    DatePicker("Date", selection: $rideDate, displayedComponents: [.date])
                    
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("0", value: $distanceKm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                    
                    TextField("Ride Name (optional)", text: $rideName)
                }
                
                Section("Bike & Wheels") {
                    Picker("Bike", selection: $selectedBike) {
                        Text("Select Bike").tag(nil as BikeConfiguration?)
                        ForEach(bikes) { bike in
                            Text(bike.name).tag(bike as BikeConfiguration?)
                        }
                    }
                    
                    if let bike = selectedBike {
                        Picker("Wheelset", selection: $selectedWheelset) {
                            Text("Select Wheelset").tag(nil as Wheelset?)
                            ForEach(bike.wheelsets) { wheelset in
                                Text(wheelset.name).tag(wheelset as Wheelset?)
                            }
                        }
                        
                        if let wheelset = selectedWheelset {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Odometer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.1f km", wheelset.totalMileageKm))
                                    .font(.body.monospacedDigit())
                            }
                            
                            if distanceKm > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("New Odometer")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.1f km", wheelset.totalMileageKm + distanceKm))
                                        .font(.body.monospacedDigit())
                                        .foregroundStyle(themeManager.currentTheme.accent)
                                }
                            }
                        }
                    }
                }
                
                Section("Conditions") {
                    Picker("Terrain", selection: $terrain) {
                        ForEach(TirePressureCalculationService.TerrainType.allCases, id: \.self) { terrain in
                            Text(terrain.displayName).tag(terrain)
                        }
                    }
                    
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRide()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        distanceKm > 0 && selectedBike != nil && selectedWheelset != nil
    }
    
    private func saveRide() {
        guard let bike = selectedBike,
              let wheelset = selectedWheelset else {
            return
        }
        
        // Create ride log
        let ride = RideLog(
            rideDate: rideDate,
            distanceKm: distanceKm,
            rideName: rideName.isEmpty ? "Ride" : rideName,
            notes: notes,
            bike: bike,
            wheelset: wheelset,
            terrain: terrain
        )
        
        modelContext.insert(ride)
        
        // Update wheelset odometer and tire tracking
        wheelset.logDistance(distanceKm)
        
        dismiss()
    }
}

// MARK: - Quick Log Button

struct QuickLogRideButton: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var showingLogSheet = false
    
    var body: some View {
        Button {
            showingLogSheet = true
        } label: {
            Label("Log Ride", systemImage: "plus.circle.fill")
                .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(themeManager.currentTheme.accent)
        .sheet(isPresented: $showingLogSheet) {
            LogRideView()
        }
    }
}

#Preview {
    LogRideView()
        .modelContainer(for: [BikeConfiguration.self, Wheelset.self, RideLog.self])
        .environment(ThemeManager.shared)
}
