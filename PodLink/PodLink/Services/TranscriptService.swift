import Foundation

actor TranscriptService {
    static let shared = TranscriptService()

    private let cache = CacheService.shared
    private let session = URLSession.shared

    func getTranscript(for episode: Episode) async -> String? {
        let cacheKey = "transcript_\(episode.id)"
        if let cached: String = await cache.get(cacheKey, as: String.self) {
            return cached
        }

        // Source 1: <podcast:transcript> tag URL
        if let transcriptURL = episode.transcriptURL {
            if let transcript = await fetchTranscriptFromURL(transcriptURL) {
                await cache.set(cacheKey, value: transcript, ttl: 86400 * 30)
                return transcript
            }
        }

        // Source 2: YouTube auto-captions (if video URL is YouTube)
        if let videoURL = episode.videoURL,
           let videoID = extractYouTubeVideoID(from: videoURL) {
            if let transcript = await fetchYouTubeCaptions(videoID: videoID) {
                await cache.set(cacheKey, value: transcript, ttl: 86400 * 30)
                return transcript
            }
        }

        return nil
    }

    private func fetchTranscriptFromURL(_ url: URL) async -> String? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let contentType = httpResponse.mimeType ?? ""

            if contentType.contains("srt") || url.pathExtension == "srt" {
                return parseSRT(data)
            } else if contentType.contains("vtt") || url.pathExtension == "vtt" {
                return parseVTT(data)
            } else if contentType.contains("json") {
                return parseJSONTranscript(data)
            } else {
                return String(data: data, encoding: .utf8)
            }
        } catch {
            return nil
        }
    }

    private func parseSRT(_ data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        var transcript: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if Int(trimmed) != nil { continue }
            if trimmed.contains("-->") { continue }
            transcript.append(trimmed)
        }

        return transcript.joined(separator: " ")
    }

    private func parseVTT(_ data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        var transcript: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed == "WEBVTT" { continue }
            if trimmed.hasPrefix("NOTE") { continue }
            if trimmed.contains("-->") { continue }
            if trimmed.hasPrefix("Kind:") || trimmed.hasPrefix("Language:") { continue }
            transcript.append(trimmed)
        }

        return transcript.joined(separator: " ")
    }

    private func parseJSONTranscript(_ data: Data) -> String? {
        struct TranscriptSegment: Codable {
            let text: String?
            let body: String?
        }

        if let segments = try? JSONDecoder().decode([TranscriptSegment].self, from: data) {
            return segments.compactMap { $0.text ?? $0.body }.joined(separator: " ")
        }
        return nil
    }

    private func fetchYouTubeCaptions(videoID: String) async -> String? {
        let captionsURL = "https://www.youtube.com/api/timedtext?v=\(videoID)&lang=en&fmt=vtt"
        guard let url = URL(string: captionsURL) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            return parseVTT(data)
        } catch {
            return nil
        }
    }

    private func extractYouTubeVideoID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        if host.contains("youtube.com") {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value
        } else if host.contains("youtu.be") {
            return url.lastPathComponent
        }
        return nil
    }
}
