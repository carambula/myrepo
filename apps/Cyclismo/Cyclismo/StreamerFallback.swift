import Foundation

enum StreamerFallback {
    private struct Rule {
        let pattern: String
        let slug: String
    }

    /// Hyphens/dashes → spaces, strip accents and year tokens so PCS-style titles match rules written with spaces.
    nonisolated private static func normalizeRaceNameForFallback(_ raw: String) -> String {
        let folded = raw.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        let apostrophes = folded
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        let lower = apostrophes.lowercased()
        let dashesAsSpaces = lower
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "\u{2013}", with: " ")
            .replacingOccurrences(of: "\u{2014}", with: " ")
        let noYears = dashesAsSpaces.replacingOccurrences(of: #"\d{4}"#, with: "", options: .regularExpression)
        let collapsed = noYears.replacingOccurrences(of: #" + "#, with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Patterns use spaces (not hyphens); `normalizeRaceNameForFallback` is applied before matching.
    nonisolated private static let rules: [Rule] = [
        Rule(pattern: "tour de france", slug: "peacock"),
        Rule(pattern: "vuelta a espana|vuelta espana", slug: "peacock"),
        Rule(
            pattern: "paris nice|criterium du dauphine|dauphine|paris roubaix|volta\\s+ciclista\\s+a\\s+catalunya|volta\\s+a\\s+catalunya|volta catalunya",
            slug: "peacock"
        ),
        Rule(
            pattern: "giro d'italia|milano san ?remo|milan san ?remo|sanremo donne|strade bianche|tirreno adriatico|uae tour|trofeo alfredo binda|nokere koerse|milano torino|e3 saxo|bredene koksijde|grand prix de denain|itzulia|basque country|ronde van brugge",
            slug: "max"
        ),
        Rule(pattern: "world championships|uci road world", slug: "flobikes"),
        Rule(
            pattern: "omloop\\s*(het\\s*)?nieuwsblad|tour of flanders|ronde van vlaanderen|amstel gold|gent wevelgem|in flanders fields|wevelgem|dwars door vlaanderen|scheldeprijs|brabantse pijl|kuurne brussel|brussels cycling classic|deutschland tour|tour of turkey|clasica san sebastian|bretagne classic|gp de plouay|gp industria|coppa sabatini|giro della toscana|fourmies|super 8|kampioenschap van vlaanderen|wallonie|tour de luxembourg|chrono gatineau|fleche wallonne|liege bastogne liege|tour de romandie",
            slug: "flobikes"
        )
    ]

    nonisolated static func inferredSlugs(for raceName: String) -> [String] {
        let normalized = normalizeRaceNameForFallback(raceName)
        guard !normalized.isEmpty else { return [] }
        var slugs: [String] = []
        for rule in rules {
            if normalized.range(of: rule.pattern, options: .regularExpression) != nil {
                if !slugs.contains(rule.slug) {
                    slugs.append(rule.slug)
                }
            }
        }
        return slugs
    }

    nonisolated static func inferredDisplayNames(for raceName: String) -> [String] {
        inferredSlugs(for: raceName).map(displayName(for:))
    }

    nonisolated static func displayName(for slug: String) -> String {
        switch slug.lowercased() {
        case "flobikes":
            return "FloBikes"
        case "peacock":
            return "Peacock"
        case "max":
            return "Max"
        default:
            return slug
        }
    }

    nonisolated static func defaultRegions(for slug: String) -> [String] {
        switch slug.lowercased() {
        case "flobikes":
            return ["US", "CA"]
        case "peacock", "max":
            return ["US"]
        default:
            return []
        }
    }
}
