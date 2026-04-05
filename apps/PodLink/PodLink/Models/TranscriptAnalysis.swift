import Foundation

struct TranscriptInsight: Identifiable, Codable {
    let id: String
    let text: String
    let category: InsightCategory
    let url: URL?
    let count: Int

    init(text: String, category: InsightCategory, url: URL? = nil, count: Int = 1) {
        self.id       = "\(category.rawValue)-\(text)"
        self.text     = text
        self.category = category
        self.url      = url
        self.count    = count
    }

    enum InsightCategory: String, Codable, CaseIterable {
        case person  = "People"
        case company = "Companies"
        case link    = "Links"
        case video   = "Videos"
        case place   = "Places"
        case event   = "Events"

        var systemImage: String {
            switch self {
            case .person:  return "person.fill"
            case .company: return "building.2.fill"
            case .link:    return "link"
            case .video:   return "play.rectangle.fill"
            case .place:   return "mappin.fill"
            case .event:   return "calendar"
            }
        }
    }
}

/// Analysis derived from a FullTranscript: keywords, entities, and resolved speaker names.
struct TranscriptAnalysis: Codable {
    /// Top nouns sorted by frequency.
    let keywords: [String]
    /// Named entities, URLs, video references, and events extracted from the text.
    let insights: [TranscriptInsight]
    /// Maps raw speaker labels ("Speaker 1") to resolved or inferred names ("John" / "Maybe Sarah").
    let speakerNames: [String: String]
    let analyzedAt: Date

    var insightsByCategory: [TranscriptInsight.InsightCategory: [TranscriptInsight]] {
        Dictionary(grouping: insights, by: \.category)
    }
}
