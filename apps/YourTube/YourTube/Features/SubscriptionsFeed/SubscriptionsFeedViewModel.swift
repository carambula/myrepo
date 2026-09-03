import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SubscriptionsFeedViewModel {
    private var allVideos: [YTVideo] = []
    var filterShorts = true
    var videos: [YTVideo] {
        filterShorts ? allVideos.filter { !YouTubeContentPolicy.isShort($0) } : allVideos
    }
    var channels: [YTChannel] = []
    private(set) var channelOrderIDs: [String] = []
    var isLoading = false
    private(set) var hasCompletedInitialLoad = false
    var errorMessage: String?
    var isGrid = false
    private(set) var lastRefreshedAt: Date?

    private let apiClient: YouTubeAPIClient
    private let authService: GoogleOAuthService
    private let channelOrderPreferenceKey = "channelOrder"

    init(apiClient: YouTubeAPIClient, authService: GoogleOAuthService) {
        self.apiClient = apiClient
        self.authService = authService
    }

    func toggleLayout() {
        isGrid.toggle()
    }

    func refresh(modelContext: ModelContext, reloadSubscriptions: Bool = true) async {
        ensureChannelOrderLoaded(modelContext: modelContext)
        isLoading = true
        defer {
            isLoading = false
            hasCompletedInitialLoad = true
        }
        errorMessage = nil
        do {
            let token = try await authService.validAccessToken()

            if reloadSubscriptions || channels.isEmpty {
                let subscribedChannels = try await apiClient.fetchSubscribedChannels(accessToken: token)
                channels = subscribedChannels
                syncChannelOrderWithCurrentChannels(modelContext: modelContext)

                for channel in subscribedChannels {
                    upsert(channel: channel, modelContext: modelContext)
                    upsert(subscriptionFor: channel.channelID, modelContext: modelContext)
                }
            }

            var fetchedVideos: [YTVideo] = []
            for channel in channels {
                do {
                    let latest = try await apiClient.fetchLatestVideos(
                        accessToken: token,
                        channelID: channel.channelID,
                        maxResults: 12
                    )
                    fetchedVideos.append(contentsOf: latest)
                } catch {
                    continue
                }
            }

            allVideos = fetchedVideos.sorted(by: { $0.publishedAt > $1.publishedAt })

            for video in allVideos {
                upsert(video: video, modelContext: modelContext)
            }
            try? modelContext.save()
            lastRefreshedAt = .now
        } catch {
            errorMessage = error.localizedDescription
            if channels.isEmpty {
                loadCachedData(modelContext: modelContext)
            }
        }
    }

    func loadCachedData(modelContext: ModelContext) {
        ensureChannelOrderLoaded(modelContext: modelContext)
        let videoDescriptor = FetchDescriptor<YTVideo>(
            sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]
        )
        let channelDescriptor = FetchDescriptor<YTChannel>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        allVideos = (try? modelContext.fetch(videoDescriptor)) ?? []
        channels = (try? modelContext.fetch(channelDescriptor)) ?? []
        syncChannelOrderWithCurrentChannels(modelContext: modelContext)
        if !channels.isEmpty {
            hasCompletedInitialLoad = true
        }
    }

    var orderedChannels: [YTChannel] {
        guard !channels.isEmpty else { return [] }
        guard !channelOrderIDs.isEmpty else { return channels }

        let channelsByID = Dictionary(uniqueKeysWithValues: channels.map { ($0.channelID, $0) })
        var usedIDs = Set<String>()
        var ordered: [YTChannel] = []

        for channelID in channelOrderIDs {
            guard let channel = channelsByID[channelID] else { continue }
            ordered.append(channel)
            usedIDs.insert(channelID)
        }

        for channel in channels where !usedIDs.contains(channel.channelID) {
            ordered.append(channel)
        }

        return ordered
    }

    func moveChannel(withID channelID: String, toIndex newIndex: Int, modelContext: ModelContext) {
        var ids = orderedChannels.map(\.channelID)
        guard let fromIndex = ids.firstIndex(of: channelID) else { return }

        let clampedIndex = max(0, min(newIndex, ids.count - 1))
        guard clampedIndex != fromIndex else { return }

        let movedID = ids.remove(at: fromIndex)
        ids.insert(movedID, at: clampedIndex)
        persistChannelOrder(ids, modelContext: modelContext)
    }

    func persistChannelOrder(_ channelIDs: [String], modelContext: ModelContext) {
        channelOrderIDs = channelIDs

        let descriptor = FetchDescriptor<ChannelOrderPreference>(
            predicate: #Predicate { $0.key == "channelOrder" }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.orderedChannelIDsCSV = channelIDs.joined(separator: ",")
            existing.updatedAt = .now
        } else {
            let preference = ChannelOrderPreference(
                key: channelOrderPreferenceKey,
                orderedChannelIDsCSV: channelIDs.joined(separator: ","),
                updatedAt: .now
            )
            modelContext.insert(preference)
        }

        try? modelContext.save()
    }

    private func ensureChannelOrderLoaded(modelContext: ModelContext) {
        guard channelOrderIDs.isEmpty else { return }

        let descriptor = FetchDescriptor<ChannelOrderPreference>(
            predicate: #Predicate { $0.key == "channelOrder" }
        )

        guard let preference = try? modelContext.fetch(descriptor).first else { return }
        channelOrderIDs = preference.orderedChannelIDsCSV
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func syncChannelOrderWithCurrentChannels(modelContext: ModelContext) {
        guard !channels.isEmpty else { return }
        let currentIDs = channels.map(\.channelID)
        let currentSet = Set(currentIDs)

        var merged: [String] = channelOrderIDs.filter { currentSet.contains($0) }
        let missing = currentIDs.filter { !merged.contains($0) }
        merged.append(contentsOf: missing)

        guard merged != channelOrderIDs else { return }
        persistChannelOrder(merged, modelContext: modelContext)
    }

    private func upsert(channel: YTChannel, modelContext: ModelContext) {
        let channelID = channel.channelID
        let descriptor = FetchDescriptor<YTChannel>(
            predicate: #Predicate { $0.channelID == channelID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.title = channel.title
            existing.summary = channel.summary
            existing.thumbnailURL = channel.thumbnailURL
            existing.uploadsPlaylistID = channel.uploadsPlaylistID
            existing.isUserSubscribed = true
            existing.lastSyncedAt = .now
        } else {
            modelContext.insert(channel)
        }
    }

    private func upsert(video: YTVideo, modelContext: ModelContext) {
        let videoID = video.videoID
        let descriptor = FetchDescriptor<YTVideo>(
            predicate: #Predicate { $0.videoID == videoID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.title = video.title
            existing.summary = video.summary
            existing.thumbnailURL = video.thumbnailURL
            existing.publishedAt = video.publishedAt
            existing.durationISO8601 = video.durationISO8601
            existing.isShortCandidate = video.isShortCandidate
            existing.lastSyncedAt = .now
        } else {
            modelContext.insert(video)
        }
    }

    private func upsert(subscriptionFor channelID: String, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<UserSubscription>(
            predicate: #Predicate { $0.channelID == channelID }
        )
        guard (try? modelContext.fetch(descriptor).first) == nil else { return }
        modelContext.insert(UserSubscription(channelID: channelID))
    }
}
