import Foundation

enum EpisodeDeepLinkMatcher {
    /// Finds the episode that best matches a cross-app title hint (WatchedIt source title or movie name).
    static func bestEpisode(in episodes: [Episode], matchingTitle rawTitle: String?) -> Episode? {
        guard let rawTitle else { return nil }
        let target = normalizedTitle(rawTitle)
        guard !target.isEmpty else { return nil }

        if let exact = episodes.first(where: { normalizedTitle($0.title) == target }) {
            return exact
        }

        let contained = episodes.filter { episode in
            let candidate = normalizedTitle(episode.title)
            guard !candidate.isEmpty else { return false }
            return candidate.contains(target) || target.contains(candidate)
        }
        if let preferred = preferredContainedMatch(contained, target: target) {
            return preferred
        }

        let targetTokens = Set(target.split(separator: " ").map(String.init))
        guard !targetTokens.isEmpty else { return nil }

        var best: (episode: Episode, score: Double)?
        for episode in episodes {
            let candidateTokens = Set(normalizedTitle(episode.title).split(separator: " ").map(String.init))
            guard !candidateTokens.isEmpty else { continue }
            let intersection = Double(targetTokens.intersection(candidateTokens).count)
            let union = Double(targetTokens.union(candidateTokens).count)
            guard union > 0 else { continue }
            let score = intersection / union
            if score > (best?.score ?? 0) {
                best = (episode, score)
            }
        }

        if let best, best.score >= 0.6 {
            return best.episode
        }
        return nil
    }

    static func episode(_ episode: Episode, matchesURL targetURL: URL) -> Bool {
        let lhs = normalizedIdentityURL(episode.audioURL)
        let rhs = normalizedIdentityURL(targetURL)
        if lhs == rhs { return true }
        if let video = episode.videoURL {
            return normalizedIdentityURL(video) == rhs
        }
        return false
    }

    static func normalizedTitle(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        var characters: [Character] = []
        var lastWasSpace = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                characters.append(Character(scalar))
                lastWasSpace = false
            } else if !lastWasSpace {
                characters.append(" ")
                lastWasSpace = true
            }
        }
        let trimmed = String(characters).trimmingCharacters(in: .whitespaces)
        return trimmed.replacingOccurrences(of: #"\s+\d{4}$"#, with: "", options: .regularExpression)
    }

    static func normalizedIdentityURL(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let normalized = components?.url?.absoluteString ?? url.absoluteString
        return normalized
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Prefer a whole-token title hit (`Rocky`) over a longer franchise sibling (`Rocky II`).
    private static func preferredContainedMatch(_ matches: [Episode], target: String) -> Episode? {
        guard !matches.isEmpty else { return nil }
        let targetTokens = target.split(separator: " ").map(String.init)
        let wholeToken = matches.filter { episode in
            let tokens = normalizedTitle(episode.title).split(separator: " ").map(String.init)
            return tokens.starts(with: targetTokens) && (
                tokens.count == targetTokens.count
                    || (tokens.count > targetTokens.count && !isLikelySequelToken(tokens[targetTokens.count]))
            )
        }
        let pool = wholeToken.isEmpty ? matches : wholeToken
        return pool.min { lhs, rhs in
            let lhsDelta = abs(normalizedTitle(lhs.title).count - target.count)
            let rhsDelta = abs(normalizedTitle(rhs.title).count - target.count)
            if lhsDelta != rhsDelta { return lhsDelta < rhsDelta }
            return normalizedTitle(lhs.title).count < normalizedTitle(rhs.title).count
        }
    }

    private static func isLikelySequelToken(_ token: String) -> Bool {
        if Int(token) != nil { return true }
        let roman = Set(["ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"])
        return roman.contains(token)
    }
}
