import Foundation

struct Podcast: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let description: String
    let feedURL: URL
    let artworkURL: URL?
    let artworkURL600: URL?
    let categories: [String]
    let language: String
    let isExplicit: Bool
    let websiteURL: URL?
    let itunesID: String?

    var isFollowed: Bool = false
    var notificationsEnabled: Bool = false
    var autoDownload: Bool = false
    var preferVideo: Bool = false
    var customPlaybackSpeed: Float?

    var displayArtworkURL: URL? {
        artworkURL600 ?? artworkURL
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        description: String = "",
        feedURL: URL,
        artworkURL: URL? = nil,
        artworkURL600: URL? = nil,
        categories: [String] = [],
        language: String = "en",
        isExplicit: Bool = false,
        websiteURL: URL? = nil,
        itunesID: String? = nil,
        isFollowed: Bool = false,
        notificationsEnabled: Bool = false,
        autoDownload: Bool = false,
        preferVideo: Bool = false,
        customPlaybackSpeed: Float? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.artworkURL600 = artworkURL600
        self.categories = categories
        self.language = language
        self.isExplicit = isExplicit
        self.websiteURL = websiteURL
        self.itunesID = itunesID
        self.isFollowed = isFollowed
        self.notificationsEnabled = notificationsEnabled
        self.autoDownload = autoDownload
        self.preferVideo = preferVideo
        self.customPlaybackSpeed = customPlaybackSpeed
    }
}

extension Notification.Name {
    static let followedPodcastsDidChange = Notification.Name("PodLink.followedPodcastsDidChange")
}

extension Podcast {
    /// Shared by `UserDefaults` and `NSUbiquitousKeyValueStore` (iCloud KVS).
    static let followedPodcastsStorageKey = "followedPodcasts"

    private static let followedCacheLock = NSLock()
    private static var cachedFollowed: [Podcast]?

    static func invalidateFollowedCache() {
        followedCacheLock.lock()
        cachedFollowed = nil
        followedCacheLock.unlock()
    }

    static func loadFollowedPodcasts() -> [Podcast] {
        followedCacheLock.lock()
        if let cached = cachedFollowed {
            followedCacheLock.unlock()
            return cached
        }
        followedCacheLock.unlock()

        let localData = UserDefaults.standard.data(forKey: followedPodcastsStorageKey)

        let fromLocal = localData.flatMap { data in try? JSONDecoder().decode([Podcast].self, from: data) } ?? []
        if !fromLocal.isEmpty {
            followedCacheLock.lock()
            cachedFollowed = fromLocal
            followedCacheLock.unlock()
            return fromLocal
        }

        guard let data = CloudKeyValueWriter.data(forKey: followedPodcastsStorageKey),
              let fromCloud = try? JSONDecoder().decode([Podcast].self, from: data),
              !fromCloud.isEmpty else {
            followedCacheLock.lock()
            cachedFollowed = []
            followedCacheLock.unlock()
            return []
        }

        // Fresh install / reinstall: restore library from iCloud KVS into local storage.
        UserDefaults.standard.set(data, forKey: followedPodcastsStorageKey)
        followedCacheLock.lock()
        cachedFollowed = fromCloud
        followedCacheLock.unlock()
        return fromCloud
    }

    /// Union of UserDefaults and iCloud KVS subscriptions (by canonical feed URL). Local entries win on conflict so this device keeps its settings; cloud-only feeds are appended.
    static func mergedFollowedPodcastsForMutation() -> [Podcast] {
        let localData = UserDefaults.standard.data(forKey: followedPodcastsStorageKey)
        let ubiquitousData = CloudKeyValueWriter.data(forKey: followedPodcastsStorageKey)
        let local = localData.flatMap { data in try? JSONDecoder().decode([Podcast].self, from: data) } ?? []
        let fromCloud = ubiquitousData.flatMap { data in try? JSONDecoder().decode([Podcast].self, from: data) } ?? []

        var merged: [Podcast] = []
        var seen = Set<String>()
        for podcast in local {
            let key = PrivateFeedAuthStore.canonicalFeedURL(podcast.feedURL).absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(podcast)
        }
        for podcast in fromCloud {
            let key = PrivateFeedAuthStore.canonicalFeedURL(podcast.feedURL).absoluteString
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(podcast)
        }
        return merged
    }

    static func saveFollowedPodcasts(_ podcasts: [Podcast]) {
        guard let data = try? JSONEncoder().encode(podcasts) else { return }
        UserDefaults.standard.set(data, forKey: followedPodcastsStorageKey)
        if MinCloudSettings.iCloudBackupEnabled {
            CloudKeyValueWriter.setData(data, forKey: followedPodcastsStorageKey)
        }
        invalidateFollowedCache()
        NotificationCenter.default.post(name: .followedPodcastsDidChange, object: nil)
        Task {
            await MinCloudClient.shared.syncFollowedWatches(podcasts)
            if MinCloudSettings.isSignedIn {
                let items = podcasts.map { podcast -> [String: Any] in
                    var item: [String: Any] = [
                        "podcastId": podcast.id,
                        "feedUrl": podcast.feedURL.absoluteString,
                        "title": podcast.title,
                        "isFollowed": true,
                        "notificationsEnabled": podcast.notificationsEnabled
                    ]
                    if let artwork = podcast.displayArtworkURL?.absoluteString {
                        item["artworkUrl"] = artwork
                    }
                    return item
                }
                try? await MinCloudClient.shared.pushLibrary(items: items)
            }
        }
    }

    /// Called when iCloud KVS delivers changes (e.g. another device or after reinstall sync).
    static func applyFollowedPodcastsFromUbiquitousStore() {
        guard let data = CloudKeyValueWriter.data(forKey: followedPodcastsStorageKey),
              (try? JSONDecoder().decode([Podcast].self, from: data)) != nil else { return }
        UserDefaults.standard.set(data, forKey: followedPodcastsStorageKey)
        invalidateFollowedCache()
        // Posted on the main thread because UI observers update SwiftUI state; this method may run off-main.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .followedPodcastsDidChange, object: nil)
        }
    }
}
