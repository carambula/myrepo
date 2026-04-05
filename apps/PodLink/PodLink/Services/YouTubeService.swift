import Foundation

actor YouTubeService {
    static let shared = YouTubeService()

    private let cache = CacheService.shared
    private let session = URLSession.shared

    func getChannelArtwork(channelID: String) async throws -> URL? {
        let cacheKey = "yt_channel_art_\(channelID)"
        if let cached: URL = await cache.get(cacheKey, as: URL.self) {
            return cached
        }

        let oembedURL = "https://www.youtube.com/oembed?url=https://www.youtube.com/channel/\(channelID)&format=json"
        guard let url = URL(string: oembedURL) else { return nil }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(YouTubeOEmbedResponse.self, from: data)

        guard let thumbnailURL = URL(string: response.thumbnailUrl) else { return nil }

        await cache.set(cacheKey, value: thumbnailURL, ttl: 86400)
        return thumbnailURL
    }

    func getVideoThumbnail(videoID: String) -> URL {
        URL(string: "https://img.youtube.com/vi/\(videoID)/maxresdefault.jpg")!
    }

    func resolveVideoURL(_ urlString: String) -> MediaLink? {
        guard let url = URL(string: urlString) else { return nil }
        let host = url.host?.lowercased() ?? ""

        var videoID: String?

        if host.contains("youtube.com") {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            videoID = components?.queryItems?.first(where: { $0.name == "v" })?.value
        } else if host.contains("youtu.be") {
            videoID = url.lastPathComponent
        }

        guard let id = videoID else { return nil }

        return MediaLink(
            id: UUID().uuidString,
            type: .youtubeVideo,
            title: "YouTube Video",
            subtitle: nil,
            imageURL: getVideoThumbnail(videoID: id),
            destinationURL: url,
            appSchemeURL: URL(string: "youtube://\(id)"),
            confidence: 0.95,
            timestamp: nil,
            sourceText: urlString
        )
    }
}

private struct YouTubeOEmbedResponse: Codable {
    let title: String
    let authorName: String
    let thumbnailUrl: String

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case thumbnailUrl = "thumbnail_url"
    }
}
