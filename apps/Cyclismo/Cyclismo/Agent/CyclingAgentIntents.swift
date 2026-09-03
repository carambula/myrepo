import AppIntents
import Foundation
import MinAppKit

struct ListSavedCyclismoRacesIntent: AppIntent {
    static var title: LocalizedStringResource = "List Saved Races in Cyclismo"
    static var description = IntentDescription("Shows races you have saved, watched, or listened to.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let races = await MainActor.run { CyclingAgentService.shared.listed() }
        if races.isEmpty {
            return .result(dialog: IntentDialog("No saved, watched, or listened races yet."))
        }
        let lines = races.prefix(15).map { race in
            let flags = [
                race.isSaved ? "saved" : nil,
                race.isWatched ? "watched" : nil,
                race.isListened ? "listened" : nil
            ].compactMap { $0 }.joined(separator: AgentSecurity.metadataSeparator)
            return "\(race.name)   \(flags)"
        }.joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: lines))
    }
}

struct SaveRaceInCyclismoIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Race in Cyclismo"
    static var description = IntentDescription("Saves a race by name or id. Reversible for 7 days.")
    static var openAppWhenRun = false

    @Parameter(title: "Race")
    var name: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let race = try await MainActor.run {
            try CyclingAgentService.shared.setStatus(raceId: nil, name: name, saved: true, watched: nil, listened: nil)
        }
        return .result(dialog: IntentDialog("Saved \(race.name)."))
    }
}

struct UndoLastCyclismoAgentWriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last Cyclismo Agent Change"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let message = try await MainActor.run { try CyclingAgentService.shared.undoLastAgentWrite() }
        return .result(dialog: IntentDialog(stringLiteral: message))
    }
}

struct CyclismoAgentShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListSavedCyclismoRacesIntent(),
            phrases: [
                "What races did I save in \(.applicationName)",
                "List saved races in \(.applicationName)"
            ],
            shortTitle: "Saved races",
            systemImageName: "flag"
        )
    }
}
