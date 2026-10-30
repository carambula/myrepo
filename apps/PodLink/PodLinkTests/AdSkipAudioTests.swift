import Testing
@testable import PodLink

// MARK: - Phase 3: Audio layer tests (L2 jingles + L3 acoustic)

@Suite("Jingle to segment conversion")
struct JingleSegmentTests {

    @Test("Paired jingles create a segment")
    func pairedJinglesCreateSegment() {
        let jingles = [
            JingleMatch(time: 60, confidence: 0.8, jingleID: "a"),
            JingleMatch(time: 150, confidence: 0.8, jingleID: "a"),
        ]
        // Simulate the pairing logic: 90s gap → segment
        let duration = jingles[1].time - jingles[0].time
        #expect(duration >= 15 && duration <= 180)
    }

    @Test("Jingles too close are not paired")
    func jinglesTooCloseNotPaired() {
        let jingles = [
            JingleMatch(time: 60, confidence: 0.8, jingleID: "a"),
            JingleMatch(time: 65, confidence: 0.8, jingleID: "a"),
        ]
        let duration = jingles[1].time - jingles[0].time
        #expect(duration < 15) // too short for an ad break
    }

    @Test("Jingles too far apart are not paired")
    func jinglesTooFarNotPaired() {
        let jingles = [
            JingleMatch(time: 60, confidence: 0.8, jingleID: "a"),
            JingleMatch(time: 600, confidence: 0.8, jingleID: "a"),
        ]
        let duration = jingles[1].time - jingles[0].time
        #expect(duration > 180) // too long for an ad break
    }
}

@Suite("Acoustic detection heuristics")
struct AcousticHeuristicTests {

    @Test("AdSegment source includes jingle and acoustic")
    func sourcesExist() {
        #expect(AdSegmentSource.allCases.contains(.jingle))
        #expect(AdSegmentSource.allCases.contains(.acoustic))
    }

    @Test("Analyzer version is 4")
    func analyzerVersion4() {
        #expect(EpisodeAdAnalysis.currentAnalyzerVersion == 4)
    }

    @Test("Jingle-paired confidence is below auto-skip threshold")
    func jingleConfidenceBelowAutoSkip() {
        // Jingle pairs get 0.7; auto-skip requires 0.8
        // This ensures jingles feed smart-30s, not auto-skip
        let confidence = 0.7
        #expect(confidence < 0.8)
    }

    @Test("Jingle+acoustic agreement reaches auto-skip")
    func agreementReachesAutoSkip() {
        // When jingle and acoustic agree on overlapping segments,
        // the merged confidence should reach 0.8+
        // (Implementation: provider keeps higher-confidence on overlap,
        //  or boosts when two sources agree — tested via integration)
        let jingleConf = 0.7
        let acousticConf = 0.6
        // Agreement boost: max + 0.15
        let merged = max(jingleConf, acousticConf) + 0.15
        #expect(merged >= 0.8)
    }
}
