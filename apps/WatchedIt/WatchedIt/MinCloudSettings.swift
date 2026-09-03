import Foundation

public enum MinCloudSettings {
    public static let baseURLKey = "mincloud.baseURL"
    static let tokenKey = "mincloud.token"
    static let handleKey = "mincloud.handle"
    static let emailKey = "mincloud.email"
    public static let iCloudBackupEnabledKey = "mincloud.icloudBackupEnabled"
    static let lastCatalogRevisionKey = "mincloud.mov.revision"

    public static var defaultBaseURL: URL {
        URL(string: "https://min-cloud.up.railway.app")!
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

    /// Defaults on so existing installs keep today's iCloud behavior until the user opts out.
    public static var iCloudBackupEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: iCloudBackupEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: iCloudBackupEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: iCloudBackupEnabledKey) }
    }

    static var lastCatalogRevision: Int {
        get { UserDefaults.standard.integer(forKey: lastCatalogRevisionKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastCatalogRevisionKey) }
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
