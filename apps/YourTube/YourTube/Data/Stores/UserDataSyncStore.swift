import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class UserDataSyncStore {
    private let kvs = NSUbiquitousKeyValueStore.default
    private let subscribedChannelIDsKey = "yt_subscribed_channel_ids_v1"
    private let searchPlacementKey = "yt_search_placement_v1"

    init() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.kvs.synchronize()
            }
        }
    }

    func syncSubscriptionsToCloud(channelIDs: [String]) {
        kvs.set(channelIDs, forKey: subscribedChannelIDsKey)
        kvs.synchronize()
    }

    func subscriptionsFromCloud() -> [String] {
        kvs.array(forKey: subscribedChannelIDsKey) as? [String] ?? []
    }

    func syncSearchPlacementToCloud(_ placement: NavigationSearchPlacement) {
        kvs.set(placement.rawValue, forKey: searchPlacementKey)
        kvs.synchronize()
    }

    func searchPlacementFromCloud() -> NavigationSearchPlacement? {
        guard let raw = kvs.string(forKey: searchPlacementKey) else { return nil }
        return NavigationSearchPlacement(rawValue: raw)
    }

    func hydrateLocalSubscriptions(modelContext: ModelContext) {
        let cloudIDs = subscriptionsFromCloud()
        guard !cloudIDs.isEmpty else { return }
        for id in cloudIDs {
            let descriptor = FetchDescriptor<UserSubscription>(
                predicate: #Predicate { $0.channelID == id }
            )
            let exists = (try? modelContext.fetch(descriptor).first) != nil
            if !exists {
                modelContext.insert(UserSubscription(channelID: id))
            }
        }
        try? modelContext.save()
    }
}
