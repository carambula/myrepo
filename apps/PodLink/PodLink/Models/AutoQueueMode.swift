import Foundation

enum AutoQueueMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case newestFirst
    case gridOrder
    case podLinkRecommendation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newestFirst:
            return "Newest First"
        case .gridOrder:
            return "Grid Order"
        case .podLinkRecommendation:
            return "PodLink Recommendation"
        }
    }

    var description: String {
        switch self {
        case .newestFirst:
            return "One latest unfinished episode per show, newest publish date first."
        case .gridOrder:
            return "One latest unfinished episode per show, matching your home grid order."
        case .podLinkRecommendation:
            return "Ranks unfinished episodes by estimated likelihood you will finish."
        }
    }
}
