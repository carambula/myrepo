import Foundation

enum MinCloudSettings {
    static let baseURLKey = "mincloud.baseURL"
    static let tokenKey = "mincloud.token"
    static let handleKey = "mincloud.handle"
    static let emailKey = "mincloud.email"
    static let iCloudBackupEnabledKey = "mincloud.icloudBackupEnabled"
    static let deviceIdKey = "mincloud.deviceId"

    static var defaultBaseURL: URL {
        URL(string: "https://min-cloud-production.up.railway.app")!
    }

    static var baseURL: URL {
        if let raw = UserDefaults.standard.string(forKey: baseURLKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: raw),
           let scheme = url.scheme,
           scheme == "http" || scheme == "https" {
            return url
        }
        return defaultBaseURL
    }

    static var token: String? {
        get { UserDefaults.standard.string(forKey: tokenKey) }
        set { UserDefaults.standard.set(newValue, forKey: tokenKey) }
    }

    static var handle: String? {
        get { UserDefaults.standard.string(forKey: handleKey) }
        set { UserDefaults.standard.set(newValue, forKey: handleKey) }
    }

    static var email: String? {
        get { UserDefaults.standard.string(forKey: emailKey) }
        set { UserDefaults.standard.set(newValue, forKey: emailKey) }
    }

    static var isSignedIn: Bool { token?.isEmpty == false }

    /// Stable anonymous device id so followed feeds can be refreshed and notified without an account.
    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: deviceIdKey)
        return created
    }

    static var iCloudBackupEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: iCloudBackupEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: iCloudBackupEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: iCloudBackupEnabledKey) }
    }

    static func storeSession(token: String, handle: String?, email: String?) {
        self.token = token
        self.handle = handle
        self.email = email
    }

    static func clearSession() {
        token = nil
        handle = nil
        email = nil
    }
}
