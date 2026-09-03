import Foundation

actor PodcastSearchService {
    static let shared = PodcastSearchService()

    private let baseURL = "https://itunes.apple.com"
    private let session = URLSession.shared
    private let cache = CacheService.shared

    func search(query: String, limit: Int = 25) async throws -> [Podcast] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let cacheKey = "search_\(query)_\(limit)"
        if let cached: [Podcast] = await cache.get(cacheKey, as: [Podcast].self) {
            return cached
        }

        var components = URLComponents(string: "\(baseURL)/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "media", value: "podcast"),
            URLQueryItem(name: "entity", value: "podcast"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "country", value: "US")
        ]

        guard let url = components.url else {
            throw PodcastSearchError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PodcastSearchError.serverError
        }

        let result = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)
        let podcasts = result.results.compactMap { mapToPodcast($0) }

        await cache.set(cacheKey, value: podcasts, ttl: 3600)
        return podcasts
    }

    func lookup(itunesID: String) async throws -> Podcast? {
        let cacheKey = "lookup_\(itunesID)"
        if let cached: Podcast = await cache.get(cacheKey, as: Podcast.self) {
            return cached
        }

        var components = URLComponents(string: "\(baseURL)/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: itunesID),
            URLQueryItem(name: "entity", value: "podcast")
        ]

        guard let url = components.url else { return nil }

        let (data, _) = try await session.data(from: url)
        let result = try JSONDecoder().decode(ITunesSearchResponse.self, from: data)

        guard let first = result.results.first else { return nil }
        let podcast = mapToPodcast(first)

        if let podcast {
            await cache.set(cacheKey, value: podcast, ttl: 86400)
        }
        return podcast
    }

    func topPodcasts(genre: String? = nil, limit: Int = 50) async throws -> [Podcast] {
        let cacheKey = "top_\(genre ?? "all")_\(limit)"
        if let cached: [Podcast] = await cache.get(cacheKey, as: [Podcast].self) {
            return cached
        }

        var urlString = "https://rss.applemarketingtools.com/api/v2/us/podcasts/top/\(limit)/podcasts.json"
        if let genre = genre {
            urlString += "?genre=\(genre)"
        }

        guard let url = URL(string: urlString) else {
            throw PodcastSearchError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        let result = try JSONDecoder().decode(AppleTopPodcastsResponse.self, from: data)

        var podcasts: [Podcast] = []
        for item in result.feed.results {
            if let itunesID = item.id,
               let podcast = try? await lookup(itunesID: itunesID) {
                podcasts.append(podcast)
            }
        }

        await cache.set(cacheKey, value: podcasts, ttl: 3600)
        return podcasts
    }

    private func mapToPodcast(_ result: ITunesResult) -> Podcast? {
        guard let feedURLString = result.feedUrl,
              let feedURL = URL(string: feedURLString) else { return nil }

        return Podcast(
            id: String(result.collectionId),
            title: result.collectionName,
            author: result.artistName,
            description: "",
            feedURL: feedURL,
            artworkURL: result.artworkUrl100.flatMap { URL(string: $0) },
            artworkURL600: result.artworkUrl600.flatMap { URL(string: $0) },
            categories: [result.primaryGenreName].compactMap { $0 },
            language: "en",
            isExplicit: result.collectionExplicitness == "explicit",
            websiteURL: nil,
            itunesID: String(result.collectionId)
        )
    }
}

// MARK: - iTunes API Response Models

private struct ITunesSearchResponse: Codable {
    let resultCount: Int
    let results: [ITunesResult]
}

private struct ITunesResult: Codable {
    let collectionId: Int
    let collectionName: String
    let artistName: String
    let feedUrl: String?
    let artworkUrl100: String?
    let artworkUrl600: String?
    let primaryGenreName: String?
    let trackCount: Int?
    let collectionExplicitness: String?
}

private struct AppleTopPodcastsResponse: Codable {
    let feed: AppleTopFeed
}

private struct AppleTopFeed: Codable {
    let results: [AppleTopResult]
}

private struct AppleTopResult: Codable {
    let id: String?
    let name: String?
    let artistName: String?
    let artworkUrl100: String?
}

enum PodcastSearchError: Error, LocalizedError {
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid search URL"
        case .serverError: return "Server returned an error"
        case .decodingError: return "Failed to parse search results"
        }
    }
}
