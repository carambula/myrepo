import Foundation

struct TranscriptMetadata: Codable {
    let source: TranscriptSource
    let format: TranscriptFormat
    let fetchedAt: Date
    let hasSpeakerLabels: Bool
    let hasTimestamps: Bool
    let wordCount: Int
    
    enum TranscriptSource: String, Codable {
        case rssTag = "podcast:transcript"
        case youtube = "YouTube Captions"
        case manual = "User Uploaded"
        case generated = "Auto-Generated"
    }
    
    enum TranscriptFormat: String, Codable {
        case srt = "SRT"
        case vtt = "VTT"
        case json = "JSON"
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

actor TranscriptService {
    static let shared = TranscriptService()

    private let cache = CacheService.shared
    private let session = URLSession.shared

    func getTranscript(for episode: Episode) async -> String? {
        let fullTranscript = await getFullTranscript(for: episode)
        return fullTranscript?.text
    }
    
    func getFullTranscript(for episode: Episode) async -> FullTranscript? {
        let cacheKey = "transcript_full_\(episode.id)"
        if let cached: FullTranscript = await cache.get(cacheKey, as: FullTranscript.self) {
            return cached
        }

        // Source 1: <podcast:transcript> tag URL
        if let transcriptURL = episode.transcriptURL {
            if let fullTranscript = await fetchTranscriptFromURL(transcriptURL) {
                await cache.set(cacheKey, value: fullTranscript, ttl: 86400 * 30)
                return fullTranscript
            }
        }

        // Source 2: YouTube auto-captions (if video URL is YouTube)
        if let videoURL = episode.videoURL,
           let videoID = extractYouTubeVideoID(from: videoURL) {
            if let fullTranscript = await fetchYouTubeCaptions(videoID: videoID) {
                await cache.set(cacheKey, value: fullTranscript, ttl: 86400 * 30)
                return fullTranscript
            }
        }

        return nil
    }

    private func fetchTranscriptFromURL(_ url: URL) async -> FullTranscript? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            let contentType = httpResponse.mimeType ?? ""
            let format: TranscriptMetadata.TranscriptFormat
            let segments: [TranscriptSegment]?
            let text: String
            
            if contentType.contains("srt") || url.pathExtension == "srt" {
                format = .srt
                let result = parseSRT(data)
                text = result.text
                segments = result.segments
            } else if contentType.contains("vtt") || url.pathExtension == "vtt" {
                format = .vtt
                let result = parseVTT(data)
                text = result.text
                segments = result.segments
            } else if contentType.contains("json") {
                format = .json
                let result = parseJSONTranscript(data)
                text = result.text
                segments = result.segments
            } else {
                format = .plainText
                text = String(data: data, encoding: .utf8) ?? ""
                segments = nil
            }
            
            let wordCount = text.split(separator: " ").count
            let metadata = TranscriptMetadata(
                source: .rssTag,
                format: format,
                fetchedAt: Date(),
                hasSpeakerLabels: segments?.contains(where: { $0.speaker != nil }) ?? false,
                hasTimestamps: segments?.contains(where: { $0.startTime != nil }) ?? false,
                wordCount: wordCount
            )
            
            return FullTranscript(text: text, segments: segments, metadata: metadata)
        } catch {
            return nil
        }
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
                transcript.append(trimmed)
                currentSegment.text += (currentSegment.text.isEmpty ? "" : " ") + trimmed
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
                    let textContent = String(trimmed[textRange])
                    transcript.append(textContent)
                    currentSegment.text += (currentSegment.text.isEmpty ? "" : " ") + textContent
                }
                continue
            }
            
            transcript.append(trimmed)
            currentSegment.text += (currentSegment.text.isEmpty ? "" : " ") + trimmed
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
