import AVFoundation
import Foundation
import Speech

enum OnDeviceTranscriptionError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case episodeNotDownloaded
    case emptyResult
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition permission is required. Go to Settings → Privacy & Security → Speech Recognition and enable PodLink."
        case .recognizerUnavailable:
            return "On-device speech recognition is not available right now. Try again shortly or check your language settings."
        case .episodeNotDownloaded:
            return "The episode needs to be downloaded first. Tap the download button on the episode, then try again."
        case .emptyResult:
            return "No speech was detected in this episode."
        case .exportFailed(let msg):
            return "Audio preparation failed: \(msg)"
        }
    }
}

actor OnDeviceTranscriptionService {
    static let shared = OnDeviceTranscriptionService()

    private static let chunkDuration: Double = 50.0
    private static let speakerSwitchPause: Double = 2.0
    private static let minTurnWords = 8

    // MARK: - Internal types

    private struct WordToken {
        let text: String
        let startTime: Double
        let endTime: Double
    }

    private struct SpeakerTurn {
        let words: [WordToken]
        let speakerLabel: String
    }

    /// Persisted after every chunk so transcription can resume if interrupted.
    private struct Checkpoint: Codable {
        var nextChunkIndex: Int
        var collectedWords: [SavedWord]
        let totalSeconds: Double

        struct SavedWord: Codable {
            let text: String
            let startTime: Double
            let endTime: Double
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    // MARK: - Checkpoint management

    private func checkpointKey(for episodeID: String) -> String { "transcript_checkpoint_\(episodeID)" }

    private func loadCheckpoint(for episodeID: String) async -> Checkpoint? {
        await CacheService.shared.get(checkpointKey(for: episodeID), as: Checkpoint.self)
    }

    private func saveCheckpoint(_ checkpoint: Checkpoint, for episodeID: String) async {
        await CacheService.shared.set(checkpointKey(for: episodeID), value: checkpoint, ttl: 86400 * 7)
    }

    func clearCheckpoint(for episodeID: String) async {
        await CacheService.shared.remove(checkpointKey(for: episodeID))
    }

    // MARK: - Transcription

    func transcribe(
        episode: Episode,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> FullTranscript {
        let status = await requestAuthorization()
        guard status == .authorized else { throw OnDeviceTranscriptionError.notAuthorized }

        guard episode.isDownloaded, let fileURL = episode.downloadedFileURL else {
            throw OnDeviceTranscriptionError.episodeNotDownloaded
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current)
                ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw OnDeviceTranscriptionError.recognizerUnavailable
        }

        let asset = AVURLAsset(url: fileURL)
        let totalSeconds = try await asset.load(.duration).seconds
        guard totalSeconds > 0 else { throw OnDeviceTranscriptionError.emptyResult }

        let chunkCount = Int(ceil(totalSeconds / Self.chunkDuration))

        // Load or create checkpoint so we can resume if interrupted.
        var checkpoint = await loadCheckpoint(for: episode.id)
            ?? Checkpoint(nextChunkIndex: 0, collectedWords: [], totalSeconds: totalSeconds)

        let resuming = checkpoint.nextChunkIndex > 0
        if resuming {
            let resumeTime = Double(checkpoint.nextChunkIndex) * Self.chunkDuration
            onProgress("Resuming from \(formatTime(resumeTime)) of \(formatTime(totalSeconds))…")
        }

        var allWords: [WordToken] = checkpoint.collectedWords.map {
            WordToken(text: $0.text, startTime: $0.startTime, endTime: $0.endTime)
        }

        for i in checkpoint.nextChunkIndex..<chunkCount {
            let chunkStart = Double(i) * Self.chunkDuration
            let chunkEnd   = min(chunkStart + Self.chunkDuration, totalSeconds)
            onProgress("Transcribing \(formatTime(chunkStart)) – \(formatTime(chunkEnd)) of \(formatTime(totalSeconds))…")

            let tempURL = URL.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("m4a")

            do {
                let range = CMTimeRange(
                    start: CMTime(seconds: chunkStart, preferredTimescale: 600),
                    duration: CMTime(seconds: chunkEnd - chunkStart, preferredTimescale: 600)
                )
                try await exportChunk(asset: asset, range: range, to: tempURL)

                let request = SFSpeechURLRecognitionRequest(url: tempURL)
                request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
                request.shouldReportPartialResults = false
                request.addsPunctuation = true

                let result = try await runRecognition(request: request, recognizer: recognizer)
                var chunkWords: [WordToken] = []
                for seg in result.bestTranscription.segments {
                    let word = seg.substring.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !word.isEmpty else { continue }
                    chunkWords.append(WordToken(
                        text: word,
                        startTime: seg.timestamp + chunkStart,
                        endTime: seg.timestamp + seg.duration + chunkStart
                    ))
                }
                allWords.append(contentsOf: chunkWords)

                // Checkpoint: mark this chunk complete and persist so we can resume after interruption.
                checkpoint.nextChunkIndex = i + 1
                checkpoint.collectedWords = allWords.map {
                    Checkpoint.SavedWord(text: $0.text, startTime: $0.startTime, endTime: $0.endTime)
                }
                await saveCheckpoint(checkpoint, for: episode.id)
            } catch {
                // Skip failed chunks but keep the checkpoint at the current index so
                // a retry will attempt this chunk again.
            }

            try? FileManager.default.removeItem(at: tempURL)
        }

        guard !allWords.isEmpty else { throw OnDeviceTranscriptionError.emptyResult }

        onProgress("Detecting speakers…")
        let turns = detectSpeakerTurns(allWords)
        let transcript = buildTranscript(from: turns, totalSeconds: totalSeconds)

        // Remove the checkpoint now that we have a complete transcript.
        await clearCheckpoint(for: episode.id)

        return transcript
    }

    // MARK: - Speaker turn detection

    private func detectSpeakerTurns(_ words: [WordToken]) -> [SpeakerTurn] {
        guard !words.isEmpty else { return [] }

        var rawBlocks: [[WordToken]] = []
        var current: [WordToken] = [words[0]]

        for i in 1..<words.count {
            let gap = words[i].startTime - words[i - 1].endTime
            if gap >= Self.speakerSwitchPause {
                rawBlocks.append(current)
                current = [words[i]]
            } else {
                current.append(words[i])
            }
        }
        rawBlocks.append(current)

        var merged: [[WordToken]] = []
        for block in rawBlocks {
            if block.count < Self.minTurnWords, !merged.isEmpty {
                merged[merged.count - 1] += block
            } else {
                merged.append(block)
            }
        }

        var turns: [SpeakerTurn] = []
        var speakerIndex = 0
        for (i, block) in merged.enumerated() {
            if i > 0 { speakerIndex = 1 - speakerIndex }
            turns.append(SpeakerTurn(words: block, speakerLabel: "Speaker \(speakerIndex + 1)"))
        }

        let uniqueLabels = Set(turns.map(\.speakerLabel))
        if uniqueLabels.count == 1 {
            return turns.map { SpeakerTurn(words: $0.words, speakerLabel: "") }
        }

        return turns
    }

    // MARK: - Build FullTranscript

    private func buildTranscript(from turns: [SpeakerTurn], totalSeconds: Double) -> FullTranscript {
        var segments: [TranscriptSegment] = []
        var textParts: [String] = []

        for turn in turns {
            let text = turn.words.map(\.text).joined(separator: " ")
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            textParts.append(text)
            segments.append(TranscriptSegment(
                text: text,
                startTime: turn.words.first?.startTime,
                endTime: turn.words.last?.endTime,
                speaker: turn.speakerLabel.isEmpty ? nil : turn.speakerLabel
            ))
        }

        let fullText = textParts.joined(separator: " ")
        let uniqueSpeakers = Set(segments.compactMap(\.speaker))
        let hasSpeakerLabels = uniqueSpeakers.count > 1

        let metadata = TranscriptMetadata(
            source: .onDevice,
            format: .plainText,
            fetchedAt: Date(),
            hasSpeakerLabels: hasSpeakerLabels,
            hasTimestamps: !segments.isEmpty,
            wordCount: fullText.split(separator: " ").count
        )

        return FullTranscript(
            text: fullText,
            segments: segments.isEmpty ? nil : segments,
            metadata: metadata
        )
    }

    // MARK: - Helpers

    private func exportChunk(asset: AVURLAsset, range: CMTimeRange, to url: URL) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw OnDeviceTranscriptionError.exportFailed("Could not create export session.")
        }
        session.outputURL = url
        session.outputFileType = .m4a
        session.timeRange = range
        await session.export()
        guard session.status == .completed else {
            throw OnDeviceTranscriptionError.exportFailed(
                session.error?.localizedDescription ?? "Unknown error."
            )
        }
    }

    private func runRecognition(
        request: SFSpeechURLRecognitionRequest,
        recognizer: SFSpeechRecognizer
    ) async throws -> SFSpeechRecognitionResult {
        try await withCheckedThrowingContinuation { continuation in
            var completed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !completed else { return }
                if let error {
                    completed = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    completed = true
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
