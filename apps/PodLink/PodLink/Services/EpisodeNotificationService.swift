import Foundation
import UserNotifications

actor EpisodeNotificationService {
    static let shared = EpisodeNotificationService()

    private let defaults = UserDefaults.standard
    private let guidPrefix = "podlink.lastEpisodeGuid."
    private let notifiedPrefix = "podlink.notifiedGuid."

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func noteFetched(feedURL: URL, episodes: [Episode]) async {
        guard let newest = episodes.first else { return }
        let key = guidPrefix + PrivateFeedAuthStore.canonicalFeedURL(feedURL).absoluteString
        let previous = defaults.string(forKey: key)
        defaults.set(newest.id, forKey: key)
        guard let previous, previous != newest.id else { return }
        guard shouldNotify(feedURL: feedURL) else { return }
        await present(
            title: podcastTitle(for: feedURL),
            body: newest.title,
            identifier: newest.id
        )
    }

    func presentCloudInbox() async {
        let items = (try? await MinCloudClient.shared.fetchDeviceInbox()) ?? []
        for item in items {
            let identifier = item.guid ?? item.id
            let seenKey = notifiedPrefix + identifier
            guard defaults.string(forKey: seenKey) == nil else { continue }
            await present(title: item.title, body: item.body, identifier: identifier)
        }
    }

    private func shouldNotify(feedURL: URL) -> Bool {
        let canonical = PrivateFeedAuthStore.canonicalFeedURL(feedURL).absoluteString
        let followed = Podcast.loadFollowedPodcasts()
        guard let podcast = followed.first(where: {
            PrivateFeedAuthStore.canonicalFeedURL($0.feedURL).absoluteString == canonical
        }) else {
            return false
        }
        if podcast.notificationsEnabled {
            return true
        }
        let preferences = PodLinkNotificationPreferences.load()
        return preferences.priorityPodcastsEnabled && preferences.priorityPodcastIDs.contains(podcast.id)
    }

    private func podcastTitle(for feedURL: URL) -> String {
        let canonical = PrivateFeedAuthStore.canonicalFeedURL(feedURL).absoluteString
        return Podcast.loadFollowedPodcasts().first(where: {
            PrivateFeedAuthStore.canonicalFeedURL($0.feedURL).absoluteString == canonical
        })?.title ?? "New episode"
    }

    private func present(title: String, body: String, identifier: String) async {
        let seenKey = notifiedPrefix + identifier
        guard defaults.string(forKey: seenKey) == nil else { return }
        defaults.set("1", forKey: seenKey)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
