import Testing
import Foundation
@testable import PodLink

// MARK: - Phase 1 tests: behavior learning (AdPatternLearner)

@Suite("AdPatternLearner")
struct AdPatternLearnerTests {
    /// Builds an isolated SeekEventStore backed by a temp file.
    private func makeStore() -> SeekEventStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        return SeekEventStore(fileURL: url)
    }

    private func logSkip(
        _ store: SeekEventStore,
        episode: String,
        from: TimeInterval,
        to: TimeInterval,
        trigger: SeekTrigger = .forwardButton
    ) {
        store.log(
            episodeID: episode,
            podcastID: "show-1",
            from: from,
            to: to,
            trigger: trigger
        )
    }

    @Test("learns a pre-roll from consistent skips across 3 episodes")
    func learnsPreRoll() {
        let store = makeStore()
        logSkip(store, episode: "ep1", from: 2, to: 62)
        logSkip(store, episode: "ep2", from: 0, to: 58)
        logSkip(store, episode: "ep3", from: 5, to: 65)

        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.count == 1)
        let pre = segments[0]
        #expect(pre.kind == .preRoll)
        #expect(pre.source == .behavior)
        #expect(pre.startTime == 0)
        // Mean of 62, 58, 65 ≈ 61.7
        #expect(abs(pre.endTime - 61.7) < 1)
        #expect(pre.confidence == 0.6)
    }

    @Test("needs 3 episodes before learning")
    func needsThreeEpisodes() {
        let store = makeStore()
        logSkip(store, episode: "ep1", from: 2, to: 62)
        logSkip(store, episode: "ep2", from: 0, to: 58)

        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.isEmpty)
    }

    @Test("ignores inconsistent skip positions")
    func ignoresInconsistentSkips() {
        let store = makeStore()
        logSkip(store, episode: "ep1", from: 2, to: 62)
        logSkip(store, episode: "ep2", from: 0, to: 120)
        logSkip(store, episode: "ep3", from: 5, to: 200)

        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.isEmpty)
    }

    @Test("ignores short skips and backward seeks")
    func ignoresShortSkips() {
        let store = makeStore()
        // Too short to be an ad skip
        logSkip(store, episode: "ep1", from: 2, to: 10)
        logSkip(store, episode: "ep2", from: 0, to: 12)
        logSkip(store, episode: "ep3", from: 5, to: 15)
        // Backward seek — not a skip-forward pattern
        logSkip(store, episode: "ep4", from: 60, to: 30, trigger: .backButton)

        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.isEmpty)
    }

    @Test("confidence grows with more episodes")
    func confidenceGrows() {
        let store = makeStore()
        for i in 1...6 {
            logSkip(store, episode: "ep\(i)", from: 0, to: 60 + Double(i % 3))
        }
        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.count == 1)
        #expect(segments[0].confidence == 0.8)
    }

    @Test("one episode cannot stuff the ballot with multiple skips")
    func oneEpisodeOneVote() {
        let store = makeStore()
        // Same episode, many skips — counts once
        logSkip(store, episode: "ep1", from: 0, to: 60)
        logSkip(store, episode: "ep1", from: 60, to: 120)
        logSkip(store, episode: "ep2", from: 0, to: 61)

        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.isEmpty) // only 2 distinct episodes
    }

    @Test("keeps the furthest skip per episode (double-tap +30s)")
    func furthestSkipPerEpisode() {
        let store = makeStore()
        // User double-taps +30s: 0→30, then 30→62
        logSkip(store, episode: "ep1", from: 0, to: 30)
        logSkip(store, episode: "ep1", from: 30, to: 62)
        logSkip(store, episode: "ep2", from: 0, to: 30)
        logSkip(store, episode: "ep2", from: 30, to: 59)
        logSkip(store, episode: "ep3", from: 0, to: 61)

        let segments = AdPatternLearner.learnedSegments(for: "show-1", seekStore: store)
        #expect(segments.count == 1)
        // Furthest per episode: 62, 59, 61 → mean ≈ 60.7
        #expect(abs(segments[0].endTime - 60.7) < 1)
    }
}
