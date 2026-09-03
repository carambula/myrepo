import Foundation
import MinAppKit
import SwiftData

@MainActor
final class TimerAgentService: AgentLibraryExporting {
    static let shared = TimerAgentService()

    private struct TimerUndo: Codable {
        let title: String
        let created: Bool
        let started: Bool
        let deleted: Bool
        let configuration: SetTimerConfiguration?
    }

    func list(context: ModelContext, query: String? = nil) throws -> [SetTimer] {
        var items = try context.fetch(FetchDescriptor<SetTimer>())
        if let query, !query.isEmpty {
            items = items.filter { $0.displayTitle.localizedCaseInsensitiveContains(query) }
        }
        return items
    }

    func create(
        context: ModelContext,
        title: String?,
        reps: Int?,
        workSeconds: Int?,
        restSeconds: Int?,
        intervalType: IntervalType = .fixed
    ) throws -> SetTimer {
        var configuration = SetTimerConfiguration()
        configuration.intervalType = intervalType
        if let reps { configuration.reps = reps }
        if let workSeconds { configuration.workSeconds = workSeconds }
        if let restSeconds { configuration.restSeconds = restSeconds }
        let timer = SetTimer(customTitle: title ?? "", configuration: configuration.normalized)
        context.insert(timer)
        try context.save()
        FitMinTimerIndexStore.save(timers: try context.fetch(FetchDescriptor<SetTimer>()))
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .fit,
            tool: "create_timer",
            summary: "Created timer \(timer.displayTitle)",
            payload: TimerUndo(title: timer.displayTitle, created: true, started: false, deleted: false, configuration: configuration)
        )
        return timer
    }

    func start(context: ModelContext, title: String) throws -> SetTimer {
        let timers = try list(context: context, query: title)
        guard let timer = timers.first else { throw AgentKitError.notFound("No timer matched \(title).") }
        FitMinPendingTimerStartStore.requestStart(timerName: timer.displayTitle)
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .fit,
            tool: "start_timer",
            summary: "Started \(timer.displayTitle)",
            payload: TimerUndo(title: timer.displayTitle, created: false, started: true, deleted: false, configuration: timer.configuration)
        )
        return timer
    }

    func exportLibraryJSON() throws -> Data {
        let records = FitMinTimerIndexStore.load()
        let payload: [String: Any] = [
            "timers": records.map { ["title": $0.title, "blockLabel": $0.blockLabel] }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func exportLibraryJSON(context: ModelContext) throws -> Data {
        let timers = try list(context: context)
        let payload: [String: Any] = [
            "timers": timers.map {
                [
                    "title": $0.displayTitle,
                    "reps": $0.reps,
                    "workSeconds": $0.workSeconds,
                    "restSeconds": $0.restSeconds
                ]
            }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func undoLastAgentWrite() throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .fit) else {
            throw AgentKitError.nothingToUndo
        }
        let payload = try AgentJournal.shared.decodePayload(record, as: TimerUndo.self)
        if payload.started {
            _ = FitMinPendingTimerStartStore.consumePendingStartName()
        }
        _ = try AgentJournal.shared.markUndone(id: record.id)
        return "Undid \(record.summary)"
    }

    func undoLastAgentWrite(context: ModelContext) throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .fit) else {
            throw AgentKitError.nothingToUndo
        }
        let payload = try AgentJournal.shared.decodePayload(record, as: TimerUndo.self)
        if payload.created || payload.deleted {
            let timers = try list(context: context)
            if payload.created, let timer = timers.first(where: { $0.displayTitle == payload.title }) {
                context.delete(timer)
                try context.save()
            }
        }
        if payload.started {
            _ = FitMinPendingTimerStartStore.consumePendingStartName()
        }
        _ = try AgentJournal.shared.markUndone(id: record.id)
        return "Undid \(record.summary)"
    }
}

final class TimerAgentExportAdapter: AgentLibraryExporting {
    let context: ModelContext?

    init(context: ModelContext? = nil) {
        self.context = context
    }

    func exportLibraryJSON() throws -> Data {
        if let context {
            return try TimerAgentService.shared.exportLibraryJSON(context: context)
        }
        return try TimerAgentService.shared.exportLibraryJSON()
    }

    func undoLastAgentWrite() throws -> String {
        if let context {
            return try TimerAgentService.shared.undoLastAgentWrite(context: context)
        }
        return try TimerAgentService.shared.undoLastAgentWrite()
    }
}
