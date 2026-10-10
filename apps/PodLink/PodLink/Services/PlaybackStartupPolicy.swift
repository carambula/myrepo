import Foundation

/// Tunables for the first seconds of `play()` — keep mid-episode resume accurate without
/// leaving the UI silent for many seconds while the item becomes ready.
enum PlaybackStartupPolicy {
    /// If `readyToPlay` is missed (KVO race) or the network is slow, seek+play after this.
    static let resumeSeekFallbackNanoseconds: UInt64 = 2_000_000_000

    /// Short forward buffer so the first audible samples are not gated on a huge preroll.
    static let initialForwardBufferDuration: TimeInterval = 8

    /// After playback is actually running, prefer a deeper buffer to reduce mid-stream hitching.
    static let steadyForwardBufferDuration: TimeInterval = 45
}
