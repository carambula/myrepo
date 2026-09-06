import Foundation

enum ScrollBottomProximity {
    /// Whether the end of scroll content is near the visible viewport.
    ///
    /// A missing or unloaded sentinel reports `0` and must not count as near-bottom,
    /// or show sheets auto-dismiss on open.
    static func isNearBottom(
        sentinelMinY: CGFloat,
        viewportHeight: CGFloat,
        scrollOffset: CGFloat,
        scrollThreshold: CGFloat = 100,
        bottomThreshold: CGFloat = 50
    ) -> Bool {
        guard viewportHeight > 0, sentinelMinY.isFinite, sentinelMinY > 0 else { return false }
        guard scrollOffset > scrollThreshold else { return false }
        return (sentinelMinY - viewportHeight) < bottomThreshold
    }
}
