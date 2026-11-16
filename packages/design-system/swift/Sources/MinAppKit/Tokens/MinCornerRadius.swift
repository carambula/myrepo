import Foundation

/// Corner radius tokens for the min apps design system.
///
/// `xs`…`xl` and `artTile` follow `MinRadiusStyle.shared.mode`. `round` is a
/// circular / pill radius and is never remapped, matching navigation and
/// buttons that use `Circle` / `Capsule`.
public enum MinCornerRadius {
    /// Extra small — base 4pt. Smallest named radius on the ramp.
    public static let baseXS: CGFloat = 4

    /// Small — base 8pt.
    public static let baseSM: CGFloat = 8

    /// Medium — base 12pt.
    public static let baseMD: CGFloat = 12

    /// Large — base 16pt.
    public static let baseLG: CGFloat = 16

    /// Extra large — base 20pt.
    public static let baseXL: CGFloat = 20

    /// Art tile — base 8pt (same step as `sm`).
    public static let baseArtTile: CGFloat = 8

    /// Round / pill — 100pt. Not remapped by the radii setting.
    public static let round: CGFloat = 100

    /// Art tile corner radius. Used for artwork tiles in grids.
    public static var artTile: CGFloat { MinRadiusStyle.shared.resolve(baseArtTile) }

    /// Extra small corner radius.
    public static var xs: CGFloat { MinRadiusStyle.shared.resolve(baseXS) }

    /// Small corner radius.
    public static var sm: CGFloat { MinRadiusStyle.shared.resolve(baseSM) }

    /// Medium corner radius.
    public static var md: CGFloat { MinRadiusStyle.shared.resolve(baseMD) }

    /// Large corner radius.
    public static var lg: CGFloat { MinRadiusStyle.shared.resolve(baseLG) }

    /// Extra large corner radius.
    public static var xl: CGFloat { MinRadiusStyle.shared.resolve(baseXL) }
}
