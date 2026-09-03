import Foundation

enum TranscriptURLDiscovery {
    private static let transcriptExtensions: Set<String> = ["srt", "vtt", "txt"]

    /// Pulls likely transcript file URLs from episode show notes (HTML or plain).
    static func candidateTranscriptURLs(in description: String, excluding excluded: URL?, limit: Int = 8) -> [URL] {
        var seen = Set<String>()
        var ordered: [URL] = []

        func consider(_ url: URL) {
            guard seen.insert(url.absoluteString).inserted else { return }
            if let excluded, url.absoluteString == excluded.absoluteString { return }
            guard looksLikeTranscriptAsset(url) else { return }
            ordered.append(url)
        }

        extractHrefs(from: description).forEach { consider($0) }

        let plain = description.strippingHTML
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(plain.startIndex..<plain.endIndex, in: plain)
            detector.enumerateMatches(in: plain, options: [], range: range) { match, _, _ in
                guard let match, let r = Range(match.range, in: plain),
                      let url = URL(string: String(plain[r])) else { return }
                consider(url)
            }
        }

        return Array(ordered.prefix(limit))
    }

    private static func looksLikeTranscriptAsset(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if transcriptExtensions.contains(ext) { return true }
        let path = url.path.lowercased()
        if path.contains("transcript"), ["txt", "json", "html", "htm", ""].contains(ext) || ext == "php" {
            return true
        }
        if path.contains("caption"), ext == "vtt" || ext == "srt" { return true }
        return false
    }

    private static func extractHrefs(from html: String) -> [URL] {
        let pattern = #"href\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match -> URL? in
            guard let r = Range(match.range(at: 1), in: html) else { return nil }
            let s = String(html[r])
            if s.hasPrefix("//"), let u = URL(string: "https:\(s)") { return u }
            return URL(string: s)
        }
    }
}
