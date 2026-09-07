import Foundation

struct LinkCardPreview: Sendable, Equatable {
    var photographURL: URL?
    var badgeURL: URL?
    var brand: LinkServiceBrand?

    static func empty(brand: LinkServiceBrand?, badgeURL: URL?) -> LinkCardPreview {
        LinkCardPreview(photographURL: nil, badgeURL: badgeURL, brand: brand)
    }
}

/// Resolves a preview photograph for a web page, plus a small service badge.
/// Favicons are never used as the full-bleed image.
actor LinkPreviewImageResolver {
    static let shared = LinkPreviewImageResolver()

    private var cache: [String: LinkCardPreview] = [:]

    func preview(for pageURL: URL) async -> LinkCardPreview {
        guard let scheme = pageURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              pageURL.host != nil else {
            return .empty(brand: nil, badgeURL: nil)
        }

        let key = pageURL.absoluteString
        if let cached = cache[key] {
            return cached
        }

        let brand = LinkServiceBrand.matching(pageURL)
        let badge = Self.faviconURL(for: pageURL)
        let resolved: LinkCardPreview

        if Self.usesBrandTileOnly(brand) {
            resolved = .empty(brand: brand, badgeURL: badge)
        } else if let youtubeThumb = YouTubeLinkMedia.thumbnailURL(from: pageURL) {
            resolved = LinkCardPreview(photographURL: youtubeThumb, badgeURL: badge, brand: brand ?? .youtube)
        } else {
            async let oembed = fetchOEmbedThumbnail(from: pageURL, brand: brand)
            async let openGraph = fetchOpenGraphImageURL(from: pageURL)
            if let photo = await oembed {
                resolved = LinkCardPreview(photographURL: photo, badgeURL: badge, brand: brand)
            } else if let photo = Self.photograph(from: await openGraph) {
                resolved = LinkCardPreview(photographURL: photo, badgeURL: badge, brand: brand)
            } else {
                resolved = .empty(brand: brand, badgeURL: badge)
            }
        }

        cache[key] = resolved
        return resolved
    }

    /// Instagram preview images are usually the app glyph or a blocked asset.
    /// Use the brand tile only — one icon on one surface, like TikTok.
    static func usesBrandTileOnly(_ brand: LinkServiceBrand?) -> Bool {
        brand == .instagram
    }

    static func looksLikeIconURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        if host.contains("google.com"), path.contains("favicon") {
            return true
        }
        if host.contains("gstatic.com"), path.contains("favicon") {
            return true
        }
        if path.hasSuffix(".ico") { return true }
        if path.contains("favicon") { return true }
        if path.contains("apple-touch-icon") { return true }
        return false
    }

    static func faviconURL(for pageURL: URL) -> URL? {
        let domain = MediaLink.registrableDomain(from: pageURL)
        guard !domain.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.google.com/s2/favicons")
        components?.queryItems = [
            URLQueryItem(name: "domain", value: domain),
            URLQueryItem(name: "sz", value: "64")
        ]
        return components?.url
    }

    static func photograph(from url: URL?) -> URL? {
        guard let url, !looksLikeIconURL(url) else { return nil }
        return url
    }

    static func oembedThumbnail(from data: Data) -> URL? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let raw = (object["thumbnail_url"] as? String) ?? (object["thumbnailUrl"] as? String)
        guard let raw, let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else {
            return nil
        }
        return photograph(from: url)
    }

    private func fetchOEmbedThumbnail(from pageURL: URL, brand: LinkServiceBrand?) async -> URL? {
        guard let endpoint = brand?.oembedURL(for: pageURL) else { return nil }
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 6
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return Self.oembedThumbnail(from: data)
        } catch {
            return nil
        }
    }

    private func fetchOpenGraphImageURL(from pageURL: URL) async -> URL? {
        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            let slice = data.prefix(256_000)
            let html =
                String(data: slice, encoding: .utf8)
                ?? String(data: slice, encoding: .isoLatin1)
            guard let html else { return nil }
            return Self.extractSocialPreviewImage(from: html, baseURL: pageURL)
        } catch {
            return nil
        }
    }

    static func extractSocialPreviewImage(from html: String, baseURL: URL) -> URL? {
        let patterns = [
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#,
            #"<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["']"#,
            #"<meta[^>]+name=["']twitter:image:src["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image:src["']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, range: range),
                  let captured = Range(match.range(at: 1), in: html) else { continue }

            let raw = String(html[captured]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }

            if let absolute = resolveImageURLString(raw, relativeTo: baseURL) {
                return photograph(from: absolute)
            }
        }
        return nil
    }

    private static func resolveImageURLString(_ raw: String, relativeTo baseURL: URL) -> URL? {
        if raw.hasPrefix("//"), let scheme = baseURL.scheme {
            return URL(string: "\(scheme):\(raw)")
        }
        if let parsed = URL(string: raw, relativeTo: baseURL) {
            let absolute = parsed.absoluteURL
            if absolute.scheme == "http" || absolute.scheme == "https" {
                return absolute
            }
        }
        return nil
    }
}
