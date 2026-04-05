import Foundation
import UIKit

extension String {
    var cleanedHTML: String {
        guard let data = self.data(using: .utf8),
              let attributed = try? NSAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ],
                documentAttributes: nil
              ) else {
            return self.strippingHTML
        }
        return attributed.string
    }

    func extractYear() -> Int? {
        let pattern = #"\b(19|20)\d{2}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..<endIndex, in: self)),
              let range = Range(match.range, in: self) else {
            return nil
        }
        return Int(String(self[range]))
    }

    func extractQuotedStrings() -> [String] {
        let pattern = #"['\u201C\u201D\u2018\u2019"]([^'\"]+)['\u201C\u201D\u2018\u2019"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(startIndex..<endIndex, in: self)
        let matches = regex.matches(in: self, range: range)
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: self) else { return nil }
            return String(self[range])
        }
    }

    var trimmedAndCleaned: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Removes entire blocks of the given tag names (including their content).
    func removingHTMLBlocks(_ tags: [String]) -> String {
        var result = self
        for tag in tags {
            let pattern = "<\(tag)\\b[^>]*>[\\s\\S]*?</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        return result
    }

    /// Strips all HTML tags, leaving only text content and decoding common entities.
    var strippingHTMLTags: String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        var stripped = regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"),
            ("&nbsp;", " "), ("&#x27;", "'"), ("&mdash;", "\u{2014}"),
            ("&ndash;", "\u{2013}"), ("&hellip;", "\u{2026}"),
            ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
        ]
        for (entity, replacement) in entities {
            stripped = stripped.replacingOccurrences(of: entity, with: replacement)
        }
        if let numericRegex = try? NSRegularExpression(pattern: "&#(\\d+);") {
            let nsRange = NSRange(stripped.startIndex..<stripped.endIndex, in: stripped)
            let mutable = NSMutableString(string: stripped)
            for match in numericRegex.matches(in: stripped, range: nsRange).reversed() {
                guard let codeRange = Range(match.range(at: 1), in: stripped),
                      let codePoint = UInt32(stripped[codeRange]),
                      let scalar = Unicode.Scalar(codePoint) else { continue }
                mutable.replaceCharacters(in: match.range, with: String(scalar))
            }
            stripped = mutable as String
        }
        return stripped
    }
}
