import Foundation
import Observation

@Observable
final class SetTimerSessionController {
    private(set) var configuration: SetTimerConfiguration
    private(set) var segments: [IntervalSegment]
    private(set) var elapsedSeconds: Int = 0
    private(set) var isPlaying: Bool
    private(set) var readyCountdownRemaining: Int?
    private(set) var readyCountdownWindProgress: Double = 0
    var showsCompletedReps = false
    var onComplete: (() -> Void)?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var resetTask: Task<Void, Never>?
    @ObservationIgnored private let soundService = TimerSoundService.shared
    @ObservationIgnored private var didNotifyCompletion = false
    @ObservationIgnored private var playbackStartDate: Date?
    @ObservationIgnored private var playbackStartElapsedSeconds = 0
    @ObservationIgnored private var lastSoundElapsedSecond = 0
    @ObservationIgnored private var readyCountdownStartDate: Date?
    @ObservationIgnored private var readyCountdownLastSecond = 0

    init(configuration: SetTimerConfiguration, segments: [IntervalSegment]? = nil, startsImmediately: Bool) {
        self.configuration = configuration.normalized
        self.segments = segments ?? SetTimerScheduleBuilder.segments(for: configuration)
        self.isPlaying = false
        if startsImmediately {
            start()
        }
    }

    deinit {
        timer?.invalidate()
        resetTask?.cancel()
        soundService.endTimerPlayback()
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

    var isReadyCountdownActive: Bool {
        readyCountdownRemaining != nil
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

    var currentSegmentElapsedSeconds: Int {
        guard !segments.isEmpty else { return 0 }
        return max(0, min((currentSegment?.durationSeconds ?? 0), elapsedSeconds - startSecond(forSegmentAt: currentSegmentIndex)))
    }

    var currentSegmentRemainingSeconds: Int {
        guard let currentSegment else { return 0 }
        return max(0, currentSegment.durationSeconds - currentSegmentElapsedSeconds)
    }

    var currentIntervalDisplaySeconds: Int {
        showsCompletedReps ? currentSegmentElapsedSeconds : currentSegmentRemainingSeconds
    }

    var isInFinalIntervalCueWindow: Bool {
        TimerSoundCueResolver.cue(forCompletedElapsedSecond: elapsedSeconds, segments: segments) == .boop
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
        resetTask?.cancel()
        guard !isComplete else { return }
        if shouldUseReadyCountdown {
            beginReadyCountdown()
            return
        }
        beginPlayback()
    }

    private func beginPlayback(playsStartCue: Bool = true) {
        clearReadyCountdown()
        isPlaying = true
        playbackStartDate = Date()
        playbackStartElapsedSeconds = elapsedSeconds
        lastSoundElapsedSecond = elapsedSeconds
        soundService.beginTimerPlayback()
        if playsStartCue {
            soundService.play(.tick)
        }
        scheduleTimer()
    }

    func pause() {
        syncElapsedWithClock(playsSound: false)
        isPlaying = false
        clearReadyCountdown()
        playbackStartDate = nil
        timer?.invalidate()
        timer = nil
        soundService.endTimerPlayback()
    }

    func togglePlayPause() {
        isPlaying ? pause() : start()
    }

    func skipBackward() {
        resetTask?.cancel()
        clearReadyCountdown()
        elapsedSeconds = startSecond(forSegmentAt: max(currentSegmentIndex - 1, 0))
        preservePlaybackCadenceAfterManualElapsedChange()
        didNotifyCompletion = false
    }

    func skipForward() {
        resetTask?.cancel()
        clearReadyCountdown()
        let nextIndex = min(currentSegmentIndex + 1, max(segments.count - 1, 0))
        elapsedSeconds = startSecond(forSegmentAt: nextIndex)
        preservePlaybackCadenceAfterManualElapsedChange()
        didNotifyCompletion = false
    }

    func addRepAndRest() {
        resetTask?.cancel()
        segments = SetTimerScheduleBuilder.extendedSegments(from: segments, configuration: configuration)
        didNotifyCompletion = false
        if isComplete {
            elapsedSeconds = max(0, totalSeconds - (segments.last?.durationSeconds ?? 1))
        }
        resetPlaybackAnchorIfNeeded()
    }

    func toggleCenterMode() {
        showsCompletedReps.toggle()
    }

    func refreshSoundPlayback() {
        soundService.endTimerPlayback()
        if isPlaying {
            soundService.beginTimerPlayback()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.syncElapsedWithClock(playsSound: true)
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func syncElapsedWithClock(playsSound: Bool) {
        guard isPlaying else { return }
        if isReadyCountdownActive {
            syncReadyCountdown(playsSound: playsSound)
            return
        }
        guard let playbackStartDate else { return }

        let elapsedSinceStart = max(0, Int(Date().timeIntervalSince(playbackStartDate)))
        let clockElapsedSeconds = min(totalSeconds, playbackStartElapsedSeconds + elapsedSinceStart)
        guard clockElapsedSeconds != elapsedSeconds else { return }

        elapsedSeconds = clockElapsedSeconds
        if playsSound,
           elapsedSeconds > lastSoundElapsedSecond,
           let cue = TimerSoundCueResolver.cue(forCompletedElapsedSecond: elapsedSeconds, segments: segments) {
            soundService.play(cue)
        }
        lastSoundElapsedSecond = max(lastSoundElapsedSecond, elapsedSeconds)

        if isComplete {
            isPlaying = false
            self.playbackStartDate = nil
            timer?.invalidate()
            timer = nil
            soundService.playCompletion()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 450_000_000)
                self?.soundService.endTimerPlayback()
            }
            notifyCompletionIfNeeded()
            scheduleResetAfterCompletion()
        }
    }

    private func resetPlaybackAnchorIfNeeded() {
        lastSoundElapsedSecond = elapsedSeconds
        guard isPlaying else { return }
        clearReadyCountdown()
        playbackStartDate = Date()
        playbackStartElapsedSeconds = elapsedSeconds
    }

    private func preservePlaybackCadenceAfterManualElapsedChange() {
        lastSoundElapsedSecond = elapsedSeconds
        guard isPlaying else { return }
        guard let playbackStartDate else {
            self.playbackStartDate = Date()
            playbackStartElapsedSeconds = elapsedSeconds
            return
        }

        let elapsedSinceStart = max(0, Int(Date().timeIntervalSince(playbackStartDate)))
        playbackStartElapsedSeconds = elapsedSeconds - elapsedSinceStart
    }

    private var shouldUseReadyCountdown: Bool {
        let key = "fitMin.readySetGoEnabled"
        let isEnabled = UserDefaults.standard.object(forKey: key) != nil && UserDefaults.standard.bool(forKey: key)
        return isEnabled && elapsedSeconds == 0 && !isReadyCountdownActive
    }

    private func beginReadyCountdown() {
        clearReadyCountdown()
        isPlaying = true
        readyCountdownRemaining = 3
        readyCountdownWindProgress = 0
        readyCountdownStartDate = Date()
        readyCountdownLastSecond = 0
        playbackStartDate = nil
        playbackStartElapsedSeconds = elapsedSeconds
        lastSoundElapsedSecond = elapsedSeconds
        soundService.beginTimerPlayback()
        soundService.play(.boop)
        scheduleTimer()
    }

    private func syncReadyCountdown(playsSound: Bool) {
        guard let readyCountdownStartDate else { return }
        let elapsed = max(0, Date().timeIntervalSince(readyCountdownStartDate))
        guard elapsed < 3 else {
            if playsSound {
                soundService.play(.boop)
            }
            clearReadyCountdown()
            beginPlayback(playsStartCue: false)
            return
        }

        let currentSecond = min(2, Int(elapsed))
        let nextRemaining = 3 - currentSecond
        readyCountdownRemaining = nextRemaining
        readyCountdownWindProgress = elapsed - Double(currentSecond)

        if playsSound, currentSecond > readyCountdownLastSecond {
            readyCountdownLastSecond = currentSecond
            soundService.play(.boop)
        }
    }

    private func clearReadyCountdown() {
        readyCountdownRemaining = nil
        readyCountdownWindProgress = 0
        readyCountdownStartDate = nil
        readyCountdownLastSecond = 0
    }

    private func notifyCompletionIfNeeded() {
        guard !didNotifyCompletion else { return }
        didNotifyCompletion = true
        onComplete?()
    }

    private func scheduleResetAfterCompletion() {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.isComplete, !self.isPlaying else { return }
                self.elapsedSeconds = 0
                self.lastSoundElapsedSecond = 0
                self.didNotifyCompletion = false
            }
        }
    }

    private func startSecond(forSegmentAt index: Int) -> Int {
        guard index > 0 else { return 0 }
        return segments.prefix(index).reduce(0) { $0 + $1.durationSeconds }
    }

    private func endSecond(forSegmentAt index: Int) -> Int {
        segments.prefix(index + 1).reduce(0) { $0 + $1.durationSeconds }
    }

}
