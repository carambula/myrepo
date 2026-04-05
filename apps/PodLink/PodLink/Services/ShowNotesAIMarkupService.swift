import Foundation
import FoundationModels

/// Uses the on-device language model to add Markdown structure to dense plain-text show notes.
/// Skips HTML and text that already looks like Markdown; never replaces the baseline formatted view on failure.
enum ShowNotesAIMarkupService {

    static func shouldOffer(for raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > 400, t.count < 7_000 else { return false }
        guard !containsHTMLTags(t) else { return false }
        guard !likelyMarkdown(t) else { return false }

        let newlines = t.filter { $0 == "\n" }.count
        let dense = newlines < max(10, t.count / 450)
        guard dense else { return false }

        guard case .available = SystemLanguageModel.default.availability else { return false }
        return true
    }

    static func structuredMarkdown(from plain: String) async -> String? {
        guard shouldOffer(for: plain) else { return nil }

        let instructions = """
        You format podcast show notes as readable GitHub-Flavored Markdown.
        Use ## only for clear section headings, and bullet lists for groups of links, sponsors, or credits.
        Preserve every URL and name exactly; do not summarize, omit, or invent content.
        Output only the markdown body with no title line or preamble.
        """

        let session = LanguageModelSession(
            model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
            instructions: instructions
        )

        let prompt = """
        Format these show notes as markdown:

        \(plain)
        """

        do {
            let response = try await session.respond(to: prompt)
            let out = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return out.isEmpty ? nil : out
        } catch {
            return nil
        }
    }

    private static func containsHTMLTags(_ s: String) -> Bool {
        s.range(of: #"<\s*[a-zA-Z][^>]*>"#, options: .regularExpression) != nil
    }

    private static func likelyMarkdown(_ s: String) -> Bool {
        if s.contains("**") || s.contains("](") { return true }
        if s.contains("```") { return true }
        if s.range(of: #"(?m)^\s{0,3}#{1,6}\s"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"(?m)^\s*[-*+]\s"#, options: .regularExpression) != nil { return true }
        if s.range(of: #"(?m)^\s*\d+\.\s"#, options: .regularExpression) != nil { return true }
        return false
    }
}
