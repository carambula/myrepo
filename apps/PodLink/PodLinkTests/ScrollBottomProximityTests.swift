import Foundation
import Testing
@testable import PodLink

struct ScrollBottomProximityTests {
    @Test
    func unloadedSentinelIsNotNearBottom() {
        #expect(
            !ScrollBottomProximity.isNearBottom(
                sentinelMinY: 0,
                viewportHeight: 700,
                scrollOffset: 0
            )
        )
        #expect(
            !ScrollBottomProximity.isNearBottom(
                sentinelMinY: 0,
                viewportHeight: 700,
                scrollOffset: 400
            )
        )
    }

    @Test
    func shortContentAtRestIsNotNearBottom() {
        #expect(
            !ScrollBottomProximity.isNearBottom(
                sentinelMinY: 620,
                viewportHeight: 700,
                scrollOffset: 0
            )
        )
    }

    @Test
    func scrolledToEndIsNearBottom() {
        #expect(
            ScrollBottomProximity.isNearBottom(
                sentinelMinY: 680,
                viewportHeight: 700,
                scrollOffset: 240
            )
        )
    }

    @Test
    func midListIsNotNearBottom() {
        #expect(
            !ScrollBottomProximity.isNearBottom(
                sentinelMinY: 2400,
                viewportHeight: 700,
                scrollOffset: 180
            )
        )
    }
}
