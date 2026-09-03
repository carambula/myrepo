import Foundation
import NaturalLanguage

extension Notification.Name {
    static let interestKeywordsDidChange = Notification.Name("PodLink.interestKeywordsDidChange")
}

/// Builds personalized search suggestions using on-device NLP from listening and library metadata.
struct InterestKeywordService {
    static let shared = InterestKeywordService()
    private static let transcriptKeywordStorageKey = "interestTranscriptKeywordsV1"

    private let stopWords: Set<String> = [
        "a", "an", "and", "are", "at", "be", "but", "by", "for", "from", "how", "if",
        "in", "into", "is", "it", "its", "of", "on", "or", "our", "out", "that", "the",
        "their", "this", "to", "up", "we", "with", "you", "your", "episode", "ep",
        "podcast", "show", "shows", "latest", "today", "daily", "weekly", "official",
        "news", "update", "updates", "conversation", "interview", "host", "guest",
        "minute", "minutes", "hour", "hours", "part", "full", "listen", "listening"
    ]

    // MARK: - Baseline Term Frequencies (TF-IDF)

    /// Estimated document frequency of common podcast terms. Terms not in this
    /// table are assumed rare (df ≈ 0.03) and receive minimal IDF penalty.
    private static let baselineTermFrequency: [String: Double] = {
        var t: [String: Double] = [:]

        let tier1: [String] = [
            "people", "world", "time", "life", "story", "way", "thing", "lot",
            "kind", "point", "fact", "idea", "question", "experience", "moment",
            "stuff", "everybody", "everything", "someone", "something", "anyone",
            "place", "reason", "level", "sense", "number", "group", "side",
            "case", "bit", "guy", "man", "woman", "year", "day", "week",
            "month", "night", "morning"
        ]
        for w in tier1 { t[w] = 0.90 }

        let tier2: [String] = [
            "new", "great", "good", "best", "real", "big", "long", "different",
            "important", "interesting", "amazing", "hard", "little", "whole",
            "first", "last", "next", "old", "high", "top", "right", "true",
            "free", "young", "huge", "special", "certain", "current", "pretty",
            "cool", "awesome", "incredible", "fantastic", "crazy", "funny",
            "weird", "simple", "deep", "personal", "entire", "major", "small",
            "wrong", "clear", "single", "early", "late", "past"
        ]
        for w in tier2 { t[w] = 0.78 }

        let tier3: [String] = [
            "talk", "work", "start", "change", "look", "help", "mind", "need",
            "run", "play", "love", "live", "join", "learn", "share", "explore",
            "create", "community", "team", "company", "industry", "market",
            "system", "process", "product", "service", "content", "media",
            "platform", "information", "data", "research", "network", "program",
            "project", "power", "money", "country", "state", "city", "family",
            "game", "food", "music", "book", "film", "art", "science", "law",
            "education", "culture", "history", "future", "relationship",
            "career", "success", "growth", "impact", "challenge",
            "perspective", "journey", "society", "opportunity", "war",
            "energy", "water", "sport"
        ]
        for w in tier3 { t[w] = 0.62 }

        let tier4: [String] = [
            "business", "technology", "health", "politics", "entertainment",
            "comedy", "crime", "fiction", "religion", "philosophy", "economics",
            "psychology", "marketing", "leadership", "management", "investment",
            "fitness", "wellness", "nutrition", "parenting", "travel", "design",
            "engineering", "environment", "government", "military", "medicine",
            "therapy", "finance", "startup", "entrepreneur", "innovation",
            "strategy", "communication", "development", "performance",
            "productivity"
        ]
        for w in tier4 { t[w] = 0.45 }

        return t
    }()

    /// IDF-inspired penalty: rare terms ≈ 1.0, ubiquitous terms ≈ 0.15.
    /// For multi-word phrases the most specific component drives the score.
    private func baselineIDF(_ keyword: String) -> Double {
        if keyword.contains(" ") {
            let words = keyword.split(separator: " ").map(String.init)
            let minDF = words.map { Self.baselineTermFrequency[$0] ?? 0.03 }.min() ?? 0.03
            return max(0.15, 1.0 - minDF)
        }
        let df = Self.baselineTermFrequency[keyword] ?? 0.03
        return max(0.15, 1.0 - df)
    }

    // MARK: - Suggested Keywords

    func suggestedKeywords(limit: Int = 12) -> [String] {
        var scores: [String: Double] = [:]
        var episodeSupport: [String: Set<String>] = [:]
        var podcastSupport: [String: Set<String>] = [:]

        let history = ListeningHistoryStore.loadEntriesForDisplay()
        let followed = Podcast.loadFollowedPodcasts()
        let historyFeedURLs = Set(history.map { canonicalFeedKey(from: $0.feedURLString) })
        let historyPodcastIDs = Set(history.map(\.podcastID))
        let historyByEpisodeID = Dictionary(uniqueKeysWithValues: history.map { ($0.episodeID, $0) })

        for (index, entry) in history.prefix(200).enumerated() {
            let weight = computeEngagementWeight(for: entry, index: index)

            scoreKeywords(in: entry.episodeTitle, weight: weight, into: &scores)
            scoreKeywords(in: entry.podcastTitle, weight: weight * 0.9, into: &scores)

            let historyTerms = extractNormalizedKeywords(
                from: "\(entry.episodeTitle) \(entry.podcastTitle)",
                limit: 24
            )
            for term in historyTerms {
                episodeSupport[term, default: []].insert(entry.episodeID)
                podcastSupport[term, default: []].insert(entry.podcastID)
            }
        }

        let relevantFollowed = followed.filter {
            historyPodcastIDs.contains($0.id) || historyFeedURLs.contains(canonicalFeedKey(from: $0.feedURL.absoluteString))
        }
        let metadataSource = relevantFollowed.isEmpty ? followed : relevantFollowed

        for podcast in metadataSource.prefix(120) {
            scoreKeywords(in: podcast.title, weight: 1.7, into: &scores)
            scoreKeywords(in: podcast.author, weight: 1.0, into: &scores)
            scoreKeywords(in: String(podcast.description.prefix(1200)), weight: 0.8, into: &scores)
            for category in podcast.categories {
                scorePhrase(category, weight: 1.8, into: &scores)
            }

            let metadataTerms = extractNormalizedKeywords(
                from: [podcast.title, podcast.author, String(podcast.description.prefix(1200))]
                    .joined(separator: " "),
                limit: 32
            ).union(
                Set(podcast.categories.compactMap { normalizePhrase($0) })
            )

            for term in metadataTerms {
                podcastSupport[term, default: []].insert(podcast.id)
            }
        }

        let transcriptKeywordIndex = loadTranscriptKeywordIndex()
        for (episodeID, episodeKeywords) in transcriptKeywordIndex {
            let entry = historyByEpisodeID[episodeID]
            let baseWeight: Double = entry == nil ? 0.45 : 1.0
            let completionBoost = (entry?.isPlayed ?? false) ? 1.2 : 1.0
            let transcriptWeight = 1.6 * baseWeight * completionBoost

            for (keyword, score) in episodeKeywords {
                scores[keyword, default: 0] += score * transcriptWeight
                episodeSupport[keyword, default: []].insert(episodeID)
                if let podcastID = entry?.podcastID {
                    podcastSupport[keyword, default: []].insert(podcastID)
                }
            }
        }

        scoreFeaturesFromStore(
            historyByEpisodeID: historyByEpisodeID,
            into: &scores,
            episodeSupport: &episodeSupport,
            podcastSupport: &podcastSupport
        )

        let feedback = feedbackSignals()

        let totalPodcasts = max(1, metadataSource.count)
        let scored = scores.compactMap { keyword, baseScore -> (String, Double)? in
            let episodeCount = episodeSupport[keyword]?.count ?? 0
            let podcastCount = podcastSupport[keyword]?.count ?? 0
            guard episodeCount > 0 || podcastCount > 0 else { return nil }

            let idf = baselineIDF(keyword)

            let commonness = Double(podcastCount) / Double(totalPodcasts)
            let commonnessPenalty = (commonness > 0.65 && podcastCount > 2) ? 0.22 : 1.0

            let crossPodcastBoost: Double
            if podcastCount >= 3 {
                crossPodcastBoost = 1.0 + (0.15 * log1p(Double(podcastCount - 2)))
            } else if podcastCount == 2 {
                crossPodcastBoost = 1.08
            } else {
                crossPodcastBoost = 1.0
            }
            let oneOffPenalty = (episodeCount <= 1 && podcastCount <= 1) ? 0.55 : 1.0

            let supportBoost =
                (0.16 * log1p(Double(max(0, episodeCount - 1)))) +
                (0.12 * log1p(Double(max(0, podcastCount - 1))))
            let specificityBoost = 1.0 + (0.34 * max(0, 1.0 - commonness))
            let phraseBoost = keyword.contains(" ") ? 1.18 : 1.0
            let lengthPenalty = keyword.count > 28 ? 0.84 : 1.0

            let feedbackBoost = feedback.boosts[keyword] ?? 1.0
            let feedbackPenalty = feedback.penalties[keyword] ?? 1.0

            let finalScore =
                ((baseScore * idf * specificityBoost * phraseBoost * commonnessPenalty * oneOffPenalty * crossPodcastBoost) + supportBoost) *
                lengthPenalty * feedbackBoost * feedbackPenalty
            return finalScore >= 1.25 ? (keyword, finalScore) : nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
            .prefix(max(1, limit))
            .map { prettyKeyword($0) }
    }

    // MARK: - Engagement & Behavioral Signals

    /// Continuous engagement weight using completion ratio and listen velocity
    /// instead of a binary played/unplayed flag.
    private func computeEngagementWeight(for entry: ListeningHistoryEntry, index: Int) -> Double {
        let recencyBoost = max(0.35, 1.0 - (Double(index) * 0.02))

        let completionFactor: Double
        if entry.isPlayed {
            completionFactor = 1.35
        } else if entry.duration > 0 {
            let ratio = min(1.0, max(0, entry.playbackPosition / entry.duration))
            completionFactor = 0.7 + (ratio * 0.65)
        } else {
            completionFactor = 0.85
        }

        let velocityFactor: Double
        let gap = entry.lastListenedAt.timeIntervalSince(entry.episodePublishDate)
        if gap < 0 || entry.episodePublishDate.timeIntervalSince1970 < 1 {
            velocityFactor = 1.0
        } else if gap < 86400 {
            velocityFactor = 1.25
        } else if gap < 86400 * 3 {
            velocityFactor = 1.12
        } else if gap < 86400 * 7 {
            velocityFactor = 1.05
        } else {
            velocityFactor = 1.0
        }

        return 2.2 * recencyBoost * completionFactor * velocityFactor
    }

    // MARK: - Feature Store Integration

    /// Injects typed features (person, organization, product, etc.) from
    /// `SuggestionFeatureStore` for episodes the user has actually listened to.
    private func scoreFeaturesFromStore(
        historyByEpisodeID: [String: ListeningHistoryEntry],
        into scores: inout [String: Double],
        episodeSupport: inout [String: Set<String>],
        podcastSupport: inout [String: Set<String>]
    ) {
        let allFeatures = SuggestionFeatureStore.snapshot()
        let listenedIDs = Set(historyByEpisodeID.keys)

        let kindWeight: [SuggestionFeatureStore.Feature.Kind: Double] = [
            .person: 2.8,
            .organization: 2.4,
            .product: 2.6,
            .termOfArt: 1.8,
            .topicPhrase: 1.2,
            .categoryTag: 0.9,
            .linkDomain: 0.6
        ]

        for epFeatures in allFeatures {
            guard listenedIDs.contains(epFeatures.episodeID) else { continue }
            let entry = historyByEpisodeID[epFeatures.episodeID]
            let engagementScale = (entry?.isPlayed ?? false) ? 1.2 : 0.8

            for feature in epFeatures.features {
                guard feature.confidence >= 0.45 else { continue }

                let key: String?
                if feature.text.contains(" ") {
                    key = normalizePhrase(feature.text)
                } else {
                    key = normalizeToken(feature.text)
                }
                guard let normalizedKey = key, normalizedKey.count >= 3 else { continue }

                let weight = (kindWeight[feature.kind] ?? 1.0) * feature.confidence * engagementScale
                scores[normalizedKey, default: 0] += weight
                episodeSupport[normalizedKey, default: []].insert(epFeatures.episodeID)
                podcastSupport[normalizedKey, default: []].insert(epFeatures.podcastID)
            }
        }
    }

    // MARK: - Feedback Loop

    /// Reads tap/impression history from `RecommendationFeedbackStore` to boost
    /// previously engaged suggestions and penalise repeatedly ignored ones.
    private func feedbackSignals() -> (boosts: [String: Double], penalties: [String: Double]) {
        let events = RecommendationFeedbackStore.loadEventsSnapshot()
        guard !events.isEmpty else { return ([:], [:]) }

        var tapCounts: [String: Int] = [:]
        var impressionCounts: [String: Int] = [:]

        for event in events {
            switch event.type {
            case .suggestionTap, .suggestionSearchConversion:
                if let key = normalizePhrase(event.value) ?? normalizeToken(event.value) {
                    tapCounts[key, default: 0] += 1
                }
            case .suggestionImpression:
                for part in event.value.components(separatedBy: " | ") {
                    let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let key = normalizePhrase(trimmed) ?? normalizeToken(trimmed) {
                        impressionCounts[key, default: 0] += 1
                    }
                }
            default:
                break
            }
        }

        var boosts: [String: Double] = [:]
        for (keyword, count) in tapCounts {
            boosts[keyword] = 1.0 + (0.3 * log1p(Double(count)))
        }

        var penalties: [String: Double] = [:]
        for (keyword, impressions) in impressionCounts {
            if (tapCounts[keyword] ?? 0) == 0 && impressions >= 3 {
                penalties[keyword] = max(0.3, 1.0 - (Double(impressions) * 0.07))
            }
        }

        return (boosts, penalties)
    }

    // MARK: - Transcript Keyword Index

    /// Indexes transcript content for one episode and notifies listeners that suggestions changed.
    func indexTranscriptKeywords(for episodeID: String, transcriptText: String) {
        let trimmed = transcriptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let sampled = String(trimmed.prefix(16_000))
        var scores: [String: Double] = [:]
        scoreKeywords(in: sampled, weight: 0.35, into: &scores)

        let compact = scores
            .filter { $0.value >= 0.7 }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(40)
            .reduce(into: [String: Double]()) { partial, item in
                partial[item.key] = item.value
            }

        guard !compact.isEmpty else { return }
        var current = loadTranscriptKeywordIndex()
        current[episodeID] = compact
        saveTranscriptKeywordIndex(current)
        NotificationCenter.default.post(name: .interestKeywordsDidChange, object: nil)
    }

    /// Transcript-derived keywords for one episode, ordered by score descending.
    func transcriptKeywords(for episodeID: String) -> [String] {
        let values = loadTranscriptKeywordIndex()[episodeID] ?? [:]
        return values
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .map(\.key)
    }

    /// Lightweight keyword matching used by library search.
    func transcriptKeywordsMatch(query: String, episodeID: String) -> Bool {
        let values = loadTranscriptKeywordIndex()[episodeID] ?? [:]
        guard !values.isEmpty else { return false }

        let normalizedTokens = normalizedSearchTokens(from: query)
        guard !normalizedTokens.isEmpty else { return false }
        let normalizedPhrase = normalizedTokens.joined(separator: " ")

        for key in values.keys {
            if key.contains(normalizedPhrase) || normalizedPhrase.contains(key) {
                return true
            }

            let keyTokens = Set(key.split(separator: " ").map(String.init))
            if !keyTokens.isDisjoint(with: normalizedTokens) {
                return true
            }
        }

        return false
    }

    // MARK: - NLP Scoring

    private func scoreKeywords(in text: String, weight: Double, into scores: inout [String: Double]) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        scoreNamedEntities(in: trimmed, weight: weight * 1.2, into: &scores)

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = trimmed

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinContractions]
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            guard let tag else { return true }
            guard tag == .noun || tag == .adjective else { return true }

            let token = String(trimmed[tokenRange])
            let lemma = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? token
            guard let normalized = normalizeToken(lemma) else { return true }

            scores[normalized, default: 0] += weight
            return true
        }
    }

    private func scoreNamedEntities(in text: String, weight: Double, into scores: inout [String: Double]) {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        let range = text.startIndex..<text.endIndex
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            guard let tag else { return true }
            guard tag == .personalName || tag == .organizationName else { return true }

            let token = String(text[tokenRange])
            scorePhrase(token, weight: weight, into: &scores)
            return true
        }
    }

    private func scorePhrase(_ phrase: String, weight: Double, into scores: inout [String: Double]) {
        let base = phrase
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")

        let cleaned = base.replacingOccurrences(
            of: #"[^A-Za-z0-9\s]+"#,
            with: " ",
            options: .regularExpression
        )

        let normalized = cleaned
            .split(whereSeparator: \.isWhitespace)
            .compactMap { normalizeToken(String($0)) }
            .joined(separator: " ")

        guard normalized.count >= 3 else { return }
        scores[normalized, default: 0] += weight
    }

    // MARK: - Normalization Helpers

    private func normalizeToken(_ raw: String) -> String? {
        let token = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()

        guard token.count >= 3 else { return nil }
        guard !stopWords.contains(token) else { return nil }

        let isNumeric = token.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
        guard !isNumeric else { return nil }
        return token
    }

    private func normalizePhrase(_ phrase: String) -> String? {
        let normalized = phrase
            .split(whereSeparator: \.isWhitespace)
            .compactMap { normalizeToken(String($0)) }
            .joined(separator: " ")

        return normalized.count >= 3 ? normalized : nil
    }

    private func prettyKeyword(_ raw: String) -> String {
        raw
            .split(separator: " ")
            .map { part in
                guard part.count > 2 else { return part.uppercased() }
                return part.prefix(1).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }

    private func normalizedSearchTokens(from query: String) -> [String] {
        query
            .split(whereSeparator: \.isWhitespace)
            .compactMap { normalizeToken(String($0)) }
    }

    private func extractNormalizedKeywords(from text: String, limit: Int) -> Set<String> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var localScores: [String: Double] = [:]
        scoreKeywords(in: trimmed, weight: 1.0, into: &localScores)
        return Set(
            localScores
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key < rhs.key }
                    return lhs.value > rhs.value
                }
                .prefix(max(1, limit))
                .map(\.key)
        )
    }

    private func canonicalFeedKey(from raw: String) -> String {
        guard let url = URL(string: raw) else { return raw.lowercased() }
        return PrivateFeedAuthStore.canonicalFeedURL(url).absoluteString
    }

    // MARK: - Persistence

    private func loadTranscriptKeywordIndex() -> [String: [String: Double]] {
        guard let data = UserDefaults.standard.data(forKey: Self.transcriptKeywordStorageKey),
              let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveTranscriptKeywordIndex(_ value: [String: [String: Double]]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: Self.transcriptKeywordStorageKey)
    }
}
