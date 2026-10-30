import Foundation

// MARK: - Per-show ad settings
//
// Simplified model (Oct 29, 2026):
// - Smart skip (+30s jumps whole breaks) is always on for every show. No toggle.
// - Auto-skip is a per-show toggle.
// - Intro/outro trims are per-show seconds.

/// Per-show ad profile: auto-skip toggle plus deterministic intro/outro trims.
/// Stored separately from `Podcast` so the iCloud-synced followed-podcasts
/// model doesn't churn as ad settings grow.
struct ShowAdProfile: Codable {
    var autoSkipEnabled: Bool = false
    var introTrimSeconds: TimeInterval = 0
    var outroTrimSeconds: TimeInterval = 0
}

final class ShowAdProfileStore {
    static let shared = ShowAdProfileStore()

    private static let defaultsKey = "showAdProfilesV2"
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

    func profile(forPodcast podcast: Podcast) -> ShowAdProfile {
        let byID = profile(for: podcast.id)
        // Prefer the id-keyed profile; fall back to feed URL
        if byID.autoSkipEnabled || byID.introTrimSeconds > 0 || byID.outroTrimSeconds > 0 {
            return byID
        }
        return profile(for: podcast.feedURL.absoluteString)
    }

    /// All podcast IDs with non-default profiles (for the settings overview).
    func allProfiledPodcastIDs() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return allProfiles().filter { _, profile in
            profile.autoSkipEnabled || profile.introTrimSeconds > 0 || profile.outroTrimSeconds > 0
        }.map(\.key)
    }

    private func allProfiles() -> [String: ShowAdProfile] {
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let profiles = try? JSONDecoder().decode([String: ShowAdProfile].self, from: data)
        else { return [:] }
        return profiles
    }
}
