import Foundation

enum YouTubeLinkMedia {
    static func videoID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            return sanitizedID(url.pathComponents.first(where: { $0 != "/" && !$0.isEmpty }))
        }
        guard host == "youtube.com"
            || host.hasSuffix(".youtube.com")
            || host == "youtube-nocookie.com"
            || host.hasSuffix(".youtube-nocookie.com") else {
            return nil
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let value = components.queryItems?.first(where: { $0.name == "v" })?.value {
            return sanitizedID(value)
        }

        let parts = url.pathComponents.filter { $0 != "/" }
        let markers: Set<String> = ["shorts", "embed", "live", "v", "watch"]
        if let index = parts.firstIndex(where: { markers.contains($0.lowercased()) }),
           parts.indices.contains(index + 1) {
            return sanitizedID(parts[index + 1])
        }
        return nil
    }

    static func thumbnailURL(from url: URL) -> URL? {
        guard let id = videoID(from: url) else { return nil }
        return thumbnailURL(videoID: id)
    }

    static func thumbnailURL(videoID: String) -> URL {
        URL(string: "https://img.youtube.com/vi/\(videoID)/hqdefault.jpg")!
    }

    private static func sanitizedID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...20).contains(id.count),
              id.range(of: #"^[\w-]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return id
    }
}
