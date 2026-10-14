import Foundation
import Testing
@testable import PodLink

struct PlaybackStartupPolicyTests {
    @Test
    func resumeSeekFallbackIsBounded() {
        #expect(PlaybackStartupPolicy.resumeSeekFallbackNanoseconds <= 2_500_000_000)
        #expect(PlaybackStartupPolicy.resumeSeekFallbackNanoseconds >= 500_000_000)
    }

    @Test
    func forcePlayWatchdogIsShortAndCoversHangingSeeks() {
        // Pause → play worked because resume() skips the seek gate. The watchdog must fire
        // quickly enough that the first play press does not feel broken — including when a
        // mid-file seek has already consumed the seek token and never completes.
        #expect(PlaybackStartupPolicy.forcePlayWatchdogNanoseconds <= 2_000_000_000)
        #expect(PlaybackStartupPolicy.forcePlayWatchdogNanoseconds >= 750_000_000)
        #expect(
            PlaybackStartupPolicy.forcePlayWatchdogNanoseconds
                >= PlaybackStartupPolicy.resumeSeekFallbackNanoseconds
        )
    }

    @Test
    func startupBufferIsMuchSmallerThanSteadyBuffer() {
        #expect(PlaybackStartupPolicy.initialForwardBufferDuration < PlaybackStartupPolicy.steadyForwardBufferDuration)
        #expect(PlaybackStartupPolicy.initialForwardBufferDuration <= 12)
    }

    @Test
    func resumeSeekToleranceIsLenientEnoughForStreams() {
        #expect(PlaybackStartupPolicy.resumeSeekToleranceSeconds >= 1)
        #expect(PlaybackStartupPolicy.resumeSeekToleranceSeconds <= 5)
    }
}
