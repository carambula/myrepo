import Foundation

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
}
