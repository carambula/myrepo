//
//  ChainWearMeasurementView.swift
//  SpinMin
//
//  Guided entry for chain-checker gauge measurements. Measured wear
//  grounds replacement warnings in real data instead of mileage
//  estimates.
//

import SwiftUI
import SwiftData

struct ChainWearMeasurementView: View {
    @Environment(\.dismiss) private var dismiss
    
    let chain: ComponentTracking
    let speedCount: Int
    
    private enum GaugeReading: String, CaseIterable {
        case under05 = "Under 0.5%"
        case at05 = "0.5%"
        case at075 = "0.75%"
        case over10 = "1.0%+"
        
        var wearValue: Double {
            switch self {
            case .under05: return 0.4
            case .at05: return 0.5
            case .at075: return 0.75
            case .over10: return 1.0
            }
        }
    }
    
    @State private var reading: GaugeReading = .under05
    @State private var useExactValue = false
    @State private var exactValue: Double = 0.25
    
    private var wearLimit: Double {
        speedCount >= 11 ? 0.5 : 0.75
    }
    
    private var measuredWear: Double {
        useExactValue ? exactValue : reading.wearValue
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Gauge reading", selection: $reading) {
                        ForEach(GaugeReading.allCases, id: \.self) { reading in
                            Text(reading.rawValue).tag(reading)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(useExactValue)
                    
                    Toggle("Enter exact value", isOn: $useExactValue)
                    
                    if useExactValue {
                        HStack {
                            Text("Measured wear")
                            Spacer()
                            TextField("0.25", value: $exactValue, format: .number.precision(.fractionLength(0...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Chain Checker Reading")
                } footer: {
                    Text("Insert the gauge into the chain. If the \(String(format: "%.2g", wearLimit))% side drops in fully, the chain is worn out for a \(speedCount)-speed drivetrain.")
                }
                
                Section {
                    HStack {
                        Image(systemName: verdictIcon)
                            .foregroundStyle(verdictColor)
                        Text(verdictText)
                            .bodySmall()
                    }
                }
            }
            .navigationTitle("Measure Chain Wear")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        chain.recordWearMeasurement(measuredWear)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var verdictText: String {
        if measuredWear >= wearLimit {
            return "Replace the chain now. Riding a worn chain wears the cassette and chainrings."
        }
        if measuredWear >= wearLimit * 0.8 {
            return "Getting close to the \(String(format: "%.2g", wearLimit))% limit. Re-check every couple hundred kilometers."
        }
        return "Chain is healthy. Measure again in about 500 km."
    }
    
    private var verdictIcon: String {
        measuredWear >= wearLimit ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }
    
    private var verdictColor: Color {
        if measuredWear >= wearLimit { return .red }
        if measuredWear >= wearLimit * 0.8 { return .orange }
        return .green
    }
}
