//
//  CompleteRideView.swift
//  SpinMin
//
//  Manually complete a scheduled ride: record actuals and log the ride
//  so bike, tire, and component mileage stays accurate. Rides synced
//  from Strava complete automatically; this covers everything else.
//

import SwiftUI
import SwiftData

struct CompleteRideView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let ride: ScheduledRide
    
    @Query private var bikes: [BikeConfiguration]
    
    @State private var actualDistanceKm: Double = 0
    @State private var actualHours: Int = 1
    @State private var actualMinutes: Int = 0
    @State private var selectedBike: BikeConfiguration?
    @State private var selectedWheelset: Wheelset?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Distance")
                        Spacer()
                        TextField("km", value: $actualDistanceKm, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("km")
                            .foregroundStyle(.secondary)
                    }
                    
                    Picker("Hours", selection: $actualHours) {
                        ForEach(0..<13, id: \.self) { Text("\($0) h").tag($0) }
                    }
                    Picker("Minutes", selection: $actualMinutes) {
                        ForEach([0, 15, 30, 45], id: \.self) { Text("\($0) min").tag($0) }
                    }
                } header: {
                    Text("Actual Ride")
                }
                
                Section {
                    Picker("Bike", selection: $selectedBike) {
                        Text("None").tag(nil as BikeConfiguration?)
                        ForEach(bikes) { bike in
                            Text(bike.name).tag(bike as BikeConfiguration?)
                        }
                    }
                    
                    if let bike = selectedBike, bike.wheelsets.count > 1 {
                        Picker("Wheelset", selection: $selectedWheelset) {
                            ForEach(bike.wheelsets) { wheelset in
                                Text(wheelset.name).tag(wheelset as Wheelset?)
                            }
                        }
                    }
                } header: {
                    Text("Equipment")
                } footer: {
                    Text("Logging the bike updates its odometer, tires, and component wear tracking.")
                }
            }
            .navigationTitle(ride.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Complete") { complete() }
                        .disabled(actualDistanceKm <= 0)
                }
            }
            .onAppear { prefill() }
        }
    }
    
    private func prefill() {
        actualDistanceKm = ride.distance ?? 0
        let planned = Int(ride.duration)
        actualHours = planned / 3600
        actualMinutes = ((planned % 3600) / 60 / 15) * 15
        selectedBike = ride.selectedBike ?? ride.recommendedBike ?? bikes.first
        selectedWheelset = selectedBike?.defaultWheelset
    }
    
    private func complete() {
        let duration = TimeInterval(actualHours * 3600 + actualMinutes * 60)
        
        ride.isCompleted = true
        ride.completedDate = Date()
        ride.actualDistance = actualDistanceKm
        ride.actualDuration = duration
        
        if let bike = selectedBike {
            RideLogger.log(
                context: modelContext,
                date: ride.scheduledDate,
                distanceKm: actualDistanceKm,
                name: ride.name,
                bike: bike,
                wheelset: selectedWheelset
            )
        }
        
        dismiss()
    }
}
