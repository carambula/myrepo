import Foundation

final class PodcastEpisodeFeedService {
    static let shared = PodcastEpisodeFeedService()
    private let artworkCache = PodcastArtworkURLCache()
    private static let feedCacheTTL: TimeInterval = 60 * 60 * 6
    private static let artworkCacheTTL: TimeInterval = 60 * 60 * 24

    private init() {}

    func fetchEpisodes(for race: Race, sources: [PodcastSource]) async -> [RacePodcastEpisodeLink] {
        guard !sources.isEmpty else { return [] }

        return await withTaskGroup(of: [RacePodcastEpisodeLink].self) { group in
            for source in sources {
                group.addTask {
                    await self.fetchEpisodes(for: race, source: source)
                }
            }

            var combined: [RacePodcastEpisodeLink] = []
            for await episodes in group {
                combined.append(contentsOf: episodes)
            }
            return combined.sorted { ($0.publishedAt ?? "") > ($1.publishedAt ?? "") }
        }
    }

    private func fetchEpisodes(for race: Race, source: PodcastSource) async -> [RacePodcastEpisodeLink] {
        guard let url = URL(string: source.feedUrl), !source.feedUrl.isEmpty else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("Cyclismo/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let data = try await UnifiedDataCache.shared.data(
                for: request,
                cacheKey: "podcast-feed:\(source.feedUrl.lowercased())",
                ttl: Self.feedCacheTTL
            )

            let xml = String(decoding: data, as: UTF8.self)
            let items = parseRSSItems(xml)

            return items.compactMap { item in
                guard matchesRace(item: item, race: race) else { return nil }
                let episodeId = makeEpisodeID(sourceId: source.sourceId, item: item)
                return RacePodcastEpisodeLink(
                    episodeId: episodeId,
                    sourceId: source.sourceId,
                    sourceSlug: source.slug,
                    sourceName: source.name,
                    title: item.title,
                    rawTitle: item.rawTitle,
                    description: item.description,
                    episodeUrl: item.episodeUrl,
                    publishedAt: item.publishedAt,
                    matchedBy: raceMatchKey(item: item, race: race)
                )
            }
        } catch {
            return []
        }
    }

    private func matchesRace(item: RSSItem, race: Race) -> Bool {
        let episodeTitleNorm = normalize("\(item.title) \(item.rawTitle ?? "")")
        if episodeTitleNorm.isEmpty { return false }
        guard isPublicationDateRelevant(item: item, race: race) else { return false }

        // If title includes an explicit year, prefer exact year parity with the race.
        let yearsInTitle = extractYears(from: "\(item.title) \(item.rawTitle ?? "")")
        if !yearsInTitle.isEmpty,
           let raceYear = Int(String(race.startDate.prefix(4))) {
            let yearOk = yearsInTitle.contains(raceYear) || yearsInTitle.contains(raceYear - 1)
            if !yearOk { return false }
        }

        let episodeSearchNorm = episodeSearchNormalized(item: item)
        let keys = buildRaceKeys(from: race.name)
        guard !keys.isEmpty else { return false }
        return keys.contains { key in
            episodeSearchNorm.contains(key) || compact(episodeSearchNorm).contains(compact(key))
        }
    }

    private func episodeSearchNormalized(item: RSSItem) -> String {
        let descPrefix = String((item.description ?? "").prefix(2500))
        return normalize("\(item.title) \(item.rawTitle ?? "") \(descPrefix)")
    }

    private func isPublicationDateRelevant(item: RSSItem, race: Race) -> Bool {
        guard let raceDate = parseRaceDate(race.startDate),
              let pubString = item.publishedAt,
              let pubDate = parsePublishedDate(pubString) else {
            return false
        }

        let raceYear = Calendar.current.component(.year, from: raceDate)
        let pubYear = Calendar.current.component(.year, from: pubDate)
        let dayDelta = Calendar.current.dateComponents([.day], from: pubDate, to: raceDate).day ?? 0

        // Typical relevant window: from one month before race start to three weeks after.
        if pubYear == raceYear && (-21...35).contains(dayDelta) {
            return true
        }

        // Allow "preview" episodes roughly one year in advance.
        if isPreviewEpisode(item) && (raceYear - pubYear == 1) && (250...430).contains(dayDelta) {
            return true
        }

        return false
    }

    private func isPreviewEpisode(_ item: RSSItem) -> Bool {
        let haystack = "\(item.title) \(item.description ?? "")".lowercased()
        return haystack.contains("preview")
            || haystack.contains("route")
            || haystack.contains("startlist")
            || haystack.contains("season preview")
    }

    private func parseRaceDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private func parsePublishedDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private func raceMatchKey(item: RSSItem, race: Race) -> String? {
        let episodeSearchNorm = episodeSearchNormalized(item: item)
        for key in buildRaceKeys(from: race.name) {
            if episodeSearchNorm.contains(key) || compact(episodeSearchNorm).contains(compact(key)) {
                return key
            }
        }
        return nil
    }

    private func buildRaceKeys(from raceName: String) -> [String] {
        let base = normalize(raceName)
        if base.isEmpty { return [] }

        var keys = Set<String>([base])
        keys.insert(base.replacingOccurrences(of: #"\b(the|la|le|de|du|des|of)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines))

        let sansCiclista = base
            .replacingOccurrences(of: #"\bciclista\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if sansCiclista != base, sansCiclista.count >= 5 {
            keys.insert(sansCiclista)
        }

        if raceName.range(of: #"\bgiro d'?italia\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["giro d italia", "giro"])
        }
        if raceName.range(of: #"\btour de france\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["tour de france", "tdf", "le tour"])
        }
        if raceName.range(of: #"\bvuelta a espa[ñn]a\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["vuelta a espana", "vuelta"])
        }
        if raceName.range(of: #"\bstrade bianche\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["strade bianche", "strade"])
        }
        if raceName.range(of: #"\bparis[- ]?roubaix\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["paris roubaix", "roubaix"])
        }
        if raceName.range(of: #"\b(milano|milan)[- ]?san ?remo\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["milano sanremo", "milan san remo", "san remo", "milan sanremo"])
        }
        if raceName.range(of: #"\b(milano|milan)[- ]?san ?remo\b.*\b(donne|women|womens)\b"#,
                          options: [.regularExpression, .caseInsensitive]) != nil {
            keys.formUnion(["milano sanremo", "milan san remo", "san remo", "milan sanremo", "sanremo donne"])
        }
        if raceName.range(
            of: #"\bvolta (ciclista )?a catalunya\b|\bvolta\s+catalunya\b|\bciclista a catalunya\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            keys.formUnion([
                "volta ciclista a catalunya",
                "volta a catalunya",
                "volta catalunya",
                "catalunya",
                "tour of catalonia",
                "catalonia"
            ])
        }

        return keys
            .map(normalize(_:))
            .filter { $0.count >= 5 }
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: #"\b(uci|mens|women|womens|race|cycling|podcast|preview|review)\b"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func compact(_ value: String) -> String {
        value.replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
    }

    private func extractYears(from value: String) -> Set<Int> {
        let pattern = #"\b(19|20)\d{2}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = value as NSString
        let matches = regex.matches(in: value, range: NSRange(location: 0, length: ns.length))
        var years: Set<Int> = []
        for match in matches {
            let text = ns.substring(with: match.range)
            if let year = Int(text) {
                years.insert(year)
            }
        }
        return years
    }

    private func makeEpisodeID(sourceId: String, item: RSSItem) -> String {
        let identity = item.guid ?? "\(item.title)|\(item.publishedAt ?? "")"
        let normalized = identity.lowercased().replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        return "\(sourceId)-\(normalized)"
    }

    private func parseRSSItems(_ xml: String) -> [RSSItem] {
        let parseBlock: (String, String) -> RSSItem? = { itemXML, publishedDatePattern in
            let rawTitle = self.firstCapture(in: itemXML, pattern: #"<title><!\[CDATA\[([\s\S]*?)\]\]><\/title>|<title>([\s\S]*?)<\/title>"#) ?? ""
            let title = self.stripHTML(self.decodeXML(rawTitle))
            guard !title.isEmpty else { return nil }

            let guid = self.firstCapture(in: itemXML, pattern: #"<guid[^>]*>([\s\S]*?)<\/guid>"#)
                ?? self.firstCapture(in: itemXML, pattern: #"<id[^>]*>([\s\S]*?)<\/id>"#)
                ?? self.firstCapture(in: itemXML, pattern: #"<yt:videoId[^>]*>([\s\S]*?)<\/yt:videoId>"#)
            let description = (
                self.firstCapture(in: itemXML, pattern: #"<description><!\[CDATA\[([\s\S]*?)\]\]><\/description>|<description>([\s\S]*?)<\/description>"#)
                ?? self.firstCapture(in: itemXML, pattern: #"<media:description[^>]*>([\s\S]*?)<\/media:description>"#)
                ?? self.firstCapture(in: itemXML, pattern: #"<summary[^>]*>([\s\S]*?)<\/summary>"#)
                ?? self.firstCapture(in: itemXML, pattern: #"<content[^>]*>([\s\S]*?)<\/content>"#)
            )
                .map(self.decodeXML)
                .map(self.stripHTML)
                .flatMap(self.cleanNilIfEmpty)
            let pubDateRaw = self.firstCapture(in: itemXML, pattern: publishedDatePattern)
            let publishedAt = self.parseDateToISO8601(pubDateRaw).flatMap(self.cleanNilIfEmpty)
            let episodeUrl = self.cleanNilIfEmpty(self.extractLink(from: itemXML))
                ?? self.cleanNilIfEmpty(self.firstCapture(in: itemXML, pattern: #"<yt:videoId[^>]*>([\s\S]*?)<\/yt:videoId>"#))
                    .map { "https://www.youtube.com/watch?v=\($0)" }

            return RSSItem(
                title: title,
                rawTitle: self.cleanNilIfEmpty(self.decodeXML(rawTitle)),
                guid: self.cleanNilIfEmpty(self.decodeXML(guid ?? "")),
                description: description,
                episodeUrl: episodeUrl,
                publishedAt: publishedAt
            )
        }

        let items = matches(in: xml, pattern: #"<item[\s\S]*?<\/item>"#).compactMap {
            parseBlock($0, #"<pubDate>([\s\S]*?)<\/pubDate>"#)
        }
        let entries = matches(in: xml, pattern: #"<entry[\s\S]*?<\/entry>"#).compactMap {
            parseBlock($0, #"<published[^>]*>([\s\S]*?)<\/published>|<updated[^>]*>([\s\S]*?)<\/updated>"#)
        }
        return items + entries
    }

    private func extractLink(from itemXML: String) -> String? {
        if let atomAlternate = firstCapture(in: itemXML, pattern: #"<link[^>]*rel=["']alternate["'][^>]*href=["']([^"']+)["'][^>]*\/?>"#) {
            return atomAlternate.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let atom = firstCapture(in: itemXML, pattern: #"<link[^>]*href="([^"]+)"[^>]*\/?>"#) {
            return atom.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return firstCapture(in: itemXML, pattern: #"<link[^>]*>([\s\S]*?)<\/link>"#)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDateToISO8601(_ value: String?) -> String? {
        guard let raw = cleanNilIfEmpty(value) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm Z"]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) {
                return ISO8601DateFormatter().string(from: date)
            }
        }
        if let isoDate = ISO8601DateFormatter().date(from: raw) {
            return ISO8601DateFormatter().string(from: isoDate)
        }
        return nil
    }

    func fetchArtworkURLs(for sources: [PodcastSource]) async -> [String: URL] {
        guard !sources.isEmpty else { return [:] }

        return await withTaskGroup(of: (String, URL?).self) { group in
            for source in sources {
                group.addTask {
                    let url = await self.fetchArtworkURL(for: source)
                    return (source.sourceId.lowercased(), url)
                }
            }

            var result: [String: URL] = [:]
            for await (sourceID, url) in group {
                if let url {
                    result[sourceID] = url
                }
            }
            return result
        }
    }

    private func fetchArtworkURL(for source: PodcastSource) async -> URL? {
        let sourceID = source.sourceId.lowercased()
        if let cached = await artworkCache.value(for: sourceID) {
            return cached
        }

        guard let feedURL = URL(string: source.feedUrl), !source.feedUrl.isEmpty else {
            await artworkCache.store(nil, for: sourceID)
            return nil
        }

        if isYouTubeFeed(source.feedUrl) {
            let artworkURL = await fetchYouTubeChannelArtwork(feedURL: source.feedUrl)
            await artworkCache.store(artworkURL, for: sourceID)
            return artworkURL
        }

        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 10
        request.setValue("Cyclismo/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let data = try await UnifiedDataCache.shared.data(
                for: request,
                cacheKey: "podcast-artwork-feed:\(source.feedUrl.lowercased())",
                ttl: Self.artworkCacheTTL
            )

            let xml = String(decoding: data, as: UTF8.self)
            let artworkURLString = firstCapture(in: xml, pattern: #"<itunes:image[^>]*href=["']([^"']+)["']"#)
                ?? firstCapture(in: xml, pattern: #"<image>[\s\S]*?<url>([^<]+)</url>[\s\S]*?</image>"#)
            let artworkURL = artworkURLString.flatMap { URL(string: $0) }
            await artworkCache.store(artworkURL, for: sourceID)
            return artworkURL
        } catch {
            await artworkCache.store(nil, for: sourceID)
            return nil
        }
    }

    private func isYouTubeFeed(_ feedURL: String) -> Bool {
        feedURL.lowercased().contains("youtube.com")
    }

    private func fetchYouTubeChannelArtwork(feedURL: String) async -> URL? {
        guard let channelID = extractYouTubeChannelID(from: feedURL) else {
            return nil
        }

        let oembedURLString = "https://www.youtube.com/oembed?url=https://www.youtube.com/channel/\(channelID)&format=json"
        guard let oembedURL = URL(string: oembedURLString) else {
            return nil
        }

        var request = URLRequest(url: oembedURL)
        request.timeoutInterval = 10
        request.setValue("Cyclismo/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let data = try await UnifiedDataCache.shared.data(
                for: request,
                cacheKey: "youtube-channel-artwork:\(channelID)",
                ttl: Self.artworkCacheTTL
            )

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let thumbnailURLString = json["thumbnail_url"] as? String,
                  let thumbnailURL = URL(string: thumbnailURLString) else {
                return nil
            }

            return thumbnailURL
        } catch {
            return nil
        }
    }

    private func extractYouTubeChannelID(from feedURL: String) -> String? {
        if let range = feedURL.range(of: "channel_id=") {
            let channelIDStart = range.upperBound
            let remaining = feedURL[channelIDStart...]
            if let ampersandIndex = remaining.firstIndex(of: "&") {
                return String(remaining[..<ampersandIndex])
            }
            return String(remaining)
        }
        return nil
    }

    private func decodeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<![CDATA[", with: "")
            .replacingOccurrences(of: "]]>", with: "")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(in text: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: range).map { nsText.substring(with: $0.range) }
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        for index in 1..<match.numberOfRanges {
            if let capture = Range(match.range(at: index), in: text) {
                return String(text[capture])
            }
        }
        return nil
    }

    private func cleanNilIfEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct RSSItem {
    let title: String
    let rawTitle: String?
    let guid: String?
    let description: String?
    let episodeUrl: String?
    let publishedAt: String?
}

private actor PodcastArtworkURLCache {
    private var values: [String: URL?] = [:]

    func value(for sourceID: String) -> URL? {
        values[sourceID] ?? nil
    }

    func store(_ url: URL?, for sourceID: String) {
        values[sourceID] = url
    }
}
