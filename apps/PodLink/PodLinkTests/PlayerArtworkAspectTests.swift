import Foundation
import Testing
@testable import PodLink

struct PlayerArtworkAspectTests {
    @Test
    func squareStaysSquare() {
        #expect(PlayerArtworkAspect.clamped(width: 1400, height: 1400) == 1)
        #expect(PlayerArtworkAspect.clamped(size: CGSize(width: 600, height: 600)) == 1)
    }

    @Test
    func landscapeKeepsNativeRatioUntilClamp() {
        #expect(PlayerArtworkAspect.clamped(width: 1600, height: 900) == 1600.0 / 900.0)
        #expect(PlayerArtworkAspect.clamped(width: 3000, height: 1000) == PlayerArtworkAspect.maximum)
    }

    @Test
    func portraitKeepsNativeRatioUntilClamp() {
        #expect(PlayerArtworkAspect.clamped(width: 900, height: 1200) == 900.0 / 1200.0)
        #expect(PlayerArtworkAspect.clamped(width: 500, height: 2000) == PlayerArtworkAspect.minimum)
    }

    @Test
    func invalidSizeFallsBackToDefault() {
        #expect(PlayerArtworkAspect.clamped(width: 0, height: 100) == PlayerArtworkAspect.defaultRatio)
        #expect(PlayerArtworkAspect.clamped(width: 100, height: 0) == PlayerArtworkAspect.defaultRatio)
    }
}
