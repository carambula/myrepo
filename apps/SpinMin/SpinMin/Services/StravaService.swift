//
//  StravaService.swift
//  SpinMin
//
//  Strava OAuth authentication and API client.
//
//  Setup (one time): create a personal API application at
//  strava.com/settings/api with Authorization Callback Domain set to
//  "localhost", then paste the Client ID and Client Secret into
//  Settings → Strava in the app.
//

import Foundation
import AuthenticationServices

// MARK: - Keychain Storage

struct KeychainStore {
    static func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.spinmin.strava",
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }
    
    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.spinmin.strava",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.spinmin.strava",
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Response Models

struct StravaTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: TimeInterval  // Unix timestamp
    
    var isExpired: Bool {
        // Refresh a minute early to avoid using a token mid-expiry
        Date().timeIntervalSince1970 >= expiresAt - 60
    }
}

struct StravaGear: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let primary: Bool?
    let distance: Double?  // lifetime meters
}

struct StravaAthlete: Codable {
    let id: Int64
    let firstname: String?
    let lastname: String?
    let bikes: [StravaGear]?
    
    var displayName: String {
        [firstname, lastname].compactMap { $0 }.joined(separator: " ")
    }
}

struct StravaActivity: Codable, Identifiable {
    let id: Int64
    let name: String
    let distance: Double  // meters
    let movingTime: Int  // seconds
    let elapsedTime: Int  // seconds
    let startDate: Date
    let sportType: String
    let gearId: String?
    let totalElevationGain: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, distance
        case movingTime = "moving_time"
        case elapsedTime = "elapsed_time"
        case startDate = "start_date"
        case sportType = "sport_type"
        case gearId = "gear_id"
        case totalElevationGain = "total_elevation_gain"
    }
    
    /// Strava sport types that count as cycling for our purposes
    static let cyclingSportTypes: Set<String> = [
        "Ride", "GravelRide", "MountainBikeRide", "VirtualRide",
        "EBikeRide", "EMountainBikeRide", "Handcycle", "Velomobile",
    ]
    
    var isCyclingActivity: Bool {
        Self.cyclingSportTypes.contains(sportType)
    }
    
    var distanceKm: Double {
        distance / 1000
    }
}

// MARK: - Errors

enum StravaError: LocalizedError {
    case missingCredentials
    case notConnected
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case apiError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Enter your Strava API Client ID and Client Secret first. Create an API application at strava.com/settings/api."
        case .notConnected:
            return "Not connected to Strava. Connect your account in Settings."
        case .authorizationFailed(let detail):
            return "Strava authorization failed: \(detail)"
        case .tokenExchangeFailed(let detail):
            return "Could not complete Strava sign-in: \(detail)"
        case .apiError(let status, let detail):
            return "Strava API error (\(status)): \(detail)"
        }
    }
}

// MARK: - Auth Service

@MainActor
final class StravaAuthService: NSObject, ObservableObject {
    static let shared = StravaAuthService()
    
    private static let redirectURI = "spinmin://localhost"
    private static let callbackScheme = "spinmin"
    
    @Published var isConnected: Bool
    @Published var athleteName: String {
        didSet { UserDefaults.standard.set(athleteName, forKey: "stravaAthleteName") }
    }
    
    private override init() {
        self.isConnected = KeychainStore.get("tokens") != nil
        self.athleteName = UserDefaults.standard.string(forKey: "stravaAthleteName") ?? ""
        super.init()
    }
    
    // MARK: Credentials
    
    var clientId: String? {
        get { KeychainStore.get("clientId") }
        set {
            if let value = newValue, !value.isEmpty { KeychainStore.set(value, forKey: "clientId") }
            else { KeychainStore.delete("clientId") }
        }
    }
    
    var clientSecret: String? {
        get { KeychainStore.get("clientSecret") }
        set {
            if let value = newValue, !value.isEmpty { KeychainStore.set(value, forKey: "clientSecret") }
            else { KeychainStore.delete("clientSecret") }
        }
    }
    
    var hasCredentials: Bool {
        clientId?.isEmpty == false && clientSecret?.isEmpty == false
    }
    
    // MARK: Tokens
    
    private var tokens: StravaTokens? {
        get {
            guard let json = KeychainStore.get("tokens"),
                  let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(StravaTokens.self, from: data)
        }
        set {
            if let newValue = newValue,
               let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                KeychainStore.set(json, forKey: "tokens")
            } else {
                KeychainStore.delete("tokens")
            }
            isConnected = newValue != nil
        }
    }
    
    // MARK: Connect / Disconnect
    
    /// Runs the OAuth authorization-code flow in a web session.
    func connect() async throws {
        guard let clientId = clientId, let secret = clientSecret,
              !clientId.isEmpty, !secret.isEmpty else {
            throw StravaError.missingCredentials
        }
        
        var components = URLComponents(string: "https://www.strava.com/oauth/mobile/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "approval_prompt", value: "auto"),
            URLQueryItem(name: "scope", value: "read,activity:read_all,profile:read_all"),
        ]
        
        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: components.url!,
                callbackURLScheme: Self.callbackScheme
            ) { url, error in
                if let url = url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: StravaError.authorizationFailed(
                        error?.localizedDescription ?? "cancelled"
                    ))
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
        
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw StravaError.authorizationFailed("no authorization code in callback")
        }
        
        let newTokens = try await exchangeToken(parameters: [
            "client_id": clientId,
            "client_secret": secret,
            "code": code,
            "grant_type": "authorization_code",
        ])
        tokens = newTokens
    }
    
    func disconnect() {
        tokens = nil
        athleteName = ""
    }
    
    /// Returns a fresh access token, refreshing via the refresh token if needed.
    func validAccessToken() async throws -> String {
        guard var current = tokens else { throw StravaError.notConnected }
        guard current.isExpired else { return current.accessToken }
        
        guard let clientId = clientId, let secret = clientSecret else {
            throw StravaError.missingCredentials
        }
        
        current = try await exchangeToken(parameters: [
            "client_id": clientId,
            "client_secret": secret,
            "refresh_token": current.refreshToken,
            "grant_type": "refresh_token",
        ])
        tokens = current
        return current.accessToken
    }
    
    private func exchangeToken(parameters: [String: String]) async throws -> StravaTokens {
        var request = URLRequest(url: URL(string: "https://www.strava.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = parameters
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StravaError.tokenExchangeFailed(body)
        }
        
        struct TokenResponse: Codable {
            let accessToken: String
            let refreshToken: String
            let expiresAt: TimeInterval
            let athlete: StravaAthlete?
            
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case expiresAt = "expires_at"
                case athlete
            }
        }
        
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let athlete = decoded.athlete {
            athleteName = athlete.displayName
        }
        return StravaTokens(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: decoded.expiresAt
        )
    }
}

extension StravaAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

// MARK: - API Client

struct StravaAPI {
    private static let baseURL = "https://www.strava.com/api/v3"
    
    /// The authenticated athlete, including their bikes (id + name).
    static func fetchAthlete(accessToken: String) async throws -> StravaAthlete {
        try await get("/athlete", accessToken: accessToken)
    }
    
    /// Activities after the given date, newest pages first from Strava but
    /// we paginate until exhausted. per_page max is 200.
    static func fetchActivities(
        accessToken: String,
        after: Date?,
        maxPages: Int = 5
    ) async throws -> [StravaActivity] {
        var all: [StravaActivity] = []
        
        for page in 1...maxPages {
            var query = "per_page=100&page=\(page)"
            if let after = after {
                query += "&after=\(Int(after.timeIntervalSince1970))"
            }
            let batch: [StravaActivity] = try await get("/athlete/activities?\(query)", accessToken: accessToken)
            all.append(contentsOf: batch)
            if batch.count < 100 { break }
        }
        return all
    }
    
    private static func get<T: Decodable>(_ path: String, accessToken: String) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw StravaError.apiError(0, "no HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw StravaError.apiError(http.statusCode, body)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
