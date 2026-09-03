import Foundation
import MinAppKit

@MainActor
final class CyclingAgentService: AgentLibraryExporting {
    static let shared = CyclingAgentService()

    private struct RaceUndo: Codable {
        let raceId: String
        let name: String
        let previousSaved: Bool
        let previousListened: Bool
        let previousWatched: Bool
    }

    func listed(saved: Bool? = nil, watched: Bool? = nil, listened: Bool? = nil, query: String? = nil, races: [Race] = []) -> [AgentRace] {
        let items: [AgentRace]
        if races.isEmpty {
            let ids = RaceStatusStore.loadSet(key: RaceStatusStore.savedKey)
                .union(RaceStatusStore.loadSet(key: RaceStatusStore.watchedKey))
                .union(RaceStatusStore.loadSet(key: RaceStatusStore.listenedKey))
            items = ids.map { id in
                let status = RaceStatusStore.status(for: id)
                return AgentRace(raceId: id, name: id, isSaved: status.isSaved, isWatched: status.isWatched, isListened: status.isListened)
            }
        } else {
            items = races.map { race in
                let status = RaceStatusStore.status(for: race.raceId)
                return AgentRace(raceId: race.raceId, name: race.name, isSaved: status.isSaved, isWatched: status.isWatched, isListened: status.isListened)
            }
        }
        return items.filter { item in
            if let saved, item.isSaved != saved { return false }
            if let watched, item.isWatched != watched { return false }
            if let listened, item.isListened != listened { return false }
            if let query, !query.isEmpty {
                return item.name.localizedCaseInsensitiveContains(query) || item.raceId.localizedCaseInsensitiveContains(query)
            }
            return true
        }
    }

    func setStatus(raceId: String?, name: String?, saved: Bool?, watched: Bool?, listened: Bool?, races: [Race] = []) throws -> AgentRace {
        let catalog = listed(races: races)
        let match = catalog.first(where: {
            ($0.raceId == raceId && raceId != nil) || (name != nil && $0.name.localizedCaseInsensitiveContains(name!))
        })
        let resolvedId = match?.raceId ?? raceId ?? name
        guard let resolvedId, !resolvedId.isEmpty else {
            throw AgentKitError.notFound("Provide a race id or name.")
        }
        let previous = RaceStatusStore.status(for: resolvedId)
        if let saved { RaceStatusStore.set(saved, raceId: resolvedId, key: RaceStatusStore.savedKey) }
        if let watched { RaceStatusStore.set(watched, raceId: resolvedId, key: RaceStatusStore.watchedKey) }
        if let listened { RaceStatusStore.set(listened, raceId: resolvedId, key: RaceStatusStore.listenedKey) }
        let current = RaceStatusStore.status(for: resolvedId)
        let resolvedName = match?.name ?? name ?? resolvedId
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .cyc,
            tool: "set_race_status",
            summary: "Updated \(resolvedName)",
            payload: RaceUndo(
                raceId: resolvedId,
                name: resolvedName,
                previousSaved: previous.isSaved,
                previousListened: previous.isListened,
                previousWatched: previous.isWatched
            )
        )
        return AgentRace(raceId: resolvedId, name: resolvedName, isSaved: current.isSaved, isWatched: current.isWatched, isListened: current.isListened)
    }

    func exportLibraryJSON() throws -> Data {
        let items = listed()
        let payload: [String: Any] = [
            "races": items.map {
                [
                    "raceId": $0.raceId,
                    "name": $0.name,
                    "isSaved": $0.isSaved,
                    "isWatched": $0.isWatched,
                    "isListened": $0.isListened
                ]
            }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func undoLastAgentWrite() throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .cyc) else {
            throw AgentKitError.nothingToUndo
        }
        let payload = try AgentJournal.shared.decodePayload(record, as: RaceUndo.self)
        RaceStatusStore.apply(
            RaceStatusStore.Status(
                isSaved: payload.previousSaved,
                isListened: payload.previousListened,
                isWatched: payload.previousWatched
            ),
            raceId: payload.raceId
        )
        _ = try AgentJournal.shared.markUndone(id: record.id)
        return "Undid \(record.summary)"
    }
}

struct AgentRace: Identifiable, Hashable {
    let raceId: String
    let name: String
    let isSaved: Bool
    let isWatched: Bool
    let isListened: Bool
    var id: String { raceId }
}
