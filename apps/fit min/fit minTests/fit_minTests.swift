import CoreGraphics
import Foundation
import SwiftData
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

    @Test func totalDurationHidesHourPlaceUntilNeeded() {
        #expect(SetTimerTitleFormatter.clockDuration(0) == "0:00")
        #expect(SetTimerTitleFormatter.clockDuration(65) == "1:05")
        #expect(SetTimerTitleFormatter.clockDuration(3661) == "01:01:01")
    }

    @Test func timingDisplayModesExposeInclusiveAndExclusiveTitles() {
        #expect(TimingDisplayMode.inclusive.title == "Inclusive")
        #expect(TimingDisplayMode.exclusive.title == "Exclusive")
    }

    @Test func extendingSessionAddsRestAndNextWork() {
        let configuration = SetTimerConfiguration(reps: 1, workSeconds: 20, restSeconds: 10)
        let original = SetTimerScheduleBuilder.segments(for: configuration)
        let extended = SetTimerScheduleBuilder.extendedSegments(from: original, configuration: configuration)

        #expect(original.map(\.durationSeconds) == [20])
        #expect(extended.map(\.kind) == [.work, .rest, .work])
        #expect(extended.map(\.durationSeconds) == [20, 10, 20])
    }

    @Test func forwardingFromLastIntervalCompletesSet() {
        UserDefaults.standard.set(false, forKey: "fitMin.timerSoundsEnabled")
        let configuration = SetTimerConfiguration(reps: 1, workSeconds: 20, restSeconds: 10)
        let session = SetTimerSessionController(configuration: configuration, startsImmediately: false)

        session.skipForward()

        #expect(session.elapsedSeconds == session.totalSeconds)
        #expect(session.isComplete)
        UserDefaults.standard.removeObject(forKey: "fitMin.timerSoundsEnabled")
    }

    @Test func finalFourSecondsUseBoopCue() {
        let segments = [
            IntervalSegment(kind: .work, durationSeconds: 8, repIndex: 0),
            IntervalSegment(kind: .rest, durationSeconds: 4, repIndex: 0),
        ]

        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 1, segments: segments) == .tick)
        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 4, segments: segments) == .tick)
        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 5, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 8, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 9, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 12, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forCompletedElapsedSecond: 13, segments: segments) == nil)
    }

    @Test func activeTickCuePlacesFourthBoopOnLastTickOfInterval() {
        let segments = [
            IntervalSegment(kind: .work, durationSeconds: 8, repIndex: 0),
            IntervalSegment(kind: .rest, durationSeconds: 8, repIndex: 0),
        ]

        #expect(TimerSoundCueResolver.cue(forActiveMarkID: 3, segments: segments) == .tick)
        #expect(TimerSoundCueResolver.cue(forActiveMarkID: 4, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forActiveMarkID: 7, segments: segments) == .boop)
        #expect(TimerSoundCueResolver.cue(forActiveMarkID: 8, segments: segments) == .tick)
    }

    @Test func defaultPresetListIncludesRequestedStarterTimersInOrder() {
        #expect(DefaultSetTimerSeeder.presets.map(\.title) == [
            "Tabata Sprint",
            "Classic HIIT",
            "Muscle Burner",
            "Cardio Build",
            "Endurance Climb",
            "Proportional Climb",
            "Power Drop",
            "Fatigue Crusher",
            "Speed Finish",
            "Classic Peak",
            "Short Blitz",
            "Heavy Endurance",
            "Heart Rate Shock",
            "Sprint Waves",
            "High-Low Wave",
        ])
    }

    @Test func defaultPresetCustomSchedulesMatchRequestedIntervals() {
        let presets = Dictionary(uniqueKeysWithValues: DefaultSetTimerSeeder.presets.map { ($0.title, $0) })

        #expect(presets["Power Drop"]?.segments?.map(\.durationSeconds) == [60, 30, 45, 30, 30])
        #expect(presets["Fatigue Crusher"]?.segments?.map(\.durationSeconds) == [90, 30, 60, 20, 30])
        #expect(presets["Classic Peak"]?.segments?.map(\.durationSeconds) == [30, 15, 45, 15, 60, 15, 45, 15, 30])
        #expect(presets["Sprint Waves"]?.segments?.map(\.durationSeconds) == [15, 45, 30, 30, 15, 45, 30])
    }

    @Test func blockStyleLabelUsesExactWorkoutSegments() {
        let segments = [
            IntervalSegment(kind: .work, durationSeconds: 30, repIndex: 0),
            IntervalSegment(kind: .rest, durationSeconds: 15, repIndex: 0),
            IntervalSegment(kind: .work, durationSeconds: 60, repIndex: 1),
            IntervalSegment(kind: .rest, durationSeconds: 30, repIndex: 1),
            IntervalSegment(kind: .work, durationSeconds: 30, repIndex: 2),
        ]

        #expect(SetTimerTitleFormatter.blockTitle(for: segments) == "30s/15s → 60s/30s → 30s")
    }

    @Test func trailingSwipeMetricsSnapAndClampOffsets() {
        let revealedWidth = TrailingSwipeMetrics.revealedWidth(actionCount: 3)
        #expect(revealedWidth == 216)
        #expect(TrailingSwipeMetrics.clampedOffset(0, revealedWidth: revealedWidth) == 0)
        #expect(TrailingSwipeMetrics.clampedOffset(-108, revealedWidth: revealedWidth) == -108)
        #expect(TrailingSwipeMetrics.clampedOffset(-216, revealedWidth: revealedWidth) == -216)
        #expect(TrailingSwipeMetrics.clampedOffset(-256, revealedWidth: revealedWidth) == -226)
        #expect(TrailingSwipeMetrics.clampedOffset(8, revealedWidth: revealedWidth) == 2)
        #expect(TrailingSwipeMetrics.restOffset(predictedOffset: -50, revealedWidth: revealedWidth) == 0)
        #expect(TrailingSwipeMetrics.restOffset(predictedOffset: -80, revealedWidth: revealedWidth) == -216)
        #expect(TrailingSwipeMetrics.isHorizontalDrag(translation: CGSize(width: -20, height: 4)))
        #expect(!TrailingSwipeMetrics.isHorizontalDrag(translation: CGSize(width: -4, height: 20)))
    }

    @Test func duplicatedTimerTitleAppendsCopy() {
        #expect(SetTimerDuplicator.duplicatedTitle(from: "") == "")
        #expect(SetTimerDuplicator.duplicatedTitle(from: "  ") == "")
        #expect(SetTimerDuplicator.duplicatedTitle(from: "Tabata Sprint") == "Tabata Sprint copy")
        #expect(SetTimerDuplicator.duplicatedTitle(from: "  Muscle Burner  ") == "Muscle Burner copy")
    }

    @Test func duplicatedTimerKeepsCustomSegmentsWhenConfigurationIsUnchanged() {
        let configuration = SetTimerConfiguration(
            intervalType: .ladder,
            restType: .regressive,
            reps: 3,
            workSeconds: 60,
            restSeconds: 30,
            workStepSeconds: 15
        )
        let originalSegments = [
            IntervalSegment(kind: .work, durationSeconds: 60, repIndex: 0),
            IntervalSegment(kind: .rest, durationSeconds: 30, repIndex: 0),
            IntervalSegment(kind: .work, durationSeconds: 45, repIndex: 1),
            IntervalSegment(kind: .rest, durationSeconds: 30, repIndex: 1),
            IntervalSegment(kind: .work, durationSeconds: 30, repIndex: 2),
        ]

        let copied = SetTimerDuplicator.copiedCustomSegments(
            originalConfiguration: configuration,
            originalCustomSegments: originalSegments,
            newConfiguration: configuration
        )

        #expect(copied?.map(\.kind) == originalSegments.map(\.kind))
        #expect(copied?.map(\.durationSeconds) == originalSegments.map(\.durationSeconds))
        let copiedIDs = copied?.map(\.id) ?? []
        #expect(!copiedIDs.isEmpty)
        #expect(Set(copiedIDs).isDisjoint(with: Set(originalSegments.map(\.id))))
    }

    @Test func duplicatedTimerDropsCustomSegmentsWhenConfigurationChanges() {
        let original = SetTimerConfiguration(reps: 3, workSeconds: 60, restSeconds: 30)
        var edited = original
        edited.workSeconds = 90
        let segments = [IntervalSegment(kind: .work, durationSeconds: 60, repIndex: 0)]

        #expect(
            SetTimerDuplicator.copiedCustomSegments(
                originalConfiguration: original,
                originalCustomSegments: segments,
                newConfiguration: edited
            ) == nil
        )
    }

    @MainActor
    @Test func makeDuplicateCopiesWorkoutWithoutSharingHistory() throws {
        let schema = Schema([SetTimer.self])
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = ModelContext(container)
        let configuration = SetTimerConfiguration(
            intervalType: .ladder,
            restType: .regressive,
            reps: 3,
            workSeconds: 60,
            restSeconds: 30,
            workStepSeconds: 15
        )
        let original = SetTimer(
            completedCount: 4,
            customTitle: "Power Drop",
            configuration: configuration,
            customSegments: [
                IntervalSegment(kind: .work, durationSeconds: 60, repIndex: 0),
                IntervalSegment(kind: .rest, durationSeconds: 30, repIndex: 0),
                IntervalSegment(kind: .work, durationSeconds: 45, repIndex: 1),
                IntervalSegment(kind: .rest, durationSeconds: 30, repIndex: 1),
                IntervalSegment(kind: .work, durationSeconds: 30, repIndex: 2),
            ]
        )
        original.lastUsedAt = Date()
        context.insert(original)

        let duplicate = original.makeDuplicate(configuration: original.configuration, customTitle: original.customTitle)
        context.insert(duplicate)

        #expect(duplicate.customTitle == "Power Drop copy")
        #expect(duplicate.completedCount == 0)
        #expect(duplicate.lastUsedAt == nil)
        #expect(duplicate.configuration == original.configuration)
        #expect(duplicate.schedule.map(\.durationSeconds) == original.schedule.map(\.durationSeconds))
        #expect(duplicate.customSegments?.map(\.id) != original.customSegments?.map(\.id))
    }
}
