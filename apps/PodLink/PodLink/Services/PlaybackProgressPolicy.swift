import Foundation

/// Thresholds for “finished” vs “partially listened” used across lists and persistence.
struct PlaybackProgressPolicy: Sendable {
    /// Treat as finished when this many seconds or fewer remain.
    var finishRemainingSeconds: TimeInterval
    /// Treat as finished when playback has reached at least this fraction of duration (0…1).
    var finishProgressFraction: Double
    /// Show partial-progress UI only after at least this many seconds of playback.
    var partialMinSeconds: TimeInterval
    /// Show partial-progress UI only after this fraction of duration (0…1), if duration is known.
    var partialMinProgressFraction: Double

    static var current: PlaybackProgressPolicy {
        let d = UserDefaults.standard
        return PlaybackProgressPolicy(
            finishRemainingSeconds: d.object(forKey: Keys.finishRemaining) as? TimeInterval ?? 45,
            finishProgressFraction: d.object(forKey: Keys.finishProgress) as? Double ?? 0.97,
            partialMinSeconds: d.object(forKey: Keys.partialMinSeconds) as? TimeInterval ?? 30,
            partialMinProgressFraction: d.object(forKey: Keys.partialMinProgress) as? Double ?? 0.02
        )
    }

    private enum Keys {
        static let finishRemaining = "playbackFinishRemainingSeconds"
        static let finishProgress = "playbackFinishProgressFraction"
        static let partialMinSeconds = "playbackPartialMinSeconds"
        static let partialMinProgress = "playbackPartialMinProgressFraction"
    }

    func effectiveDuration(feedDuration: TimeInterval, observedDuration: TimeInterval) -> TimeInterval {
        let fd = feedDuration
        let od = observedDuration
        if fd > 1, od > 1 { return max(fd, od) }
        if od > 1 { return od }
        return fd
    }

    func isFinished(playbackPosition: TimeInterval, duration: TimeInterval) -> Bool {
        guard duration > 0 else { return false }
        let remaining = duration - playbackPosition
        if remaining <= finishRemainingSeconds { return true }
        let progress = playbackPosition / duration
        return progress >= finishProgressFraction
    }

    func hasMeaningfulProgress(playbackPosition: TimeInterval, duration: TimeInterval) -> Bool {
        if duration > 0 {
            if playbackPosition >= partialMinSeconds { return true }
            return (playbackPosition / duration) >= partialMinProgressFraction
        }
        return playbackPosition >= partialMinSeconds
    }

    func shouldShowPartialProgress(isPlayed: Bool, playbackPosition: TimeInterval, duration: TimeInterval) -> Bool {
        if isPlayed { return false }
        if isFinished(playbackPosition: playbackPosition, duration: duration) { return false }
        return hasMeaningfulProgress(playbackPosition: playbackPosition, duration: duration)
    }
}
