import AppIntents
import Foundation
import SwiftData

struct ListYourTubeSubscriptionsIntent: AppIntent {
    static var title: LocalizedStringResource = "List YourTube Subscriptions"
    static var description = IntentDescription("Shows channels you follow in YourTube.")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try YourTubeIntentModelContainer.make()
        let context = ModelContext(container)
        let channels = try await MainActor.run { try VideoAgentService.shared.subscriptions(context: context) }
        if channels.isEmpty {
            return .result(dialog: IntentDialog("You have no YourTube subscriptions yet."))
        }
        let lines = channels.prefix(20).map(\.title).joined(separator: "\n")
        return .result(dialog: IntentDialog(stringLiteral: lines))
    }
}

struct SubscribeYourTubeChannelIntent: AppIntent {
    static var title: LocalizedStringResource = "Subscribe in YourTube"
    static var description = IntentDescription("Adds a channel by title or id. Reversible for 7 days.")
    static var openAppWhenRun = false

    @Parameter(title: "Channel")
    var title: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try YourTubeIntentModelContainer.make()
        let context = ModelContext(container)
        let channel = try await MainActor.run {
            try VideoAgentService.shared.subscribe(context: context, channelID: nil, title: title, thumbnailURL: nil)
        }
        return .result(dialog: IntentDialog("Subscribed to \(channel.title)."))
    }
}

struct YourTubeAgentShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ListYourTubeSubscriptionsIntent(),
            phrases: [
                "What channels do I follow in \(.applicationName)",
                "List subscriptions in \(.applicationName)"
            ],
            shortTitle: "Subscriptions",
            systemImageName: "play.rectangle"
        )
    }
}

enum YourTubeIntentModelContainer {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            YTChannel.self,
            YTVideo.self,
            UserSubscription.self,
            WatchState.self,
            ThemePreference.self,
            SearchHistoryEntry.self,
            ChannelOrderPreference.self
        ])
        do {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)])
        } catch {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("YourTube.store")
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)])
        }
    }
}
