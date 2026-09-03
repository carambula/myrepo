import Foundation

enum YouTubeAppPreference: String, CaseIterable, Identifiable {
    case defaultBrowser = "defaultBrowser"
    case youtube = "youtube"
    case vidMin = "vidMin"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultBrowser:
            return "Default Browser"
        case .youtube:
            return "YouTube"
        case .vidMin:
            return "Vid Min"
        }
    }

    func appURLs(for webURL: URL) -> [URL] {
        switch self {
        case .defaultBrowser:
            return []
        case .youtube:
            if let videoID = Self.extractVideoID(from: webURL) {
                return [
                    URL(string: "youtube://watch?v=\(videoID)"),
                    URL(string: "youtube://")
                ].compactMap { $0 }
            }
            return [URL(string: "youtube://")].compactMap { $0 }
        case .vidMin:
            if let videoID = Self.extractVideoID(from: webURL) {
                return [URL(string: "vidmin://watch?v=\(videoID)")].compactMap { $0 }
            }
            return []
        }
    }

    static func extractVideoID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtube.com") {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value
        }
        if host.contains("youtu.be") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? nil : path
        }
        return nil
    }
}
