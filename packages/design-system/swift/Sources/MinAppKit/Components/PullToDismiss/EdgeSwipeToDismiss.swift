import CoreGraphics
import Foundation

/// Shared math for omnidirectional edge-swipe-to-dismiss.
/// Mirrors `packages/design-system/src/components/edgeSwipeToDismiss.js`.
public struct EdgeSwipeToDismissConfiguration {
    public var sideInset: CGFloat
    public var topInset: CGFloat
    public var bottomInset: CGFloat
    public var dismissDistance: CGFloat
    public var velocityThreshold: CGFloat
    public var minFlingDistance: CGFloat
    public var minScale: CGFloat
    public var includesBottomEdge: Bool
    public var minFlingSpeed: CGFloat
    public var maxFlingSpeed: CGFloat
    public var minFlingDuration: TimeInterval
    public var maxFlingDuration: TimeInterval
    /// Higher = closer to 1:1. ~720 lets an 80pt pull move ~71pt.
    public var bottomSwipeStiffness: CGFloat
    /// Continuous corner radius for the floating card (all four corners).
    /// Negative means unset (read the live platter). `0` is square.
    public var cardCornerRadius: CGFloat
    /// When true, the dismiss host installs a darker dim plate behind the
    /// sheet and fades it with drag progress (shared across all min apps).
    public var usesDimBackdrop: Bool

    public init(
        sideInset: CGFloat = 24,
        topInset: CGFloat = 44,
        bottomInset: CGFloat = 24,
        dismissDistance: CGFloat = 120,
        velocityThreshold: CGFloat = 900,
        minFlingDistance: CGFloat = 48,
        minScale: CGFloat = 0.92,
        includesBottomEdge: Bool = false,
        minFlingSpeed: CGFloat = 1100,
        maxFlingSpeed: CGFloat = 2800,
        minFlingDuration: TimeInterval = 0.18,
        maxFlingDuration: TimeInterval = 0.42,
        bottomSwipeStiffness: CGFloat = 720,
        cardCornerRadius: CGFloat = 0,
        usesDimBackdrop: Bool = true
    ) {
        self.sideInset = sideInset
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.dismissDistance = dismissDistance
        self.velocityThreshold = velocityThreshold
        self.minFlingDistance = minFlingDistance
        self.minScale = minScale
        self.includesBottomEdge = includesBottomEdge
        self.minFlingSpeed = minFlingSpeed
        self.maxFlingSpeed = maxFlingSpeed
        self.minFlingDuration = minFlingDuration
        self.maxFlingDuration = maxFlingDuration
        self.bottomSwipeStiffness = bottomSwipeStiffness
        self.cardCornerRadius = cardCornerRadius
        self.usesDimBackdrop = usesDimBackdrop
    }

    /// Fallback when the presentation platter has not published a radius yet.
    public static var systemSheetCornerRadius: CGFloat { MinCornerRadius.baseSheet }

    public static let `default` = EdgeSwipeToDismissConfiguration()
}

public enum EdgeSwipeToDismiss {
    public static func isOnSheetEdge(
        _ point: CGPoint,
        in size: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> Bool {
        let width = size.width
        let height = size.height
        guard width > 0, height > 0 else { return false }
        let x = point.x
        let y = point.y
        let onLeft = x >= 0 && x <= configuration.sideInset
        let onRight = x >= width - configuration.sideInset && x <= width
        let onTop = y >= 0 && y <= configuration.topInset
        let onBottom = configuration.includesBottomEdge
            && y >= height - configuration.bottomInset
            && y <= height
        return onLeft || onRight || onTop || onBottom
    }

    public enum Activation: Equatable {
        case edge
        case topOverscroll
        case bottomOverscroll
    }

    /// Once content cannot scroll farther, remaining movement can take over the sheet.
    public static func scrollLimitActivation(
        translation: CGSize,
        atTop: Bool,
        atBottom: Bool
    ) -> Activation? {
        guard abs(translation.height) >= abs(translation.width) else { return nil }
        if atTop, translation.height > 0 { return .topOverscroll }
        if atBottom, translation.height < 0 { return .bottomOverscroll }
        return nil
    }

    /// Prefer an explicit override (`0` is square), otherwise the live platter.
    /// Negative `configured` means unset.
    public static func effectiveCardCornerRadius(
        configured: CGFloat,
        platter: CGFloat
    ) -> CGFloat {
        if configured >= 0 { return configured }
        if platter > 0.5 { return platter }
        return EdgeSwipeToDismissConfiguration.systemSheetCornerRadius
    }

    /// Mild resistance so the sheet lags the finger a little.
    public static func resistOffset(
        _ offset: CGFloat,
        stiffness: CGFloat = EdgeSwipeToDismissConfiguration.default.bottomSwipeStiffness
    ) -> CGFloat {
        guard offset != 0 else { return 0 }
        let s = max(stiffness, 1)
        return offset / (1 + abs(offset) / s)
    }

    /// Bottom-overscroll follow is resisted (especially upward). Edge and
    /// top-overscroll stay 1:1 with the finger.
    public static func visualTranslation(
        _ translation: CGSize,
        activation: Activation,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> CGSize {
        guard activation == .bottomOverscroll else { return translation }
        let stiffness = configuration.bottomSwipeStiffness
        let x = resistOffset(translation.width, stiffness: stiffness)
        let y = translation.height < 0
            ? resistOffset(translation.height, stiffness: stiffness)
            : translation.height
        return CGSize(width: x, height: y)
    }

    public static func isScrollAtTop(_ offsetY: CGFloat, insetTop: CGFloat, epsilon: CGFloat = 1.5) -> Bool {
        offsetY <= -insetTop + epsilon
    }

    public static func isScrollAtBottom(
        offsetY: CGFloat,
        contentHeight: CGFloat,
        boundsHeight: CGFloat,
        insetTop: CGFloat,
        insetBottom: CGFloat,
        epsilon: CGFloat = 1.5
    ) -> Bool {
        let minY = -insetTop
        let maxY = max(minY, contentHeight - boundsHeight + insetBottom)
        let visible = boundsHeight - insetTop - insetBottom
        let scrollable = contentHeight > visible + 0.5
        if !scrollable { return true }
        return offsetY >= maxY - epsilon
    }

    public static func distance(_ translation: CGSize) -> CGFloat {
        hypot(translation.width, translation.height)
    }

    public static func progress(
        _ translation: CGSize,
        dismissDistance: CGFloat = EdgeSwipeToDismissConfiguration.default.dismissDistance
    ) -> CGFloat {
        guard dismissDistance > 0 else { return 0 }
        return min(1, distance(translation) / dismissDistance)
    }

    public static func scale(
        progress: CGFloat,
        minScale: CGFloat = EdgeSwipeToDismissConfiguration.default.minScale
    ) -> CGFloat {
        let clamped = min(1, max(0, progress))
        return 1 - (1 - minScale) * clamped
    }

    /// 1 at rest → 0 when fully dragged away. Drives dim plate strength.
    public static func backdropOpacity(progress: CGFloat) -> CGFloat {
        max(0, 1 - min(1, max(0, progress)))
    }

    public static func shouldDismiss(
        translation: CGSize,
        velocity: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> Bool {
        let dist = distance(translation)
        if dist >= configuration.dismissDistance { return true }
        if dist < configuration.minFlingDistance { return false }
        let speed = hypot(velocity.width, velocity.height)
        guard speed >= configuration.velocityThreshold else { return false }
        return translation.width * velocity.width + translation.height * velocity.height > 0
    }

    public static func flingDirection(
        translation: CGSize,
        velocity: CGSize
    ) -> CGSize {
        let speed = hypot(velocity.width, velocity.height)
        let along = translation.width * velocity.width + translation.height * velocity.height
        let useVelocity = speed >= 80 && along > 0
        let x = useVelocity ? velocity.width : translation.width
        let y = useVelocity ? velocity.height : translation.height
        let mag = hypot(x, y)
        guard mag >= 1 else { return CGSize(width: 0, height: 1) }
        return CGSize(width: x / mag, height: y / mag)
    }

    public static func dismissTranslation(
        _ translation: CGSize,
        sheetSize: CGSize,
        velocity: CGSize = .zero
    ) -> CGSize {
        let dir = flingDirection(translation: translation, velocity: velocity)
        let travel = max(hypot(sheetSize.width, sheetSize.height), 1)
        return CGSize(width: dir.width * travel, height: dir.height * travel)
    }

    public static func clampedFlingSpeed(
        _ velocity: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> CGFloat {
        let speed = hypot(velocity.width, velocity.height)
        return min(configuration.maxFlingSpeed, max(configuration.minFlingSpeed, speed == 0 ? configuration.minFlingSpeed : speed))
    }

    public static func flingDuration(
        translation: CGSize,
        velocity: CGSize,
        sheetSize: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> TimeInterval {
        let target = dismissTranslation(translation, sheetSize: sheetSize, velocity: velocity)
        let remaining = hypot(target.width - translation.width, target.height - translation.height)
        let speed = clampedFlingSpeed(velocity, configuration: configuration)
        let duration = TimeInterval(remaining / speed)
        return min(configuration.maxFlingDuration, max(configuration.minFlingDuration, duration))
    }

    /// Uniform scale so a floating sheet's width lands on the source image.
    public static func heroReturnScale(currentWidth: CGFloat, sourceWidth: CGFloat) -> CGFloat {
        guard currentWidth > 1 else { return 1 }
        return sourceWidth / currentWidth
    }

    /// Clip-only radius for the returning card. Do not bake the sheet radius
    /// into the snapshot and scale it — that only matches the tile in default
    /// mode, where 38pt happens to scale onto an 8pt art tile.
    public static func heroReturnClipRadius(from start: CGFloat, to end: CGFloat) -> (from: CGFloat, to: CGFloat) {
        (from: max(0, start), to: max(0, end))
    }

    /// Presenter scale shrinks tiles. Keep the rest-size, on-screen frame.
    public static func shouldReplaceHeroFrame(
        existing: CGRect?,
        next: CGRect,
        existingOnScreen: Bool = false,
        nextOnScreen: Bool = true
    ) -> Bool {
        guard next.width > 1, next.height > 1 else { return false }
        guard let existing else { return true }
        if next.width < existing.width * 0.97 { return false }
        if existingOnScreen && !nextOnScreen { return false }
        return true
    }

    /// Pin every sheet in a stack to the same chrome radius.
    public static func stackedSheetCornerRadius(
        _ preferred: CGFloat,
        fallback: CGFloat = MinCornerRadius.baseSheet
    ) -> CGFloat {
        preferred < 0 ? fallback : preferred
    }

    /// Fling duration from the current card frame back to the source image.
    public static func heroReturnDuration(
        from: CGRect,
        to: CGRect,
        velocity: CGSize,
        configuration: EdgeSwipeToDismissConfiguration = .default
    ) -> TimeInterval {
        let distance = hypot(to.midX - from.midX, to.midY - from.midY)
        let speed = clampedFlingSpeed(velocity, configuration: configuration)
        let duration = TimeInterval(distance / max(speed, 1))
        return min(configuration.maxFlingDuration, max(configuration.minFlingDuration, duration))
    }

    public static func transform(
        translation: CGSize,
        progress: CGFloat,
        configuration: EdgeSwipeToDismissConfiguration = .default,
        dismissing: Bool = false,
        dismissTranslation: CGSize = .zero
    ) -> CGAffineTransform {
        let x = dismissing ? dismissTranslation.width : translation.width
        let y = dismissing ? dismissTranslation.height : translation.height
        let scale = dismissing
            ? configuration.minScale
            : self.scale(progress: progress, minScale: configuration.minScale)
        return CGAffineTransform(translationX: x, y: y).scaledBy(x: scale, y: scale)
    }
}
