import Foundation
import NaturalLanguage

actor AIEntityExtractor {
    static let shared = AIEntityExtractor()

    struct ExtractedEntity {
        let text: String
        let type: MediaLink.MediaLinkType
        let confidence: Float
    }

    func extractEntities(from text: String) async -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        // Layer 1: Named entity recognition via NLTagger
        let nlpEntities = extractWithNLTagger(text)
        entities.append(contentsOf: nlpEntities)

        // Layer 2: Pattern-based extraction
        let patternEntities = extractWithPatterns(text)
        entities.append(contentsOf: patternEntities)

        return deduplicateEntities(entities)
    }

    // MARK: - NLTagger-based Extraction

    private func extractWithNLTagger(_ text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]

        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: options) { tag, range in
            guard let tag else { return true }

            let entity = String(text[range])
            guard entity.count >= 2 else { return true }

            switch tag {
            case .personalName:
                entities.append(ExtractedEntity(
                    text: entity,
                    type: .person,
                    confidence: 0.7
                ))
            case .organizationName:
                entities.append(ExtractedEntity(
                    text: entity,
                    type: .website,
                    confidence: 0.5
                ))
            case .placeName:
                break // Skip places for media linking
            default:
                break
            }

            return true
        }

        return entities
    }

    // MARK: - Pattern-based Extraction

    private func extractWithPatterns(_ text: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        let patterns: [(String, MediaLink.MediaLinkType, Float)] = [
            // Movies/TV: quoted titles with optional year
            (#"['\u201C\u201D\u2018\u2019"]([^'\"]+)['\u201C\u201D\u2018\u2019"](?:\s*\((\d{4})\))?"#,
             .movie, 0.75),

            // Apps: "the X app" or "X from the App Store"
            (#"(?:the\s+)?(\w+(?:\s+\w+){0,2})\s+app(?:\s|$|,|\.)"#,
             .app, 0.65),

            // YouTube: "on YouTube", "YouTube channel"
            (#"(\w+(?:\s+\w+){0,3})\s+(?:YouTube\s+)?channel"#,
             .youtubeChannel, 0.6),

            // Songs: "song X by Y"
            (#"(?:song|track|single)\s+['\"]([^'\"]+)['\"]"#,
             .song, 0.7),

            // Books: "the book X" or "X by [author]"
            (#"(?:the\s+)?book\s+['\"]([^'\"]+)['\"]"#,
             .book, 0.7),
        ]

        for (pattern, type, confidence) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                guard let titleRange = Range(match.range(at: 1), in: text) else { continue }
                let title = String(text[titleRange])
                entities.append(ExtractedEntity(text: title, type: type, confidence: confidence))
            }
        }

        return entities
    }

    // MARK: - Deduplication

    private func deduplicateEntities(_ entities: [ExtractedEntity]) -> [ExtractedEntity] {
        var seen = Set<String>()
        var result: [ExtractedEntity] = []

        for entity in entities.sorted(by: { $0.confidence > $1.confidence }) {
            let key = entity.text.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(entity)
            }
        }

        return result
    }
}
