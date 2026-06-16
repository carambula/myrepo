import Foundation
import Observation

@Observable
final class SetTimerSessionController {
    private(set) var configuration: SetTimerConfiguration
    private(set) var segments: [IntervalSegment]
    private(set) var elapsedSeconds: Int = 0
    private(set) var isPlaying: Bool
    var showsCompletedReps = false
    var onComplete: (() -> Void)?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let soundService = TimerSoundService.shared
    @ObservationIgnored private var didNotifyCompletion = false

    init(configuration: SetTimerConfiguration, startsImmediately: Bool) {
        self.configuration = configuration.normalized
        self.segments = SetTimerScheduleBuilder.segments(for: configuration)
        self.isPlaying = false
        if startsImmediately {
            start()
        }
    }

    deinit {
        timer?.invalidate()
    }

    var totalSeconds: Int {
        segments.reduce(0) { $0 + $1.durationSeconds }
    }

    var marks: [TimerSecondMark] {
        TimerSecondMark.marks(for: segments)
    }

    var currentMarkID: Int? {
        guard elapsedSeconds < totalSeconds else { return nil }
        return elapsedSeconds
    }

    var isComplete: Bool {
        totalSeconds > 0 && elapsedSeconds >= totalSeconds
    }

    var currentSegmentIndex: Int {
        var boundary = 0
        for (index, segment) in segments.enumerated() {
            boundary += segment.durationSeconds
            if elapsedSeconds < boundary {
                return index
            }
        }
        return max(segments.count - 1, 0)
    }

    var currentSegment: IntervalSegment? {
        guard !segments.isEmpty else { return nil }
        return segments[min(currentSegmentIndex, segments.count - 1)]
    }

    var completedReps: Int {
        return segments.enumerated().reduce(0) { count, pair in
            let (index, segment) = pair
            guard segment.kind == .work else { return count }
            return elapsedSeconds >= endSecond(forSegmentAt: index) ? count + 1 : count
        }
    }

    var repsRemaining: Int {
        max(0, segments.filter { $0.kind == .work }.count - completedReps)
    }

    var centerNumber: Int {
        showsCompletedReps ? completedReps : repsRemaining
    }

    var centerLabel: String {
        showsCompletedReps ? "complete" : "remaining"
    }

    func start() {
        guard !isComplete else { return }
        isPlaying = true
        scheduleTimer()
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func togglePlayPause() {
        isPlaying ? pause() : start()
    }

    func skipBackward() {
        elapsedSeconds = startSecond(forSegmentAt: max(currentSegmentIndex - 1, 0))
        didNotifyCompletion = false
    }

    func skipForward() {
        let nextIndex = min(currentSegmentIndex + 1, max(segments.count - 1, 0))
        elapsedSeconds = startSecond(forSegmentAt: nextIndex)
        didNotifyCompletion = false
    }

    func addRepAndRest() {
        segments = SetTimerScheduleBuilder.extendedSegments(from: segments, configuration: configuration)
        didNotifyCompletion = false
        if isComplete {
            elapsedSeconds = max(0, totalSeconds - (segments.last?.durationSeconds ?? 1))
        }
    }

    func toggleCenterMode() {
        showsCompletedReps.toggle()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.advanceOneSecond()
        }
    }

    private func advanceOneSecond() {
        guard isPlaying else { return }
        if let cue = TimerSoundCueResolver.cue(forElapsedSecond: elapsedSeconds, segments: segments) {
            soundService.play(cue)
        }
        elapsedSeconds += 1
        if isComplete {
            pause()
            notifyCompletionIfNeeded()
        }
    }

    private func notifyCompletionIfNeeded() {
        guard !didNotifyCompletion else { return }
        didNotifyCompletion = true
        onComplete?()
    }

    private func startSecond(forSegmentAt index: Int) -> Int {
        guard index > 0 else { return 0 }
        return segments.prefix(index).reduce(0) { $0 + $1.durationSeconds }
    }

    private func endSecond(forSegmentAt index: Int) -> Int {
        segments.prefix(index + 1).reduce(0) { $0 + $1.durationSeconds }
    }

}
