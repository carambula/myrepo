import Foundation

enum PodcastPlayerPreference: String, CaseIterable, Identifiable {
    case system = "system"
    case apple = "apple"
    case spotify = "spotify"
    case overcast = "overcast"
    case pocketCasts = "pocketCasts"
    case podLink = "podLink"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "Automatic"
        case .apple:
            return "Apple Podcasts"
        case .spotify:
            return "Spotify"
        case .overcast:
            return "Overcast"
        case .pocketCasts:
            return "Pocket Casts"
        case .podLink:
            return "Pod Min"
        }
    }
}
