import Foundation

enum DeepLinkHandler {
    enum DeepLink: Equatable {
        case movie(tmdbID: Int)
    }

    static func parse(url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == "movmin" else { return nil }
        let host = url.host()?.lowercased() ?? ""

        if host == "movie" {
            if let idString = url.queryValue(for: "id"), let id = Int(idString) {
                return .movie(tmdbID: id)
            }
            if let idString = url.pathComponents.dropFirst().first, let id = Int(idString) {
                return .movie(tmdbID: id)
            }
        }

        return nil
    }
}
