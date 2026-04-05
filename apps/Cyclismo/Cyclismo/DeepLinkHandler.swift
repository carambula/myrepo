import Foundation

enum DeepLinkHandler {
    enum DeepLink: Equatable {
        case race(id: String)
    }

    static func parse(url: URL) -> DeepLink? {
        guard url.scheme?.lowercased() == "cycmin" else { return nil }
        let host = url.host()?.lowercased() ?? ""

        if host == "race" {
            if let id = url.queryValue(for: "id") {
                return .race(id: id)
            }
            if let id = url.pathComponents.dropFirst().first, !id.isEmpty {
                return .race(id: id)
            }
        }

        return nil
    }
}
