import Testing
@testable import fit_min

struct fit_minTests {
    @Test func fixedScheduleMatchesSetNotation() {
        let configuration = SetTimerConfiguration(
            intervalType: .fixed,
            restType: .fixed,
            reps: 3,
            workSeconds: 45,
            restSeconds: 15
        )

        let segments = SetTimerScheduleBuilder.segments(for: configuration)

        #expect(segments.map(\.kind) == [.work, .rest, .work, .rest, .work])
        #expect(segments.map(\.durationSeconds) == [45, 15, 45, 15, 45])
        #expect(SetTimerScheduleBuilder.totalDuration(for: configuration) == 165)
        #expect(SetTimerTitleFormatter.title(for: configuration) == "3 × 45s / 15s")
    }

    @Test func ladderProgressiveRestBuildsIncreasingDurations() {
        let configuration = SetTimerConfiguration(
            intervalType: .ladder,
            restType: .progressive,
            reps: 4,
            workSeconds: 30,
            restSeconds: 10,
            workStepSeconds: 15,
            restStepSeconds: 5
        )

        let segments = SetTimerScheduleBuilder.segments(for: configuration)

        #expect(segments.map(\.durationSeconds) == [30, 10, 45, 15, 60, 20, 75])
        #expect(SetTimerTitleFormatter.title(for: configuration) == "30s / 10s → 45s / 15s → 1m / 20s → 1m 15s")
    }

    @Test func totalDurationUsesStandardClockFormat() {
        #expect(SetTimerTitleFormatter.clockDuration(0) == "00:00:00")
        #expect(SetTimerTitleFormatter.clockDuration(65) == "00:01:05")
        #expect(SetTimerTitleFormatter.clockDuration(3661) == "01:01:01")
    }

    @Test func extendingSessionAddsRestAndNextWork() {
        let configuration = SetTimerConfiguration(reps: 1, workSeconds: 20, restSeconds: 10)
        let original = SetTimerScheduleBuilder.segments(for: configuration)
        let extended = SetTimerScheduleBuilder.extendedSegments(from: original, configuration: configuration)

        #expect(original.map(\.durationSeconds) == [20])
        #expect(extended.map(\.kind) == [.work, .rest, .work])
        #expect(extended.map(\.durationSeconds) == [20, 10, 20])
    }

    @Test func finalFourSecondsUseBoopCue() {
        let segments = [
            IntervalSegment(kind: .work, durationSeconds: 8, repIndex: 0),
            IntervalSegment(kind: .rest, durationSeconds: 4, repIndex: 0),
        ]

        #expect(TimerSoundCueResolver.cue(forElapsedSecond: 0, segments: segments) == .tick)
        #expect(TimerSoundCueResolver.cue(forElapsedSecond: 4, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forElapsedSecond: 8, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forElapsedSecond: 12, segments: segments) == nil)
    }
}
