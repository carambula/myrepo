import Foundation
import Testing
@testable import PodLink

struct PlaybackResumeSeekTests {
    @Test
    func appliesWhenPlaybackHasNotMovedPastTarget() {
        #expect(PlaybackResumeSeek.shouldApply(target: 600, live: 0))
        #expect(PlaybackResumeSeek.shouldApply(target: 600, live: 600))
        #expect(PlaybackResumeSeek.shouldApply(target: 600, live: 601.2))
    }

    @Test
    func rejectsRewindWhenLiveHasAdvanced() {
        #expect(!PlaybackResumeSeek.shouldApply(target: 600, live: 630))
        #expect(!PlaybackResumeSeek.shouldApply(target: 600, live: 601.6))
    }

    @Test
    func rejectsNonPositiveTargets() {
        #expect(!PlaybackResumeSeek.shouldApply(target: 0, live: 0))
        #expect(!PlaybackResumeSeek.shouldApply(target: -4, live: 10))
    }
}
