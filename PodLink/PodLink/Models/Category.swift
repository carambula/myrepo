import Foundation

enum PodcastCategory: String, Codable, CaseIterable, Identifiable {
    case arts = "Arts"
    case business = "Business"
    case comedy = "Comedy"
    case education = "Education"
    case fiction = "Fiction"
    case government = "Government"
    case health = "Health & Fitness"
    case history = "History"
    case kidsFamily = "Kids & Family"
    case leisure = "Leisure"
    case music = "Music"
    case news = "News"
    case religionSpirituality = "Religion & Spirituality"
    case science = "Science"
    case societyCulture = "Society & Culture"
    case sports = "Sports"
    case technology = "Technology"
    case trueCrime = "True Crime"
    case tvFilm = "TV & Film"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .arts: return "paintpalette"
        case .business: return "briefcase"
        case .comedy: return "face.smiling"
        case .education: return "graduationcap"
        case .fiction: return "book.closed"
        case .government: return "building.columns"
        case .health: return "heart"
        case .history: return "clock.arrow.circlepath"
        case .kidsFamily: return "figure.and.child.holdinghands"
        case .leisure: return "gamecontroller"
        case .music: return "music.note"
        case .news: return "newspaper"
        case .religionSpirituality: return "sparkles"
        case .science: return "atom"
        case .societyCulture: return "globe"
        case .sports: return "sportscourt"
        case .technology: return "cpu"
        case .trueCrime: return "magnifyingglass"
        case .tvFilm: return "film"
        }
    }
}
