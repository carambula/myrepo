import CryptoKit
import Foundation
import Security

/// HTTP authentication for member / private RSS feeds (Bearer or Basic). Secrets live in Keychain only.
enum FeedHTTPAuth: Codable, Equatable, Sendable {
    case bearer(String)
    case basic(username: String, password: String)

    func apply(to request: inout URLRequest) {
        switch self {
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .basic(let username, let password):
            let raw = "\(username):\(password)"
            let encoded = Data(raw.utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Stable fragment for cache keys so authed and unauthenticated responses never collide.
    func cacheKeySegment() -> String {
        let payload: Data
        switch self {
        case .bearer(let t):
            payload = Data("b:\(t)".utf8)
        case .basic(let u, let p):
            payload = Data("a:\(u):\(p)".utf8)
        }
        let digest = SHA256.hash(data: payload)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    private enum CodingKeys: String, CodingKey {
        case kind, token, username, password
    }

    private enum Kind: String, Codable {
        case bearer, basic
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bearer(let token):
            try c.encode(Kind.bearer, forKey: .kind)
            try c.encode(token, forKey: .token)
        case .basic(let username, let password):
            try c.encode(Kind.basic, forKey: .kind)
            try c.encode(username, forKey: .username)
            try c.encode(password, forKey: .password)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .kind)
        switch kind {
        case .bearer:
            self = .bearer(try c.decode(String.self, forKey: .token))
        case .basic:
            self = .basic(
                username: try c.decode(String.self, forKey: .username),
                password: try c.decode(String.self, forKey: .password)
            )
        }
    }
}

actor PrivateFeedAuthStore {
    static let shared = PrivateFeedAuthStore()

    private let service = "com.podlink.privateFeedAuth"

    private init() {}

    static func canonicalFeedURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.fragment = nil
        return components.url ?? url
    }

    private func accountKey(for feedURL: URL) -> String {
        Self.canonicalFeedURL(feedURL).absoluteString
    }

    func credential(for feedURL: URL) -> FeedHTTPAuth? {
        let account = accountKey(for: feedURL)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(FeedHTTPAuth.self, from: data)
    }

    func saveCredential(_ auth: FeedHTTPAuth, for feedURL: URL) throws {
        let account = accountKey(for: feedURL)
        let data = try JSONEncoder().encode(auth)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func removeCredential(for feedURL: URL) {
        let account = accountKey(for: feedURL)
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }

    func cacheKeySegment(for feedURL: URL) -> String? {
        guard let auth = credential(for: feedURL) else { return nil }
        return auth.cacheKeySegment()
    }

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }
}
