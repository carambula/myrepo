import Foundation
import Security

/// Stores an optional AssemblyAI API key in the Keychain (same pattern as `PrivateFeedAuthStore`).
enum TranscriptionAPIKeyStore {
    private static let service = "com.podlink.transcription.assemblyai"
    private static let account = "apiKey"

    static func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let string = String(data: data, encoding: .utf8), !string.isEmpty else {
            return nil
        }
        return string
    }

    static func saveAPIKey(_ key: String?) throws {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)

        guard let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let data = Data(key.utf8)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static var hasAPIKey: Bool { loadAPIKey() != nil }

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }
}
