import Foundation

struct MinCloudSessionResponse: Decodable {
    struct User: Decodable {
        let email: String
        let handle: String
        let displayName: String
    }

    struct Session: Decodable {
        let token: String
    }

    let user: User
    let session: Session
}

struct MinCloudFeedEpisode: Decodable {
    let id: String?
    let guid: String?
    let title: String
    let description: String?
    let publishDate: String?
    let duration: TimeInterval?
    let audioUrl: String?
    let videoUrl: String?
    let artworkUrl: String?
    let episodeNumber: Int?
    let seasonNumber: Int?
}

struct MinCloudFeedResponse: Decodable {
    let podcastId: String?
    let source: String?
    let episodes: [MinCloudFeedEpisode]
}

struct MinCloudPodLibraryItem: Decodable {
    let podcastId: String
    let feedUrl: String?
    let title: String?
    let artworkUrl: String?
    let isFollowed: Bool?
    let notificationsEnabled: Bool?
}

struct MinCloudInboxItem: Decodable {
    let id: String
    let title: String
    let body: String
    let payload: Payload?

    struct Payload: Decodable {
        let podcastId: String?
        let episodeTitle: String?
        let publishDate: String?
    }

    var guid: String? {
        if let podcastId = payload?.podcastId, let episodeTitle = payload?.episodeTitle {
            return "\(podcastId):\(episodeTitle)"
        }
        return nil
    }
}

enum MinCloudError: Error {
    case invalidURL
    case httpFailure(Int)
    case decoding
    case notSignedIn
}

actor MinCloudClient {
    static let shared = MinCloudClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config)
    }()

    func isReachable() async -> Bool {
        guard let url = URL(string: "/health", relativeTo: MinCloudSettings.baseURL) else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func register(email: String, password: String, displayName: String?) async throws -> MinCloudSessionResponse {
        try await postSession(path: "/v1/auth/register", body: [
            "email": email,
            "password": password,
            "displayName": displayName ?? ""
        ])
    }

    func login(email: String, password: String) async throws -> MinCloudSessionResponse {
        try await postSession(path: "/v1/auth/login", body: [
            "email": email,
            "password": password
        ])
    }

    func logout() async {
        _ = try? await request(path: "/v1/auth/logout", method: "POST", authorized: true)
        MinCloudSettings.clearSession()
    }

    func fetchFeedEpisodes(feedURL: URL) async throws -> [Episode] {
        let data = try await request(
            path: "/v1/pod/feeds",
            method: "GET",
            authorized: false,
            query: [URLQueryItem(name: "url", value: feedURL.absoluteString)]
        )
        let decoded = try JSONDecoder().decode(MinCloudFeedResponse.self, from: data)
        return decoded.episodes.compactMap { episode in
            guard let audio = episode.audioUrl.flatMap(URL.init(string:)) else { return nil }
            let published = episode.publishDate.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
            return Episode(
                id: episode.guid ?? episode.id ?? UUID().uuidString,
                podcastID: feedURL.absoluteString,
                title: episode.title,
                description: episode.description ?? "",
                publishDate: published,
                duration: episode.duration ?? 0,
                audioURL: audio,
                videoURL: episode.videoUrl.flatMap(URL.init(string:)),
                artworkURL: episode.artworkUrl.flatMap(URL.init(string:)),
                episodeNumber: episode.episodeNumber,
                seasonNumber: episode.seasonNumber
            )
        }
    }

    func saveNotificationPreferences(_ preferences: [String: Any]) async throws {
        _ = try await request(
            path: "/v1/me/notifications",
            method: "PUT",
            authorized: true,
            body: [
                "app": "podlink",
                "preferences": preferences
            ]
        )
    }

    func pushLibrary(items: [[String: Any]]) async throws {
        _ = try await request(
            path: "/v1/me/library/pod",
            method: "PUT",
            authorized: true,
            body: ["items": items]
        )
    }

    func fetchPodcastLibrary() async throws -> [MinCloudPodLibraryItem] {
        let data = try await request(
            path: "/v1/me/library/pod",
            method: "GET",
            authorized: true
        )
        let decoded = try JSONDecoder().decode(LibraryResponse.self, from: data)
        return decoded.items
    }

    func registerDevice() async {
        var body: [String: Any] = [
            "deviceId": MinCloudSettings.deviceId,
            "app": "podlink",
            "platform": "ios",
            "timezone": TimeZone.current.identifier
        ]
        if let token = MinCloudSettings.pushToken {
            body["pushToken"] = token
        }
        _ = try? await request(
            path: "/v1/devices/register",
            method: "POST",
            authorized: MinCloudSettings.isSignedIn,
            body: body
        )
    }

    private struct LibraryResponse: Decodable {
        let items: [MinCloudPodLibraryItem]
    }

    func syncFollowedWatches(_ podcasts: [Podcast]) async {
        await registerDevice()
        let preferences = PodLinkNotificationPreferences.load()
        let items: [[String: Any]] = podcasts.map { podcast in
            let notify = podcast.notificationsEnabled
                || (preferences.priorityPodcastsEnabled && preferences.priorityPodcastIDs.contains(podcast.id))
            var item: [String: Any] = [
                "podcastId": podcast.id,
                "feedUrl": podcast.feedURL.absoluteString,
                "title": podcast.title,
                "notificationsEnabled": notify
            ]
            if let artwork = podcast.displayArtworkURL?.absoluteString {
                item["artworkUrl"] = artwork
            }
            if let itunesID = podcast.itunesID {
                item["itunesId"] = itunesID
            }
            return item
        }
        _ = try? await request(
            path: "/v1/pod/watch",
            method: "POST",
            authorized: false,
            body: [
                "deviceId": MinCloudSettings.deviceId,
                "replace": true,
                "items": items
            ]
        )
    }

    func fetchDeviceInbox() async throws -> [MinCloudInboxItem] {
        let data = try await request(
            path: "/v1/devices/\(MinCloudSettings.deviceId)/inbox",
            method: "GET",
            authorized: false,
            query: [URLQueryItem(name: "app", value: "podlink")]
        )
        let decoded = try JSONDecoder().decode(InboxResponse.self, from: data)
        return decoded.inbox
    }

    private struct InboxResponse: Decodable {
        let inbox: [MinCloudInboxItem]
    }

    private func postSession(path: String, body: [String: Any]) async throws -> MinCloudSessionResponse {
        let data = try await request(path: path, method: "POST", authorized: false, body: body)
        let decoded = try JSONDecoder().decode(MinCloudSessionResponse.self, from: data)
        MinCloudSettings.storeSession(token: decoded.session.token, handle: decoded.user.handle, email: decoded.user.email)
        return decoded
    }

    private func request(
        path: String,
        method: String,
        authorized: Bool,
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard var components = URLComponents(url: URL(string: path, relativeTo: MinCloudSettings.baseURL) ?? MinCloudSettings.baseURL, resolvingAgainstBaseURL: true) else {
            throw MinCloudError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw MinCloudError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = MinCloudSettings.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            throw MinCloudError.httpFailure(status)
        }
        return data
    }
}
