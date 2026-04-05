import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

@MainActor
@Observable
final class GoogleOAuthService: NSObject {
    struct Tokens: Codable {
        let accessToken: String
        let refreshToken: String?
        let expiry: Date
    }

    enum OAuthError: LocalizedError {
        case missingClientID
        case missingCallbackScheme
        case invalidRedirectURL
        case callbackSchemeMismatch
        case cancelled
        case invalidResponse
        case tokenExchangeFailed
        case missingAccessToken

        var errorDescription: String? {
            switch self {
            case .missingClientID:
                return "Missing `GOOGLE_CLIENT_ID` in Info.plist."
            case .missingCallbackScheme:
                return "Missing OAuth callback URL scheme in Info.plist."
            case .invalidRedirectURL:
                return "Could not build OAuth redirect URL."
            case .callbackSchemeMismatch:
                return "OAuth redirect URI scheme does not match an app URL scheme."
            case .cancelled:
                return "Sign-in was cancelled."
            case .invalidResponse:
                return "Google sign-in returned an invalid response."
            case .tokenExchangeFailed:
                return "Could not exchange the authorization code for tokens."
            case .missingAccessToken:
                return "Google sign-in finished without an access token."
            }
        }
    }

    private let keychainKey = "yourtube_google_oauth_tokens_v1"
    private var authSession: ASWebAuthenticationSession?
    var isSignedIn = false

    override init() {
        super.init()
        isSignedIn = readTokensFromKeychain() != nil
    }

    func validAccessToken() async throws -> String {
        if let tokens = readTokensFromKeychain(), tokens.expiry > .now.addingTimeInterval(30) {
            return tokens.accessToken
        }
        guard let refreshed = try await refreshAccessTokenIfPossible() else {
            throw OAuthError.missingAccessToken
        }
        storeTokensInKeychain(refreshed)
        isSignedIn = true
        return refreshed.accessToken
    }

    func signIn() async throws {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
              !clientID.isEmpty else {
            throw OAuthError.missingClientID
        }

        guard let callbackScheme = Self.callbackURLSchemeFromInfoPlist() else {
            throw OAuthError.missingCallbackScheme
        }
        guard let redirectURIString = Self.redirectURIFromInfoPlist(defaultCallbackScheme: callbackScheme),
              let redirectURI = URL(string: redirectURIString) else {
            throw OAuthError.invalidRedirectURL
        }
        guard redirectURI.scheme == callbackScheme else {
            throw OAuthError.callbackSchemeMismatch
        }

        let codeVerifier = Self.randomString(length: 64)
        let codeChallenge = Self.base64URL(SHA256.hash(data: Data(codeVerifier.utf8)))
        let state = UUID().uuidString

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid profile email https://www.googleapis.com/auth/youtube.readonly"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ]

        guard let authURL = components?.url else {
            throw OAuthError.invalidRedirectURL
        }

        let callbackURL = try await authorize(url: authURL, callbackScheme: callbackScheme)
        guard let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let callbackState = urlComponents.queryItems?.first(where: { $0.name == "state" })?.value,
              callbackState == state,
              let code = urlComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.invalidResponse
        }

        let tokens = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier,
            redirectURI: redirectURIString,
            clientID: clientID
        )
        storeTokensInKeychain(tokens)
        isSignedIn = true
    }

    func signOut() {
        deleteTokensFromKeychain()
        isSignedIn = false
    }

    private func authorize(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { url, error in
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.cancelled)
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: OAuthError.invalidResponse)
                    return
                }
                continuation.resume(returning: url)
            }
            authSession?.prefersEphemeralWebBrowserSession = true
            authSession?.presentationContextProvider = self
            _ = authSession?.start()
        }
    }

    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectURI: String,
        clientID: String
    ) async throws -> Tokens {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyItems = [
            "code=\(code)",
            "client_id=\(clientID)",
            "redirect_uri=\(redirectURI)",
            "grant_type=authorization_code",
            "code_verifier=\(codeVerifier)",
        ]
        request.httpBody = bodyItems.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= status else {
            throw OAuthError.tokenExchangeFailed
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: TimeInterval
        }
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        return Tokens(
            accessToken: tokenResponse.access_token,
            refreshToken: tokenResponse.refresh_token,
            expiry: .now.addingTimeInterval(tokenResponse.expires_in)
        )
    }

    private func refreshAccessTokenIfPossible() async throws -> Tokens? {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String,
              let existing = readTokensFromKeychain(),
              let refreshToken = existing.refreshToken else {
            return nil
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyItems = [
            "client_id=\(clientID)",
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
        ]
        request.httpBody = bodyItems.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= status else {
            return nil
        }

        struct RefreshResponse: Decodable {
            let access_token: String
            let expires_in: TimeInterval
        }
        let refresh = try JSONDecoder().decode(RefreshResponse.self, from: data)
        return Tokens(
            accessToken: refresh.access_token,
            refreshToken: refreshToken,
            expiry: .now.addingTimeInterval(refresh.expires_in)
        )
    }

    private func storeTokensInKeychain(_ tokens: Tokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func readTokensFromKeychain() -> Tokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Tokens.self, from: data)
    }

    private func deleteTokensFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func randomString(length: Int) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    private static func base64URL(_ digest: SHA256Digest) -> String {
        Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func callbackURLSchemeFromInfoPlist() -> String? {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return nil
        }
        for urlType in urlTypes {
            if let schemes = urlType["CFBundleURLSchemes"] as? [String],
               let firstScheme = schemes.first,
               !firstScheme.isEmpty {
                return firstScheme
            }
        }
        return nil
    }

    private static func redirectURIFromInfoPlist(defaultCallbackScheme callbackScheme: String) -> String? {
        if let explicitRedirectURI = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_REDIRECT_URI") as? String,
           !explicitRedirectURI.isEmpty {
            return explicitRedirectURI
        }

        // Google OAuth for native iOS apps uses this callback path.
        return "\(callbackScheme):/oauthredirect"
    }
}

extension GoogleOAuthService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
