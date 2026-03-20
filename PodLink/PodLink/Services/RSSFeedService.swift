import Foundation

actor RSSFeedService {
    static let shared = RSSFeedService()

    private let session = URLSession.shared
    private let cache = CacheService.shared

    func fetchEpisodes(feedURL: URL, authToken: String? = nil) async throws -> [Episode] {
        let cacheKey = "feed_episodes_\(feedURL.absoluteString)"
        if let cached: [Episode] = await cache.get(cacheKey, as: [Episode].self) {
            return cached
        }

        var request = URLRequest(url: feedURL)
        request.setValue("PodLink/1.0", forHTTPHeaderField: "User-Agent")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await session.data(for: request)
        let parser = RSSParser()
        let episodes = parser.parseEpisodes(from: data, podcastID: feedURL.absoluteString)

        await cache.set(cacheKey, value: episodes, ttl: 1800) // 30 min
        return episodes
    }

    func fetchPodcastMetadata(feedURL: URL) async throws -> Podcast? {
        let cacheKey = "feed_meta_\(feedURL.absoluteString)"
        if let cached: Podcast = await cache.get(cacheKey, as: Podcast.self) {
            return cached
        }

        var request = URLRequest(url: feedURL)
        request.setValue("PodLink/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let parser = RSSParser()
        let podcast = parser.parsePodcast(from: data, feedURL: feedURL)

        if let podcast {
            await cache.set(cacheKey, value: podcast, ttl: 86400)
        }
        return podcast
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
            case "title": itemTitle = text
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
