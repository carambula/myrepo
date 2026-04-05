import Foundation
import UIKit

/// Rich show notes: HTML from feeds, optional Markdown, plain text with detected links.
/// Typography matches `DesignSystem.Typography.bodyMedium` (15pt) with Dynamic Type scaling.
enum ShowNotesFormattedContent {

    private static let bodyPointSize: CGFloat = 15

    static func attributedString(from raw: String, linkUIColor: UIColor) -> AttributedString {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return AttributedString() }

        if containsHTMLTags(trimmed) {
            if let html = attributedFromHTML(trimmed, linkUIColor: linkUIColor) {
                return html
            }
            let plain = trimmed.cleanedHTML
            return markdownOrPlain(plain, linkUIColor: linkUIColor)
        }

        return markdownOrPlain(trimmed, linkUIColor: linkUIColor)
    }

    // MARK: - HTML

    private static func containsHTMLTags(_ s: String) -> Bool {
        s.range(of: #"<\s*[a-zA-Z][^>]*>"#, options: .regularExpression) != nil
    }

    private static func attributedFromHTML(_ fragment: String, linkUIColor: UIColor) -> AttributedString? {
        let wrapped = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"></head><body>\(fragment)</body></html>
        """
        guard let data = wrapped.data(using: .utf8) else { return nil }
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let parsed = try? NSMutableAttributedString(data: data, options: opts, documentAttributes: nil) else {
            return nil
        }
        let text = parsed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        normalizeUIKitTypography(in: parsed, linkUIColor: linkUIColor)
        return AttributedString(parsed)
    }

    // MARK: - Markdown / plain

    private static func markdownOrPlain(_ text: String, linkUIColor: UIColor) -> AttributedString {
        let normalized = normalizePlainText(text)
        guard !normalized.isEmpty else { return AttributedString() }

        if likelyMarkdown(normalized), let md = tryMarkdownAttributed(normalized, linkUIColor: linkUIColor) {
            return md
        }
        return attributedPlainWithURLs(normalized, linkUIColor: linkUIColor)
    }

    private static func normalizePlainText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func likelyMarkdown(_ s: String) -> Bool {
        if s.contains("**") || s.contains("](") { return true }
        if s.contains("```") { return true }
        if s.range(of: #"(?m)^\s{0,3}#{1,6}\s"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"(?m)^\s*[-*+]\s"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"(?m)^\s*\d+\.\s"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func tryMarkdownAttributed(_ text: String, linkUIColor: UIColor) -> AttributedString? {
        var opts = AttributedString.MarkdownParsingOptions()
        opts.interpretedSyntax = .full
        opts.failurePolicy = .returnPartiallyParsedIfPossible
        guard let foundationAttr = try? AttributedString(markdown: text, options: opts),
              !foundationAttr.characters.isEmpty else {
            return nil
        }
        let ns = NSMutableAttributedString(attributedString: NSAttributedString(foundationAttr))
        normalizeUIKitTypography(in: ns, linkUIColor: linkUIColor)
        return AttributedString(ns)
    }

    private static func attributedPlainWithURLs(_ text: String, linkUIColor: UIColor) -> AttributedString {
        let mutable = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: scaledBodyFont(weight: .regular),
                .foregroundColor: UIColor.label
            ]
        )
        let full = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.paragraphStyle, value: paragraphStyle(), range: full)

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        detector?.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match, let url = match.url else { return }
            mutable.addAttribute(.link, value: url, range: match.range)
            mutable.addAttribute(.foregroundColor, value: linkUIColor, range: match.range)
        }

        return AttributedString(mutable)
    }

    // MARK: - Shared UIKit polish

    private static func normalizeUIKitTypography(in ns: NSMutableAttributedString, linkUIColor: UIColor) {
        let full = NSRange(location: 0, length: ns.length)
        guard full.length > 0 else { return }

        ns.enumerateAttribute(.font, in: full, options: []) { value, range, _ in
            let font = (value as? UIFont) ?? UIFont.systemFont(ofSize: bodyPointSize)
            let traits = font.fontDescriptor.symbolicTraits
            let weight: UIFont.Weight = traits.contains(.traitBold) ? .semibold : .regular
            var descriptor = UIFont.systemFont(ofSize: bodyPointSize, weight: weight).fontDescriptor
            if traits.contains(.traitItalic) {
                descriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic))
                    ?? descriptor
            }
            let replacement = UIFont(descriptor: descriptor, size: bodyPointSize)
            let scaled = UIFontMetrics(forTextStyle: .body).scaledFont(for: replacement)
            ns.addAttribute(.font, value: scaled, range: range)
        }

        ns.addAttribute(.paragraphStyle, value: paragraphStyle(), range: full)
        ns.addAttribute(.foregroundColor, value: UIColor.label, range: full)

        ns.enumerateAttribute(.link, in: full, options: []) { value, range, _ in
            guard value != nil else { return }
            ns.addAttribute(.foregroundColor, value: linkUIColor, range: range)
        }
    }

    private static func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 9
        style.paragraphSpacing = 18
        style.lineHeightMultiple = 1.14
        style.alignment = .natural
        return style
    }

    private static func scaledBodyFont(weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: bodyPointSize, weight: weight)
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: base)
    }
}
