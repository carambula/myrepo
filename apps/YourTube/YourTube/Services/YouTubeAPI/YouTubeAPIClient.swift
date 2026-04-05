import Foundation

struct YouTubeAPIClient {
    enum APIError: LocalizedError {
        case invalidURL
        case requestFailed(statusCode: Int, message: String?, reason: String?)
        case decodingFailed
        case missingVideoID

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid YouTube API URL."
            case .requestFailed(let statusCode, let message, let reason):
                if statusCode == 403 {
                    return Self.forbiddenMessage(reason: reason, fallbackMessage: message)
                }
                if let message, !message.isEmpty {
                    return "YouTube API request failed (\(statusCode)): \(message)"
                }
                return "YouTube API request failed (\(statusCode))."
            case .decodingFailed: return "Could not decode YouTube API response."
            case .missingVideoID: return "Video data is missing an ID."
            }
        }

        private static func forbiddenMessage(reason: String?, fallbackMessage: String?) -> String {
            switch reason {
            case "youtubeSignupRequired":
                return "This Google account does not have a YouTube channel yet. Open YouTube once, create your channel, then try again."
            case "insufficientPermissions", "forbidden":
                return "Google sign-in succeeded, but this token cannot read subscriptions. Please disconnect and sign in again to grant YouTube access."
            case "accessNotConfigured", "serviceDisabled":
                return "YouTube Data API is not enabled for this Google Cloud project. Enable YouTube Data API v3, then try again."
            case "quotaExceeded", "dailyLimitExceeded", "dailyLimitExceededUnreg":
                return "The YouTube API quota has been exceeded for now. Please try again later."
            default:
                if let fallbackMessage, !fallbackMessage.isEmpty {
                    return "YouTube denied this request (403): \(fallbackMessage)"
                }
                return "YouTube denied this request (403)."
            }
        }
    }

    private let session: URLSession = .shared
    private let dateFormatter = ISO8601DateFormatter()

    func fetchSubscribedChannels(accessToken: String) async throws -> [YTChannel] {
        var allChannels: [YTChannel] = []
        var pageToken: String?

        repeat {
            var queryItems = [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "mine", value: "true"),
                URLQueryItem(name: "maxResults", value: "50"),
            ]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }

            let response: SubscriptionsResponse = try await request(
                path: "/youtube/v3/subscriptions",
                queryItems: queryItems,
                accessToken: accessToken
            )

            let channels = response.items.map { item in
                let snippet = item.snippet
                return YTChannel(
                    channelID: snippet.resourceId.channelId,
                    title: snippet.title.decodedHTMLEntities,
                    summary: snippet.description.decodedHTMLEntities,
                    thumbnailURL: snippet.thumbnails.high?.url ?? snippet.thumbnails.defaultValue?.url ?? "",
                    uploadsPlaylistID: "",
                    isUserSubscribed: true
                )
            }
            allChannels.append(contentsOf: channels)
            pageToken = response.nextPageToken
        } while pageToken != nil

        return allChannels
    }

    func fetchLatestVideos(
        accessToken: String,
        channelID: String,
        maxResults: Int = 12
    ) async throws -> [YTVideo] {
        let uploadsPlaylistID = "UU" + channelID.dropFirst(2)

        let response: PlaylistItemsResponse = try await request(
            path: "/youtube/v3/playlistItems",
            queryItems: [
                URLQueryItem(name: "part", value: "snippet,contentDetails"),
                URLQueryItem(name: "playlistId", value: uploadsPlaylistID),
                URLQueryItem(name: "maxResults", value: String(maxResults)),
            ],
            accessToken: accessToken
        )

        return response.items.map { item in
            let videoID = item.contentDetails.videoId
            let snippet = item.snippet
            let publishedAt = item.contentDetails.videoPublishedAt ?? snippet.publishedAt
            return YTVideo(
                videoID: videoID,
                channelID: channelID,
                title: snippet.title.decodedHTMLEntities,
                summary: snippet.description.decodedHTMLEntities,
                thumbnailURL: snippet.thumbnails.high?.url ?? snippet.thumbnails.medium?.url ?? "",
                publishedAt: dateFormatter.date(from: publishedAt) ?? .now
            )
        }
    }

    func searchChannels(accessToken: String, query: String) async throws -> [YTChannel] {
        let response: SearchResponse = try await request(
            path: "/youtube/v3/search",
            queryItems: [
                URLQueryItem(name: "part", value: "snippet"),
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "channel"),
                URLQueryItem(name: "maxResults", value: "25"),
            ],
            accessToken: accessToken
        )

        return response.items.compactMap { item in
            guard let channelID = item.id.channelId else { return nil }
            let snippet = item.snippet
            return YTChannel(
                channelID: channelID,
                title: snippet.title.decodedHTMLEntities,
                summary: snippet.description.decodedHTMLEntities,
                thumbnailURL: snippet.thumbnails.high?.url ?? snippet.thumbnails.defaultValue?.url ?? "",
                uploadsPlaylistID: "",
                isUserSubscribed: false
            )
        }
    }

    private func fetchVideoDetails(accessToken: String, videoIDs: [String]) async throws -> [String: VideoDetailsResponse.Item] {
        guard !videoIDs.isEmpty else { return [:] }
        let response: VideoDetailsResponse = try await request(
            path: "/youtube/v3/videos",
            queryItems: [
                URLQueryItem(name: "part", value: "contentDetails"),
                URLQueryItem(name: "id", value: videoIDs.joined(separator: ",")),
                URLQueryItem(name: "maxResults", value: "50"),
            ],
            accessToken: accessToken
        )

        return Dictionary(uniqueKeysWithValues: response.items.map { ($0.id, $0) })
    }

    private func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        accessToken: String
    ) async throws -> Response {
        var components = URLComponents(string: "https://www.googleapis.com\(path)")
        components?.queryItems = queryItems
        guard let url = components?.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            throw APIError.requestFailed(statusCode: -1, message: nil, reason: nil)
        }
        guard 200..<300 ~= statusCode else {
            let googleError = try? JSONDecoder().decode(GoogleErrorResponse.self, from: data)
            throw APIError.requestFailed(
                statusCode: statusCode,
                message: googleError?.error.message,
                reason: googleError?.error.errors.first?.reason
            )
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }
}

private struct GoogleErrorResponse: Decodable {
    struct ErrorPayload: Decodable {
        struct ErrorDetail: Decodable {
            let reason: String?
            let message: String?
        }
        let code: Int?
        let message: String?
        let errors: [ErrorDetail]
    }
    let error: ErrorPayload
}

private struct SubscriptionsResponse: Decodable {
    struct Item: Decodable {
        struct Snippet: Decodable {
            struct ResourceID: Decodable {
                let channelId: String
            }
            struct ThumbnailContainer: Decodable {
                struct Thumbnail: Decodable { let url: String }
                let `default`: Thumbnail?
                let high: Thumbnail?
                var defaultValue: Thumbnail? { `default` }
            }
            let title: String
            let description: String
            let resourceId: ResourceID
            let thumbnails: ThumbnailContainer
        }
        let snippet: Snippet
    }
    let items: [Item]
    let nextPageToken: String?
}

private struct SearchResponse: Decodable {
    struct Item: Decodable {
        struct ID: Decodable {
            let videoId: String?
            let channelId: String?
        }
        struct Snippet: Decodable {
            struct ThumbnailContainer: Decodable {
                struct Thumbnail: Decodable { let url: String }
                let medium: Thumbnail?
                let high: Thumbnail?
                let `default`: Thumbnail?
                var defaultValue: Thumbnail? { `default` }
            }
            let title: String
            let description: String
            let channelId: String
            let publishedAt: String
            let thumbnails: ThumbnailContainer
        }
        let id: ID
        let snippet: Snippet
    }
    let items: [Item]
}

private struct PlaylistItemsResponse: Decodable {
    struct Item: Decodable {
        struct Snippet: Decodable {
            struct ThumbnailContainer: Decodable {
                struct Thumbnail: Decodable { let url: String }
                let medium: Thumbnail?
                let high: Thumbnail?
                let `default`: Thumbnail?
                var defaultValue: Thumbnail? { `default` }
            }
            let title: String
            let description: String
            let publishedAt: String
            let thumbnails: ThumbnailContainer
        }
        struct ContentDetails: Decodable {
            let videoId: String
            let videoPublishedAt: String?
        }
        let snippet: Snippet
        let contentDetails: ContentDetails
    }
    let items: [Item]
}

private struct VideoDetailsResponse: Decodable {
    struct Item: Decodable {
        struct ContentDetails: Decodable {
            let duration: String
        }
        let id: String
        let contentDetails: ContentDetails
    }
    let items: [Item]
}
