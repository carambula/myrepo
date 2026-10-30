import Foundation

// MARK: - Ad skip data model (Phase 0)

/// Where in the episode an ad break sits.
enum AdSegmentKind: String, Codable, CaseIterable {
    case preRoll
    case midRoll
    case postRoll
}

/// Which detection layer produced the segment. Later phases add sources;
/// every segment keeps its provenance so the UI can explain itself.
enum AdSegmentSource: String, Codable, CaseIterable {
    case chapters
    case jingle // Phase 1: ShazamKit cue-sting fingerprinting
    case acoustic // Phase 1: loudness / silence / speaker-change heuristics
    case transcript // Phase 2: on-device transcription + host-read classifier
    case behavior // Phase 3: learned from the listener's own skip patterns
}

/// A detected ad break. Confidence is 0...1; only high-confidence segments
/// (multiple agreeing sources, or a learned behavior segment) auto-skip.
struct AdSegment: Identifiable, Codable, Hashable {
    let id: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let kind: AdSegmentKind
    let confidence: Double
    let source: AdSegmentSource

    init(
        id: String = UUID().uuidString,
        startTime: TimeInterval,
        endTime: TimeInterval,
        kind: AdSegmentKind,
        confidence: Double,
        source: AdSegmentSource
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.kind = kind
        self.confidence = max(0, min(1, confidence))
        self.source = source
    }

    var duration: TimeInterval { max(0, endTime - startTime) }
}

/// Cached per-episode analysis. `analyzerVersion` lets a better detector
/// re-run without re-downloading; stale versions are recomputed on read.
struct EpisodeAdAnalysis: Codable {
    static let currentAnalyzerVersion = 4 // v4: + jingle + acoustic segments (Phase 2)

    let episodeID: String
    let analyzerVersion: Int
    let analyzedAt: Date
    let segments: [AdSegment]

    init(
        episodeID: String,
        segments: [AdSegment],
        analyzerVersion: Int = currentAnalyzerVersion,
        analyzedAt: Date = Date()
    ) {
        self.episodeID = episodeID
        self.segments = segments
        self.analyzerVersion = analyzerVersion
        self.analyzedAt = analyzedAt
    }
}

// MARK: - Skip decision (pure, unit-tested)

/// Pure decision logic for smart skip-forward.
enum AdSkipEngine {
    /// Returns the segment end to jump to when a forward skip is pressed,
    /// or nil when the press should behave as a normal forward skip.
    ///
    /// A forward press jumps a whole break when the playhead is inside (or
    /// just before) a detected segment and the normal landing would hit it.
    static func smartSkipTarget(
        currentTime: TimeInterval,
        forwardSeconds: TimeInterval,
        segments: [AdSegment]
    ) -> TimeInterval? {
        segments
            .filter { $0.endTime > $0.startTime }
            .filter { currentTime < $0.endTime && currentTime + forwardSeconds >= $0.startTime - 5 }
            .sorted { $0.startTime < $1.startTime }
            .first
            .map { $0.endTime }
    }
}
