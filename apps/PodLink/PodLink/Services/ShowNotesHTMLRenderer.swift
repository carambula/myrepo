import Foundation
import UIKit

/// Turns show-notes HTML into an attributed string without WebKit.
///
/// `NSAttributedString`'s HTML importer runs WebKit and spins the main run
/// loop until it finishes. The player builds its show notes as it appears, so
/// that nested run loop let Core Animation commit a half-built presentation:
/// the sheet drew at full size for a frame before its zoom started.
///
/// Only inline emphasis, links, line breaks, paragraphs and lists are kept.
/// Fonts carry bold / italic traits only; the caller applies final typography.
enum ShowNotesHTMLRenderer {
    static func render(_ html: String, pointSize: CGFloat) -> NSMutableAttributedString {
        var source = html.removingHTMLBlocks(["script", "style", "head"])
        source = source.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        source = source.replacingOccurrences(of: "<![^>]*>", with: "", options: .regularExpression)

        var builder = Builder(pointSize: pointSize)
        let ns = source as NSString
        let matches = tagRegex?.matches(in: source, range: NSRange(location: 0, length: ns.length)) ?? []
        var cursor = 0
        for match in matches {
            if match.range.location > cursor {
                let textRange = NSRange(location: cursor, length: match.range.location - cursor)
                builder.appendText(ns.substring(with: textRange))
            }
            let nameRange = match.range(at: 2)
            let attributeRange = match.range(at: 3)
            builder.handleTag(
                ns.substring(with: nameRange).lowercased(),
                closing: match.range(at: 1).length > 0,
                attributes: attributeRange.location == NSNotFound ? "" : ns.substring(with: attributeRange)
            )
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length {
            builder.appendText(ns.substring(from: cursor))
        }
        return builder.finished()
    }

    // MARK: - Patterns

    private static let tagRegex = try? NSRegularExpression(
        pattern: "<(/?)([A-Za-z][A-Za-z0-9]*)([^>]*)>"
    )

    private static let hrefRegex = try? NSRegularExpression(
        pattern: "href\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))",
        options: .caseInsensitive
    )

    private static let entityRegex = try? NSRegularExpression(
        pattern: "&(#[0-9]{1,7}|#[xX][0-9A-Fa-f]{1,6}|[A-Za-z][A-Za-z0-9]{1,10});"
    )

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": " ", "ensp": " ", "emsp": " ", "thinsp": " ",
        "mdash": "\u{2014}", "ndash": "\u{2013}", "hellip": "\u{2026}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "laquo": "\u{00AB}", "raquo": "\u{00BB}", "bull": "\u{2022}", "middot": "\u{00B7}",
        "copy": "\u{00A9}", "reg": "\u{00AE}", "trade": "\u{2122}", "deg": "\u{00B0}",
        "euro": "\u{20AC}", "pound": "\u{00A3}", "cent": "\u{00A2}", "yen": "\u{00A5}",
        "times": "\u{00D7}", "frac12": "\u{00BD}", "frac14": "\u{00BC}", "frac34": "\u{00BE}",
        "eacute": "\u{00E9}", "egrave": "\u{00E8}", "ecirc": "\u{00EA}", "euml": "\u{00EB}",
        "aacute": "\u{00E1}", "agrave": "\u{00E0}", "acirc": "\u{00E2}", "auml": "\u{00E4}",
        "iacute": "\u{00ED}", "igrave": "\u{00EC}", "icirc": "\u{00EE}", "iuml": "\u{00EF}",
        "oacute": "\u{00F3}", "ograve": "\u{00F2}", "ocirc": "\u{00F4}", "ouml": "\u{00F6}",
        "uacute": "\u{00FA}", "ugrave": "\u{00F9}", "ucirc": "\u{00FB}", "uuml": "\u{00FC}",
        "ccedil": "\u{00E7}", "ntilde": "\u{00F1}", "szlig": "\u{00DF}"
    ]

    // MARK: - Helpers

    static func decodingEntities(_ text: String) -> String {
        guard text.contains("&"), let regex = entityRegex else { return text }
        let ns = text as NSString
        let result = NSMutableString(string: text)
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for match in matches.reversed() {
            let body = ns.substring(with: match.range(at: 1))
            guard let replacement = replacement(forEntity: body) else { continue }
            result.replaceCharacters(in: match.range, with: replacement)
        }
        return result as String
    }

    private static func replacement(forEntity body: String) -> String? {
        if body.hasPrefix("#") {
            let digits = body.dropFirst()
            let code: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                code = UInt32(digits.dropFirst(), radix: 16)
            } else {
                code = UInt32(digits, radix: 10)
            }
            guard let code, let scalar = Unicode.Scalar(code) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[body] ?? namedEntities[body.lowercased()]
    }

    private static func href(in attributes: String) -> URL? {
        guard let regex = hrefRegex else { return nil }
        let ns = attributes as NSString
        guard let match = regex.firstMatch(in: attributes, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        for group in 1...3 {
            let range = match.range(at: group)
            guard range.location != NSNotFound, range.length > 0 else { continue }
            let raw = decodingEntities(ns.substring(with: range))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return URL(string: raw)
        }
        return nil
    }

    // MARK: - Builder

    private struct ListContext {
        let ordered: Bool
        var count = 0
    }

    private struct Builder {
        let pointSize: CGFloat
        private let output = NSMutableAttributedString(string: "")
        private var boldDepth = 0
        private var italicDepth = 0
        private var links: [URL?] = []
        private var lists: [ListContext] = []
        private var pendingParagraphBreak = false
        private var pendingMarker: String?
        private var atLineStart = true

        private static let lineSeparator = "\u{2028}"
        private static let nestedListIndent = "\u{2003}"
        private static let spaces = CharacterSet(charactersIn: " ")
        private static let spacesAndLineBreaks = CharacterSet(charactersIn: " \u{2028}")

        init(pointSize: CGFloat) {
            self.pointSize = pointSize
        }

        mutating func appendText(_ raw: String) {
            let collapsed = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            var text = ShowNotesHTMLRenderer.decodingEntities(collapsed)
            if atLineStart || pendingParagraphBreak || output.mutableString.hasSuffix(" ") {
                while text.hasPrefix(" ") {
                    text.removeFirst()
                }
            }
            guard !text.isEmpty else { return }
            flushParagraphBreak()
            if let marker = pendingMarker {
                pendingMarker = nil
                output.append(NSAttributedString(string: marker, attributes: attributes(emphasis: false)))
            }
            output.append(NSAttributedString(string: text, attributes: attributes(emphasis: true)))
            atLineStart = false
        }

        mutating func handleTag(_ name: String, closing: Bool, attributes: String) {
            switch name {
            case "b", "strong":
                boldDepth = max(0, boldDepth + (closing ? -1 : 1))
            case "i", "em", "cite":
                italicDepth = max(0, italicDepth + (closing ? -1 : 1))
            case "a":
                if closing {
                    if !links.isEmpty { links.removeLast() }
                } else {
                    links.append(ShowNotesHTMLRenderer.href(in: attributes))
                }
            case "br":
                if !closing { lineBreak() }
            case "ul", "ol":
                if closing {
                    if !lists.isEmpty { lists.removeLast() }
                } else {
                    lists.append(ListContext(ordered: name == "ol"))
                }
                paragraphBreak()
            case "li":
                paragraphBreak()
                if closing {
                    pendingMarker = nil
                } else if var list = lists.popLast() {
                    list.count += 1
                    lists.append(list)
                    let indent = String(repeating: Self.nestedListIndent, count: lists.count - 1)
                    pendingMarker = indent + (list.ordered ? "\(list.count). " : "\u{2022} ")
                } else {
                    pendingMarker = "\u{2022} "
                }
            case "h1", "h2", "h3", "h4", "h5", "h6":
                boldDepth = max(0, boldDepth + (closing ? -1 : 1))
                paragraphBreak()
            case "p", "div", "blockquote", "section", "article", "header", "footer",
                 "pre", "table", "tr", "hr", "figure", "figcaption", "dl", "dt", "dd":
                paragraphBreak()
            default:
                break
            }
        }

        func finished() -> NSMutableAttributedString {
            trimTrailing(.whitespacesAndNewlines)
            return output
        }

        private mutating func paragraphBreak() {
            pendingParagraphBreak = true
            atLineStart = true
        }

        private mutating func flushParagraphBreak() {
            guard pendingParagraphBreak else { return }
            pendingParagraphBreak = false
            guard output.length > 0 else { return }
            trimTrailing(Self.spacesAndLineBreaks)
            output.append(NSAttributedString(string: "\n", attributes: attributes(emphasis: false)))
        }

        /// `<br>` is a soft break inside a paragraph, so it does not pick up
        /// paragraph spacing. Runs of them are capped at one blank line.
        private mutating func lineBreak() {
            guard output.length > 0, !pendingParagraphBreak else { return }
            trimTrailing(Self.spaces)
            let doubled = Self.lineSeparator + Self.lineSeparator
            if output.mutableString.hasSuffix(doubled) || output.mutableString.hasSuffix("\n") { return }
            output.append(NSAttributedString(string: Self.lineSeparator, attributes: attributes(emphasis: false)))
            atLineStart = true
        }

        private func trimTrailing(_ characters: CharacterSet) {
            while output.length > 0,
                  let scalar = Unicode.Scalar(output.mutableString.character(at: output.length - 1)),
                  characters.contains(scalar) {
                output.deleteCharacters(in: NSRange(location: output.length - 1, length: 1))
            }
        }

        private func attributes(emphasis: Bool) -> [NSAttributedString.Key: Any] {
            guard emphasis else {
                return [.font: font(bold: false, italic: false)]
            }
            var result: [NSAttributedString.Key: Any] = [
                .font: font(bold: boldDepth > 0, italic: italicDepth > 0)
            ]
            if let url = links.last ?? nil {
                result[.link] = url
            }
            return result
        }

        private func font(bold: Bool, italic: Bool) -> UIFont {
            let base = bold
                ? UIFont.boldSystemFont(ofSize: pointSize)
                : UIFont.systemFont(ofSize: pointSize)
            guard italic else { return base }
            var traits = base.fontDescriptor.symbolicTraits
            traits.insert(.traitItalic)
            guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else { return base }
            return UIFont(descriptor: descriptor, size: pointSize)
        }
    }
}
