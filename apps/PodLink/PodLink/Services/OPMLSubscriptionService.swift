import Foundation

enum OPMLSubscriptionService {
    /// OPML 2.0-style document with `type="rss"` outlines, compatible with most podcast apps.
    static func opmlData(for podcasts: [Podcast]) -> Data? {
        let title = "PodLink Subscriptions"
        var lines: [String] = []
        lines.append(#"<?xml version="1.0" encoding="UTF-8"?>"#)
        lines.append(#"<opml version="2.0">"#)
        lines.append("<head>")
        lines.append("  <title>\(xmlEscape(title))</title>")
        lines.append("</head>")
        lines.append("<body>")
        for podcast in podcasts {
            let feed = podcast.feedURL.absoluteString
            let label = podcast.title.isEmpty ? feed : podcast.title
            lines.append(
                #"  <outline text="\#(xmlEscape(label))" title="\#(xmlEscape(label))" type="rss" xmlUrl="\#(xmlEscape(feed))" />"#
            )
        }
        lines.append("</body>")
        lines.append("</opml>")
        return lines.joined(separator: "\n").data(using: .utf8)
    }

    /// Extracts unique feed URLs in document order (nested `outline` elements included).
    static func feedURLs(from opmlData: Data) -> [URL] {
        let collector = OPMLFeedURLCollector()
        let parser = XMLParser(data: opmlData)
        parser.delegate = collector
        _ = parser.parse()
        return collector.feedURLs
    }

    private static func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private final class OPMLFeedURLCollector: NSObject, XMLParserDelegate {
    private(set) var feedURLs: [URL] = []
    private var seen = Set<String>()

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        guard elementName.lowercased() == "outline" else { return }
        guard let raw = attributeDict.first(where: { $0.key.lowercased() == "xmlurl" })?.value else {
            return
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return
        }
        let key = PrivateFeedAuthStore.canonicalFeedURL(url).absoluteString
        guard !seen.contains(key) else { return }
        seen.insert(key)
        feedURLs.append(url)
    }
}
