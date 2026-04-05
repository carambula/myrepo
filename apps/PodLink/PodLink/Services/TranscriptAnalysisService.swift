import Foundation
import NaturalLanguage

actor TranscriptAnalysisService {
    static let shared = TranscriptAnalysisService()

    private let cache = CacheService.shared

    // MARK: - Public API

    func analyze(_ transcript: FullTranscript, episodeID: String) async -> TranscriptAnalysis {
        let cacheKey = "transcript_analysis_\(episodeID)"
        if let cached: TranscriptAnalysis = await cache.get(cacheKey, as: TranscriptAnalysis.self) {
            return cached
        }
        let analysis = build(from: transcript)
        await cache.set(cacheKey, value: analysis, ttl: 86400 * 30)
        return analysis
    }

    func invalidate(for episodeID: String) async {
        await cache.remove("transcript_analysis_\(episodeID)")
    }

    // MARK: - Core build

    private func build(from transcript: FullTranscript) -> TranscriptAnalysis {
        let text = transcript.text
        let speakerNames = inferSpeakerNames(from: transcript)
        let insights = extractInsights(from: text)
        let entityWords = Set(insights.map { $0.text.lowercased() })
        let keywords = extractKeywords(from: text, skip: entityWords)

        return TranscriptAnalysis(
            keywords: keywords,
            insights: insights,
            speakerNames: speakerNames,
            analyzedAt: Date()
        )
    }

    // MARK: - Entity / insight extraction

    private func extractInsights(from text: String) -> [TranscriptInsight] {
        var counts: [String: (category: TranscriptInsight.InsightCategory, count: Int, url: URL?)] = [:]

        // Named entity recognition via NLTagger
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            guard let tag else { return true }
            let entity = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard entity.count >= 2, entity.first?.isUppercase == true else { return true }

            let category: TranscriptInsight.InsightCategory
            switch tag {
            case .personalName:   category = .person
            case .organizationName: category = .company
            case .placeName:      category = .place
            default:              return true
            }
            counts[entity, default: (category, 0, nil)].count += 1
            return true
        }

        // URLs via NSDataDetector
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, let r = Range(match.range, in: text), let url = match.url else { return }
                let urlStr = String(text[r])
                counts[urlStr] = (.link, (counts[urlStr]?.count ?? 0) + 1, url)
            }
        }

        // YouTube / video references
        let videoPatterns = [
            #"https?://(?:www\.)?youtu(?:be\.com|\.be)[^\s]+"#,
            #"(?i)youtube\.com/[^\s]+"#,
        ]
        for pattern in videoPatterns {
            applyPattern(pattern, to: text, category: .video, into: &counts, extractURL: true)
        }

        // Named events (Conference, Summit, Cup, etc.)
        applyPattern(
            #"(?:[A-Z][a-z]+ ){1,3}(?:Conference|Summit|Forum|Festival|Award|Awards|Championship|Cup|Race|Congress|Convention|Expo)\b"#,
            to: text, category: .event, into: &counts, extractURL: false
        )

        return counts
            .filter { $0.value.count >= 1 }
            .map { name, info in
                TranscriptInsight(text: name, category: info.category, url: info.url, count: info.count)
            }
            .sorted { a, b in
                a.count != b.count ? a.count > b.count : a.text < b.text
            }
    }

    private func applyPattern(
        _ pattern: String,
        to text: String,
        category: TranscriptInsight.InsightCategory,
        into counts: inout [String: (category: TranscriptInsight.InsightCategory, count: Int, url: URL?)],
        extractURL: Bool
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let r = Range(match.range, in: text) else { return }
            let s = String(text[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard s.count >= 4 else { return }
            let url: URL? = extractURL ? URL(string: s) : nil
            counts[s] = (category, (counts[s]?.count ?? 0) + 1, url)
        }
    }

    // MARK: - Keyword extraction

    private static let stopWords: Set<String> = [
        "the", "a", "an", "is", "it", "this", "that", "was", "are", "be", "have", "had", "do",
        "did", "will", "would", "could", "should", "may", "might", "must", "been", "being",
        "has", "very", "just", "really", "like", "know", "think", "going", "kind", "got", "get",
        "go", "we", "you", "he", "she", "they", "them", "their", "our", "us", "one", "also",
        "even", "then", "than", "so", "but", "and", "or", "not", "no", "there", "here", "when",
        "where", "how", "what", "which", "who", "why", "about", "into", "out", "up", "down",
        "more", "some", "many", "much", "any", "all", "new", "now", "only", "can", "said", "say",
        "says", "lot", "things", "thing", "way", "time", "right", "because", "something", "want",
        "actually", "basically", "literally", "yeah", "okay", "well", "sure", "mean", "look",
        "people", "good", "great", "little", "back", "come", "make", "take", "work", "year",
        "different", "other", "need", "first", "last", "next", "long", "high", "every", "while",
        "using", "used", "able", "part", "kind", "place", "case", "side", "point", "never",
        "always", "still", "already", "another", "again", "become", "coming", "going", "putting",
        "talking", "saying", "seeing", "following", "given", "called", "called", "today", "whole"
    ]

    private func extractKeywords(from text: String, skip: Set<String>) -> [String] {
        var frequency: [String: Int] = [:]

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            guard let tag, tag == .noun || tag == .adjective else { return true }
            let word = String(text[range]).lowercased()
            guard word.count > 3,
                  !Self.stopWords.contains(word),
                  !skip.contains(word) else { return true }
            frequency[word, default: 0] += 1
            return true
        }

        return frequency
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(25)
            .map { $0.key }
    }

    // MARK: - Speaker name inference

    private func inferSpeakerNames(from transcript: FullTranscript) -> [String: String] {
        guard let segments = transcript.segments, !segments.isEmpty else { return [:] }

        // Patterns that mean the CURRENT speaker is introducing themselves (high confidence).
        let selfIntroPatterns = [
            (#"(?i)\bI'?m\s+([A-Z][a-z]{1,20})\b"#, 3),
            (#"(?i)\bmy name(?:'?s| is)\s+([A-Z][a-z]{1,20})\b"#, 3),
            (#"(?i)\bI'?m your host,?\s+([A-Z][a-z]{1,20})\b"#, 4),
            (#"(?i)\bthis is\s+([A-Z][a-z]{1,20})\b"#, 2),
        ]

        // Patterns that reveal the OTHER speaker's name (lower confidence).
        let otherIntroPatterns = [
            (#"(?i)\bwelcome(?:\s+back)?,?\s+([A-Z][a-z]{1,20})\b"#, 2),
            (#"(?i)\bthanks?(?:\s+(?:so much|for (?:having|joining))?,?\s+([A-Z][a-z]{1,20})\b"#, 1),
            (#"(?i)\bthank you,?\s+([A-Z][a-z]{1,20})\b"#, 1),
        ]

        var speakerCandidates: [String: [(name: String, score: Int)]] = [:]

        func scan(_ seg: TranscriptSegment, patterns: [(String, Int)], speakerKey: String?) {
            guard let key = speakerKey else { return }
            for (pattern, score) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let fullRange = NSRange(seg.text.startIndex..<seg.text.endIndex, in: seg.text)
                regex.enumerateMatches(in: seg.text, options: [], range: fullRange) { match, _, _ in
                    guard let match,
                          match.numberOfRanges > 1,
                          let nr = Range(match.range(at: 1), in: seg.text) else { return }
                    let name = String(seg.text[nr])
                    speakerCandidates[key, default: []].append((name, score))
                }
            }
        }

        // For "other intro" patterns we want to attribute the name to the OTHER speaker.
        // Collect all segment speaker labels and map each to its "partner".
        let speakerLabels = Array(Set(segments.compactMap(\.speaker))).sorted()
        let otherSpeaker: (String) -> String? = { label in
            guard let idx = speakerLabels.firstIndex(of: label), speakerLabels.count > 1 else { return nil }
            return speakerLabels[(idx + 1) % speakerLabels.count]
        }

        for segment in segments {
            scan(segment, patterns: selfIntroPatterns, speakerKey: segment.speaker)
            if let other = otherSpeaker(segment.speaker ?? "") {
                scan(segment, patterns: otherIntroPatterns, speakerKey: other)
            }
        }

        // Pick the highest-scoring unique name per speaker.
        var result: [String: String] = [:]
        var usedNames: Set<String> = []

        let sortedSpeakers = speakerCandidates.keys.sorted()
        for key in sortedSpeakers {
            let candidates = speakerCandidates[key]!
                .sorted { $0.score > $1.score }
            for (name, score) in candidates where !usedNames.contains(name.lowercased()) {
                usedNames.insert(name.lowercased())
                // Low-confidence patterns prefix with "Maybe ".
                result[key] = score >= 3 ? name : "Maybe \(name)"
                break
            }
        }

        return result
    }
}
