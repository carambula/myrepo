import Foundation

// MARK: - Phase 1: Behavior-based ad learning (L1)

/// Learns ad break positions from the user's own skip behavior.
///
/// The SeekEventStore (Phase 0) records every seek. This learner mines those
/// events per show to find consistent patterns:
///
/// - **Pre-roll**: forward seeks starting near 0:00 that end at a consistent
///   position across episodes. "Skipped the first 60s in 8 straight episodes"
///   is a pre-roll without listening to a second of audio.
///
/// Learned segments use `AdSegmentSource.behavior` and feed the same
/// smart-30s-forward and auto-skip paths as chapter segments.
enum AdPatternLearner {
    /// Minimum episodes with a consistent skip before we trust the pattern.
    private static let minEpisodes = 3
    /// How close skip end-times must be to cluster (± seconds).
    private static let clusterTolerance: TimeInterval = 10
    /// A skip counts as "from the start" if it begins within this many seconds.
    private static let preRollStartThreshold: TimeInterval = 15
    /// Ignore skips shorter than this (probably just skipping silence).
    private static let minSkipDuration: TimeInterval = 20

    /// Learned ad segments for a show, from the user's skip history.
    /// - Parameter podcastID: The show to learn for (matches `Episode.podcastID`).
    /// - Parameter seekStore: Defaults to the shared store; injectable for tests.
    static func learnedSegments(
        for podcastID: String,
        seekStore: SeekEventStore = .shared
    ) -> [AdSegment] {
        let events = seekStore.recentEvents(forPodcastID: podcastID, limit: 1000)
        var segments: [AdSegment] = []

        if let preRoll = learnPreRoll(from: events) {
            segments.append(preRoll)
        }

        return segments
    }

    // MARK: - Pre-roll learning

    /// Finds a consistent pre-roll skip: forward seeks from near 0:00 that
    /// land at a consistent position across multiple episodes.
    private static func learnPreRoll(from events: [SeekEvent]) -> AdSegment? {
        // Candidate skips: forward, starting near 0, meaningful duration.
        // Group end-times by episode so one episode can't stuff the ballot.
        var endByEpisode: [String: TimeInterval] = [:]
        for event in events {
            guard event.trigger == .forwardButton || event.trigger == .remote,
                  event.fromTime < preRollStartThreshold,
                  event.toTime - event.fromTime >= minSkipDuration
            else { continue }
            // Keep the furthest skip per episode (user may tap +30s twice).
            if let existing = endByEpisode[event.episodeID] {
                endByEpisode[event.episodeID] = max(existing, event.toTime)
            } else {
                endByEpisode[event.episodeID] = event.toTime
            }
        }

        guard endByEpisode.count >= minEpisodes else { return nil }

        // Cluster end times: sort, then greedily group within tolerance.
        let sortedEnds = endByEpisode.values.sorted()
        var bestCluster: [TimeInterval] = []
        var currentCluster: [TimeInterval] = []

        for end in sortedEnds {
            if let last = currentCluster.last, end - last > clusterTolerance {
                if currentCluster.count > bestCluster.count {
                    bestCluster = currentCluster
                }
                currentCluster = [end]
            } else {
                currentCluster.append(end)
            }
        }
        if currentCluster.count > bestCluster.count {
            bestCluster = currentCluster
        }

        guard bestCluster.count >= minEpisodes else { return nil }

        let meanEnd = bestCluster.reduce(0, +) / Double(bestCluster.count)
        let confidence = confidenceFor(sampleCount: bestCluster.count)

        return AdSegment(
            startTime: 0,
            endTime: meanEnd,
            kind: .preRoll,
            confidence: confidence,
            source: .behavior
        )
    }

    /// Confidence grows with evidence: 3 episodes → 0.6, 5 → 0.8, 10+ → 0.9.
    private static func confidenceFor(sampleCount: Int) -> Double {
        switch sampleCount {
        case ..<3: return 0
        case 3..<5: return 0.6
        case 5..<10: return 0.8
        default: return 0.9
        }
    }
}
