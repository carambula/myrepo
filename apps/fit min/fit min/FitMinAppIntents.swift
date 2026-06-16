import AppIntents
import Foundation
import SwiftData

struct SetTimerEntity: AppEntity {
    typealias ID = String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Fit Min Timer")
    }

    static var defaultQuery = SetTimerEntityQuery()

    let id: String
    let title: String
    let blockLabel: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(blockLabel)")
    }

    init(title: String, blockLabel: String) {
        self.title = title
        self.id = title
        self.blockLabel = blockLabel
    }

    init(timer: SetTimer) {
        self.init(title: timer.displayTitle, blockLabel: timer.blockStyleLabel)
    }
}

struct SetTimerEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [SetTimerEntity] {
        let query = FitMinTimerNameNormalizer.normalize(string)
        let timers = Self.loadTimerEntities()
        guard !query.isEmpty else {
            return timers
        }
        return timers.filter { timer in
            let title = FitMinTimerNameNormalizer.normalize(timer.title)
            let block = FitMinTimerNameNormalizer.normalize(timer.blockLabel)
            return title.contains(query)
                || query.contains(title)
                || block.contains(query)
                || FitMinTimerNameNormalizer.words(in: query).isSubset(of: FitMinTimerNameNormalizer.words(in: title))
        }
    }

    func entities(for identifiers: [SetTimerEntity.ID]) async throws -> [SetTimerEntity] {
        let names = Set(identifiers.map(FitMinTimerNameNormalizer.normalize(_:)))
        return Self.loadTimerEntities().filter { names.contains(FitMinTimerNameNormalizer.normalize($0.title)) }
    }

    func suggestedEntities() async throws -> [SetTimerEntity] {
        Self.loadTimerEntities()
    }

    private static func loadTimerEntities() -> [SetTimerEntity] {
        let indexed = FitMinTimerIndexStore.load()
        if !indexed.isEmpty {
            return indexed.map { SetTimerEntity(title: $0.title, blockLabel: $0.blockLabel) }
        }

        let defaultEntities = DefaultSetTimerSeeder.presets.map { preset in
            SetTimerEntity(
                title: preset.title,
                blockLabel: SetTimerTitleFormatter.blockTitle(
                    for: preset.segments ?? SetTimerScheduleBuilder.segments(for: preset.configuration)
                )
            )
        }

        do {
            let container = try FitMinIntentModelContainer.make()
            let context = ModelContext(container)
            let timers = try context.fetch(FetchDescriptor<SetTimer>())
            let saved = timers.map(SetTimerEntity.init(timer:))
            return saved.isEmpty ? defaultEntities : saved
        } catch {
            return defaultEntities
        }
    }
}

struct StartFitMinTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Fit Min Timer"
    static var description = IntentDescription("Starts a saved Fit Min set timer by name.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Timer", requestValueDialog: IntentDialog("Which Fit Min timer?"))
    var timer: SetTimerEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$timer) in Fit Min")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        FitMinPendingTimerStartStore.requestStart(timerName: timer.title)
        return .result(dialog: IntentDialog("Starting \(timer.title)."))
    }
}

struct FitMinShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartFitMinTimerIntent(),
            phrases: [
                "Start \(\.$timer) in \(.applicationName)",
                "Start my \(\.$timer) timer in \(.applicationName)",
                "Run \(\.$timer) in \(.applicationName)"
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )
    }
}

enum FitMinIntentModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([SetTimer.self])
        do {
            let cloudConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let localStoreURL = appSupportURL.appendingPathComponent("FitMin.store")
            let localConfig = ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [localConfig])
        }
    }
}

enum FitMinPendingTimerStartStore {
    static let didRequestStartNotification = Notification.Name("FitMinPendingTimerStartStore.didRequestStart")
    private static let nameKey = "fitMin.pendingTimerStartName"
    private static let requestIDKey = "fitMin.pendingTimerStartRequestID"

    static func requestStart(timerName: String) {
        let defaults = UserDefaults.standard
        defaults.set(timerName, forKey: nameKey)
        defaults.set(UUID().uuidString, forKey: requestIDKey)
        NotificationCenter.default.post(name: didRequestStartNotification, object: nil)
    }

    static func consumePendingStartName() -> String? {
        let defaults = UserDefaults.standard
        guard let name = defaults.string(forKey: nameKey), !name.isEmpty else { return nil }
        defaults.removeObject(forKey: nameKey)
        defaults.removeObject(forKey: requestIDKey)
        return name
    }
}

struct FitMinTimerIndexRecord: Codable, Hashable {
    let title: String
    let blockLabel: String
}

enum FitMinTimerIndexStore {
    private static let key = "fitMin.timerNameIndex"

    static func save(timers: [SetTimer]) {
        let records = timers.map { FitMinTimerIndexRecord(title: $0.displayTitle, blockLabel: $0.blockStyleLabel) }
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> [FitMinTimerIndexRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([FitMinTimerIndexRecord].self, from: data) else {
            return []
        }
        return records
    }
}

enum FitMinTimerNameNormalizer {
    static func normalize(_ name: String) -> String {
        name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func words(in name: String) -> Set<Substring> {
        Set(name.split(separator: " "))
    }
}
