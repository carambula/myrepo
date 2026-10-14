import Foundation

/// Tunables for the first seconds of `play()` — mid-episode resume should seek quickly and
/// start audio without waiting on an exact sample or a long readyToPlay gate.
enum PlaybackStartupPolicy {
    /// Only used when the first immediate seek is ignored (item not ready yet).
    static let resumeSeekRetryFallbackNanoseconds: UInt64 = 800_000_000

    /// Independent of the seek token: if audio still has not started, force `beginPlayback()`.
    static let forcePlayWatchdogNanoseconds: UInt64 = 1_500_000_000

    /// Short forward buffer so the first audible samples are not gated on a huge preroll.
    static let initialForwardBufferDuration: TimeInterval = 2

    /// After playback is actually running, prefer a deeper buffer to reduce mid-stream hitching.
    static let steadyForwardBufferDuration: TimeInterval = 45

    /// Startup resume seeks use indefinite tolerances so AVPlayer can snap to a nearby keyframe
    /// instead of blocking on an exact sample (the slow path for HTTP byte-range seeks).
    static let usesApproximateResumeSeek = true
}
