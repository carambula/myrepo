import Foundation

actor MediaLinkingService {
    static let shared = MediaLinkingService()

    private let cache = CacheService.shared
    private let youtubeService = YouTubeService.shared

    func extractMediaLinks(from episode: Episode) async -> [MediaLink] {
        let cacheKey = "media_links_\(episode.id)"
        if let cached: [MediaLink] = await cache.get(cacheKey, as: [MediaLink].self) {
            return cached
        }

        var allReferences: [RawMediaReference] = []

        // Step 1: Parse show notes for explicit links
        let showNoteLinks = parseShowNotes(episode.description)
        allReferences.append(contentsOf: showNoteLinks)

        // Step 2: Parse episode title
        let titleLinks = parseTitle(episode.title)
        allReferences.append(contentsOf: titleLinks)

        // Step 3: Parse transcript if available (from Episode model or fetch fresh)
        let transcriptText: String?
        if let existingTranscript = episode.transcript {
            transcriptText = existingTranscript
        } else {
            transcriptText = await TranscriptService.shared.getTranscript(for: episode)
        }
        
        if let transcript = transcriptText {
            let transcriptLinks = parseTranscriptText(transcript)
            allReferences.append(contentsOf: transcriptLinks)
        }

        // Step 4: Resolve references to concrete media links
        var mediaLinks: [MediaLink] = []
        for ref in allReferences {
            if let link = await resolve(ref) {
                mediaLinks.append(link)
            }
        }

        // Step 5: Deduplicate
        mediaLinks = deduplicate(mediaLinks)

        await cache.set(cacheKey, value: mediaLinks, ttl: 86400 * 7) // 1 week
        return mediaLinks
    }

    // MARK: - Show Notes Parser

    private func parseShowNotes(_ html: String) -> [RawMediaReference] {
        var refs: [RawMediaReference] = []

        let linkPattern = #"<a[^>]+href=["\']([^"\']+)["\'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) else {
            return refs
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        for match in matches {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html) else { continue }

            let urlString = String(html[urlRange])
            let anchorText = String(html[textRange]).strippingHTML

            guard let url = URL(string: urlString) else { continue }

            let ref = classifyURL(url, anchorText: anchorText)
            if let ref { refs.append(ref) }
        }

        return refs
    }

    // MARK: - Title Parser

    private func parseTitle(_ title: String) -> [RawMediaReference] {
        var refs: [RawMediaReference] = []

        // Pattern: quoted titles like "'Jaws' (1975)" or "\"The Matrix\""
        let quotedPattern = #"['\"]([^'\"]+)['\"](?:\s*\((\d{4})\))?"#
        if let regex = try? NSRegularExpression(pattern: quotedPattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..<title.endIndex, in: title)),
           let titleRange = Range(match.range(at: 1), in: title) {
            let extractedTitle = String(title[titleRange])
            var year: Int?
            if let yearRange = Range(match.range(at: 2), in: title) {
                year = Int(String(title[yearRange]))
            }
            refs.append(RawMediaReference(
                text: extractedTitle,
                likelyType: .movie,
                url: nil,
                year: year,
                confidence: 0.8
            ))
        }

        return refs
    }

    // MARK: - Transcript Parser

    private func parseTranscriptText(_ text: String) -> [RawMediaReference] {
        var refs: [RawMediaReference] = []

        // Look for "check out [title]", "download [app]", "watch [show]" patterns
        let mediaPatterns: [(String, MediaLink.MediaLinkType)] = [
            (#"(?:watch|see|check out|stream)\s+['\"]([^'\"]+)['\"]"#, .movie),
            (#"(?:download|get|try)\s+(?:the\s+)?(\w+(?:\s+\w+)?)\s+(?:app|from the app store)"#, .app),
            (#"(?:listen to|playing|song)\s+['\"]([^'\"]+)['\"](?:\s+by\s+(.+?))?"#, .song),
            (#"(?:read|book|reading)\s+['\"]([^'\"]+)['\"]"#, .book),
        ]

        for (pattern, type) in mediaPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                guard let titleRange = Range(match.range(at: 1), in: text) else { continue }
                let title = String(text[titleRange])
                refs.append(RawMediaReference(
                    text: title,
                    likelyType: type,
                    url: nil,
                    year: nil,
                    confidence: 0.6
                ))
            }
        }

        return refs
    }

    // MARK: - URL Classification

    private func classifyURL(_ url: URL, anchorText: String) -> RawMediaReference? {
        let host = url.host?.lowercased() ?? ""

        if host.contains("youtube.com") || host.contains("youtu.be") {
            return RawMediaReference(text: anchorText, likelyType: .youtubeVideo, url: url, confidence: 0.95)
        }
        if host.contains("apps.apple.com") || host.contains("itunes.apple.com") {
            return RawMediaReference(text: anchorText, likelyType: .app, url: url, confidence: 0.95)
        }
        if host.contains("imdb.com") || host.contains("themoviedb.org") {
            return RawMediaReference(text: anchorText, likelyType: .movie, url: url, confidence: 0.95)
        }
        if host.contains("spotify.com") || host.contains("music.apple.com") {
            return RawMediaReference(text: anchorText, likelyType: .song, url: url, confidence: 0.9)
        }
        if host.contains("netflix.com") || host.contains("hulu.com") ||
           host.contains("disneyplus.com") || host.contains("hbomax.com") ||
           host.contains("peacocktv.com") || host.contains("max.com") {
            return RawMediaReference(text: anchorText, likelyType: .tvShow, url: url, confidence: 0.9)
        }
        if host.contains("amazon.com") && url.path.contains("/dp/") {
            return RawMediaReference(text: anchorText, likelyType: .product, url: url, confidence: 0.85)
        }

        if !anchorText.isEmpty && anchorText.count > 2 {
            return RawMediaReference(text: anchorText, likelyType: .website, url: url, confidence: 0.5)
        }

        return nil
    }

    // MARK: - Resolution

    private func resolve(_ ref: RawMediaReference) async -> MediaLink? {
        if let url = ref.url {
            return MediaLink(
                id: UUID().uuidString,
                type: ref.likelyType,
                title: ref.text,
                subtitle: ref.year.map { "\($0)" },
                imageURL: nil,
                destinationURL: url,
                appSchemeURL: nil,
                confidence: ref.confidence,
                timestamp: nil,
                sourceText: ref.text
            )
        }

        // For references without URLs, create a search-based link
        let searchQuery = ref.text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ref.text
        let searchURL: URL?

        switch ref.likelyType {
        case .movie, .tvShow:
            searchURL = URL(string: "https://www.themoviedb.org/search?query=\(searchQuery)")
        case .app:
            searchURL = URL(string: "https://apps.apple.com/search?term=\(searchQuery)")
        case .song, .album:
            searchURL = URL(string: "https://open.spotify.com/search/\(searchQuery)")
        case .book:
            searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)+book")
        case .youtubeVideo, .youtubeChannel:
            searchURL = URL(string: "https://www.youtube.com/results?search_query=\(searchQuery)")
        default:
            searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)")
        }

        guard let url = searchURL else { return nil }

        return MediaLink(
            id: UUID().uuidString,
            type: ref.likelyType,
            title: ref.text,
            subtitle: ref.year.map { "\($0)" },
            imageURL: nil,
            destinationURL: url,
            appSchemeURL: nil,
            confidence: ref.confidence,
            timestamp: nil,
            sourceText: ref.text
        )
    }

    // MARK: - Deduplication

    private func deduplicate(_ links: [MediaLink]) -> [MediaLink] {
        var seen = Set<String>()
        var result: [MediaLink] = []

        for link in links.sorted(by: { $0.confidence > $1.confidence }) {
            let key = link.title.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(key) {
                seen.insert(key)
                result.append(link)
            }
        }

        return result.filter { $0.confidence >= 0.5 }
    }
}

// MARK: - Raw Media Reference

struct RawMediaReference {
    let text: String
    let likelyType: MediaLink.MediaLinkType
    let url: URL?
    let year: Int?
    var confidence: Float = 0.5
}

// MARK: - String HTML Stripping

extension String {
    var strippingHTML: String {
        guard let data = self.data(using: .utf8) else { return self }
        let pattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return self }
        let range = NSRange(self.startIndex..<self.endIndex, in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
