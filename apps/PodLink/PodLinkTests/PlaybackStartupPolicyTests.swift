import Foundation
import Testing
@testable import PodLink

struct PlaybackStartupPolicyTests {
    @Test
    func resumeSeekFallbackIsBounded() {
        // An 8s silent wait made play feel broken until pause → play. Keep the fallback short.
        #expect(PlaybackStartupPolicy.resumeSeekFallbackNanoseconds <= 2_500_000_000)
        #expect(PlaybackStartupPolicy.resumeSeekFallbackNanoseconds >= 500_000_000)
    }

    @Test
    func startupBufferIsMuchSmallerThanSteadyBuffer() {
        #expect(PlaybackStartupPolicy.initialForwardBufferDuration < PlaybackStartupPolicy.steadyForwardBufferDuration)
        #expect(PlaybackStartupPolicy.initialForwardBufferDuration <= 12)
    }
}
