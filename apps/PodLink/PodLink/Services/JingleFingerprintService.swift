import Foundation
import ShazamKit

// MARK: - Phase 3: Jingle Fingerprinting (L2)
//
// Podcasts often bound ad breaks with short musical stings ("we'll be right back").
// These are identical across episodes, short (2-5s), and distinctive.
// ShazamKit's SHCustomCatalog matches them on-device, no server needed.
//
// Flow:
// 1. User long-presses progress bar → "Train ad cue here" → learnJingle()
// 2. Background analysis → findJingles() → jingle timestamps
// 3. Paired jingles (sting ... content ... sting) → ad segment, source .jingle

/// A learned ad-boundary sting for a show.
struct JingleInfo: Codable, Identifiable {
    let id: String
    let podcastID: String
    let learnedAt: Date
    var useCount: Int
    var lastMatchedAt: Date?
}

/// A jingle match found in an episode.
struct JingleMatch {
    let time: TimeInterval
    let confidence: Double
    let jingleID: String
}

actor JingleFingerprintService {
    static let shared = JingleFingerprintService()

    private var catalogs: [String: SHCustomCatalog] = [:]
    private var metadata: [String: [JingleInfo]] = [:]

    private var baseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PodLink/jingles", isDirectory: true)
    }

    // MARK: - Learning

    /// Learn a jingle from 5s of audio centered on `time`.
    /// Called from the "Train on this cue" UI.
    func learnJingle(for podcastID: String, from audioURL: URL, at time: TimeInterval) async throws {
        let signature = try await makeSignature(from: audioURL, at: time, duration: 5.0)
        let catalog = await catalog(for: podcastID)
        let jingleID = UUID().uuidString
        let mediaItem = SHMediaItem(
            properties: [.title: jingleID]
        )
        try await catalog.addReferenceSignature(signature, representing: [mediaItem])

        var infos = metadata[podcastID] ?? []
        infos.append(JingleInfo(
            id: jingleID,
            podcastID: podcastID,
            learnedAt: Date(),
            useCount: 0,
            lastMatchedAt: nil
        ))
        metadata[podcastID] = infos
        saveCatalog(catalog, for: podcastID)
        saveMetadata(for: podcastID)
    }

    // MARK: - Matching

    /// Scan an episode for known jingles. Returns matches sorted by time.
    func findJingles(in audioURL: URL, for podcastID: String) async -> [JingleMatch] {
        let catalog = await catalog(for: podcastID)
        guard !(metadata[podcastID] ?? []).isEmpty else { return [] }

        let session = SHSession(catalog: catalog)
        let delegate = JingleMatchDelegate()
        session.delegate = delegate

        // Stream the audio through ShazamKit in 12s chunks
        do {
            let audioFile = try AVAudioFile(forReading: audioURL)
            let format = audioFile.processingFormat
            let chunkFrames = AVAudioFrameCount(format.sampleRate * 12)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
                return []
            }
            var currentTime: TimeInterval = 0
            while audioFile.framePosition < audioFile.length {
                try audioFile.read(into: buffer)
                let signature = SHSignatureGenerator()
                try signature.append(buffer, at: nil)
                // Note: real implementation would use SHSession.matchStreamingBuffer
                currentTime += Double(buffer.frameLength) / format.sampleRate
            }
        } catch {
            return []
        }

        return delegate.matches
    }

    // MARK: - Management

    func jingles(for podcastID: String) -> [JingleInfo] {
        metadata[podcastID] ?? []
    }

    func removeJingle(id: String, for podcastID: String) async {
        metadata[podcastID]?.removeAll { $0.id == id }
        saveMetadata(for: podcastID)
        // Note: SHCustomCatalog doesn't support removing single signatures;
        // rebuild catalog from remaining metadata on next load.
        catalogs.removeValue(forKey: podcastID)
    }

    // MARK: - Private

    private func catalog(for podcastID: String) async -> SHCustomCatalog {
        if let existing = catalogs[podcastID] { return existing }
        let catalog = SHCustomCatalog()
        // TODO: load persisted signatures from disk
        catalogs[podcastID] = catalog
        if metadata[podcastID] == nil {
            metadata[podcastID] = loadMetadata(for: podcastID)
        }
        return catalog
    }

    private func makeSignature(from audioURL: URL, at time: TimeInterval, duration: TimeInterval) async throws -> SHSignature {
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let startFrame = AVAudioFramePosition(time * format.sampleRate)
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        audioFile.framePosition = max(0, startFrame)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw JingleError.bufferAllocationFailed
        }
        try audioFile.read(into: buffer, frameCount: frameCount)
        let generator = SHSignatureGenerator()
        try generator.append(buffer, at: nil)
        return generator.signature()
    }

    private func saveCatalog(_ catalog: SHCustomCatalog, for podcastID: String) {
        // TODO: persist SHCustomCatalog to disk via NSKeyedArchiver
    }

    private func saveMetadata(for podcastID: String) {
        guard let infos = metadata[podcastID] else { return }
        let url = baseURL.appendingPathComponent("\(podcastID).json")
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        try? JSONEncoder().encode(infos).write(to: url)
    }

    private func loadMetadata(for podcastID: String) -> [JingleInfo] {
        let url = baseURL.appendingPathComponent("\(podcastID).json")
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([JingleInfo].self, from: data)) ?? []
    }
}

private class JingleMatchDelegate: NSObject, SHSessionDelegate {
    var matches: [JingleMatch] = []

    func session(_ session: SHSession, didFind match: SHMatch) {
        for item in match.mediaItems {
            // jingleID is stored in the title
            let jingleID = item.title ?? UUID().uuidString
            // TODO: get actual match time from session
            matches.append(JingleMatch(time: 0, confidence: 0.8, jingleID: jingleID))
        }
    }
}

enum JingleError: Error {
    case bufferAllocationFailed
    case signatureGenerationFailed
}
