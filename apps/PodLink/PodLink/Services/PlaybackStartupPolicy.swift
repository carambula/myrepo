import Foundation

/// Tunables for the first seconds of `play()` — keep mid-episode resume accurate without
/// leaving the UI silent until the user taps pause → play.
enum PlaybackStartupPolicy {
    /// If `readyToPlay` is missed (KVO race) or the network is slow, attempt seek+play after this.
    static let resumeSeekFallbackNanoseconds: UInt64 = 1_200_000_000

    /// Independent of the seek token: if audio still has not started, force `beginPlayback()`.
    /// Covers hanging mid-file seeks that consumed the seek token and never completed.
    static let forcePlayWatchdogNanoseconds: UInt64 = 1_500_000_000

    /// Short forward buffer so the first audible samples are not gated on a huge preroll.
    static let initialForwardBufferDuration: TimeInterval = 4

    /// After playback is actually running, prefer a deeper buffer to reduce mid-stream hitching.
    static let steadyForwardBufferDuration: TimeInterval = 45

    /// Startup resume seeks use a modest tolerance so HTTP range requests finish quickly.
    static let resumeSeekToleranceSeconds: TimeInterval = 2
}
