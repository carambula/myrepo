import Foundation

extension Notification.Name {
    static let suggestionFeaturesDidChange = Notification.Name("PodLink.suggestionFeaturesDidChange")
}

actor SuggestionFeatureStore {
    static let shared = SuggestionFeatureStore()

    private static let storageKey = "suggestionFeatureStoreV1"
    private static let maxFeaturesPerEpisode = 120
    private static let maxEpisodes = 1500
    private static let htmlArtifactTokens: Set<String> = [
        "html", "head", "body", "doctype", "meta", "charset", "viewport", "title",
        "script", "style", "div", "span", "class", "href", "http", "https", "www", "com"
    ]

    struct Feature: Codable, Hashable {
        enum Source: String, Codable, Hashable {
            case transcriptInsight
            case transcriptKeyword
            case chapter
            case episodeMetadata
            case podcastMetadata
            case category
            case mediaLink
        }

        enum Kind: String, Codable, Hashable {
            case person
            case organization
            case topicPhrase
            case categoryTag
            case termOfArt
            case product
            case linkDomain
        }

        let text: String
        let source: Source
        let kind: Kind
        let confidence: Double
    }

    struct EpisodeFeatures: Codable, Hashable {
        let episodeID: String
        let podcastID: String
        let updatedAt: Date
        let features: [Feature]
    }

    private func loadStore() -> [String: EpisodeFeatures] {
        Self.loadStoreSnapshot()
    }

    private func persistStore(_ store: [String: EpisodeFeatures]) {
        let trimmed = store
            .values
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(Self.maxEpisodes)
        let dictionary = Dictionary(uniqueKeysWithValues: trimmed.map { ($0.episodeID, $0) })
        guard let data = try? JSONEncoder().encode(dictionary) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func allFeatures() -> [EpisodeFeatures] {
        Array(loadStore().values)
    }

    func features(for episodeID: String) -> EpisodeFeatures? {
        loadStore()[episodeID]
    }

    func clearAll() {
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        NotificationCenter.default.post(name: .suggestionFeaturesDidChange, object: nil)
    }

    nonisolated static func loadStoreSnapshot() -> [String: EpisodeFeatures] {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: EpisodeFeatures].self, from: data) else {
            return [:]
        }
        return decoded
    }

    nonisolated static func snapshot() -> [EpisodeFeatures] {
        Array(loadStoreSnapshot().values)
    }

    nonisolated static func snapshot(for episodeID: String) -> EpisodeFeatures? {
        loadStoreSnapshot()[episodeID]
    }

    func upsertFeatures(
        episodeID: String,
        podcastID: String,
        features: [Feature]
    ) {
        let deduped = dedupeAndTrim(features)
        guard !deduped.isEmpty else { return }

        var store = loadStore()
        store[episodeID] = EpisodeFeatures(
            episodeID: episodeID,
            podcastID: podcastID,
            updatedAt: Date(),
            features: deduped
        )
        persistStore(store)
        NotificationCenter.default.post(name: .suggestionFeaturesDidChange, object: nil)
    }

    func indexTranscript(
        episode: Episode,
        fullTranscript: FullTranscript,
        analysis: TranscriptAnalysis?
    ) {
        var features: [Feature] = []

        if let analysis {
            for insight in analysis.insights.prefix(80) {
                let kind: Feature.Kind
                switch insight.category {
                case .person:
                    kind = .person
                case .company:
                    kind = .organization
                case .event:
                    kind = .topicPhrase
                case .link, .video:
                    kind = .linkDomain
                case .place:
                    kind = .topicPhrase
                }
                features.append(
                    Feature(
                        text: insight.text,
                        source: .transcriptInsight,
                        kind: kind,
                        confidence: min(1.0, 0.45 + (Double(insight.count) * 0.08))
                    )
                )
            }

            for keyword in analysis.keywords.prefix(50) {
                features.append(
                    Feature(
                        text: keyword,
                        source: .transcriptKeyword,
                        kind: keyword.contains(" ") ? .topicPhrase : .termOfArt,
                        confidence: keyword.contains(" ") ? 0.74 : 0.58
                    )
                )
            }
        }

        let plainKeywords = tokenizePhrases(fullTranscript.text, maxTerms: 50)
        for term in plainKeywords {
            features.append(
                Feature(
                    text: term,
                    source: .transcriptKeyword,
                    kind: term.contains(" ") ? .topicPhrase : .termOfArt,
                    confidence: term.contains(" ") ? 0.64 : 0.52
                )
            )
        }

        upsertFeatures(episodeID: episode.id, podcastID: episode.podcastID, features: features)
    }

    func indexEpisodeMetadata(episode: Episode, podcast: Podcast?) {
        var features: [Feature] = []

        for term in tokenizePhrases(episode.title, maxTerms: 18) {
            features.append(
                Feature(text: term, source: .episodeMetadata, kind: .topicPhrase, confidence: 0.82)
            )
        }

        for term in tokenizePhrases(String(episode.description.prefix(900)), maxTerms: 26) {
            features.append(
                Feature(
                    text: term,
                    source: .episodeMetadata,
                    kind: term.contains(" ") ? .topicPhrase : .termOfArt,
                    confidence: term.contains(" ") ? 0.61 : 0.47
                )
            )
        }

        for chapter in episode.chapters ?? [] {
            for term in tokenizePhrases(chapter.title, maxTerms: 6) {
                features.append(
                    Feature(text: term, source: .chapter, kind: .topicPhrase, confidence: 0.72)
                )
            }
        }

        for link in episode.mediaLinks {
            features.append(
                Feature(
                    text: link.title,
                    source: .mediaLink,
                    kind: link.type == .person ? .person : .product,
                    confidence: Double(max(0.2, min(link.confidence, 0.95)))
                )
            )
        }

        if let podcast {
            for term in tokenizePhrases(podcast.title, maxTerms: 8) {
                features.append(
                    Feature(text: term, source: .podcastMetadata, kind: .organization, confidence: 0.76)
                )
            }
            for term in tokenizePhrases(podcast.author, maxTerms: 8) {
                features.append(
                    Feature(text: term, source: .podcastMetadata, kind: .person, confidence: 0.7)
                )
            }
            for category in podcast.categories {
                features.append(
                    Feature(text: category, source: .category, kind: .categoryTag, confidence: 0.78)
                )
            }
        }

        upsertFeatures(episodeID: episode.id, podcastID: episode.podcastID, features: features)
    }

    private func dedupeAndTrim(_ features: [Feature]) -> [Feature] {
        var bestByKey: [String: Feature] = [:]
        for feature in features {
            let normalized = normalizeFeatureText(feature.text)
            guard !normalized.isEmpty else { continue }
            let key = "\(feature.kind.rawValue)|\(normalized)"
            let featureWithNormalizedText = Feature(
                text: normalized,
                source: feature.source,
                kind: feature.kind,
                confidence: feature.confidence
            )
            if let existing = bestByKey[key] {
                if featureWithNormalizedText.confidence > existing.confidence {
                    bestByKey[key] = featureWithNormalizedText
                }
            } else {
                bestByKey[key] = featureWithNormalizedText
            }
        }

        return bestByKey.values
            .sorted { $0.confidence > $1.confidence }
            .prefix(Self.maxFeaturesPerEpisode)
            .map { $0 }
    }

    private func tokenizePhrases(_ text: String, maxTerms: Int) -> [String] {
        let lowered = text.lowercased().replacingOccurrences(of: "&", with: " and ")
        let cleaned = lowered.replacingOccurrences(
            of: #"[^a-z0-9\s]+"#,
            with: " ",
            options: .regularExpression
        )
        let tokens = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return [] }

        let stopWords: Set<String> = [
            "the", "and", "for", "with", "from", "this", "that", "your", "have", "will", "about",
            "into", "episode", "podcast", "show", "today", "latest", "video", "audio"
        ]
        let filtered = tokens.filter { token in
            token.count >= 3 &&
            !stopWords.contains(token) &&
            !Self.htmlArtifactTokens.contains(token)
        }
        guard !filtered.isEmpty else { return [] }

        var terms: [String] = []
        for i in filtered.indices {
            terms.append(filtered[i])
            if i + 1 < filtered.count {
                terms.append("\(filtered[i]) \(filtered[i + 1])")
            }
            if i + 2 < filtered.count {
                terms.append("\(filtered[i]) \(filtered[i + 1]) \(filtered[i + 2])")
            }
        }

        var seen = Set<String>()
        var output: [String] = []
        for term in terms {
            let normalized = normalizeFeatureText(term)
            guard normalized.count >= 3, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            output.append(normalized)
            if output.count >= maxTerms { break }
        }
        return output
    }

    private func normalizeFeatureText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9\s]+"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .filter { !Self.htmlArtifactTokens.contains(String($0)) }
            .joined(separator: " ")
    }
}
