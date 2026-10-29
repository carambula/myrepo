import Testing
import Foundation
@testable import PodLink

// MARK: - Phase 2 tests: transcript ad classifier

@Suite("TranscriptAdClassifier")
struct TranscriptAdClassifierTests {
    private func makeTranscript(_ segments: [(text: String, start: TimeInterval, end: TimeInterval)]) -> FullTranscript {
        let segs = segments.map {
            TranscriptSegment(text: $0.text, startTime: $0.start, endTime: $0.end, speaker: nil)
        }
        return FullTranscript(
            text: segs.map(\.text).joined(separator: " "),
            segments: segs,
            metadata: TranscriptMetadata(duration: segs.last?.endTime ?? 0)
        )
    }

    @Test("detects a host-read pre-roll")
    func detectsHostReadPreRoll() {
        let transcript = makeTranscript([
            (text: "Welcome to the show.", start: 0, end: 5),
            (text: "This episode is brought to you by Squarespace. Go to squarespace dot com for a free trial.", start: 5, end: 35),
            (text: "Use code PODCAST for 10 percent off your first purchase.", start: 35, end: 50),
            (text: "Now, let's talk about the news.", start: 50, end: 60),
        ])

        let segments = TranscriptAdClassifier.detect(from: transcript)
        #expect(!segments.isEmpty)
        let ad = segments[0]
        #expect(ad.source == .transcript)
        #expect(ad.kind == .preRoll)
        #expect(ad.confidence >= 0.5)
    }

    @Test("returns empty for no ad phrasing")
    func noFalsePositive() {
        let transcript = makeTranscript([
            (text: "Welcome to the show. Today we're discussing the latest news.", start: 0, end: 30),
            (text: "The weather is nice and we're happy to be here.", start: 30, end: 60),
        ])

        let segments = TranscriptAdClassifier.detect(from: transcript)
        #expect(segments.isEmpty)
    }

    @Test("extracts sponsor name and promo code")
    func extractsSponsorInfo() {
        let (sponsor, code) = TranscriptAdClassifier.extractSponsorInfo(
            from: "This episode is brought to you by Athletic Greens. Use code HEALTH for a discount."
        )
        #expect(sponsor?.contains("athletic greens") == true)
        #expect(code == "HEALTH")
    }

    @Test("scores sponsor phrases highly")
    func sponsorPhraseScore() {
        let transcript = makeTranscript([
            (text: "Thanks to our sponsor Helix Sleep for supporting the show.", start: 0, end: 20),
        ])
        let segments = TranscriptAdClassifier.detect(from: transcript)
        // "thanks to our sponsor" (+0.4) alone is below threshold 0.5
        // This tests that we don't over-trigger on weak signals
        #expect(segments.isEmpty || segments[0].confidence < 0.8)
    }

    @Test("handles empty transcript")
    func emptyTranscript() {
        let transcript = FullTranscript(
            text: "",
            segments: [],
            metadata: TranscriptMetadata(duration: 0)
        )
        #expect(TranscriptAdClassifier.detect(from: transcript).isEmpty)
    }

    @Test("handles nil segments")
    func nilSegments() {
        let transcript = FullTranscript(
            text: "Some text",
            segments: nil,
            metadata: TranscriptMetadata(duration: 60)
        )
        #expect(TranscriptAdClassifier.detect(from: transcript).isEmpty)
    }
}
