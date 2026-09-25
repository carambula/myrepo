import Foundation

struct PodLinkEpisodeHint: Equatable {
    let episodeURL: URL?
    let episodeTitle: String?
    let movieTitle: String?

    init(episodeURL: URL? = nil, episodeTitle: String? = nil, movieTitle: String? = nil) {
        self.episodeURL = episodeURL
        self.episodeTitle = episodeTitle
        self.movieTitle = movieTitle
    }

    var titleCandidates: [String] {
        [episodeTitle, movieTitle].compactMap { title in
            let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

enum PodLinkDeepLink {
    case show(feedURL: URL)
    case episode(feedURL: URL, hint: PodLinkEpisodeHint)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "podmin" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        let host = (url.host ?? "").lowercased()

        func cleaned(_ raw: String?) -> String? {
            guard let raw else { return nil }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        func firstQueryValue(_ keys: [String]) -> String? {
            for key in keys {
                if let value = cleaned(url.queryValue(for: key)) {
                    return value
                }
            }
            return nil
        }

        func firstPathComponentValue() -> String? {
            let parts = components.path
                .split(separator: "/")
                .map { String($0).removingPercentEncoding ?? String($0) }
                .filter { !$0.isEmpty }
            let routeWords: Set<String> = ["open", "show", "episode", "x-callback-url"]
            let payload = parts.first { !routeWords.contains($0.lowercased()) }
            return cleaned(payload)
        }

        let feedRaw = firstQueryValue(["feed", "feedurl", "feed_url", "podcast", "podcasturl", "podcast_url", "rss", "url"])
            ?? firstPathComponentValue()

        guard let feedRaw,
              let feedURL = URL(string: feedRaw) else {
            return nil
        }

        let episodeRaw = firstQueryValue(["episode", "episodeurl", "episode_url", "ep", "audio", "media"])
        let episodeURL = episodeRaw.flatMap(URL.init(string:))
        let episodeTitle = firstQueryValue(["title", "episodetitle", "episode_title"])
        let movieTitle = firstQueryValue(["movie", "movietitle", "movie_title"])

        switch host {
        case "episode":
            self = .episode(
                feedURL: feedURL,
                hint: PodLinkEpisodeHint(episodeURL: episodeURL, episodeTitle: episodeTitle, movieTitle: movieTitle)
            )
        case "show":
            self = .show(feedURL: feedURL)
        case "open":
            if episodeURL != nil || episodeTitle != nil || movieTitle != nil {
                self = .episode(
                    feedURL: feedURL,
                    hint: PodLinkEpisodeHint(episodeURL: episodeURL, episodeTitle: episodeTitle, movieTitle: movieTitle)
                )
            } else {
                self = .show(feedURL: feedURL)
            }
        default:
            if episodeURL != nil || episodeTitle != nil || movieTitle != nil {
                self = .episode(
                    feedURL: feedURL,
                    hint: PodLinkEpisodeHint(episodeURL: episodeURL, episodeTitle: episodeTitle, movieTitle: movieTitle)
                )
            } else {
                self = .show(feedURL: feedURL)
            }
        }
    }
}
