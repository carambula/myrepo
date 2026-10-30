import Foundation
import Testing
@testable import PodLink

// MARK: - Ad skip Phase 0 tests

struct AdSkipPhase0Tests {
    // MARK: ChapterAdDetector

    @Test func detectsAdChapterTitles() {
        #expect(ChapterAdDetector.isAdTitle("Ad: Squarespace"))
        #expect(ChapterAdDetector.isAdTitle("Ad - Squarespace"))
        #expect(ChapterAdDetector.isAdTitle("Ad break"))
        #expect(ChapterAdDetector.isAdTitle("A word from our sponsor"))
        #expect(ChapterAdDetector.isAdTitle("Sponsored by Acme"))
        #expect(ChapterAdDetector.isAdTitle("Advertisement"))
        #expect(!ChapterAdDetector.isAdTitle("Interview with the founder"))
        #expect(!ChapterAdDetector.isAdTitle("Ad-free Q&A"))
        #expect(!ChapterAdDetector.isAdTitle(""))
    }

    @Test func classifiesPreMidPostRollByPosition() {
        let chapters = [
            Chapter(title: "Ad: Squarespace", startTime: 0, endTime: 60),
            Chapter(title: "Interview", startTime: 60, endTime: 1200),
            Chapter(title: "Sponsor", startTime: 1200, endTime: 1260),
            Chapter(title: "Ad: Outro", startTime: 3480, endTime: 3540),
        ]
        let segments = ChapterAdDetector.detect(from: chapters, episodeDuration: 3600)
        #expect(segments.count == 3)
        #expect(segments[0].kind == .preRoll)
        #expect(segments[1].kind == .midRoll)
        #expect(segments[2].kind == .postRoll)
        #expect(segments.allSatisfy { $0.source == .chapters && $0.confidence == 1.0 })
    }

    @Test func boundsChapterWithoutEndTime() {
        let chapters = [
            Chapter(title: "Intro", startTime: 0, endTime: 30),
            Chapter(title: "Ad: Squarespace", startTime: 30), // no endTime
            Chapter(title: "Interview", startTime: 90, endTime: 600),
        ]
        let segments = ChapterAdDetector.detect(from: chapters, episodeDuration: 600)
        #expect(segments.count == 1)
        #expect(segments[0].startTime == 30)
        #expect(segments[0].endTime == 90)
    }

    @Test func returnsEmptyForNoChapters() {
        #expect(ChapterAdDetector.detect(from: nil, episodeDuration: 3600).isEmpty)
        #expect(ChapterAdDetector.detect(from: [], episodeDuration: 3600).isEmpty)
    }

    // MARK: AdSkipEngine

    @Test func smartSkipJumpsWholeBreak() {
        let segments = [
            AdSegment(startTime: 600, endTime: 660, kind: .midRoll, confidence: 1, source: .chapters),
        ]
        // Inside the break, +30s lands mid-break -> jump to the end.
        #expect(AdSkipEngine.smartSkipTarget(currentTime: 610, forwardSeconds: 30, segments: segments) == 660)
        // Just before the break, +30s would land inside -> jump to the end.
        #expect(AdSkipEngine.smartSkipTarget(currentTime: 575, forwardSeconds: 30, segments: segments) == 660)
        // Far from any break -> normal skip.
        #expect(AdSkipEngine.smartSkipTarget(currentTime: 100, forwardSeconds: 30, segments: segments) == nil)
        // Past the break -> normal skip.
        #expect(AdSkipEngine.smartSkipTarget(currentTime: 700, forwardSeconds: 30, segments: segments) == nil)
        // No segments -> normal skip.
        #expect(AdSkipEngine.smartSkipTarget(currentTime: 610, forwardSeconds: 30, segments: []) == nil)
    }

    // MARK: SeekEventStore

    @Test func seekEventStoreLogsAndClears() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = SeekEventStore(fileURL: dir.appendingPathComponent("events.json"))
        // No-op seeks are ignored.
        store.log(episodeID: "ep", podcastID: "pod", from: 10, to: 10.5, trigger: .scrub)
        #expect(store.recentEvents(forPodcastID: "pod").isEmpty)
        for i in 0..<50 {
            store.log(
                episodeID: "ep",
                podcastID: "pod",
                from: Double(i),
                to: Double(i + 30),
                trigger: .forwardButton
            )
        }
        #expect(store.recentEvents(forPodcastID: "pod").count == 50)
        #expect(store.recentEvents(forPodcastID: "other").isEmpty)
        store.clear()
        #expect(store.recentEvents(forPodcastID: "pod").isEmpty)
    }

    // MARK: ShowAdProfileStore

    @Test func showAdProfileDefaultsAndRoundTrip() {
        let defaults = UserDefaults(suiteName: "AdSkipPhase0Tests")!
        defaults.removeObject(forKey: "showAdProfilesV1")
        let store = ShowAdProfileStore(defaults: defaults)

        let def = store.profile(for: "pod-1")
        #expect(def.mode == .smartSkip)
        #expect(def.introTrimSeconds == 0)
        #expect(def.outroTrimSeconds == 0)

        var custom = ShowAdProfile()
        custom.mode = .off
        custom.introTrimSeconds = 90
        custom.outroTrimSeconds = 30
        store.save(custom, for: "pod-1")

        let loaded = store.profile(for: "pod-1")
        #expect(loaded.mode == .off)
        #expect(loaded.introTrimSeconds == 90)
        #expect(loaded.outroTrimSeconds == 30)

        defaults.removeObject(forKey: "showAdProfilesV1")
    }

    // MARK: EpisodeAdAnalysisProvider

    @Test func analysisProviderDetectsAndCaches() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let provider = EpisodeAdAnalysisProvider(cacheDirectory: dir)
        let episode = Episode(
            podcastID: "pod",
            title: "T",
            duration: 3600,
            audioURL: URL(string: "https://example.com/e.mp3")!,
            chapters: [Chapter(title: "Ad: Squarespace", startTime: 0, endTime: 60)]
        )
        let first = provider.analysis(for: episode)
        #expect(first.segments.count == 1)
        #expect(first.segments[0].kind == .preRoll)
        // Second read comes from cache with identical content.
        let second = provider.analysis(for: episode)
        #expect(second.segments.count == 1)
        #expect(second.analyzerVersion == EpisodeAdAnalysis.currentAnalyzerVersion)
        provider.invalidate(episodeID: episode.id)
    }
}
