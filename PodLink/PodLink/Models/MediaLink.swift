import Foundation

struct MediaLink: Identifiable, Codable, Hashable {
    let id: String
    let type: MediaLinkType
    let title: String
    let subtitle: String?
    let imageURL: URL?
    let destinationURL: URL
    let appSchemeURL: URL?
    let confidence: Float
    let timestamp: TimeInterval?
    let sourceText: String?

    enum MediaLinkType: String, Codable, CaseIterable {
        case movie
        case tvShow
        case sportingEvent
        case sportingReplay
        case youtubeVideo
        case youtubeChannel
        case app
        case book
        case song
        case album
        case podcast
        case website
        case product
        case person

        var displayName: String {
            switch self {
            case .movie: return "Movie"
            case .tvShow: return "TV Show"
            case .sportingEvent: return "Sporting Event"
            case .sportingReplay: return "Replay"
            case .youtubeVideo: return "YouTube"
            case .youtubeChannel: return "YouTube Channel"
            case .app: return "App"
            case .book: return "Book"
            case .song: return "Song"
            case .album: return "Album"
            case .podcast: return "Podcast"
            case .website: return "Website"
            case .product: return "Product"
            case .person: return "Person"
            }
        }

        var systemImage: String {
            switch self {
            case .movie: return "film"
            case .tvShow: return "tv"
            case .sportingEvent: return "sportscourt"
            case .sportingReplay: return "play.rectangle"
            case .youtubeVideo: return "play.rectangle.fill"
            case .youtubeChannel: return "person.crop.rectangle"
            case .app: return "app.badge"
            case .book: return "book"
            case .song: return "music.note"
            case .album: return "opticaldisc"
            case .podcast: return "mic"
            case .website: return "globe"
            case .product: return "shippingbox"
            case .person: return "person"
            }
        }
    }
}

extension MediaLink {
    static let appSchemes: [String: String] = [
        "netflix": "nflx://",
        "hulu": "hulu://",
        "disney+": "disneyplus://",
        "hbo": "hbomax://",
        "amazon": "aiv://",
        "apple_tv": "videos://",
        "peacock": "peacock://",
        "spotify": "spotify://",
        "apple_music": "music://",
        "youtube": "youtube://",
        "twitch": "twitch://",
        "espn": "sportscenter://"
    ]
}
