import Foundation

/// Resolves a preview image URL for a web page (Open Graph / Twitter card, then favicon).
actor LinkPreviewImageResolver {
    static let shared = LinkPreviewImageResolver()

    private var cache: [String: URL] = [:]

    func imageURL(for pageURL: URL) async -> URL? {
        guard let scheme = pageURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              pageURL.host != nil else {
            return nil
        }

        let key = pageURL.absoluteString
        if let cached = cache[key] {
            return cached
        }

        let favicon = Self.faviconURL(for: pageURL)

        async let openGraph = fetchOpenGraphImageURL(from: pageURL)
        if let og = await openGraph {
            cache[key] = og
            return og
        }

        if let favicon {
            cache[key] = favicon
            return favicon
        }

        return nil
    }

    private static func faviconURL(for pageURL: URL) -> URL? {
        let domain = MediaLink.registrableDomain(from: pageURL)
        guard !domain.isEmpty else { return nil }
        var c = URLComponents(string: "https://www.google.com/s2/favicons")
        c?.queryItems = [
            URLQueryItem(name: "domain", value: domain),
            URLQueryItem(name: "sz", value: "128")
        ]
        return c?.url
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

    private static func extractSocialPreviewImage(from html: String, baseURL: URL) -> URL? {
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
                  let r = Range(match.range(at: 1), in: html) else { continue }

            let raw = String(html[r]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { continue }

            if let absolute = resolveImageURLString(raw, relativeTo: baseURL) {
                return absolute
            }
        }
        return nil
    }

    private static func resolveImageURLString(_ raw: String, relativeTo baseURL: URL) -> URL? {
        if raw.hasPrefix("//"), let scheme = baseURL.scheme {
            return URL(string: "\(scheme):\(raw)")
        }
        if let u = URL(string: raw, relativeTo: baseURL) {
            let abs = u.absoluteURL
            if abs.scheme == "http" || abs.scheme == "https" {
                return abs
            }
        }
        return nil
    }
}
