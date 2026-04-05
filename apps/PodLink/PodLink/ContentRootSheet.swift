import Foundation

/// Root-level sheet identity (podcast, search, account). Now playing uses a separate stacked sheet so it does not replace these.
enum ContentRootSheet: Identifiable, Equatable {
    case podcast(Podcast)
    case account
    case search
    case offline

    var id: String {
        switch self {
        case .podcast(let p): return "podcast-\(p.id)"
        case .account: return "account"
        case .search: return "search"
        case .offline: return "offline"
        }
    }
}
