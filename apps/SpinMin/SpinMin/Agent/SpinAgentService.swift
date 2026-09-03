import Foundation
import MinAppKit
import SwiftData

@MainActor
final class SpinAgentService {
    static let shared = SpinAgentService()

    private struct RideUndo: Codable {
        let rideId: String
    }

    func bikes(context: ModelContext, query: String? = nil) throws -> [BikeConfiguration] {
        var items = try context.fetch(FetchDescriptor<BikeConfiguration>())
        if let query, !query.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        return items
    }

    func rides(context: ModelContext, limit: Int = 20) throws -> [RideLog] {
        var descriptor = FetchDescriptor<RideLog>(sortBy: [SortDescriptor(\.rideDate, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func logRide(context: ModelContext, distanceKm: Double, date: Date?, bikeId: String?, notes: String?) throws -> RideLog {
        let bike = try bikes(context: context).first(where: { bikeId != nil && $0.id.uuidString == bikeId })
        let ride = RideLogger.log(
            context: context,
            date: date ?? Date(),
            distanceKm: distanceKm,
            name: notes?.isEmpty == false ? notes! : "Agent ride",
            notes: notes ?? "",
            bike: bike
        )
        try context.save()
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .spin,
            tool: "log_ride",
            summary: "Logged \(distanceKm) km ride",
            payload: RideUndo(rideId: ride.id.uuidString)
        )
        return ride
    }

    func exportLibraryJSON(context: ModelContext) throws -> Data {
        let bikes = try bikes(context: context)
        let rides = try rides(context: context, limit: 50)
        let payload: [String: Any] = [
            "bikes": bikes.map { ["id": $0.id.uuidString, "name": $0.name] },
            "rides": rides.map {
                [
                    "id": $0.id.uuidString,
                    "distanceKm": $0.distanceKm,
                    "date": ISO8601DateFormatter().string(from: $0.rideDate)
                ]
            }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func undoLastAgentWrite(context: ModelContext) throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .spin) else {
            throw AgentKitError.nothingToUndo
        }
        let payload = try AgentJournal.shared.decodePayload(record, as: RideUndo.self)
        let rides = try context.fetch(FetchDescriptor<RideLog>())
        if let ride = rides.first(where: { $0.id.uuidString == payload.rideId }) {
            context.delete(ride)
            try context.save()
        }
        _ = try AgentJournal.shared.markUndone(id: record.id)
        return "Undid \(record.summary)"
    }
}

final class SpinAgentExportAdapter: AgentLibraryExporting {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func exportLibraryJSON() throws -> Data {
        try SpinAgentService.shared.exportLibraryJSON(context: context)
    }

    func undoLastAgentWrite() throws -> String {
        try SpinAgentService.shared.undoLastAgentWrite(context: context)
    }
}
