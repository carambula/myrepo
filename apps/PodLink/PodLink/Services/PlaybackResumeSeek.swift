import Foundation

/// Guards mid-play rewinds when a delayed resume-seek finally lands.
enum PlaybackResumeSeek {
    /// Allow a small lead so a just-started resume is not treated as "already past."
    static let rewindGrace: TimeInterval = 1.5

    /// `false` when applying `target` would jump backward over audio the listener already heard.
    static func shouldApply(target: TimeInterval, live: TimeInterval, grace: TimeInterval = rewindGrace) -> Bool {
        guard target.isFinite, target > 0 else { return false }
        guard live.isFinite, live >= 0 else { return true }
        return live <= target + grace
    }
}
