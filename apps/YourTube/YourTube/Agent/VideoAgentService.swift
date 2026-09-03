import Foundation
import MinAppKit
import SwiftData

@MainActor
final class VideoAgentService: AgentLibraryExporting {
    static let shared = VideoAgentService()

    private struct ChannelUndo: Codable {
        let channelID: String
        let title: String
        let thumbnailURL: String
        let subscribed: Bool
    }

    private struct WatchUndo: Codable {
        let videoID: String
        let previousProgress: Double?
        let previousCompleted: Bool?
        let existed: Bool
    }

    func subscriptions(context: ModelContext, query: String? = nil) throws -> [YTChannel] {
        let descriptor = FetchDescriptor<YTChannel>(
            predicate: #Predicate { $0.isUserSubscribed == true }
        )
        var items = try context.fetch(descriptor)
        if let query, !query.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(query) || $0.channelID.localizedCaseInsensitiveContains(query)
            }
        }
        return items
    }

    func subscribe(context: ModelContext, channelID: String?, title: String?, thumbnailURL: String?) throws -> YTChannel {
        let resolvedID = channelID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key = resolvedID ?? resolvedTitle, !key.isEmpty else {
            throw AgentKitError.notFound("Provide a channel id or title.")
        }

        let channels = try context.fetch(FetchDescriptor<YTChannel>())
        if let existing = channels.first(where: {
            $0.channelID == resolvedID || (resolvedTitle != nil && $0.title.compare(resolvedTitle!, options: .caseInsensitive) == .orderedSame)
        }) {
            let previous = existing.isUserSubscribed
            existing.isUserSubscribed = true
            existing.lastSyncedAt = .now
            ensureSubscription(context: context, channelID: existing.channelID)
            try context.save()
            AgentJournal.shared.recordWrite(
                connectionId: "on-device",
                app: .vid,
                tool: "subscribe_channel",
                summary: "Subscribed to \(existing.title)",
                payload: ChannelUndo(channelID: existing.channelID, title: existing.title, thumbnailURL: existing.thumbnailURL, subscribed: previous)
            )
            return existing
        }

        let channel = YTChannel(
            channelID: resolvedID ?? "agent-\(key)",
            title: resolvedTitle ?? key,
            thumbnailURL: thumbnailURL ?? "",
            isUserSubscribed: true
        )
        context.insert(channel)
        ensureSubscription(context: context, channelID: channel.channelID)
        try context.save()
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .vid,
            tool: "subscribe_channel",
            summary: "Subscribed to \(channel.title)",
            payload: ChannelUndo(channelID: channel.channelID, title: channel.title, thumbnailURL: channel.thumbnailURL, subscribed: false)
        )
        return channel
    }

    func unsubscribe(context: ModelContext, channelID: String?, title: String?) throws -> YTChannel {
        let channels = try subscriptions(context: context)
        guard let channel = channels.first(where: {
            (channelID != nil && $0.channelID == channelID)
                || (title != nil && $0.title.localizedCaseInsensitiveContains(title!))
        }) else {
            throw AgentKitError.notFound("No subscribed channel matched.")
        }
        channel.isUserSubscribed = false
        let descriptor = FetchDescriptor<UserSubscription>(
            predicate: #Predicate { $0.channelID == channel.channelID }
        )
        if let row = try context.fetch(descriptor).first {
            context.delete(row)
        }
        try context.save()
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .vid,
            tool: "unsubscribe_channel",
            summary: "Unsubscribed from \(channel.title)",
            payload: ChannelUndo(channelID: channel.channelID, title: channel.title, thumbnailURL: channel.thumbnailURL, subscribed: true)
        )
        return channel
    }

    func setWatchState(
        context: ModelContext,
        videoID: String,
        title: String?,
        progressSeconds: Double?,
        isCompleted: Bool?
    ) throws -> WatchState {
        let descriptor = FetchDescriptor<WatchState>(
            predicate: #Predicate { $0.videoID == videoID }
        )
        let existing = try context.fetch(descriptor).first
        let undo = WatchUndo(
            videoID: videoID,
            previousProgress: existing?.progressSeconds,
            previousCompleted: existing?.isCompleted,
            existed: existing != nil
        )
        let state = existing ?? WatchState(videoID: videoID)
        if existing == nil { context.insert(state) }
        if let progressSeconds { state.progressSeconds = progressSeconds }
        if let isCompleted { state.isCompleted = isCompleted }
        state.lastWatchedAt = .now
        try context.save()
        AgentJournal.shared.recordWrite(
            connectionId: "on-device",
            app: .vid,
            tool: "set_video_watch_state",
            summary: "Updated watch state for \(title ?? videoID)",
            payload: undo
        )
        return state
    }

    func exportLibraryJSON() throws -> Data {
        throw AgentKitError.notFound("Open Agents from Account while the app is running to export with live SwiftData.")
    }

    func exportLibraryJSON(context: ModelContext) throws -> Data {
        let channels = try subscriptions(context: context)
        let watches = try context.fetch(FetchDescriptor<WatchState>())
        let payload: [String: Any] = [
            "channels": channels.map {
                ["channelID": $0.channelID, "title": $0.title, "isUserSubscribed": true]
            },
            "watchState": watches.map {
                [
                    "videoID": $0.videoID,
                    "progressSeconds": $0.progressSeconds,
                    "isCompleted": $0.isCompleted
                ]
            }
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    func undoLastAgentWrite() throws -> String {
        throw AgentKitError.notFound("Undo needs a live model context.")
    }

    func undoLastAgentWrite(context: ModelContext) throws -> String {
        guard let record = AgentJournal.shared.latestUsable(app: .vid) else {
            throw AgentKitError.nothingToUndo
        }
        if record.tool == "set_video_watch_state" {
            let payload = try AgentJournal.shared.decodePayload(record, as: WatchUndo.self)
            let descriptor = FetchDescriptor<WatchState>(
                predicate: #Predicate { $0.videoID == payload.videoID }
            )
            if let row = try context.fetch(descriptor).first {
                if payload.existed {
                    if let previousProgress = payload.previousProgress { row.progressSeconds = previousProgress }
                    if let previousCompleted = payload.previousCompleted { row.isCompleted = previousCompleted }
                } else {
                    context.delete(row)
                }
            }
        } else {
            let payload = try AgentJournal.shared.decodePayload(record, as: ChannelUndo.self)
            let channelDescriptor = FetchDescriptor<YTChannel>(
                predicate: #Predicate { $0.channelID == payload.channelID }
            )
            if let channel = try context.fetch(channelDescriptor).first {
                channel.isUserSubscribed = payload.subscribed
            }
            let subscriptionDescriptor = FetchDescriptor<UserSubscription>(
                predicate: #Predicate { $0.channelID == payload.channelID }
            )
            let existingSub = try context.fetch(subscriptionDescriptor).first
            if payload.subscribed {
                if existingSub == nil {
                    context.insert(UserSubscription(channelID: payload.channelID))
                }
            } else if let existingSub {
                context.delete(existingSub)
            }
        }
        try context.save()
        _ = try AgentJournal.shared.markUndone(id: record.id)
        return "Undid \(record.summary)"
    }

    private func ensureSubscription(context: ModelContext, channelID: String) {
        let descriptor = FetchDescriptor<UserSubscription>(
            predicate: #Predicate { $0.channelID == channelID }
        )
        if (try? context.fetch(descriptor).first) == nil {
            context.insert(UserSubscription(channelID: channelID))
        }
    }
}

@MainActor
final class VideoAgentExportAdapter: AgentLibraryExporting {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func exportLibraryJSON() throws -> Data {
        try VideoAgentService.shared.exportLibraryJSON(context: context)
    }

    func undoLastAgentWrite() throws -> String {
        try VideoAgentService.shared.undoLastAgentWrite(context: context)
    }
}
