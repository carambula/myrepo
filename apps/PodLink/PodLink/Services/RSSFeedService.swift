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

    /// Newest window used by home / Up Next. Full archives stay on show detail and deep links.
    static let recentEpisodeWindow = 40

    /// Clears cached RSS for this feed (call after changing stored credentials).
    func invalidateFeedCache(feedURL: URL) async {
        let u = feedURL.absoluteString
        await cache.remove("feed_episodes_\(u)")
        await cache.remove("feed_meta_\(u)")
        await cache.remove(episodeCacheKey(feedURL: feedURL, authTag: "none"))
        await cache.remove(latestCacheKey(feedURL: feedURL, authTag: "none"))
        await cache.remove(recentCacheKey(feedURL: feedURL, authTag: "none"))
        await cache.remove("feed_episodes_\(feedURL.absoluteString)_none")
        await cache.remove("feed_episodes_\(feedURL.absoluteString)_none_dates2")
        await cache.remove("feed_episodes_\(feedURL.absoluteString)_none_archive1")
        await cache.remove(metaCacheKey(feedURL: feedURL, authTag: "none"))
        if let seg = await PrivateFeedAuthStore.shared.cacheKeySegment(for: feedURL) {
            await cache.remove(episodeCacheKey(feedURL: feedURL, authTag: seg))
            await cache.remove(latestCacheKey(feedURL: feedURL, authTag: seg))
            await cache.remove(recentCacheKey(feedURL: feedURL, authTag: seg))
            await cache.remove("feed_episodes_\(feedURL.absoluteString)_\(seg)")
            await cache.remove("feed_episodes_\(feedURL.absoluteString)_\(seg)_dates2")
            await cache.remove("feed_episodes_\(feedURL.absoluteString)_\(seg)_archive1")
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

        async let cloudEpisodes = fetchCloudEpisodes(
            feedURL: feedURL,
            includeCloud: provisionalAuth == nil
        )

        let liveEpisodes: [Episode]
        do {
            liveEpisodes = try await fetchLiveEpisodes(feedURL: feedURL, auth: auth)
        } catch {
            let cloud = await cloudEpisodes
            guard !cloud.isEmpty else { throw error }
            await rememberFetchedEpisodes(cloud, cacheKey: cacheKey, authTag: authTag, feedURL: feedURL)
            return cloud
        }

        let episodes = EpisodeArchive.merge(await cloudEpisodes, liveEpisodes)
        guard !episodes.isEmpty else {
            throw RSSFeedError.invalidFeed
        }
        await rememberFetchedEpisodes(episodes, cacheKey: cacheKey, authTag: authTag, feedURL: feedURL)
        return episodes
    }

    /// Home grid / Up Next only need a short newest window. Skip the full catalog∪live archive
    /// merge so opening the app does not download and decode thousands of episodes per follow.
    func fetchRecentEpisodes(
        feedURL: URL,
        limit: Int = RSSFeedService.recentEpisodeWindow,
        provisionalAuth: FeedHTTPAuth? = nil
    ) async throws -> [Episode] {
        let cappedLimit = max(1, limit)
        let auth = await resolvedAuth(feedURL: feedURL, provisionalAuth: provisionalAuth)
        let authTag = auth.map { $0.cacheKeySegment() } ?? "none"

        if let latest: Episode = await cache.get(latestCacheKey(feedURL: feedURL, authTag: authTag), as: Episode.self),
           cappedLimit == 1 {
            return [latest]
        }

        if let recent: [Episode] = await cache.get(recentCacheKey(feedURL: feedURL, authTag: authTag), as: [Episode].self),
           !recent.isEmpty {
            return Array(recent.prefix(cappedLimit))
        }

        if let cached: [Episode] = await cache.get(episodeCacheKey(feedURL: feedURL, authTag: authTag), as: [Episode].self),
           !cached.isEmpty {
            let prefix = Array(cached.prefix(cappedLimit))
            await rememberRecentEpisodes(prefix, authTag: authTag, feedURL: feedURL, notify: false)
            return prefix
        }

        let liveEpisodes = try await fetchLiveEpisodes(feedURL: feedURL, auth: auth, maxItems: cappedLimit)
        let recent = Array(liveEpisodes.prefix(cappedLimit))
        guard !recent.isEmpty else {
            throw RSSFeedError.invalidFeed
        }
        await rememberRecentEpisodes(recent, authTag: authTag, feedURL: feedURL, notify: true)
        return recent
    }

    private func rememberFetchedEpisodes(
        _ episodes: [Episode],
        cacheKey: String,
        authTag: String,
        feedURL: URL
    ) async {
        await cache.set(cacheKey, value: episodes, ttl: 1800) // 30 min
        await rememberRecentEpisodes(
            Array(episodes.prefix(Self.recentEpisodeWindow)),
            authTag: authTag,
            feedURL: feedURL,
            notify: true
        )
    }

    private func rememberRecentEpisodes(
        _ episodes: [Episode],
        authTag: String,
        feedURL: URL,
        notify: Bool
    ) async {
        guard !episodes.isEmpty else { return }
        await cache.set(recentCacheKey(feedURL: feedURL, authTag: authTag), value: episodes, ttl: 1800)
        await cache.set(latestCacheKey(feedURL: feedURL, authTag: authTag), value: episodes[0], ttl: 1800)
        if notify {
            await EpisodeNotificationService.shared.noteFetched(feedURL: feedURL, episodes: episodes)
        }
    }

    private func fetchCloudEpisodes(feedURL: URL, includeCloud: Bool) async -> [Episode] {
        guard includeCloud, await MinCloudClient.shared.isReachable() else { return [] }
        return (try? await MinCloudClient.shared.fetchFeedEpisodes(
            feedURL: PrivateFeedAuthStore.canonicalFeedURL(feedURL)
        )) ?? []
    }

    private func fetchLiveEpisodes(
        feedURL: URL,
        auth: FeedHTTPAuth?,
        maxItems: Int? = nil
    ) async throws -> [Episode] {
        var request = URLRequest(url: PrivateFeedAuthStore.canonicalFeedURL(feedURL))
        request.setValue("PodLink/1.0", forHTTPHeaderField: "User-Agent")
        auth?.apply(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response)

        let parser = RSSParser()
        return parser.parseEpisodes(from: data, podcastID: feedURL.absoluteString, maxItems: maxItems)
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
        "feed_episodes_\(feedURL.absoluteString)_\(authTag)_archive2"
    }

    private func recentCacheKey(feedURL: URL, authTag: String) -> String {
        "feed_episodes_\(feedURL.absoluteString)_\(authTag)_recent1"
    }

    private func latestCacheKey(feedURL: URL, authTag: String) -> String {
        "feed_latest_\(feedURL.absoluteString)_\(authTag)_v1"
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
    private var maxItems: Int?

    func parseEpisodes(from data: Data, podcastID: String, maxItems: Int? = nil) -> [Episode] {
        self.podcastID = podcastID
        self.maxItems = maxItems
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

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInItem {
            switch elementName {
            case "title": itemTitle = text
            case "description", "content:encoded":
                if text.count > itemDescription.count { itemDescription = text }
            case "pubDate", "published", "dc:date", "itunes:pubDate":
                if itemPubDate.isEmpty || text.count > itemPubDate.count { itemPubDate = text }
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
                if let maxItems, episodes.count >= maxItems {
                    parser.abortParsing()
                }
            default: break
            }
        } else if isInChannel {
            switch elementName {
            case "title": channelTitle = text
            case "description": channelDescription = text
            case "itunes:author": channelAuthor = text
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
            publishDate: PodcastDateParser.parse(itemPubDate) ?? .distantPast,
            duration: parseDuration(itemDuration),
            audioURL: audioURL,
            videoURL: itemVideoURL.flatMap { URL(string: $0) },
            artworkURL: itemArtworkURL.flatMap { URL(string: $0) },
            episodeNumber: itemEpisodeNumber,
            seasonNumber: itemSeasonNumber,
            transcriptURL: itemTranscriptURL.flatMap { URL(string: $0) }
        )
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
