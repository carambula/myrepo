import Foundation

enum DeepLinkHandler {
    static func videoID(from url: URL) -> String? {
        if let id = videoIDFromCustomScheme(url) {
            return id
        }
        return videoIDFromYouTubeURL(url)
    }

    private static func videoIDFromCustomScheme(_ url: URL) -> String? {
        guard url.scheme?.lowercased() == "vidmin" else { return nil }
        let host = url.host()?.lowercased() ?? ""

        if host == "watch" {
            return url.queryValue(for: "v")
        }

        if host == "video" {
            let id = url.pathComponents.dropFirst().first
            return id?.isEmpty == false ? id : nil
        }

        if host == "open",
           let encoded = url.queryValue(for: "url"),
           let innerURL = URL(string: encoded) {
            return videoIDFromYouTubeURL(innerURL)
        }

        if !host.isEmpty, host.count == 11, host.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            return host
        }

        return nil
    }

    static func videoIDFromYouTubeURL(_ url: URL) -> String? {
        let host = url.host()?.lowercased() ?? ""

        let youtubeHosts = ["youtube.com", "www.youtube.com", "m.youtube.com",
                            "music.youtube.com", "youtube-nocookie.com", "www.youtube-nocookie.com"]

        if youtubeHosts.contains(host) {
            let path = url.path()

            if path.hasPrefix("/watch") {
                return url.queryValue(for: "v")
            }

            for prefix in ["/shorts/", "/embed/", "/live/", "/v/"] {
                if path.hasPrefix(prefix) {
                    let id = String(path.dropFirst(prefix.count)).components(separatedBy: "/").first
                    return id?.isEmpty == false ? id : nil
                }
            }
        }

        if host == "youtu.be" {
            let id = url.pathComponents.dropFirst().first
            return id?.isEmpty == false ? id : nil
        }

        return nil
    }
}
