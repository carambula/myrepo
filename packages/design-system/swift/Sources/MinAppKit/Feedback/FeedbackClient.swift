import Foundation
#if os(iOS)
import UIKit
#endif

public enum FeedbackKind: String, CaseIterable, Codable, Sendable {
    case idea
    case bug

    public var title: String {
        switch self {
        case .idea: return "Ideas"
        case .bug: return "Bugs"
        }
    }

    public var singular: String {
        switch self {
        case .idea: return "Idea"
        case .bug: return "Bug"
        }
    }
}

public enum FeedbackStatus: String, CaseIterable, Codable, Sendable {
    case open
    case planned
    case inProgress = "in_progress"
    case shipped
    case closed
    case hidden

    public var title: String {
        switch self {
        case .open: return "Open"
        case .planned: return "Planned"
        case .inProgress: return "In progress"
        case .shipped: return "Shipped"
        case .closed: return "Closed"
        case .hidden: return "Hidden"
        }
    }
}

public struct FeedbackItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var app: String
    public var kind: FeedbackKind
    public var status: FeedbackStatus
    public var title: String
    public var body: String?
    public var voteCount: Int
    public var authorHandle: String?
    public var createdAt: String
    public var updatedAt: String
    public var voted: Bool

    public var metadataLine: String {
        let votes = voteCount == 1 ? "1 vote" : "\(voteCount) votes"
        return [status.title, votes, authorHandle.map { "@\($0)" }]
            .compactMap { $0 }
            .joined(separator: AgentSecurity.metadataSeparator)
    }
}

public enum FeedbackIdentity {
    public static let baseURLKey = "mincloud.baseURL"
    public static let tokenKey = "mincloud.token"
    public static let deviceIdKey = "mincloud.deviceId"

    public static var defaultBaseURL: URL {
        URL(string: "https://min-cloud-production.up.railway.app")!
    }

    public static var baseURL: URL {
        if let raw = UserDefaults.standard.string(forKey: baseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: raw),
           let scheme = url.scheme,
           scheme == "http" || scheme == "https" {
            return url
        }
        return defaultBaseURL
    }

    public static var token: String? {
        UserDefaults.standard.string(forKey: tokenKey)
    }

    public static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: deviceIdKey)
        return created
    }

    public static var appContext: [String: String] {
        var context: [String: String] = [:]
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            context["appVersion"] = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            context["build"] = build
        }
        #if os(iOS)
        context["platform"] = "iOS"
        context["systemVersion"] = UIDevice.current.systemVersion
        #elseif os(macOS)
        context["platform"] = "macOS"
        #elseif os(tvOS)
        context["platform"] = "tvOS"
        #elseif os(watchOS)
        context["platform"] = "watchOS"
        #endif
        return context
    }
}

public enum FeedbackClientError: LocalizedError, Sendable {
    case unreachable
    case server(String)

    public var errorDescription: String? {
        switch self {
        case .unreachable:
            return "Min Cloud is unreachable. Try again when you have a connection."
        case .server(let message):
            return message
        }
    }
}

public actor FeedbackClient {
    public static let shared = FeedbackClient()

    private struct ListResponse: Decodable {
        let items: [FeedbackItem]
    }

    private struct ItemResponse: Decodable {
        let item: FeedbackItem
    }

    public func list(app: AgentAppID, kind: FeedbackKind) async throws -> [FeedbackItem] {
        let url = try makeURL(
            "v1/feedback",
            query: [
                URLQueryItem(name: "app", value: app.rawValue),
                URLQueryItem(name: "kind", value: kind.rawValue),
                URLQueryItem(name: "deviceId", value: FeedbackIdentity.deviceId)
            ]
        )
        let response: ListResponse = try await get(url)
        return response.items
    }

    public func item(id: String) async throws -> FeedbackItem {
        let url = try makeURL(
            "v1/feedback/\(id)",
            query: [URLQueryItem(name: "deviceId", value: FeedbackIdentity.deviceId)]
        )
        let response: ItemResponse = try await get(url)
        return response.item
    }

    public func submit(
        app: AgentAppID,
        kind: FeedbackKind,
        title: String,
        body: String
    ) async throws -> FeedbackItem {
        let response: ItemResponse = try await send(
            path: "v1/feedback",
            method: "POST",
            body: [
                "app": app.rawValue,
                "kind": kind.rawValue,
                "title": title,
                "body": body,
                "deviceId": FeedbackIdentity.deviceId,
                "context": FeedbackIdentity.appContext
            ]
        )
        return response.item
    }

    public func toggleVote(id: String) async throws -> FeedbackItem {
        let response: ItemResponse = try await send(
            path: "v1/feedback/\(id)/vote",
            method: "POST",
            body: ["deviceId": FeedbackIdentity.deviceId]
        )
        return response.item
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        attachAuth(&request)
        return try await decode(request)
    }

    private func send<T: Decodable>(path: String, method: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: try makeURL(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        attachAuth(&request)
        return try await decode(request)
    }

    private func makeURL(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard var components = URLComponents(url: FeedbackIdentity.baseURL, resolvingAgainstBaseURL: false) else {
            throw FeedbackClientError.unreachable
        }
        let existing = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = "\(existing)/\(trimmedPath)"
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw FeedbackClientError.unreachable
        }
        return url
    }

    private func attachAuth(_ request: inout URLRequest) {
        if let token = FeedbackIdentity.token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func decode<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw FeedbackClientError.unreachable
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if let decoded = try? JSONDecoder().decode(T.self, from: data), (200...299).contains(status) {
            return decoded
        }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = payload["error"] as? String {
            throw FeedbackClientError.server(message)
        }
        if status == 0 {
            throw FeedbackClientError.unreachable
        }
        throw FeedbackClientError.server("Could not load feedback.")
    }
}
