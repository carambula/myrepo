import Foundation

struct MinCloudSessionResponse: Decodable {
    struct User: Decodable {
        let id: String
        let email: String
        let handle: String
        let displayName: String
        let isAdmin: Bool?
    }

    struct Session: Decodable {
        let token: String
        let expiresAt: String?
    }

    let user: User
    let session: Session
}

struct MinCloudMovieCatalog: Decodable {
    struct Movie: Decodable {
        struct Provider: Decodable {
            let id: String?
            let name: String?
            let logoPath: String?
            let url: String?
            let providerId: Int?
            let providerName: String?
        }

        struct SourceLink: Decodable {
            let identifier: String?
            let rank: Int?
            let sourceTitle: String?
        }

        let id: String
        let tmdbId: Int?
        let title: String
        let year: Int?
        let posterPath: String?
        let backdropPath: String?
        let overview: String?
        let mpaaRating: String?
        let genres: [String]?
        let lastUpdated: String?
        let streamingServices: [Provider]?
        let sources: [SourceLink]?
    }

    struct Source: Decodable {
        let identifier: String
        let name: String
        let type: String
        let url: String?
        let is_ranked: Bool?
        let enabled: Bool?
    }

    let revision: Int
    let movies: [Movie]
    let sources: [Source]
    let truncated: Bool?
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
        guard MinCloudSettings.token != nil else { return }
        _ = try? await request(path: "/v1/auth/logout", method: "POST", authorized: true)
        MinCloudSettings.clearSession()
    }

    func fetchMovieCatalog(updatedSince: String? = nil, limit: Int = 400) async throws -> MinCloudMovieCatalog {
        var items: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        if let updatedSince {
            items.append(URLQueryItem(name: "updatedSince", value: updatedSince))
        }
        return try await get(path: "/v1/mov/catalog", query: items)
    }

    func registerDevice(pushToken: String?, timezone: String) async throws {
        var body: [String: Any] = [
            "app": "watchedit",
            "platform": "ios",
            "timezone": timezone
        ]
        if let pushToken {
            body["pushToken"] = pushToken
        }
        _ = try await request(
            path: "/v1/me/devices",
            method: "PUT",
            authorized: true,
            body: body
        )
    }

    func saveNotificationPreferences(_ preferences: [String: Any]) async throws {
        _ = try await request(
            path: "/v1/me/notifications",
            method: "PUT",
            authorized: true,
            body: [
                "app": "watchedit",
                "preferences": preferences
            ]
        )
    }

    func pushLibrary(items: [[String: Any]]) async throws {
        _ = try await request(
            path: "/v1/me/library/mov",
            method: "PUT",
            authorized: true,
            body: ["items": items]
        )
    }

    private func postSession(path: String, body: [String: Any]) async throws -> MinCloudSessionResponse {
        let data = try await request(path: path, method: "POST", authorized: false, body: body)
        let decoded = try JSONDecoder().decode(MinCloudSessionResponse.self, from: data)
        MinCloudSettings.storeSession(token: decoded.session.token, handle: decoded.user.handle, email: decoded.user.email)
        return decoded
    }

    private func get<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        let data = try await request(path: path, method: "GET", authorized: false, query: query)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MinCloudError.decoding
        }
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
        if authorized {
            guard let token = MinCloudSettings.token else {
                throw MinCloudError.notSignedIn
            }
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
