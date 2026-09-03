import Foundation
import UIKit

struct TranscriptMetadata: Codable {
    let source: TranscriptSource
    let format: TranscriptFormat
    let fetchedAt: Date
    let hasSpeakerLabels: Bool
    let hasTimestamps: Bool
    let wordCount: Int

    enum TranscriptSource: String, Codable {
        case rssTag = "podcast:transcript"
        case showNotesLink = "Show notes link"
        case youtube = "YouTube Captions"
        case manual = "User Uploaded"
        case onDevice = "On-device"
        case generated = "Cloud transcription"
    }

    enum TranscriptFormat: String, Codable {
        case srt = "SRT"
        case vtt = "VTT"
        case json = "JSON"
        case html = "HTML"
        case plainText = "Plain Text"
    }
}

struct TranscriptSegment: Codable {
    let text: String
    let startTime: TimeInterval?
    let endTime: TimeInterval?
    let speaker: String?
}

struct FullTranscript: Codable {
    let text: String
    let segments: [TranscriptSegment]?
    let metadata: TranscriptMetadata
}

enum TranscriptImportError: LocalizedError {
    case unrecognizedFormat

    var errorDescription: String? {
        switch self {
        case .unrecognizedFormat:
            return "Could not read that file as SRT, VTT, JSON, or plain text."
        }
    }
}

actor TranscriptService {
    static let shared = TranscriptService()

    private let cache = CacheService.shared
    private let session = URLSession.shared

    func getTranscript(for episode: Episode) async -> String? {
        let fullTranscript = await getFullTranscript(for: episode)
        return fullTranscript?.text
    }

    func getFullTranscript(for episode: Episode) async -> FullTranscript? {
        if let cached: FullTranscript = await cache.get("transcript_full_\(episode.id)", as: FullTranscript.self) {
            InterestKeywordService.shared.indexTranscriptKeywords(for: episode.id, transcriptText: cached.text)
            return cached
        }

        if let transcriptURL = episode.transcriptURL {
            if let fullTranscript = await fetchTranscriptFromURL(transcriptURL, transcriptSource: .rssTag) {
                return await cacheAndIndex(fullTranscript, for: episode.id, ttl: 86400 * 30)
            }
        }

        if let videoURL = episode.videoURL,
           let videoID = extractYouTubeVideoID(from: videoURL) {
            if let fullTranscript = await fetchYouTubeCaptions(videoID: videoID) {
                return await cacheAndIndex(fullTranscript, for: episode.id, ttl: 86400 * 30)
            }
        }

        let showNoteURLs = TranscriptURLDiscovery.candidateTranscriptURLs(
            in: episode.description,
            excluding: episode.transcriptURL
        )
        for url in showNoteURLs {
            if let fullTranscript = await fetchTranscriptFromURL(url, transcriptSource: .showNotesLink) {
                return await cacheAndIndex(fullTranscript, for: episode.id, ttl: 86400 * 30)
            }
        }

        return nil
    }

    /// Parses an imported file and stores it as this episode’s transcript (long-lived cache).
    func importTranscript(data: Data, filename: String?, episode: Episode) async throws -> FullTranscript {
        let hint = filename.map { URL(fileURLWithPath: $0) }
        guard let full = makeFullTranscript(
            data: data,
            responseURL: hint,
            contentType: nil,
            transcriptSource: .manual
        ), !full.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptImportError.unrecognizedFormat
        }
        return await cacheAndIndex(full, for: episode.id, ttl: 86400 * 365)
    }

    /// Sends the episode enclosure URL to AssemblyAI (their servers fetch the audio). Requires API key in Keychain.
    func requestAssemblyAITranscript(for episode: Episode) async throws -> FullTranscript {
        guard let key = TranscriptionAPIKeyStore.loadAPIKey() else {
            throw AssemblyAITranscriptionClient.ClientError.missingAPIKey
        }
        let client = AssemblyAITranscriptionClient()
        let full = try await client.transcribe(audioURL: episode.audioURL, apiKey: key)
        let cached = await cacheAndIndex(full, for: episode.id, ttl: 86400 * 365)
        Task { await TranscriptAnalysisService.shared.analyze(cached, episodeID: episode.id) }
        return cached
    }

    /// Transcribes a downloaded episode using iOS on-device speech recognition (free, no API key).
    func requestOnDeviceTranscript(
        for episode: Episode,
        onProgress: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws -> FullTranscript {
        let full = try await OnDeviceTranscriptionService.shared.transcribe(
            episode: episode,
            onProgress: onProgress
        )
        let cached = await cacheAndIndex(full, for: episode.id, ttl: 86400 * 365)
        Task { await TranscriptAnalysisService.shared.analyze(cached, episodeID: episode.id) }
        return cached
    }

    func getCachedFullTranscript(forEpisodeID episodeID: String) async -> FullTranscript? {
        await cache.get("transcript_full_\(episodeID)", as: FullTranscript.self)
    }

    func getCachedTranscriptText(forEpisodeID episodeID: String) async -> String? {
        await getCachedFullTranscript(forEpisodeID: episodeID)?.text
    }

    /// Removes the cached transcript for an episode so the next call to `getFullTranscript` re-fetches.
    func clearTranscriptCache(for episode: Episode) async {
        await cache.remove("transcript_full_\(episode.id)")
    }

    private func cacheAndIndex(_ fullTranscript: FullTranscript, for episodeID: String, ttl: TimeInterval) async -> FullTranscript {
        let cacheKey = "transcript_full_\(episodeID)"
        await cache.set(cacheKey, value: fullTranscript, ttl: ttl)
        InterestKeywordService.shared.indexTranscriptKeywords(for: episodeID, transcriptText: fullTranscript.text)
        return fullTranscript
    }

    private func fetchTranscriptFromURL(_ url: URL, transcriptSource: TranscriptMetadata.TranscriptSource) async -> FullTranscript? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }
            return makeFullTranscript(
                data: data,
                responseURL: url,
                contentType: httpResponse.mimeType,
                transcriptSource: transcriptSource
            )
        } catch {
            return nil
        }
    }

    private func makeFullTranscript(
        data: Data,
        responseURL: URL?,
        contentType: String?,
        transcriptSource: TranscriptMetadata.TranscriptSource
    ) -> FullTranscript? {
        let mime = (contentType ?? "").lowercased()
        let ext = (responseURL?.pathExtension ?? "").lowercased()

        let format: TranscriptMetadata.TranscriptFormat
        let segments: [TranscriptSegment]?
        let text: String

        if mime.contains("srt") || ext == "srt" {
            format = .srt
            let result = parseSRT(data)
            text = result.text
            segments = result.segments
        } else if mime.contains("vtt") || ext == "vtt" {
            format = .vtt
            let result = parseVTT(data)
            text = result.text
            segments = result.segments
        } else if mime.contains("json") || ext == "json" {
            format = .json
            let result = parseJSONTranscript(data)
            text = result.text
            segments = result.segments
        } else if mime.contains("html") || ext == "html" || ext == "htm" || Self.looksLikeHTML(data) {
            format = .html
            let result = parseHTML(data)
            text = result.text
            segments = result.segments
        } else {
            format = .plainText
            let raw = String(data: data, encoding: .utf8) ?? ""
            // Safety net: if the "plain text" still has stray HTML tags, strip them.
            if raw.range(of: "<[a-z/][^>]*>", options: [.regularExpression, .caseInsensitive]) != nil {
                text = raw.strippingHTMLTags
            } else {
                text = raw
            }
            segments = nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let wordCount = trimmed.split(separator: " ").count
        let metadata = TranscriptMetadata(
            source: transcriptSource,
            format: format,
            fetchedAt: Date(),
            hasSpeakerLabels: segments?.contains(where: { $0.speaker != nil }) ?? false,
            hasTimestamps: segments?.contains(where: { $0.startTime != nil }) ?? false,
            wordCount: wordCount
        )

        return FullTranscript(text: trimmed, segments: segments, metadata: metadata)
    }

    private func parseSRT(_ data: Data) -> (text: String, segments: [TranscriptSegment]?) {
        guard let text = String(data: data, encoding: .utf8) else {
            return ("", nil)
        }

        let lines = text.components(separatedBy: .newlines)
        var transcript: [String] = []
        var segments: [TranscriptSegment] = []

        var currentSegment: (start: TimeInterval?, end: TimeInterval?, text: String) = (nil, nil, "")
        var expectingTimestamp = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !currentSegment.text.isEmpty {
                    segments.append(TranscriptSegment(
                        text: currentSegment.text,
                        startTime: currentSegment.start,
                        endTime: currentSegment.end,
                        speaker: nil
                    ))
                    currentSegment = (nil, nil, "")
                }
                expectingTimestamp = false
                continue
            }

            if Int(trimmed) != nil {
                expectingTimestamp = true
                continue
            }

            if trimmed.contains("-->") {
                let times = trimmed.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                if times.count == 2 {
                    currentSegment.start = parseSRTTimestamp(times[0])
                    currentSegment.end = parseSRTTimestamp(times[1])
                }
                continue
            }

            if !expectingTimestamp {
                let clean = trimmed.strippingHTMLTags
                transcript.append(clean)
                currentSegment.text += (currentSegment.text.isEmpty ? "" : " ") + clean
            }
        }

        if !currentSegment.text.isEmpty {
            segments.append(TranscriptSegment(
                text: currentSegment.text,
                startTime: currentSegment.start,
                endTime: currentSegment.end,
                speaker: nil
            ))
        }

        return (transcript.joined(separator: " "), segments.isEmpty ? nil : segments)
    }

    private func parseSRTTimestamp(_ timestamp: String) -> TimeInterval? {
        let components = timestamp.replacingOccurrences(of: ",", with: ".")
            .components(separatedBy: ":")

        guard components.count == 3 else { return nil }

        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0

        return hours * 3600 + minutes * 60 + seconds
    }

    private func parseVTT(_ data: Data) -> (text: String, segments: [TranscriptSegment]?) {
        guard let text = String(data: data, encoding: .utf8) else {
            return ("", nil)
        }

        let lines = text.components(separatedBy: .newlines)
        var transcript: [String] = []
        var segments: [TranscriptSegment] = []

        var currentSegment: (start: TimeInterval?, end: TimeInterval?, speaker: String?, text: String) = (nil, nil, nil, "")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !currentSegment.text.isEmpty {
                    segments.append(TranscriptSegment(
                        text: currentSegment.text,
                        startTime: currentSegment.start,
                        endTime: currentSegment.end,
                        speaker: currentSegment.speaker
                    ))
                    currentSegment = (nil, nil, nil, "")
                }
                continue
            }

            if trimmed == "WEBVTT" { continue }
            if trimmed.hasPrefix("NOTE") { continue }
            if trimmed.hasPrefix("Kind:") || trimmed.hasPrefix("Language:") { continue }

            if trimmed.contains("-->") {
                let components = trimmed.components(separatedBy: "-->").map { $0.trimmingCharacters(in: .whitespaces) }
                if components.count == 2 {
                    currentSegment.start = parseVTTTimestamp(components[0])
                    currentSegment.end = parseVTTTimestamp(components[1])
                }
                continue
            }

            if trimmed.hasPrefix("<v ") {
                let speakerPattern = #"<v ([^>]+)>(.+)"#
                if let regex = try? NSRegularExpression(pattern: speakerPattern),
                   let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)),
                   let speakerRange = Range(match.range(at: 1), in: trimmed),
                   let textRange = Range(match.range(at: 2), in: trimmed) {
                    currentSegment.speaker = String(trimmed[speakerRange])
                    let textContent = String(trimmed[textRange]).strippingHTMLTags
                    transcript.append(textContent)
                    currentSegment.text += (currentSegment.text.isEmpty ? "" : " ") + textContent
                }
                continue
            }

            let clean = trimmed.strippingHTMLTags
            transcript.append(clean)
            currentSegment.text += (currentSegment.text.isEmpty ? "" : " ") + clean
        }

        if !currentSegment.text.isEmpty {
            segments.append(TranscriptSegment(
                text: currentSegment.text,
                startTime: currentSegment.start,
                endTime: currentSegment.end,
                speaker: currentSegment.speaker
            ))
        }

        return (transcript.joined(separator: " "), segments.isEmpty ? nil : segments)
    }

    private func parseVTTTimestamp(_ timestamp: String) -> TimeInterval? {
        let cleaned = timestamp.components(separatedBy: " ")[0]
        let components = cleaned.components(separatedBy: ":")

        if components.count == 3 {
            let hours = Double(components[0]) ?? 0
            let minutes = Double(components[1]) ?? 0
            let seconds = Double(components[2]) ?? 0
            return hours * 3600 + minutes * 60 + seconds
        } else if components.count == 2 {
            let minutes = Double(components[0]) ?? 0
            let seconds = Double(components[1]) ?? 0
            return minutes * 60 + seconds
        }

        return nil
    }

    private func parseJSONTranscript(_ data: Data) -> (text: String, segments: [TranscriptSegment]?) {
        struct JSONTranscriptSegment: Codable {
            let text: String?
            let body: String?
            let speaker: String?
            let startTime: Double?
            let endTime: Double?
            let start: Double?
            let end: Double?
        }

        if let jsonSegments = try? JSONDecoder().decode([JSONTranscriptSegment].self, from: data) {
            let textParts = jsonSegments.compactMap { $0.text ?? $0.body }
            let segments = jsonSegments.compactMap { segment -> TranscriptSegment? in
                guard let text = segment.text ?? segment.body else { return nil }
                return TranscriptSegment(
                    text: text,
                    startTime: segment.startTime ?? segment.start,
                    endTime: segment.endTime ?? segment.end,
                    speaker: segment.speaker
                )
            }

            return (textParts.joined(separator: " "), segments.isEmpty ? nil : segments)
        }

        return ("", nil)
    }

    private func fetchYouTubeCaptions(videoID: String) async -> FullTranscript? {
        let captionsURL = "https://www.youtube.com/api/timedtext?v=\(videoID)&lang=en&fmt=vtt"
        guard let url = URL(string: captionsURL) else { return nil }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let result = parseVTT(data)
            let wordCount = result.text.split(separator: " ").count

            let metadata = TranscriptMetadata(
                source: .youtube,
                format: .vtt,
                fetchedAt: Date(),
                hasSpeakerLabels: result.segments?.contains(where: { $0.speaker != nil }) ?? false,
                hasTimestamps: result.segments?.contains(where: { $0.startTime != nil }) ?? false,
                wordCount: wordCount
            )

            return FullTranscript(text: result.text, segments: result.segments, metadata: metadata)
        } catch {
            return nil
        }
    }

    /// Checks raw bytes for common HTML signatures without fully decoding.
    private static func looksLikeHTML(_ data: Data) -> Bool {
        guard let prefix = String(data: data.prefix(512), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return false }
        return prefix.hasPrefix("<!doctype html")
            || prefix.hasPrefix("<html")
            || prefix.contains("<head")
            || prefix.contains("<body")
    }

    private func parseHTML(_ data: Data) -> (text: String, segments: [TranscriptSegment]?) {
        guard let raw = String(data: data, encoding: .utf8) else { return ("", nil) }

        let cleaned = raw.removingHTMLBlocks(["script", "style", "nav", "header", "footer", "aside", "noscript", "iframe"])

        let paragraphs = Self.extractParagraphs(from: cleaned)
        if !paragraphs.isEmpty {
            let segments = paragraphs.map { TranscriptSegment(text: $0, startTime: nil, endTime: nil, speaker: nil) }
            let fullText = paragraphs.joined(separator: "\n\n")
            return (fullText, segments)
        }

        // Regex fallback: insert newlines before block elements, then strip all tags.
        var text = cleaned
        let blockTags = "p|div|br|li|h[1-6]|blockquote|tr"
        if let blockRegex = try? NSRegularExpression(pattern: "<(?:\(blockTags))\\b[^>]*/?>", options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            text = blockRegex.stringByReplacingMatches(in: text, range: range, withTemplate: "\n")
        }
        let stripped = text.strippingHTMLTags
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " *\n *", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return (stripped, nil)
    }

    /// Extracts visible text from `<p>` and block-level elements, collapsing whitespace within each.
    private static func extractParagraphs(from html: String) -> [String] {
        // Match <p …>…</p>, <div …>…</div>, <li …>…</li> blocks.
        let blockPattern = #"<(?:p|div|li|blockquote|h[1-6])\b[^>]*>(.*?)</(?:p|div|li|blockquote|h[1-6])>"#
        guard let regex = try? NSRegularExpression(pattern: blockPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: range)

        var paragraphs: [String] = []
        for match in matches {
            guard let innerRange = Range(match.range(at: 1), in: html) else { continue }
            let inner = String(html[innerRange])
                .strippingHTMLTags
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty {
                paragraphs.append(inner)
            }
        }

        return paragraphs
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
