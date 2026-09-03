import AppIntents
import Foundation
import SwiftData

struct ListSpinMinRidesIntent: AppIntent {
    static var title: LocalizedStringResource = "List Recent Rides in SpinMin"
    static var description = IntentDescription("Shows recently logged rides.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SpinMinIntentModelContainer.make()
        let context = ModelContext(container)
        let rides = try await MainActor.run { try SpinAgentService.shared.rides(context: context, limit: 8) }
        if rides.isEmpty {
            return .result(dialog: IntentDialog("No rides logged yet."))
        }
        let lines = rides.map { "\($0.rideName.isEmpty ? "Ride" : $0.rideName)   \($0.distanceKm) km" }.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: lines))
    }
}

struct LogRideInSpinMinIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Ride in SpinMin"
    static var description = IntentDescription("Logs a ride. Reversible for 7 days from Settings, Agents.")
    static var openAppWhenRun = false

    @Parameter(title: "Distance in kilometers")
    var distanceKm: Double

    @Parameter(title: "Notes")
    var notes: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SpinMinIntentModelContainer.make()
        let context = ModelContext(container)
        let ride = try await MainActor.run {
            try SpinAgentService.shared.logRide(context: context, distanceKm: distanceKm, date: Date(), bikeId: nil, notes: notes)
        }
        return .result(dialog: IntentDialog("Logged \(ride.distanceKm) km."))
    }
}

enum SpinMinIntentModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            BikeConfiguration.self,
            Wheelset.self,
            TireTracking.self,
            TireHistory.self,
            RideLog.self,
            MaintenanceRecord.self,
            ComponentTracking.self,
            CalculationHistory.self,
            GearConfiguration.self,
            ThemePreference.self,
            TireProduct.self,
            ChainProduct.self,
            WheelsetProduct.self,
            ComponentProduct.self,
            BikeProduct.self,
            VendorPreference.self,
            GearItem.self,
            RideChecklist.self,
            ChecklistItem.self,
            ScheduledRide.self,
            Route.self
        ])
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)])
        } catch {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("SpinMin.store")
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        }
    }
}
