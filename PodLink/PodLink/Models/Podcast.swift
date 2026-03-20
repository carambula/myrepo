import Foundation

struct Podcast: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let description: String
    let feedURL: URL
    let artworkURL: URL?
    let artworkURL600: URL?
    let categories: [String]
    let language: String
    let isExplicit: Bool
    let websiteURL: URL?
    let itunesID: String?

    var isFollowed: Bool = false
    var notificationsEnabled: Bool = false
    var autoDownload: Bool = false
    var preferVideo: Bool = false
    var customPlaybackSpeed: Float?

    var displayArtworkURL: URL? {
        artworkURL600 ?? artworkURL
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String,
        description: String = "",
        feedURL: URL,
        artworkURL: URL? = nil,
        artworkURL600: URL? = nil,
        categories: [String] = [],
        language: String = "en",
        isExplicit: Bool = false,
        websiteURL: URL? = nil,
        itunesID: String? = nil,
        isFollowed: Bool = false,
        notificationsEnabled: Bool = false,
        autoDownload: Bool = false,
        preferVideo: Bool = false,
        customPlaybackSpeed: Float? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.description = description
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.artworkURL600 = artworkURL600
        self.categories = categories
        self.language = language
        self.isExplicit = isExplicit
        self.websiteURL = websiteURL
        self.itunesID = itunesID
        self.isFollowed = isFollowed
        self.notificationsEnabled = notificationsEnabled
        self.autoDownload = autoDownload
        self.preferVideo = preferVideo
        self.customPlaybackSpeed = customPlaybackSpeed
    }
}
