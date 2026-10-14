import Foundation
import Testing
@testable import PodLink

struct PlaybackStartupPolicyTests {
    @Test
    func resumeSeekRetryFallbackIsShort() {
        // Ready-wait before the first seek is what made resume feel stuck. The retry path
        // only runs when an immediate seek was ignored, and must stay brief.
        #expect(PlaybackStartupPolicy.resumeSeekRetryFallbackNanoseconds <= 1_200_000_000)
        #expect(PlaybackStartupPolicy.resumeSeekRetryFallbackNanoseconds >= 250_000_000)
    }

    @Test
    func forcePlayWatchdogIsShortAndCoversHangingSeeks() {
        #expect(PlaybackStartupPolicy.forcePlayWatchdogNanoseconds <= 2_000_000_000)
        #expect(PlaybackStartupPolicy.forcePlayWatchdogNanoseconds >= 750_000_000)
        #expect(
            PlaybackStartupPolicy.forcePlayWatchdogNanoseconds
                >= PlaybackStartupPolicy.resumeSeekRetryFallbackNanoseconds
        )
    }

    @Test
    func startupBufferIsMuchSmallerThanSteadyBuffer() {
        #expect(PlaybackStartupPolicy.initialForwardBufferDuration < PlaybackStartupPolicy.steadyForwardBufferDuration)
        #expect(PlaybackStartupPolicy.initialForwardBufferDuration <= 4)
    }

    @Test
    func startupResumeUsesApproximateSeek() {
        #expect(PlaybackStartupPolicy.usesApproximateResumeSeek)
    }
}
