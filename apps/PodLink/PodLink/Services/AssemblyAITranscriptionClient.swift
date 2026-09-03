import Foundation

/// Submits a public `audio_url` to AssemblyAI and polls until the job completes.
struct AssemblyAITranscriptionClient {
    enum ClientError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case jobFailed(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Add your AssemblyAI API key in Account → Transcription."
            case .invalidResponse:
                return "Unexpected response from the transcription service."
            case .jobFailed(let message):
                return message
            case .timeout:
                return "Transcription is taking longer than expected. Try again in a few minutes."
            }
        }
    }

    func transcribe(audioURL: URL, apiKey: String) async throws -> FullTranscript {
        let session = URLSession.shared
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ClientError.missingAPIKey }

        let createURL = URL(string: "https://api.assemblyai.com/v2/transcript")!
        var createReq = URLRequest(url: createURL)
        createReq.httpMethod = "POST"
        createReq.setValue(key, forHTTPHeaderField: "authorization")
        createReq.setValue("application/json", forHTTPHeaderField: "content-type")

        let payload: [String: Any] = [
            "audio_url": audioURL.absoluteString,
            "speaker_labels": true
        ]
        createReq.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (createData, createResp) = try await session.data(for: createReq)
        guard let http = createResp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClientError.invalidResponse
        }

        struct CreateBody: Decodable {
            let id: String?
            let error: String?
        }
        let created = try JSONDecoder().decode(CreateBody.self, from: createData)
        if let err = created.error, !err.isEmpty {
            throw ClientError.jobFailed(err)
        }
        guard let jobId = created.id, !jobId.isEmpty else {
            throw ClientError.invalidResponse
        }

        let pollURL = URL(string: "https://api.assemblyai.com/v2/transcript/\(jobId)")!
        for _ in 0..<400 {
            try await Task.sleep(nanoseconds: 2_000_000_000)

            var pollReq = URLRequest(url: pollURL)
            pollReq.setValue(key, forHTTPHeaderField: "authorization")

            let (pollData, pollResp) = try await session.data(for: pollReq)
            guard let pollHttp = pollResp as? HTTPURLResponse, (200...299).contains(pollHttp.statusCode) else {
                throw ClientError.invalidResponse
            }

            let statusDoc = try JSONDecoder().decode(PollBody.self, from: pollData)
            switch statusDoc.status {
            case "completed":
                return try Self.buildFullTranscript(from: statusDoc)
            case "error":
                throw ClientError.jobFailed(statusDoc.error ?? "Transcription failed.")
            default:
                break
            }
        }

        throw ClientError.timeout
    }

    private struct PollBody: Decodable {
        let status: String
        let text: String?
        let utterances: [Utterance]?
        let error: String?

        struct Utterance: Decodable {
            let start: Int
            let end: Int
            let text: String
            let speaker: String?
        }
    }

    private static func buildFullTranscript(from body: PollBody) throws -> FullTranscript {
        let text = body.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            throw ClientError.jobFailed("Empty transcript result.")
        }

        let segments: [TranscriptSegment]? = body.utterances.map { utts in
            utts.map { u in
                TranscriptSegment(
                    text: u.text,
                    startTime: TimeInterval(u.start) / 1000.0,
                    endTime: TimeInterval(u.end) / 1000.0,
                    speaker: u.speaker
                )
            }
        }

        let wordCount = text.split(separator: " ").count
        let metadata = TranscriptMetadata(
            source: .generated,
            format: .plainText,
            fetchedAt: Date(),
            hasSpeakerLabels: segments?.contains(where: { $0.speaker != nil }) ?? false,
            hasTimestamps: segments?.contains(where: { $0.startTime != nil }) ?? false,
            wordCount: wordCount
        )

        return FullTranscript(text: text, segments: segments, metadata: metadata)
    }
}
