import CoreGraphics

/// Aspect ratio helpers for the full episode player artwork slot.
/// Keeps art at its native width÷height while clamping extreme ratios so the
/// sheet chrome stays usable.
enum PlayerArtworkAspect {
    /// Fallback before the image loads (podcast art is usually square).
    static let defaultRatio: CGFloat = 1
    /// Tallest container allowed (3∶4). Taller images letterbox inside this.
    static let minimum: CGFloat = 3.0 / 4.0
    /// Widest container allowed (2∶1). Wider images letterbox inside this.
    static let maximum: CGFloat = 2.0

    /// Clamped width÷height from pixel or point size.
    static func clamped(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return defaultRatio }
        let raw = width / height
        return min(maximum, max(minimum, raw))
    }

    static func clamped(size: CGSize) -> CGFloat {
        clamped(width: size.width, height: size.height)
    }
}
