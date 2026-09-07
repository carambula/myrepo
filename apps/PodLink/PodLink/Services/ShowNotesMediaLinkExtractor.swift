import Foundation

/// Pulls every http(s) URL out of episode show notes and turns it into a media-link card.
enum ShowNotesMediaLinkExtractor {

    static func mediaLinks(fromShowNotes html: String) -> [MediaLink] {
        references(from: html).compactMap { ref in
            guard let url = ref.url else { return nil }
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
    }

    static func references(from html: String) -> [RawMediaReference] {
        let source = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return [] }

        var refs: [RawMediaReference] = []
        var seen = Set<String>()

        func consider(url: URL, anchor: String) {
            guard let web = normalizedWebURL(url) else { return }
            let key = canonicalURLKey(web)
            guard seen.insert(key).inserted else { return }
            if let ref = reference(for: web, anchorText: anchor) {
                refs.append(ref)
            }
        }

        extractHTMLAnchors(from: source, consider: consider)
        extractQuotedHrefs(from: source, consider: consider)
        extractMarkdownLinks(from: source, consider: consider)
        extractDetectedLinks(from: source, consider: consider)
        extractDetectedLinks(from: source.strippingHTML, consider: consider)

        return refs
    }

    static func reference(for url: URL, anchorText: String) -> RawMediaReference? {
        guard let web = normalizedWebURL(url) else { return nil }
        let title = displayTitle(url: web, anchor: anchorText)
        return RawMediaReference(
            text: title,
            likelyType: classifyHost(web),
            url: web,
            year: nil,
            confidence: 0.95
        )
    }

    static func canonicalURLKey(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = components?.scheme?.lowercased()
        components?.host = components?.host?.lowercased()
        components?.fragment = nil
        if var path = components?.path, path.count > 1, path.hasSuffix("/") {
            path.removeLast()
            components?.path = path
        }
        let raw = components?.string ?? url.absoluteString
        var key = raw.lowercased()
        if key.hasSuffix("/"), !key.contains("?"), key.count > 8 {
            key.removeLast()
        }
        return key
    }

    // MARK: - Extraction

    private static func extractHTMLAnchors(
        from html: String,
        consider: (URL, String) -> Void
    ) {
        let pattern = #"<a[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in regex.matches(in: html, range: range) {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let textRange = Range(match.range(at: 2), in: html),
                  let url = parseWebURL(String(html[urlRange])) else { continue }
            consider(url, String(html[textRange]).strippingHTML)
        }
    }

    private static func extractQuotedHrefs(
        from html: String,
        consider: (URL, String) -> Void
    ) {
        let pattern = #"href\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in regex.matches(in: html, range: range) {
            guard let urlRange = Range(match.range(at: 1), in: html),
                  let url = parseWebURL(String(html[urlRange])) else { continue }
            consider(url, "")
        }
    }

    private static func extractMarkdownLinks(
        from text: String,
        consider: (URL, String) -> Void
    ) {
        let pattern = #"\[([^\]]+)\]\((https?://[^)\s]+|www\.[^)\s]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in regex.matches(in: text, range: range) {
            guard let textRange = Range(match.range(at: 1), in: text),
                  let urlRange = Range(match.range(at: 2), in: text),
                  let url = parseWebURL(String(text[urlRange])) else { continue }
            consider(url, String(text[textRange]))
        }
    }

    private static func extractDetectedLinks(
        from text: String,
        consider: (URL, String) -> Void
    ) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let url = match?.url else { return }
            consider(url, "")
        }
    }

    // MARK: - URL helpers

    private static func parseWebURL(_ raw: String) -> URL? {
        let decoded = decodeHTMLEntities(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !decoded.isEmpty else { return nil }
        if let url = URL(string: decoded), isWebURL(url) {
            return url
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
            if let match = detector.firstMatch(in: decoded, options: [], range: range),
               let url = match.url, isWebURL(url) {
                return url
            }
        }
        if decoded.lowercased().hasPrefix("www."),
           let url = URL(string: "https://\(decoded)"),
           isWebURL(url) {
            return url
        }
        return nil
    }

    private static func normalizedWebURL(_ url: URL) -> URL? {
        guard isWebURL(url) else { return nil }
        return url
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return url.host != nil
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities = [
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">"
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }

    private static func displayTitle(url: URL, anchor: String) -> String {
        let cleaned = decodeHTMLEntities(anchor)
            .strippingHTML
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 2, !looksLikeURL(cleaned) {
            return cleaned
        }
        let domain = MediaLink.registrableDomain(from: url)
        return domain.isEmpty ? (url.host ?? url.absoluteString) : domain
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.hasPrefix("www.")
    }

    private static func classifyHost(_ url: URL) -> MediaLink.MediaLinkType {
        let host = url.host?.lowercased() ?? ""

        if host.contains("youtube.com") || host.contains("youtu.be") {
            return .youtubeVideo
        }
        if host.contains("apps.apple.com") || host.contains("itunes.apple.com") {
            return .app
        }
        if host.contains("imdb.com") || host.contains("themoviedb.org") {
            return .movie
        }
        if host.contains("spotify.com") || host.contains("music.apple.com") {
            return .song
        }
        if host.contains("netflix.com") || host.contains("hulu.com")
            || host.contains("disneyplus.com") || host.contains("hbomax.com")
            || host.contains("peacocktv.com") || host.contains("max.com") {
            return .tvShow
        }
        if host.contains("amazon.com") && url.path.contains("/dp/") {
            return .product
        }
        return .website
    }
}
