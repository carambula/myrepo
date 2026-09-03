import Foundation

struct MinCloudNowPlayingResponse: Decodable {
    struct Movie: Decodable {
        let tmdbId: Int
        let title: String?
        let hasIMAX: Bool?
    }

    let region: String?
    let movies: [Movie]
    let refreshedAt: String?
    let source: String?
}

struct MinCloudSessionResponse: Decodable {
    struct User: Decodable {
        let id: String
        let email: String
        let handle: String
        let displayName: String
        let isAdmin: Bool?
    }

    struct Session: Decodable {
        let token: String
        let expiresAt: String?
    }

    let user: User
    let session: Session
}

struct MinCloudMovieCatalog: Decodable {
    struct Movie: Decodable {
        struct Provider: Decodable {
            let id: String?
            let name: String?
            let logoPath: String?
            let url: String?
            let providerId: Int?
            let providerName: String?
        }

        struct SourceLink: Decodable {
            struct EpisodeStub: Decodable {
                let title: String?
                let episodeId: String?
                let description: String?
                let publishDate: String?
            }

            let identifier: String?
            let rank: Int?
            let sourceTitle: String?
            let episodeDate: String?
            let episode: EpisodeStub?

            enum CodingKeys: String, CodingKey {
                case identifier, rank, sourceTitle, episodeDate, episode
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                identifier = try container.decodeIfPresent(String.self, forKey: .identifier)
                rank = try container.decodeIfPresent(Int.self, forKey: .rank)
                sourceTitle = try container.decodeIfPresent(String.self, forKey: .sourceTitle)
                episodeDate = try? container.decodeIfPresent(String.self, forKey: .episodeDate)
                episode = try? container.decodeIfPresent(EpisodeStub.self, forKey: .episode)
            }
        }

        let id: String
        let tmdbId: Int?
        let title: String
        let year: Int?
        let posterPath: String?
        let backdropPath: String?
        let overview: String?
        let mpaaRating: String?
        let genres: [String]?
        let lastUpdated: String?
        let streamingServices: [Provider]?
        let sources: [SourceLink]?
        let physicalMedia: PhysicalMedia?
        let credits: MovieCredits?
        let trailer: MovieTrailer?
        let oscarAwards: OscarAwards?

        enum CodingKeys: String, CodingKey {
            case id, tmdbId, title, year, posterPath, backdropPath, overview, mpaaRating
            case genres, lastUpdated, streamingServices, sources, physicalMedia
            case credits, trailer, oscarAwards
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            tmdbId = Self.decodeFlexibleInt(container, forKey: .tmdbId)
            title = try container.decode(String.self, forKey: .title)
            year = Self.decodeFlexibleInt(container, forKey: .year)
            posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
            backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
            overview = try container.decodeIfPresent(String.self, forKey: .overview)
            mpaaRating = try container.decodeIfPresent(String.self, forKey: .mpaaRating)
            genres = try container.decodeIfPresent([String].self, forKey: .genres)
            lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated)
            streamingServices = try container.decodeIfPresent([Provider].self, forKey: .streamingServices)
            sources = try container.decodeIfPresent([SourceLink].self, forKey: .sources)
            physicalMedia = try? container.decodeIfPresent(PhysicalMedia.self, forKey: .physicalMedia)
            credits = try? container.decode(MovieCredits.self, forKey: .credits)
            trailer = try? container.decode(MovieTrailer.self, forKey: .trailer)
            oscarAwards = try? container.decode(OscarAwards.self, forKey: .oscarAwards)
        }

        private static func decodeFlexibleInt(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Int? {
            if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let raw = try? container.decodeIfPresent(String.self, forKey: key), let value = Int(raw) {
                return value
            }
            if let raw = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Int(raw)
            }
            return nil
        }
    }

    struct Source: Decodable {
        let identifier: String
        let name: String
        let type: String
        let url: String?
        let is_ranked: Bool?
        let enabled: Bool?
    }

    let revision: Int
    let generatedAt: String?
    let movies: [Movie]
    let sources: [Source]
    let truncated: Bool?
    let total: Int?

    init(revision: Int, generatedAt: String?, movies: [Movie], sources: [Source], truncated: Bool?, total: Int?) {
        self.revision = revision
        self.generatedAt = generatedAt
        self.movies = movies
        self.sources = sources
        self.truncated = truncated
        self.total = total
    }
}

struct MinCloudCatalogMeta: Decodable {
    let revision: Int
    let generatedAt: String?
    let movieCount: Int?
    let unmatchedCount: Int?
}

struct MinCloudMovLibraryItem: Decodable {
    let movieId: String
    let isWatched: Bool?
    let isSaved: Bool?
    let isRewatched: Bool?
    let isListened: Bool?
    let rating: Int?
    let notes: String?
    let updatedAt: String?
}

struct MinCloudPodLibraryItem: Decodable {
    let podcastId: String
    let feedUrl: String?
    let title: String?
    let artworkUrl: String?
    let isFollowed: Bool?
    let notificationsEnabled: Bool?
}

enum MinCloudError: Error {
    case invalidURL
    case httpFailure(Int)
    case decoding
    case notSignedIn
}

actor MinCloudClient {
    static let shared = MinCloudClient()

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    func isReachable() async -> Bool {
        guard let url = URL(string: "/health", relativeTo: MinCloudSettings.baseURL) else {
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func register(email: String, password: String, displayName: String?) async throws -> MinCloudSessionResponse {
        try await postSession(path: "/v1/auth/register", body: [
            "email": email,
            "password": password,
            "displayName": displayName ?? ""
        ])
    }

    func login(email: String, password: String) async throws -> MinCloudSessionResponse {
        try await postSession(path: "/v1/auth/login", body: [
            "email": email,
            "password": password
        ])
    }

    func logout() async {
        guard MinCloudSettings.token != nil else { return }
        _ = try? await request(path: "/v1/auth/logout", method: "POST", authorized: true)
        MinCloudSettings.clearSession()
    }

    func fetchNowPlaying() async throws -> MinCloudNowPlayingResponse {
        try await get(path: "/v1/mov/now-playing")
    }

    func fetchCatalogMeta() async throws -> MinCloudCatalogMeta {
        try await get(path: "/v1/mov/meta")
    }

    func fetchMovieCatalog(updatedSince: String? = nil, limit: Int = 400) async throws -> MinCloudMovieCatalog {
        var movies: [MinCloudMovieCatalog.Movie] = []
        var sources: [MinCloudMovieCatalog.Source] = []
        var revision = 0
        var generatedAt: String?
        var total: Int?
        var offset = 0
        while true {
            var items: [URLQueryItem] = [
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset))
            ]
            if let updatedSince {
                items.append(URLQueryItem(name: "updatedSince", value: updatedSince))
            }
            let page: MinCloudMovieCatalog = try await get(path: "/v1/mov/catalog", query: items)
            revision = page.revision
            generatedAt = page.generatedAt
            if let pageTotal = page.total {
                total = pageTotal
            }
            if sources.isEmpty {
                sources = page.sources
            }
            movies.append(contentsOf: page.movies)
            let hasMore: Bool
            if page.movies.isEmpty {
                hasMore = false
            } else if let total, movies.count >= total {
                hasMore = false
            } else if let total {
                hasMore = movies.count < total
            } else {
                hasMore = page.truncated == true
            }
            guard hasMore else { break }
            offset += page.movies.count
        }
        let catalogTotal = total ?? movies.count
        return MinCloudMovieCatalog(
            revision: revision,
            generatedAt: generatedAt,
            movies: movies,
            sources: sources,
            truncated: movies.count < catalogTotal,
            total: catalogTotal
        )
    }

    func fetchMovieLibrary() async throws -> [MinCloudMovLibraryItem] {
        let payload: LibraryResponse<MinCloudMovLibraryItem> = try await get(
            path: "/v1/me/library/mov",
            authorized: true
        )
        return payload.items
    }

    func registerDevice(pushToken: String? = MinCloudSettings.pushToken, timezone: String = TimeZone.current.identifier) async {
        var body: [String: Any] = [
            "deviceId": MinCloudSettings.deviceId,
            "app": "watchedit",
            "platform": "ios",
            "timezone": timezone
        ]
        if let pushToken {
            body["pushToken"] = pushToken
        }
        _ = try? await request(
            path: "/v1/devices/register",
            method: "POST",
            authorized: MinCloudSettings.isSignedIn,
            body: body
        )
        if MinCloudSettings.isSignedIn {
            _ = try? await request(
                path: "/v1/me/devices",
                method: "PUT",
                authorized: true,
                body: body
            )
        }
    }

    private struct LibraryResponse<Item: Decodable>: Decodable {
        let items: [Item]
    }

    func saveNotificationPreferences(_ preferences: [String: Any]) async throws {
        _ = try await request(
            path: "/v1/me/notifications",
            method: "PUT",
            authorized: true,
            body: [
                "app": "watchedit",
                "preferences": preferences
            ]
        )
    }

    func pushLibrary(items: [[String: Any]]) async throws {
        _ = try await request(
            path: "/v1/me/library/mov",
            method: "PUT",
            authorized: true,
            body: ["items": items]
        )
    }

    private func postSession(path: String, body: [String: Any]) async throws -> MinCloudSessionResponse {
        let data = try await request(path: path, method: "POST", authorized: false, body: body)
        let decoded = try JSONDecoder().decode(MinCloudSessionResponse.self, from: data)
        MinCloudSettings.storeSession(token: decoded.session.token, handle: decoded.user.handle, email: decoded.user.email)
        return decoded
    }

    private func get<T: Decodable>(path: String, query: [URLQueryItem] = [], authorized: Bool = false) async throws -> T {
        let data = try await request(path: path, method: "GET", authorized: authorized, query: query)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MinCloudError.decoding
        }
    }

    private func request(
        path: String,
        method: String,
        authorized: Bool,
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard var components = URLComponents(url: URL(string: path, relativeTo: MinCloudSettings.baseURL) ?? MinCloudSettings.baseURL, resolvingAgainstBaseURL: true) else {
            throw MinCloudError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw MinCloudError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if authorized {
            guard let token = MinCloudSettings.token else {
                throw MinCloudError.notSignedIn
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            throw MinCloudError.httpFailure(status)
        }
        return data
    }
}
