import Foundation

// MARK: - Per-show ad settings

/// Per-show ad-skip behavior. `.auto` is reserved for Phase 2 (auto-skip);
/// Phase 0 surfaces `.off` and `.smartSkip`.
enum AdSkipMode: String, Codable, CaseIterable {
    case off
    case smartSkip
    case auto

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .smartSkip: return "Smart skip"
        case .auto: return "Auto-skip"
        }
    }
}

/// Per-show ad profile: skip mode plus deterministic intro/outro trims.
/// Stored separately from `Podcast` so the iCloud-synced followed-podcasts
/// model doesn't churn as ad settings grow.
struct ShowAdProfile: Codable {
    var mode: AdSkipMode = .smartSkip
    var introTrimSeconds: TimeInterval = 0
    var outroTrimSeconds: TimeInterval = 0
}

final class ShowAdProfileStore {
    static let shared = ShowAdProfileStore()

    private static let defaultsKey = "showAdProfilesV1"
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func profile(for podcastID: String) -> ShowAdProfile {
        lock.lock()
        defer { lock.unlock() }
        return allProfiles()[podcastID] ?? ShowAdProfile()
    }

    func save(_ profile: ShowAdProfile, for podcastID: String) {
        lock.lock()
        defer { lock.unlock() }
        var profiles = allProfiles()
        profiles[podcastID] = profile
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    /// Saves under both the podcast's id and its feed URL, because
    /// `Episode.podcastID` may hold either form depending on the feed path.
    func save(_ profile: ShowAdProfile, forPodcast podcast: Podcast) {
        save(profile, for: podcast.id)
        let feedKey = podcast.feedURL.absoluteString
        if feedKey != podcast.id {
            save(profile, for: feedKey)
        }
    }

    /// All podcast IDs with a saved profile. Used by the ad-settings
    /// overview to list only shows the user has customized.
    func allProfiledPodcastIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(allProfiles().keys)
    }

    private func allProfiles() -> [String: ShowAdProfile] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let profiles = try? JSONDecoder().decode([String: ShowAdProfile].self, from: data)
        else { return [:] }
        return profiles
    }
}

// MARK: - App-wide ad-skip settings

/// App-wide ad-skip settings. The key must match
/// `@AppStorage("adSkipEnabled")` in `PlaybackSettingsView`.
enum AdSkipSettings {
    private static let enabledKey = "adSkipEnabled"

    /// Master toggle. Defaults ON: smart 30s-forward is the safe default —
    /// it never skips anything the user can't see and undo.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }
}
