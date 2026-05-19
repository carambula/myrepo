import Foundation

enum RSSFeedError: Error {
    case authenticationRequired
    case httpFailure(statusCode: Int)
    case invalidFeed
}

actor RSSFeedService {
    static let shared = RSSFeedService()

    private let session = URLSession.shared
    private let cache = CacheService.shared

    /// Clears cached RSS for this feed (call after changing stored credentials).
    func invalidateFeedCache(feedURL: URL) async {
        let u = feedURL.absoluteString
        await cache.remove("feed_episodes_\(u)")
        await cache.remove("feed_meta_\(u)")
        await cache.remove(episodeCacheKey(feedURL: feedURL, authTag: "none"))
        await cache.remove(metaCacheKey(feedURL: feedURL, authTag: "none"))
        if let seg = await PrivateFeedAuthStore.shared.cacheKeySegment(for: feedURL) {
            await cache.remove(episodeCacheKey(feedURL: feedURL, authTag: seg))
            await cache.remove(metaCacheKey(feedURL: feedURL, authTag: seg))
        }
    }

    func fetchEpisodes(feedURL: URL, provisionalAuth: FeedHTTPAuth? = nil) async throws -> [Episode] {
        let auth = await resolvedAuth(feedURL: feedURL, provisionalAuth: provisionalAuth)
        let authTag = auth.map { $0.cacheKeySegment() } ?? "none"
        let cacheKey = episodeCacheKey(feedURL: feedURL, authTag: authTag)
        if let cached: [Episode] = await cache.get(cacheKey, as: [Episode].self) {
            return cached
        }

        var request = URLRequest(url: PrivateFeedAuthStore.canonicalFeedURL(feedURL))
        request.setValue("PodLink/1.0", forHTTPHeaderField: "User-Agent")
        auth?.apply(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response)

        let parser = RSSParser()
        let episodes = parser.parseEpisodes(from: data, podcastID: feedURL.absoluteString)

        await cache.set(cacheKey, value: episodes, ttl: 1800) // 30 min
        return episodes
    }

    /// Reads cached episodes only (no network fetch). Tries authenticated and unauthenticated keys.
    func cachedEpisodes(feedURL: URL) async -> [Episode]? {
        let canonicalURL = PrivateFeedAuthStore.canonicalFeedURL(feedURL)
        if let authTag = await PrivateFeedAuthStore.shared.cacheKeySegment(for: canonicalURL),
           let cachedWithAuth: [Episode] = await cache.get(episodeCacheKey(feedURL: canonicalURL, authTag: authTag), as: [Episode].self) {
            return cachedWithAuth
        }

        if let cachedWithoutAuth: [Episode] = await cache.get(episodeCacheKey(feedURL: canonicalURL, authTag: "none"), as: [Episode].self) {
            return cachedWithoutAuth
        }

        return nil
    }

    func fetchPodcastMetadata(feedURL: URL, provisionalAuth: FeedHTTPAuth? = nil) async throws -> Podcast? {
        let auth = await resolvedAuth(feedURL: feedURL, provisionalAuth: provisionalAuth)
        let authTag = auth.map { $0.cacheKeySegment() } ?? "none"
        let cacheKey = metaCacheKey(feedURL: feedURL, authTag: authTag)
        if let cached: Podcast = await cache.get(cacheKey, as: Podcast.self) {
            return cached
        }

        var request = URLRequest(url: PrivateFeedAuthStore.canonicalFeedURL(feedURL))
        request.setValue("PodLink/1.0", forHTTPHeaderField: "User-Agent")
        auth?.apply(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response)

        let parser = RSSParser()
        let podcast = parser.parsePodcast(from: data, feedURL: PrivateFeedAuthStore.canonicalFeedURL(feedURL))

        if let podcast {
            await cache.set(cacheKey, value: podcast, ttl: 86400)
        }
        return podcast
    }

    private func resolvedAuth(feedURL: URL, provisionalAuth: FeedHTTPAuth?) async -> FeedHTTPAuth? {
        if let provisionalAuth {
            return provisionalAuth
        }
        return await PrivateFeedAuthStore.shared.credential(for: feedURL)
    }

    private func episodeCacheKey(feedURL: URL, authTag: String) -> String {
        "feed_episodes_\(feedURL.absoluteString)_\(authTag)"
    }

    private func metaCacheKey(feedURL: URL, authTag: String) -> String {
        "feed_meta_\(feedURL.absoluteString)_\(authTag)"
    }

    private nonisolated func validateHTTP(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw RSSFeedError.authenticationRequired
        default:
            throw RSSFeedError.httpFailure(statusCode: http.statusCode)
        }
    }
}

// MARK: - RSS Parser

private class RSSParser: NSObject, XMLParserDelegate {
    private var episodes: [Episode] = []
    private var currentPodcast: Podcast?
    private var feedURL: URL?
    private var podcastID: String = ""

    private var currentElement = ""
    private var currentText = ""
    private var isInItem = false
    private var isInChannel = false

    // Episode fields
    private var itemTitle = ""
    private var itemDescription = ""
    private var itemPubDate = ""
    private var itemDuration = ""
    private var itemGUID = ""
    private var itemAudioURL = ""
    private var itemVideoURL: String?
    private var itemArtworkURL: String?
    private var itemEpisodeNumber: Int?
    private var itemSeasonNumber: Int?
    private var itemTranscriptURL: String?

    // Channel fields
    private var channelTitle = ""
    private var channelDescription = ""
    private var channelAuthor = ""
    private var channelArtworkURL: String?
    private var channelLanguage = ""
    private var channelExplicit = false
    private var channelWebsite: String?
    private var channelCategories: [String] = []

    func parseEpisodes(from data: Data, podcastID: String) -> [Episode] {
        self.podcastID = podcastID
        episodes = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return episodes
    }

    func parsePodcast(from data: Data, feedURL: URL) -> Podcast? {
        self.feedURL = feedURL
        self.podcastID = feedURL.absoluteString
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return currentPodcast
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "channel":
            isInChannel = true
        case "item":
            isInItem = true
            resetItemFields()
        case "enclosure":
            if isInItem {
                let type = attributeDict["type"] ?? ""
                let url = attributeDict["url"] ?? ""
                if type.contains("video") {
                    itemVideoURL = url
                } else if type.contains("audio") || itemAudioURL.isEmpty {
                    itemAudioURL = url
                }
            }
        case "itunes:image":
            let href = attributeDict["href"]
            if isInItem {
                itemArtworkURL = href
            } else if isInChannel {
                channelArtworkURL = href
            }
        case "podcast:transcript":
            if isInItem {
                itemTranscriptURL = attributeDict["url"]
            }
        case "media:content":
            if isInItem, let url = attributeDict["url"],
               attributeDict["type"]?.contains("video") == true {
                itemVideoURL = url
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInItem {
            switch elementName {
            case "title": itemTitle = text.rssDecodedPlainText
            case "description", "content:encoded":
                if text.count > itemDescription.count { itemDescription = text }
            case "pubDate": itemPubDate = text
            case "itunes:duration": itemDuration = text
            case "guid": itemGUID = text
            case "itunes:episode": itemEpisodeNumber = Int(text)
            case "itunes:season": itemSeasonNumber = Int(text)
            case "yt:videoId":
                itemVideoURL = "https://www.youtube.com/watch?v=\(text)"
                if itemAudioURL.isEmpty {
                    itemAudioURL = "https://www.youtube.com/watch?v=\(text)"
                }
            case "item":
                if let episode = buildEpisode() {
                    episodes.append(episode)
                }
                isInItem = false
            default: break
            }
        } else if isInChannel {
            switch elementName {
            case "title": channelTitle = text.rssDecodedPlainText
            case "description": channelDescription = text
            case "itunes:author": channelAuthor = text.rssDecodedPlainText
            case "language": channelLanguage = text
            case "itunes:explicit": channelExplicit = (text == "yes" || text == "true")
            case "link": channelWebsite = text
            case "itunes:category": channelCategories.append(text)
            case "channel":
                isInChannel = false
                if let url = feedURL {
                    currentPodcast = Podcast(
                        id: podcastID,
                        title: channelTitle,
                        author: channelAuthor,
                        description: channelDescription,
                        feedURL: url,
                        artworkURL: channelArtworkURL.flatMap { URL(string: $0) },
                        artworkURL600: channelArtworkURL.flatMap { URL(string: $0) },
                        categories: channelCategories,
                        language: channelLanguage.isEmpty ? "en" : channelLanguage,
                        isExplicit: channelExplicit,
                        websiteURL: channelWebsite.flatMap { URL(string: $0) }
                    )
                }
            default: break
            }
        }
    }

    private func resetItemFields() {
        itemTitle = ""
        itemDescription = ""
        itemPubDate = ""
        itemDuration = ""
        itemGUID = ""
        itemAudioURL = ""
        itemVideoURL = nil
        itemArtworkURL = nil
        itemEpisodeNumber = nil
        itemSeasonNumber = nil
        itemTranscriptURL = nil
    }

    private func buildEpisode() -> Episode? {
        guard !itemTitle.isEmpty,
              let audioURL = URL(string: itemAudioURL.isEmpty ? "about:blank" : itemAudioURL) else {
            return nil
        }

        let id = itemGUID.isEmpty ? UUID().uuidString : itemGUID

        return Episode(
            id: id,
            podcastID: podcastID,
            title: itemTitle,
            description: itemDescription,
            publishDate: parseDate(itemPubDate) ?? Date(),
            duration: parseDuration(itemDuration),
            audioURL: audioURL,
            videoURL: itemVideoURL.flatMap { URL(string: $0) },
            artworkURL: itemArtworkURL.flatMap { URL(string: $0) },
            episodeNumber: itemEpisodeNumber,
            seasonNumber: itemSeasonNumber,
            transcriptURL: itemTranscriptURL.flatMap { URL(string: $0) }
        )
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd"
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }

    private func parseDuration(_ string: String) -> TimeInterval {
        if let seconds = TimeInterval(string) {
            return seconds
        }
        let parts = string.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        case 2: return TimeInterval(parts[0] * 60 + parts[1])
        case 1: return TimeInterval(parts[0])
        default: return 0
        }
    }
}
