import Foundation

/// Shared client for the Min Cloud ideas / bug-report loop.
/// Uses the same base URL and session keys as mov/pod Min Cloud when present.
public enum FeedbackClient {
    public static let baseURLKey = "mincloud.baseURL"
    public static let tokenKey = "mincloud.token"
    public static let deviceIdKey = "minapps.feedback.deviceId"

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

    public static var authToken: String? {
        let value = UserDefaults.standard.string(forKey: tokenKey)
        return (value?.isEmpty == false) ? value : nil
    }

    public static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        // Prefer shared Min Cloud device id when mov/pod already created one.
        if let shared = UserDefaults.standard.string(forKey: "mincloud.deviceId"), !shared.isEmpty {
            UserDefaults.standard.set(shared, forKey: deviceIdKey)
            return shared
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: deviceIdKey)
        return created
    }

    public struct Item: Identifiable, Decodable, Sendable, Hashable {
        public let id: String
        public let app: String?
        public let kind: String
        public let title: String
        public let status: String
        public let statusRaw: String?
        public let createdAt: String?
        public let shippedAt: String?

        enum CodingKeys: String, CodingKey {
            case id, app, kind, title, status
            case statusRaw = "status_raw"
            case createdAt = "created_at"
            case shippedAt = "shipped_at"
        }

        public var publicStatusLabel: String {
            switch status {
            case "received": return "Received"
            case "in review": return "In review"
            case "building": return "Building"
            case "shipped": return "Shipped"
            case "declined": return "Declined"
            default: return status.capitalized
            }
        }
    }

    private struct ListResponse: Decodable {
        let items: [Item]
    }

    public enum ClientError: LocalizedError {
        case badURL
        case http(Int, String)
        case decoding

        public var errorDescription: String? {
            switch self {
            case .badURL: return "Could not reach Min Cloud."
            case .http(_, let message): return message.isEmpty ? "Request failed." : message
            case .decoding: return "Unexpected response from Min Cloud."
            }
        }
    }

    public static func list(app: AgentAppID, limit: Int = 50) async throws -> [Item] {
        var components = URLComponents(url: baseURL.appendingPathComponent("v1/feedback"), resolvingAgainstBaseURL: false)
        var query: [URLQueryItem] = [
            URLQueryItem(name: "app", value: app.rawValue),
            URLQueryItem(name: "device_id", value: deviceId),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        components?.queryItems = query
        guard let url = components?.url else { throw ClientError.badURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(&request)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(data: data, response: response)
        do {
            return try JSONDecoder().decode(ListResponse.self, from: data).items
        } catch {
            throw ClientError.decoding
        }
    }

    public static func submit(
        app: AgentAppID,
        kind: String,
        title: String,
        body: String,
        page: String = "ios"
    ) async throws -> Item {
        let url = baseURL.appendingPathComponent("v1/feedback")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        let payload: [String: Any] = [
            "app": app.rawValue,
            "kind": kind,
            "title": title,
            "body": body,
            "page": page,
            "device_id": deviceId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfNeeded(data: data, response: response)
        do {
            return try JSONDecoder().decode(Item.self, from: data)
        } catch {
            throw ClientError.decoding
        }
    }

    private static func applyAuth(_ request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private static func throwIfNeeded(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            var message = ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                message = String(describing: json["error"] ?? json["detail"] ?? "")
            }
            if message.isEmpty {
                message = String(data: data, encoding: .utf8) ?? ""
            }
            throw ClientError.http(http.statusCode, message)
        }
    }
}
