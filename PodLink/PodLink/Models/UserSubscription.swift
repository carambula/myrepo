import Foundation

struct UserSubscription: Identifiable, Codable, Hashable {
    let id: String
    let podcastID: String
    let platform: SubscriptionPlatform?
    var isAuthenticated: Bool = false

    enum SubscriptionPlatform: String, Codable, CaseIterable {
        case patreon
        case applePodcasts
        case spotify
        case memberful
        case supercast
        case glow
        case custom

        var displayName: String {
            switch self {
            case .patreon: return "Patreon"
            case .applePodcasts: return "Apple Podcasts"
            case .spotify: return "Spotify"
            case .memberful: return "Memberful"
            case .supercast: return "Supercast"
            case .glow: return "Glow"
            case .custom: return "Custom RSS"
            }
        }

        var systemImage: String {
            switch self {
            case .patreon: return "heart.circle"
            case .applePodcasts: return "apple.logo"
            case .spotify: return "waveform"
            case .memberful: return "person.badge.key"
            case .supercast: return "antenna.radiowaves.left.and.right"
            case .glow: return "lightbulb"
            case .custom: return "link"
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        podcastID: String,
        platform: SubscriptionPlatform? = nil,
        isAuthenticated: Bool = false
    ) {
        self.id = id
        self.podcastID = podcastID
        self.platform = platform
        self.isAuthenticated = isAuthenticated
    }
}
