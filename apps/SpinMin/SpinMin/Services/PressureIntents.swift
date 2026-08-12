//
//  PressureIntents.swift
//  SpinMin
//
//  Siri / Shortcuts intent: ask for recommended tire pressure.
//  Reads the same App Group snapshot the widget uses.
//

import Foundation
import AppIntents

struct GetTirePressureIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Tire Pressure"
    static var description = IntentDescription(
        "Tells you the recommended front and rear tire pressure for a bike."
    )
    
    @Parameter(title: "Bike Name", requestValueDialog: "Which bike?")
    var bikeName: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get tire pressure for \(\.$bikeName)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let snapshot = WidgetSnapshot.load(), !snapshot.bikes.isEmpty else {
            return .result(dialog: "Open SpinMin first so it can calculate pressures for your bikes.")
        }
        
        let bike: WidgetSnapshot.BikePressure
        if let name = bikeName, !name.isEmpty {
            let normalized = name.lowercased()
            guard let match = snapshot.bikes.first(where: {
                $0.bikeName.lowercased().contains(normalized) || normalized.contains($0.bikeName.lowercased())
            }) else {
                let names = snapshot.bikes.map { $0.bikeName }.joined(separator: ", ")
                return .result(dialog: "I couldn't find a bike called \(name). Your bikes are: \(names).")
            }
            bike = match
        } else {
            bike = snapshot.bikes[0]
        }
        
        let front = Int(bike.frontPSI.rounded())
        let rear = Int(bike.rearPSI.rounded())
        return .result(dialog: "For \(bike.bikeName), run \(front) psi in front and \(rear) psi in the rear.")
    }
}

struct SpinMinShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetTirePressureIntent(),
            phrases: [
                "What tire pressure in \(.applicationName)",
                "Get tire pressure from \(.applicationName)",
            ],
            shortTitle: "Tire Pressure",
            systemImageName: "gauge.with.dots.needle.bottom.50percent"
        )
    }
}
